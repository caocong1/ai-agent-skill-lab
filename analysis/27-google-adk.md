# Google ADK（Python）源码分析

> 分析版本：1.0 ｜ 最后更新：2026-10-25 ｜ 来源：Google, adk-python（commit `d68ca857`，v2.13.0，2026-10-23 tag，详见 `analysis/SOURCE_INDEX.md`）

Google Agent Development Kit（ADK）是 Google 的 code-first agent 框架，Apache-2.0。Python 版 `google/adk-python` 是参考实现，另有几个兄弟 SDK：Go（adk-go v2.6.0，另维护 v1.9.0 线）、TypeScript（`@google/adk` 2.3.0）、Java（adk-java v1.13.0）、Kotlin（v1.4.0，待核验），版本号据 2026-10-25 的 release 列表。2.0 于 2026-05-19 GA，把运行时改成节点图：`BaseNode` 是执行单元，`Workflow` 是按边调度子节点的节点，agent 本身也是节点。本仓库此前的生产来源都是 TypeScript（`analysis/01-pi-source-analysis.md`、`analysis/02-agent-framework-patterns.md`、`analysis/18-deepseek-harness.md`）、Java（`analysis/03-java-agent-patterns.md`）或 Rust（`analysis/16-openai-codex-harness.md`）。ADK 是第一个 Python 生产框架，也是从第一轮起就在队列里的来源。本文只分析 Python 版，而且只看本地或自托管能跑的部分；VertexAiSessionService、Vertex Memory Bank / RAG memory、Agent Engine / Cloud Run / GKE 部署（`adk deploy`）、依赖 Vertex 的评测指标、Gemini Interactions 托管 agent（`src/google/adk/agents/_managed_agent.py`）都是云端功能，不在本仓库范围。

ADK 对本仓库的价值在于它下了一个清楚的赌注：**会话事件日志是唯一的持久单位**。compaction、rewind、取消、检查点全是追加的事件。恢复不加载快照，而是重扫当前 invocation 的事件，快进已完成的步骤，并把没拿到结果的调用再派发一次。存储形态上它最接近 DeepSeek Harness 的事件溯源（`analysis/18`），而不是 OpenAI Agents JS 的序列化 `RunState` 或 LangGraph 的逐 super-step 快照（`analysis/02`）；副作用上它停在"至少一次，工具自己防重"，比 Pi 的按工具重放否决（`analysis/01`）弱一档。它有几处工程比本仓库的持久规则更强：调用完整性 HMAC、按"义务闭合"切 compaction 窗口、取消时给悬空调用封口、交换后的凭据默认不落盘、带修订号的追加。也有几处默认值更弱：没有按工具的重放策略，已落盘的审批在崩溃窗口里会被再用一次，节点重试一旦开启就默认对所有异常重试，环境模拟未命中时落到真实工具，GEPA 的验证集默认等于训练集。下文逐条给出代码位置；证据来自 `src/`、仓库自带的设计说明 `.agents/skills/adk-architecture/` 和 2026-10-25 抓取的 adk.dev 页面，没有引用 `tests/`。

## 核心抽象

- **Event 是唯一的记录与持久单位。** `Event` 继承 `LlmResponse`，主要字段：
  - `invocation_id`、`author`；
  - `branch`：`a.b@1` 形式的点分路径，用来隔离兄弟 agent 的历史；
  - `isolation_scope`：Task API 用委托调用的 id 隔离任务子 agent；
  - `node_info.path`：形如 `wf@1/child@2`，`run_id` 从路径末段派生，不单独存储；
  - `long_running_tool_ids`：一旦设置，这条事件就是 interrupt；
  - `actions`。

  `EventActions` 声明为 `extra='forbid'`，是"这条事件改变了什么"的闭合字段集：`state_delta`、`artifact_delta`（文件名→版本）、`transfer_to_agent`、`escalate`、`requested_auth_configs`、`requested_tool_confirmations`、`compaction`、`agent_state`/`end_of_agent`、`rewind_before_invocation_id`、`route`（`src/google/adk/events/event_actions.py`）。设计约定是：事件落盘后不可变；"待决还是已决"看后来有没有对应的 function response 事件，而不是翻转原事件上的标志（`.agents/skills/adk-architecture/references/interface-event.md`）。
- **State 是事件 delta 的折叠，键前缀决定作用域与寿命。** `app:` 与 `user:` 跨会话共享。`temp:` 只在本次 invocation 的内存里生效，落盘前从 delta 中剪掉（`src/google/adk/sessions/base_session_service.py`）。
- **Runner、NodeRunner、Workflow 三分。** Runner 管 invocation 生命周期、会话与插件。NodeRunner 执行单个节点：建子 Context、开 span、重试、给事件打标。Workflow 是图引擎。按 ADK 自己的说明，把 Runner 与 NodeRunner 合并会让嵌套 workflow 死锁（`architecture-runner-roles.md`）。节点与父节点之间有两条通道：`ctx` 向上传结果（output、route、interrupt_ids），事件负责持久化与流式输出。
- **App 是配置单元。** 由 `root_agent`、`plugins`、`events_compaction_config`、`context_cache_config`、`resumability_config` 组成（`src/google/adk/apps/app.py`）。其中 `ResumabilityConfig` 与 `EventsCompactionConfig` 都标了 `@experimental`。
- **本地会话服务有三种。**
  - `InMemorySessionService`：注释写明只用于测试与开发。
  - `SqliteSessionService`：基于 aiosqlite，`app_states`/`user_states`/`sessions`/`events` 四张表，事件以 JSON 存。
  - `DatabaseSessionService`：SQLAlchemy async，支持 sqlite、postgresql、mysql、mariadb、mssql。
- **插件与 agent 回调的关系。** 插件对 Runner 下所有 agent 生效，按注册顺序先于 agent 回调执行。任何回调返回非 None，就短路其余插件和全部 agent 回调（`src/google/adk/plugins/plugin_manager.py` 的 `_run_callbacks`）。
- **LlmAgent 的委托模式 `mode` 有三种。**
  - `chat`：经 `transfer_to_agent` 转交控制，不自动交回。
  - `task`：可以向用户追问，以 `finish_task` 结束后自动返回。
  - `single_turn`：不与用户交互，自动返回。

  后两种会在父 agent 上自动生成一个以子 agent 命名的委托工具（`src/google/adk/agents/llm_agent.py` 末尾的 sub-agent 包装逻辑）。

## 重要模式

### 一切修改都是追加：日志是真相源，模型上下文是投影

事实：

- **四类"修改"都实现为追加。**
  - compaction 追加一个带 `EventCompaction(start_timestamp, end_timestamp, compacted_content)` 的事件，原始事件不删（`src/google/adk/apps/compaction.py`）。
  - rewind 追加一个带 `rewind_before_invocation_id` 和反向 state/artifact delta 的事件（`src/google/adk/sessions/_rewind_utils.py`）。
  - 客户端取消追加 `error_code='INVOCATION_ABORTED'` 的封口事件（`src/google/adk/events/_abort_events.py`）。
  - 可恢复模式下的进度检查点是 `agent_state`/`end_of_agent` 事件。

  "哪些事件仍然有效"只有一个实现：`_apply_rewinds`（`src/google/adk/events/_rewind_events.py`）。源码注释说明，提示词组装与 compaction 必须共用它，否则被回退的内容会经摘要漏回提示词。
- **先持久化，再继续。** 节点调用 `_enqueue_event` 时，非 partial 事件会阻塞到 Runner 主循环把它写进会话才返回（`src/google/adk/agents/invocation_context.py`）。Runner 的顺序是：先跑插件的 `on_event_callback`，再 `append_event`，最后才 yield 给调用方（`src/google/adk/runners.py` 的 `_consume_event_queue` 与 `_process_and_append_event`）。partial 事件只流不存。因此，模型发出的 function call 事件在工具执行之前就已落盘。下文的副作用分析以这一点为前提。
- **并发写入有陈旧检测。**
  - `SqliteSessionService.append_event` 先比对存储里的 `update_time` 与内存会话的 `last_update_time`，落后就抛 `StaleSessionError`，然后在同一个提交里写三层 state 并插入事件。
  - `DatabaseSessionService` 用精确的存储修订标记代替浮点时间戳比较；在支持行锁的方言上加 `with_for_update()`；同一进程内还有每会话一把的 `asyncio.Lock`（`src/google/adk/sessions/database_session_service.py`）。
  - 会后 compaction 如果输给了并发的新一轮追加，摘要直接丢弃，不让已经答完的 invocation 失败；原始事件仍在。
- **读回的字节按不可信输入处理。** v0 schema 把 `EventActions` 存成 pickle。现在读取时用受限 unpickler，只解析重建 `EventActions` 所需的 global；旧版本曾允许进入 `state_delta` 的任意 callable 会被拒（`src/google/adk/sessions/_restricted_pickle.py`，2.8.0）。
- **反面：序列化失败会静默降级。** `state_delta` 与 `agent_state` 里不能 JSON 序列化的值，落盘时被替换成 `repr` 字符串，只打一条 warning（`event_actions.py` 的 wrap serializer）。恢复后读到的是这个字符串，而不是原对象。

判断：存储侧与 DeepSeek 的事件溯源是同一形态。区别在于，ADK 明说 LLM 上下文"不是日志的转储"，而是按角色、任务、分支编排出来的视图（`.agents/skills/adk-architecture/references/architecture-llm-context-orchestration.md`），却没有 DeepSeek 那条反向断言 `model-visible ⟹ logged`。请求处理器在请求时追加的 instruction、工具声明和 fencing 前言都不进事件日志（推论，依据 `src/google/adk/flows/llm_flows/single_flow.py` 的处理器链与 `append_instructions` 的用法）。所以在 ADK 里，"能从日志重建模型看到的内容"还要求代码与配置版本不变。

### Resume：`is_resumable` 是持久化开关，恢复靠重放日志

事实：

- **配置自己写明了"至少一次"。** `ResumabilityConfig`（`src/google/adk/apps/_configs.py`，默认 `is_resumable=False`）的 docstring 写了两条：恢复只保证至少一次，所以被恢复的工具调用必须幂等；任何临时或内存状态在恢复后都会丢失。adk.dev 的 Resume 页补充了三点：
  - 工具可能运行不止一次，购买类工具要自己检测并阻止重复运行；
  - 不要在恢复前改动已停止的 workflow，增删 agent 不受支持；
  - ADK Web 与 CLI 都不支持恢复，只能通过 `run_async(invocation_id=...)` 或 API server。
- **这个开关不决定能不能恢复，只决定持久化。** 这是 ADK 设计说明自己的定性（`architecture-workflow-resumability.md`），代码与之一致。2.0 节点路径（LlmAgent 根与 Workflow 根）总是用 function response 的 id 反查所属 invocation 并续跑，不看开关（`src/google/adk/workflow/_node_runner_utils.py`）。开关真正改变的是三件事：
  - composite agent 与 workflow 是否把 `agent_state`/`end_of_agent` 检查点写进日志。`SequentialAgent` 记 `current_sub_agent`，`LoopAgent` 另记 `times_looped`，`ParallelAgent` 记哪些子 agent 已完成。
  - LLM flow 在恢复时是否重放日志末尾那个未执行的调用。
  - BaseAgent 根的经典路径是否允许不带新消息续跑一个 invocation（`runners.py` 的 `_setup_context_for_resumed_invocation`）。
- **Workflow 写检查点，但从不读。** `_run_impl` 的开头就是 `# TODO: resume from checkpoint event.`，随后由 `ReplayManager.scan_workflow_events` 按 invocation id 重扫全部事件、重建循环状态（`src/google/adk/workflow/_workflow.py:254`）。重扫结果交给 `check_interception`（`src/google/adk/workflow/utils/_replay_interceptor.py`）：
  - 已完成的节点用记录下来的 output/route 快进；
  - 失败的节点重跑；
  - 仍在等待 interrupt 的节点保持 WAITING；
  - interrupt 只答复了一部分的节点，仅在 `rerun_on_resume=True` 时带着已答复的部分重跑。

  检查点刻意不包含 `resume_inputs`：对挂了 `auth_config` 的节点，那里面是用户发来的凭据（`_emit_node_checkpoint` 注释，2.9.0）。设计说明承认恢复成本随历史长度增长，把"读检查点而不是重放"列为方向，并列出三个未决项：检查点载荷是否完整、部分 interrupt 的语义、检查点的版本标记（长期暂停的运行可能跨越代码变更）。
- **自定义 agent 要自己做检查点。** 做法是：继承 `BaseAgentState`（`extra='forbid'`）；每完成一个可保存的步骤就调用 `ctx.set_agent_state(...)`，并 yield `_create_agent_state_event`；结束时调用 `set_agent_state(name, end_of_agent=True)`（`src/google/adk/agents/base_agent.py`、`invocation_context.py`）。
- **动态子节点的恢复键是 `node_path`（`name@run_id`）。** `run_id` 缺省是一个计数器，按 `(parent_path, node_name)` 在派发时递增（`DynamicNodeScheduler.next_run_id`，`src/google/adk/workflow/_dynamic_node_scheduler.py`）。设计说明要求子节点名确定：用时间戳、UUID 或模型输出起名，恢复时就永远找不到上一次执行，只能重跑（`interface-workflow.md`）。
- **节点重试。** `RetryConfig` 默认关闭。一旦设置，未填写的字段默认最多 5 次，`exceptions=None` 表示对所有异常重试（`src/google/adk/workflow/utils/_retry_utils.py`）。重试计数不持久化，日志明写 "retry count is not persisted across resuming"（`src/google/adk/workflow/_node_runner.py`）。

对照：

| 框架 | 持久单位 | 恢复时读什么 | 崩溃时没拿到结果的工具调用 | 授权跨恢复 |
| --- | --- | --- | --- | --- |
| ADK | 会话事件日志 | 重扫本 invocation 的事件；workflow 检查点只写不读 | `is_resumable` 下再派发（至少一次），由工具作者防重 | 交换后的凭据默认在 `temp:` 里，不跨进程；尚未被消费的审批事件恢复后直接生效（推论） |
| Pi（`analysis/01-pi-source-analysis.md`） | 整体替换的任务检查点，加原子的 Session 提交 | 读检查点 | 只有存储的 intent 策略与当前声明都为 `safe` 时才重跑，否则合成 `interrupted` | 恢复路径不重跑 `beforeTool`（Pi 自己的缺口） |
| LangGraph（`analysis/02`；另见 ADK 设计说明里的对比表） | 每个 super-step 一个 checkpoint | 载入最新 checkpoint | 被中断的节点从头重跑，幂等是节点作者的契约 | — |
| OpenAI Agents JS（`analysis/02`） | 序列化的 `RunState` | 反序列化 | 无法证明待决输出属于哪次调用时，以 `UserError` fail closed | 序列化的凭据与不安全的挂载授权，恢复时一律不信任 |

判断：ADK 的计数器在派发时分配，不在完成时分配，所以不会踩 `skills/design-ai-agent/SKILL.md` 警告的"按完成顺序计数导致缓存错位"。但它仍然是顺序键：同一父节点里一个条件分支变了，后面的计数就整体平移，比内容哈希键脆弱（推论）。

### 副作用三问：意图记录有了，恢复策略没有

按本仓库的三个问题逐条看：

1. **知道做没做。** 结构上 ADK 已经有 effect sandwich 的意图与结算两层：function call 事件在工具执行前同步落盘，并带一个稳定的 `function_call_id`（由模型给出，或由 ADK 补齐）。这正是本仓库要求的"带预铸 id 的意图记录"，而 function response 事件就是结算。缺的是恢复时怎么用它：`decide_step_resume` 只看日志里有没有结果，没有就 `REPLAY_CALLS`，从不去问外部系统"这件事发生过没有"（`src/google/adk/flows/llm_flows/core/_resume.py`）。
   - 唯一的例外是协作式取消。`abort_signal` 触发后，Runner 为每个悬空调用追加一个合成的错误 response，按 author/branch/isolation_scope 分组，使它在发起 agent 的视图里与调用配对。模块文档写明，恢复时封了口的调用不会被重放，因此用户取消之后，有副作用的工具不会再跑一次（`src/google/adk/events/_abort_events.py`，2.11.0）。
   - 未处理的异常与进程崩溃都不会走这一步。
2. **不要重复。** 框架把这件事交给工具作者。
   - 传输层做对了一件事：MCP 会话建立失败时重试一次，因为此时什么都还没发出，可以证明服务端没有执行任何东西；而工具调用在含糊的传输失败之后不自动重试，理由正是可能重复远端副作用（`src/google/adk/tools/mcp_tool/mcp_tool.py`）。
   - 节点级 `RetryConfig` 的默认却是对所有异常重试，而且没有崩溃循环保护。在 `src/` 里没有找到类似 Pi `restartLimit` 的机制；Pi 默认在第 5 次后把任务停放为 blocked。
3. **能够撤销。** rewind 只恢复会话级 state 与会话级 artifact：`app:`/`user:` state 和 `user:` artifact 都不恢复，回退点之前不存在的 artifact 写成墓碑；外部系统明确不管。它也不是原子的：代码先把旧版本 artifact 另存为新版本，再追加 rewind 事件，中途崩溃会留下"artifact 已回退、日志未回退"的状态（`_rewind_utils.py`；adk.dev Rewind 页的 Limitations 一节也写明了非原子）。ADK 也没有 LangChain4j 1.19 那样的补偿登记（`analysis/03-java-agent-patterns.md`）。

可迁移的做法（推论）：
- 恢复时重放的是日志里那条原始调用事件，只给 response 事件换新 id（`base_llm_flow.py` 的 `_replay_function_calls`）。`ToolContext.function_call_id` 取自原调用（`flows/llm_flows/tools/_caller.py` 的 `_create_tool_context`），所以它在恢复前后不变，可以直接当作下游的幂等键。
- 后端不支持幂等键时，在一个 `before_tool_callback` 插件里用同一个 id 维护"已开始"台账；再次派发时按台账合成"已中断"结果，而不是重跑。

这样就把 Pi 的按工具重放否决补到了 ADK 上。

### 审批与凭据：一次性、绑定参数，但审批从日志继承

事实：

- **确认门对所有工具生效。** 2.x 的工具管线在所有 before 回调都没作答之后，先过 `apply_confirmation_gate`，所以"需要确认"对每个工具都成立，不只对自己检查的工具（`src/google/adk/tools/_confirmation_utils.py`，`_caller.py` 的 Step 3）。需要确认而尚无答复时，记录 `requested_tool_confirmations[fc_id]`，返回一个错误结果给模型，并把它标为无需总结；否则模型会再调用一次。
- **答复先校验再执行。** 用户的答复是一条对 `adk_request_confirmation` 的 function response，`author='user'`。处理器用它重新执行原调用之前，做三项校验（`src/google/adk/flows/llm_flows/tools/_confirmation.py`）：
  - 原调用确实在历史里，并且是当前 agent 发出的；
  - 工具已注册，并且对这组参数确实需要确认（静态声明，或历史里动态请求过）；
  - 确认里携带的调用名与参数，和历史里的逐字相同。

  去重规则是：该确认之后如果已经有原调用的结果，就视为已消费。客户端重发同一条确认不会再执行一次。
- **凭据默认不落盘。** 标准流程里，OAuth 交换后的凭据写在 `temp:` 前缀的 state 里（`src/google/adk/auth/auth_handler.py`），按上文规则不落盘，进程重启后必须重新取得。`Runner` 默认不带 credential service，CLI 用的是 `InMemoryCredentialService`，同样只在内存里。例外是 experimental 的 `SessionStateCredentialService`：选用它时，最终用户的 access/refresh token 以明文写进持久化的会话 state，而会话读取接口会原样返回这份 state，它的 docstring 自己就警告"不安全"（`src/google/adk/auth/credential_service/session_state_credential_service.py`）。agent 自己配置的 API key、HTTP 密码/token、OAuth client secret，在认证请求发给客户端并持久化之前就被剥离。客户端的答复要与服务端发出的请求钉在一起比对，答复中出现从未请求过的 id 会被忽略（`src/google/adk/auth/auth_preprocessor.py`）。
- **内置 bash 工具总要确认。** `ExecuteBashTool` 对每条命令都要求确认（`src/google/adk/tools/bash_tool.py`）。

判断：
- 凭据这一半在默认配置下与本仓库"授权不从序列化状态继承"的规则一致，而且是靠 `temp:` 前缀在结构上做到的，不靠纪律。换成 `SessionStateCredentialService` 就失去了这个性质，选型时要当作一个安全决策。
- 审批这一半不一致。一条已落盘、但还没被"后续结果"消费的确认，恢复后会被直接用来执行工具，不重新询问（推论，依据处理器在每个 LLM 步之前运行、且只按"后续结果是否存在"去重）。"之后有结果即已消费"恰好在最危险的窗口失效：副作用已经发生、结果事件还没落盘时崩溃，恢复会拿同一份审批再执行一次。
- 对照 `skills/secure-ai-agents/SKILL.md` 的现有条款（人类审批只能用一次，不为重放复用）：ADK 把审批绑定到调用 id 与参数这一点做到了；单次使用靠日志判断，没有覆盖崩溃窗口。

### 会被重放的就是攻击面：调用完整性插件

事实：

- **核心里有一道闸。** 崩溃恢复只重放当前 agent 自己发出的尾部调用。原因是会话初始化接受调用方提供的事件：如果 author 为 user 的事件里被塞进一个 function call，没有这道闸的话，它会在没有模型轮次、没有来源校验的情况下被派发（`_resume.py` 的 SECURITY 注释；2.5.0 的修复："拒绝用户发出的 function call，防止绕过模型"）。
- **可选的 `ToolCallIntegrityPlugin`（2.11.0）。** 动机写在模块开头：能写会话存储的人，就能在恢复之前改掉存储下来的调用参数（`src/google/adk/plugins/_tool_call_integrity_plugin.py`）。机制：
  - 在 `on_event_callback` 为每个调用盖 `v1:` + HMAC-SHA256 戳，覆盖 app、user、session、invocation、branch、author、调用名、id 和规范化的 JSON 参数。整数值的浮点数会被归一，以抵消存储造成的数字往返。
  - 每次运行前，重算会话里所有带 id 调用的戳，不符、畸形或重复都抛错。
  - `before_tool_callback` 只放行"每个存储副本都验证通过，且名称与参数匹配其中之一"的调用；没有 id 的调用一律拒绝。
  - 无戳调用默认拒绝。设置 `allow_unstamped_calls=True` 后只记 warning，调用照样执行，文档自己说明这只报告、不阻止。
  - 支持多密钥轮换。
- **导入的历史永不执行。** 从外部导入的历史会被标为 restored，入口包括 `adk run --resume`、create-session API 和 `prepare_restored_event()`。标记时先清除事件原有的内部元数据，再打上 `__adk_internal_restored_event`；这类事件里的调用在插件之下永不执行。调用方写不进 `__adk_internal_` 前缀的元数据：它会从 `RunConfig.custom_metadata`、恢复的事件和远端 A2A 消息里被丢弃，事件离开 ADK 时也会被剥离（`src/google/adk/events/_internal_metadata.py`）。
- **插件写明了自己覆盖不到的地方。** 一是以 workflow 节点身份运行的工具，其参数来自图，而不是会话里的调用；二是 workflow 从会话恢复的节点输出。另外，它必须第一个注册，因为插件管理器在第一个返回事件的 `on_event_callback` 处就停止了。

判断：本仓库此前把序列化状态当作"不可继承的授权"处理。ADK 补上了另一个维度：**恢复时会被重新执行的持久数据就是可执行权限，必须防篡改。** 值得照抄的是它的写法：默认 fail closed、支持密钥轮换、导入事件不可执行，并把不覆盖的面写进 docstring。

### Compaction：追加摘要事件，按义务闭合切窗，先估值再付费

事实（`src/google/adk/apps/compaction.py`、`src/google/adk/flows/llm_flows/context/_compaction.py`）：

- **两种触发，至少配一对。** token 阈值是 `token_threshold` + `event_retention_size`，滑动窗口是 `compaction_interval` + `overlap_size`，各自必须成对配置。
  - token 阈值在两个时点检查：作为请求处理器在每次模型调用前检查（排在 contents 之前，见 `single_flow.py`），以及 invocation 结束后。
  - 滑动窗口只在结束后检查，按"新完成的用户 invocation 数"计数。
  - 两者都配时，只有 token 路径真正写出了摘要才跳过滑动窗口；token 达标但被判定不值得压缩时，滑动窗口照常评估。代码比 adk.dev 页面上"超过阈值即跳过滑窗"的说法更精确。
- **token 数怎么来。** 优先取最近一次由 provider 报告的 `prompt_token_count`，往回只读到上一个 compaction 事件为止，因为更早的计数描述的是已被替换的 prompt；取不到才按每 4 字符一个 token 估算。请求前的检查只认当前 agent 自己的计数，为的是避免多 agent 应用永远量到某个小子 agent 的上下文、怎么也触发不了；会后检查以根为准，不区分 agent（`agent_name=''`）。缺省摘要器在第一次需要时，由触发它的 `LlmAgent` 的模型创建，并写回共享的配置对象供之后复用。
- **窗口只在没有未闭合义务的点切。** function call 还没得到 response、工具确认或认证请求还没答复，都算未闭合。
  - 孤儿调用的出口：一个永远等不到结果的调用（处理它的进程已经死了）如果不特殊处理，会让之后每一次压缩都被卡住。所以算法第二遍把"可证明已死"的调用当作已闭合：它不在最新 invocation 里，没有任何已决 response，也不是受保护的长时调用。
  - 保留尾部时的切点：token 路径把切点前移，保证保留下来的 response 和它的调用在同一侧。
  - 组装请求时的补救：如果某个 response 的调用被压缩掉了（典型情况是恢复后才到达的长时工具结果），就把原调用事件原样重新注入，连同并行调用的 thought signature 和被压掉的兄弟 response。
- **付费前先估值。** 先用一个"零长度摘要"算出这个范围最多能省多少字符；如果不超过上一次摘要的长度，就不调用摘要模型。估值必须在调用之前：写好之后再拒绝摘要，不会移动触发点，下一轮还会为同一次调用付钱。
  - 摘要失败时只记录，继续用未压缩的历史，不结束本轮。
  - token 路径把上一份摘要作为种子放进新窗口，形成滚动摘要。
  - 范围重叠或互相包含的摘要，只保留未被包含的那些。
- **压缩前先应用 rewind，并按 `isolation_scope` 过滤**（2.13.0），被回退或被隔离的任务内容不会经摘要漏进根会话。

判断（对照本仓库"只追加、前缀稳定"的规则）：

- **存储侧完全符合只追加。** 摘要是一个带覆盖范围的新事件，原始事件全部保留，可审计、可回退。它与 `skills/design-agent-tools/SKILL.md` 要求的"显式 surface 操作"同构，都是"覆盖范围 + 替换内容"，替换只发生在投影里。
- **请求侧不是前缀稳定的，而且不止 compaction 一处。**
  - 摘要在其覆盖范围的结束时间处，被物化为一条以当前 agent 名义发出的模型消息。
  - 卸载 skill 时，历史里早先的 `load_skill` 响应（整份 SKILL.md）在请求中被改写成一句短通知。之所以改写而不是删除，是为了保住调用与响应的配对（`src/google/adk/tools/skill_toolset.py` 的 `_prune_unloaded_skill_instructions`）。
  - `EPHEMERAL` 生命周期的 skill 在加载它的那一轮结束时就释放，下一轮就会触发一次上述改写。
  - `revalidate_skills` 的文档自己写着：重述一个 skill 会让 prompt cache 失效。
- **ADK 在别处是在意前缀的。** 设置 `static_instruction` 之后，动态 `instruction` 改走 contents，以保持静态前缀逐字节稳定（见 `agents/llm_agent.py` 与 `_fencing.py` 的注释）；2.13.0 还修复了 skill 工具的顺序。

结论：日志只追加不等于请求前缀稳定。每一处请求时改写都应该在文档里写明其缓存效应。

### 2.0 图运行时与三种委托模式

事实：

- **`Workflow`。**
  - `edges` 编译成 `Graph`，按边调度，支持基于 `actions.route` 的条件路由。
  - `max_concurrency` 只限制由图调度的节点，不限 `ctx.run_node()` 的动态子节点：后者由父节点内联 await，对它们限流会死锁。
  - 节点有 `timeout`（抛 `NodeTimeoutError`，可与 `retry_config` 组合），以及 `input_schema`/`output_schema`/`state_schema`；`use_as_output` 用于委托输出。
  - `abort_signal` 提供协作式取消；被取消的 workflow 不会写 `end_of_agent`，否则会把没完成的运行记成完成。
  - 动态子节点必须被 await。脱离出去的任务，其 interrupt 无法冒泡，workflow 会把它变成 `RuntimeError`（`interface-workflow.md`）。
- **三种模式的具体机制**（`src/google/adk/tools/agent_tool.py`、`src/google/adk/workflow/_llm_agent_wrapper.py`、`src/google/adk/agents/llm/task/_finish_task_tool.py`）：
  - `chat`：子 agent 经 `transfer_to_agent` 接管对话，需要手动交回。
  - `task`：子 agent 被包成 `_TaskAgentTool`，工具名就是子 agent 名，缺省输入是 `{"request": str}`。它在一个私有上下文里运行，以委托调用的 id 作为 `isolation_scope`，可以向用户追问，并以自动追加的 `finish_task` 工具结束。`finish_task` 的参数按 `output_schema` 校验：校验失败就返回错误让模型重试，成功后提升为该 invocation 的终态 output。
  - `single_turn`：子 agent 被包成 `_SingleTurnAgentTool`，经 `ctx.run_node` 在一个以调用 id 命名的子分支上运行；它抛出的异常作为字符串结果回给父模型。
- **task 委托的几个细节。**
  - "不要与其他工具并行调用"只是追加在 task 工具描述里的一句话；代码对同一轮里的多个 task 调用是逐个顺序派发的。
  - 同一轮里既委托又调用 `finish_task` 时，`finish_task` 的结果被改写为错误，要求等委托结果到了再单独调用。
  - 每次进入时，先把以往运行里未决的 task 委托重新派发一遍，所以子 agent 层面同样是至少一次。
- **多 agent 隔离与数据围栏。** 多个 agent 共享一个会话日志，隔离靠 `branch`。别的 agent 的发言进入当前 agent 的请求时，被包在 `<<<BEGIN_QUOTED_AGENT_CONTENT>>>` 标记里，并加一段前言，声明"标记之间是数据，不是指令"；正文里出现的标记字面量会被替换掉。第三方 MCP 服务器提供的工具描述也用同样方式围栏（`_fencing.py`，2.8.0 与 2.10.0）。模块文档的定性很诚实：这只是提高门槛，不消除这一类攻击，消除的是结构歧义。
- **A2A。** `to_a2a()` 把 ADK agent 暴露为 A2A 服务（`A2aAgentExecutor`）；`RemoteA2aAgent` 消费远端 agent，远端 agent card 的描述按不可信数据处理（`src/google/adk/a2a/`）。这一层可以本地自托管，本文不展开。

判断：`finish_task` 是一个结构化的"我做完了"，只校验形状，不校验证据。按本仓库的完成判定规则，它是 turn 结束的信号，不是目标达成的判定；需要可验证终态的任务，仍然要在 task 之外放一个独立判定。

### 插件链：注册顺序加首个非 None 短路

事实（`src/google/adk/plugins/base_plugin.py`、`plugin_manager.py`、`flows/llm_flows/tools/_caller.py`）：

- 插件按注册顺序执行，并先于 agent 回调。任何回调返回非 None，就短路其余插件和全部 agent 回调。对参数、请求、响应的就地修改，会沿链传给下一个回调。
- 工具管线的顺序是：插件 before_tool → agent before_tool →（两者都没作答时）确认门 → 工具 → 插件 after_tool → agent after_tool。
- 异常走 `on_tool_error_callback`。取消也会通知它，以便释放 before 回调申请的资源，但取消本身不可被"恢复"。
- 插件抛出的异常被包成 `RuntimeError`，让本次运行失败；`on_agent_error` 与 `on_run_error` 只做通知，异常一定会被重新抛出。

判断：

- **对执行而言，这条链是单调的。** 真实工具只在所有 before 回调都返回 None 时才运行：任何一个都能拦，没有一个能强制放行。效果与 DeepSeek 的"guard 没有 allow"相同，只是靠"返回值即替代结果"的约定实现，而不是靠类型。
- **对观察与策略而言，它不是单调的。**
  - 一个返回了值的插件（缓存、mock、环境模拟）会让排在后面的审计插件、策略插件和确认门都看不到这次调用。
  - 先注册的校验插件看到的参数，可能被后注册的插件改掉之后才执行（推论）。

所以 ADK 要求完整性插件第一个注册。同理，任何策略插件都应排在所有会改参数或会作答的插件之前，并假定排在它前面的作答插件会让它失明。

### 评测：用户模拟、环境模拟与录制回放

事实：

- **指标分本地与云端两类**（`src/google/adk/evaluation/`）。
  - 本地可跑，分三种。确定性的：工具轨迹匹配（`EXACT` / `IN_ORDER` / `ANY_ORDER`）与 `response_match_score`（ROUGE-1）。LLM 评审的（评审模型可配置）：`final_response_match_v2`、各种 rubric 类指标、`hallucinations_v1`、`per_turn_user_simulator_quality_v1`。只报告、不判通过的效率指标（如工具调用次数）。
  - 云端：`safety_v1`、`response_evaluation_score` 和三个 `multi_turn_*` 指标委托给 Vertex Gen AI Eval SDK，需要 GCP 项目，不在本仓库范围。
- **用户模拟。**
  - `ConversationScenario` 由三部分组成：固定的 `starting_prompt`、模拟器必须遵循的 `conversation_plan`、可选的 persona。
  - LLM 模拟器默认用 `gemini-2.5-flash`，thinking 预算 10240；说出 `</finished>` 即结束对话。`max_allowed_invocations` 默认 20，防止 agent 与模拟器无限对聊。模拟器默认看不到工具调用（`include_function_calls=False`）（`src/google/adk/evaluation/simulation/llm_backed_user_simulator.py`）。
  - 还有一个专门评模拟器本身的指标：第一轮校验它是否说了指定的开场白，之后每轮由 LLM 判定它是否仍按计划进行，多次采样取多数；得分是发现问题之前的轮次占比（`per_turn_user_simulator_quality_v1.py`）。
- **环境模拟**（`@experimental`，`src/google/adk/tools/environment_simulation/`）。以 `before_tool_callback` 或插件的形式接入，对每个已配置的工具：
  1. 依次检查注入规则：`match_args` 子集匹配 → 概率判定 → 可选延迟（不超过 120 秒）→ 返回 HTTP 风格的错误或固定响应。
  2. 都未命中时，按 mock 策略让 LLM 生成一致的响应。生成依据有两样：从全部工具 schema 分析出的"工具连接图"（谁产生 id、谁消费 id），以及一个状态存储。还可以喂入 `environment_data`（如数据库快照）或历史 trace。

  每条注入规则有自己的随机数生成器，按 `(tool, 注入序号)` 播种（2.13.0），所以概率注入可以复现。
- **未命中时落到哪里。** 配置了注入、但没配 mock 策略的工具，未命中时返回 None，真实工具照常执行，只记一条 warning；根本没配置的工具一律真实执行。
- **`adk test` 录制回放。** `--rebuild` 用真实 agent 跑一遍用户消息并录制下来。回放时把 `BaseLlm.generate_content_async` 换成按录制内容逐条返回的 `MockModel`，invocation、event、function-call 的 id 都被确定化，比较时排除时间戳、用量等易变字段（`src/google/adk/cli/agent_test_runner.py`）。`adk conformance record/test` 是仍在进行中的规范化录制回放。

判断：

- **环境模拟会 fail-open 到真实环境。** 只要一个工具没有 mock 兜底，一次没命中的概率注入就会打到真实后端。本地 harness 的评测环境应该反过来：未配置或未命中的工具调用，在评测里直接报错。
- **mock 在确认门之前作答。** 所以被模拟的工具不会触发审批，用环境模拟跑的评测覆盖不到 HITL 路径，审批要单独测。
- **先验证模拟器，再相信多轮分数。** 这条纪律值得照搬：多轮指标的分母里，混着模拟器自己跑偏的那些轮次。
- ADK 自带录制回放式的 scripted model，满足 `skills/test-ai-agents/SKILL.md` 里"框架是否自带 scripted model"这一选型条件。

### 优化：评测结果驱动 GEPA 改 prompt 与 skill 指令（experimental）

事实（`src/google/adk/optimization/`）：

- **两个优化器。**
  - `GEPARootAgentPromptOptimizer` 只优化根 agent 的静态 `instruction`：遇到动态 instruction provider 直接报错；子 agent 的 prompt 不优化，只给警告。
  - `GEPARootAgentOptimizer`（2.3.0 起）把根 prompt 与每个 `SkillToolset` 中每个 skill 的 instructions 当作独立组件，各用一份改写提示。改根 prompt 时提示"不要去修 skill 里的指令"；改某个 skill 时提示"评测任务没用到这个 skill 就别改"，也不碰其他 skill。一个样例是否用到了某个 skill，靠"skill 名是否出现在评测数据的字符串里"来判断。
  - 候选只在内存里克隆 toolset 进行评估，结果连同验证分返回，不写回任何文件。
- **默认参数。** 优化模型 `gemini-2.5-flash`，`max_metric_calls=100`，反思小批量为 3；推理失败的样例记 0 分，而不是中止整个优化。
- **`LocalEvalSampler` 的数据处理。**
  - 不提供 `validation_eval_set` 时，用训练集做验证。
  - 训练集与验证集的 id 重叠时，只打一条 warning（"WILL cause aliasing issues"）。
  - 送进反思的数据包括：每个样例的用户输入、agent 回复、工具调用与返回、各项指标的分数与通过状态、`conversation_scenario`，以及有参考答案时的 `expected_invocation`。不包括评审理由。

判断（对照 `analysis/13-skillopt.md`）：

- **与 SkillOpt 一致的三点：** 不把评审理由喂给优化器；组件化地分别改 prompt 与 skill 指令；只返回候选，不自动采纳。这与 SkillOpt 的"优化器反馈边界"和 staged adoption 方向一致。
- **低于本仓库纪律的四点：** 验证集默认等于训练集；重叠只警告；没有测试集；反思输入里带参考答案，等于把答案交给了改写者。这些都低于 `skills/optimize-agent-skills/SKILL.md` 的数据划分要求。
- **可以直接借用的是组件化：** 让核心 prompt 管"何时加载哪个 skill"，让 skill 指令只管 skill 自己，改写时互不越界。

### 持久化执行集成与兄弟 SDK

- **Temporal / DBOS / Restate / Dapr。** 事实：v2.13.0 的 `src/`、仓库内文档和 CHANGELOG 都没有任何 Temporal、DBOS、Restate 的代码或条目。adk.dev 的集成目录（2026-10-25 抓取的 llms.txt 索引）列出了 "Temporal plugin for ADK"、"DBOS plugin for ADK"、"Restate plugin for ADK" 与 "Dapr plugin for ADK" 四个页面。这些集成把什么变成持久步骤、是否要求确定性、如何与 ADK 自身的 resume 共存，本轮因网络中断没能读到页面，**待核验**。推论：它们由第三方包以插件形态接入，说明 ADK 核心把"持久化执行引擎"当作可替换的外部组件，而不自己承诺 exactly-once。这几种引擎的服务端是否都能自托管、许可如何，同样待核验。
- **兄弟 SDK 的能力面并不对齐**（据 2026-10-25 抓取的 adk.dev 页面）。Resume 只标注支持 Python（v1.16.0 起）与 Kotlin（v0.1.0 起）。Compaction 五种语言都有，但配置形状不同：TypeScript 配在 `LlmAgent` 的 `contextCompactors` 上，示例只有 token 阈值形状；Go 配在 runner 配置上。跨语言移植 ADK 的设计时，要按语言逐项核对能力面，不能以 Python 为准推断。

## 工程启发

- **把"可恢复"开关读成"至少一次"。** 靠重放日志实现的 resume，会把每一个没有落盘结果的调用再派发一次。上线前列出所有有副作用的工具，逐个回答"被调用两次会怎样"。ADK 的答案是工具作者自己负责；本仓库的答案是按工具声明重放策略，且默认不可重放。
- **意图记录已经免费拿到，缺的是恢复策略。** 凡是"先落盘调用事件、再执行工具"的框架，都已经具备 effect sandwich 的意图与结算两层。把调用 id 当作下游幂等键，再在 before_tool 层用同一个 id 维护"已开始"台账，就能把"至少一次"升级为"知道做没做"。
- **协作式取消与崩溃是同一件事的两半。** ADK 为取消合成错误结果，既保住调用与结果的配对，又阻止重放。自研 harness 应该让崩溃恢复对不可重放的工具走同一条路径，而不是只在用户按下取消时才做对。
- **恢复时会重新执行的持久数据要防篡改。** 会话存储是一个写入面。对恢复时可能执行的调用，盖覆盖身份与参数的 HMAC，默认拒绝无戳调用，导入的历史永不执行，并写明哪些面不覆盖。
- **压缩是带范围的追加事件，切点必须义务闭合。** 不要在调用还没得到结果、确认或认证还没答复的地方切。给孤儿调用一个"可证明已死"的出口，否则一个死调用会永久卡住压缩。调用摘要模型之前先估值，不值得就别付钱。与并发写入冲突时丢弃摘要，而不是让已完成的轮次失败。
- **日志只追加不等于请求前缀稳定。** 把每一处请求时改写（摘要物化、卸载 skill 时改写早期响应、按轮过期的 skill）连同它的缓存效应写进能力文档。
- **单次审批要在崩溃窗口之前消费。** "之后有结果即已消费"在"副作用已发生、结果未落盘"时失效。应在执行前把审批标为已用，并与意图记录在同一次提交里完成；恢复时据此决定是重放，还是合成中断结果。
- **插件链的短路既是保护，也是盲区。** 真实执行是单调的，观察与策略不是。策略与完整性检查要排第一；排在任何作答型插件之后的检查，都要假定会被绕过。
- **评测环境默认关死。** 环境模拟、mock、录制回放都应该让未覆盖的工具调用报错，而不是打到真实后端。多轮评测先验证用户模拟器，再相信分数。
- **优化回路的验证集不能默认等于训练集，参考答案也不进反思输入。**

## 适用场景

- Python 服务里需要多 agent 编排、HITL 与本地持久化（SQLite 或 Postgres）的团队。模型可以走 Gemini、Anthropic，或经 LiteLLM 接入其他 provider，包括本地模型。
- 想在框架内直接拿到评测设施（用户模拟、环境模拟、录制回放、GEPA）的团队。
- 研究"事件日志是唯一持久单位"这种设计及其代价：恢复成本随历史增长，检查点需要版本标记。
- **不适合：**
  - 依赖框架恢复来保护不可逆副作用（支付、下单、外发通知），又无法给下游加幂等键；
  - 要求 exactly-once；
  - 要求请求严格只追加、前缀稳定，又不愿逐处处理请求时改写；
  - 只想要一个最小的 tool loop，此时 `analysis/17-mini-swe-agent.md` 的形态更合适。

## 注意

- **关键能力仍是 experimental。** `ResumabilityConfig`、`EventsCompactionConfig`、环境模拟和两个 GEPA 优化器都带 experimental 标记，adk.dev 也把工具确认标为 experimental。`src/google/adk/workflow/` 下全是下划线模块；按仓库自己的架构说明，这些名字可以不经主版本变更就改动（`.agents/skills/adk-architecture/SKILL.md`）。
- **文档与代码有出入时，以代码为准。**
  - `interface-event.md` 说后台 compaction "可能改写或丢弃旧事件"，而本地三种会话服务里的 compaction 只追加。
  - adk.dev 的确认页把 `DatabaseSessionService` 列为不支持，但源码里没见到对应的限制（待核验）。
  - 环境模拟页写默认模型是 `gemini-flash-latest`，代码默认是 `gemini-2.5-flash`。
  - compaction 页对两种触发优先级的描述比代码粗。
- **默认持久性的边界。** `InMemorySessionService` 只用于测试与开发；`temp:` state 和默认流程里的 OAuth 交换结果都不跨进程，但选用 `SessionStateCredentialService` 会把用户 token 明文写进持久 state；不可 JSON 序列化的 state 值会被静默替换成 `repr`。
- **`ExecuteBashTool` 的默认值**（`src/google/adk/tools/bash_tool.py`）：
  - 命令白名单默认是 `("*",)`；
  - 不经 shell 执行，运算符作为字面参数传入，`blocked_operators` 默认为空；
  - 可选 rlimit，超时 30 秒后杀掉整个进程组；
  - 继承父进程的完整环境变量；`workspace` 只是 cwd，不是沙箱。
- **通用确认门只把谓词返回值恰为 `True` 视为需要确认。** `FunctionTool` 与 `McpTool` 在自己的 `run_async` 里还有一次真值判断兜底，自定义的 `BaseTool` 子类没有。
- **并行调用的连带取消。** 并行调用中一个失败，会取消它的兄弟调用（见 `on_tool_error_callback` 的文档）。被取消的调用没有结果事件，在可恢复的 invocation 里按前文规则会被再派发（推论，未用测试核实）。

## 对最终 skill 的影响

本轮（suite 2.3.0）实际落地：

- `skills/secure-ai-agents/SKILL.md`：恢复时会被重新执行的已存调用要盖完整性戳，未盖戳或导入的历史一律不执行；一次性审批在工具运行前、与 intent 记录同一个提交里标记为已用（否则崩溃窗口里同一审批会再授权一次）。
- `skills/design-agent-tools/SKILL.md`：只追加的存储不等于稳定的请求前缀，请求时的拼接与改写都要列出其缓存影响；压缩只在没有未完成义务（工具调用、待确认、待授权）的位置切分。
- `skills/test-ai-agents/SKILL.md`：环境模拟中未配置或未匹配的调用必须失败而不是落到真实系统，每个注入单独设种子，审批路径单独测试（mock 可能跳过确认闸），多轮分数之前先验证模拟用户。
- `skills/optimize-agent-skills/SKILL.md`：检查优化器默认值（验证集可能默认等于训练集、重叠只告警），参考答案不进入反思输入。
- `skills/review-ai-agents/SKILL.md`：反模式增加"至少一次重放的框架上开了 resume 而工具不幂等""有副作用的步骤开了无异常过滤的重试""resume 或缓存键来自 UUID、时间戳或模型输出""策略或完整性插件注册在会自行应答调用的插件之后"。
- `skills/design-ai-agent/SKILL.md`：框架的 resumable 标志在读过其恢复路径之前按至少一次重放对待。
- `skills/build-ai-agents/SKILL.md`：路由表新增 Python 一行，指向设计、工具与测试三个 skill 与 source map 里的框架路径。
- `skills/build-ai-agents/references/source-map.md`：登记克隆 `d68ca857`（v2.13.0）与关键文件路径。
- `analysis/07-overall-agent-analysis.md`：把"事件日志是唯一持久记录、恢复即至少一次重放"记为第三种恢复模型。

提议但本轮未采纳：

- 新建 `implement-python-agents`：按本文自己的判断，只有一个 Python 生产来源不足以归纳，等第二个 Python 框架分析落地再建（候选：deepagents、Microsoft Agent Framework、Pydantic AI）；本文给出的种子规则（`aclosing` 关闭异步生成器、持久化模型声明 `extra='forbid'`、回调不得吞掉 `CancelledError`）届时并入。
- 把"只重放事件日志"作为第三种恢复模型写进 `design-ai-agent`：受体积预算限制，只落地了"resumable 按至少一次对待"一句，完整论述留在本文与 07。
- 取消与崩溃恢复按同一方式处理（合成 interrupted 结果）：已由既有的"不可重放的工具合成 interrupted 结果"覆盖。
