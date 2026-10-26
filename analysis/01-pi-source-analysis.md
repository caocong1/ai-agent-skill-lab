# Pi 源码分析

> 分析版本：2.0 ｜ 最后更新：2026-10-25 ｜ 来源：Pi（commit `d5b3de22`，v1.4.x 线，详见 `analysis/SOURCE_INDEX.md`）
>
> 2.0 变更（2026-10-25）：Pi 在 1.0.0（2026-10-01）把实验性 harness 整体移出 `@earendil-works/pi-agent-core`，持久化执行改由新的实验包 `@earendil-works/pi-durable` 承担。本版重写"Harness/session 层"与"持久化执行"两节（后者以 `packages/durable/docs/spec.md` 为准并引用其节号），定点修订其余各节，新增 `## v0.84 → v1.4 增量（2026-10-25 核验）`；正文按本仓库统一结构重排，原有主题节降为 `## 重要模式` 下的小节。1.1 引用的三条路径 1.0 起已失效，替代见 `## 注意`。钉住的 commit 是 1.4.0 之后的 HEAD，spec 中少量条款（§4.1 deferred commits、`Storage.commit` 的 `adopt` 回调、`readOnly`）属于尚未发布的 `[Unreleased]`。
>
> 1.1 变更（2026-08-23）：新增持久化执行 harness 一节（基于当时的 `packages/agent/docs/harness.md`）与 v0.78 → v0.84 增量。

Pi 仍是本仓库里最适合学习"编码 agent 本身如何组织"的项目：模型适配、agent loop、宿主（会话、资源、扩展、权限）分层清楚，每层都有契约级文档。2.0 刷新最重要的事实是一次拆分：1.0 起 `pi-agent-core` 只剩 `Agent`、loop 与 proxy stream，持久化执行搬进实验包 `pi-durable`，而旗舰产品——本地 CLI `pi-coding-agent`——不依赖它。同一个仓库因此给出两种宿主答案：**不做持久化执行的本地 CLI**（内存 loop + 只追加的 JSONL 会话树），和**以任务检查点为单位的持久化运行时**（规范 5,739 行的 `pi-durable`）。

它与其他来源的关系也随之改变。`analysis/18-deepseek-harness.md` 的 `model-visible ⟺ logged` 不变量，Pi 在 0.86/0.87 以自己的方式达成：system prompt 与工具声明成为 transcript 里的 system message，会话存储成为 provider 上下文的唯一来源。1.1 把 Pi（覆写当前态）与 DeepSeek（事件溯源）对立起来，这个对照需要改写（见工程启发 1）。`analysis/20-mcp-2026-07-28-revision.md` 记录的"流恢复是非目标"在 `pi-durable` 里仍然成立，只是改成了正文中的局部声明；`analysis/22-anthropic-managed-agents.md` 中可迁移到本地的那条——harness 无状态、仅凭会话存储即可恢复——`pi-durable` 给出了单进程、本地存储的完整实现。

## 核心抽象

- **包边界（npm `latest` 均为 1.4.0）**。`pi-ai`：多 provider 模型层，也是 transcript 契约的所有者；`pi-agent-core`：`Agent`、`agentLoop`、`streamProxy`；`pi-coding-agent`：CLI 宿主（`AgentSession`、`SessionManager`、resource loader、extensions，codemode / `tool_search` / MCP 作为内建扩展）；`pi-durable`（Experimental）：持久化的会话、任务与文档运行时。新增支撑包：`pi-codemode`（QuickJS 沙箱，唯一能力是调用注入的工具）、`pi-mcp`（不依赖官方 SDK 的独立 MCP client）、`pi-env`（给 `pi-durable` 用的远程 `ExecutionEnv`，经 SSH 部署的小 daemon）、`pi-telemetry`、`chord`（类型化宿主运行时与文档状态）。依赖方向是关键事实：`pi-coding-agent` 依赖 agent-core / ai / codemode / mcp / tui，**不依赖 `pi-durable`**；`pi-durable` 依赖 chord / ai / codemode / telemetry，**不依赖 `pi-agent-core`**，其 harness 只 import chord、pi-ai、pi-telemetry，生成与工具执行是自己的实现。
- **Transcript 拥有 prompt 与工具（pi-ai 0.86.0）**。provider 层只接收 `TranscriptContext`（只有 `messages`）。`SystemMessage` 带 `sections`（按名打补丁，`null` 删除）、`toolsAdded`、`toolsRemoved`；按顺序重放全部 system message 得到当前 prompt 与工具集（`getCurrentSystemPrompt()`、`getCurrentTools()`）。支持会中 system message 的模型原位接收补丁以保住前缀缓存，其余模型由 pi-ai 折叠成一条前导 system message。
- **Loop 的一轮**是一次 assistant 响应加它引发的工具调用，run 是从一次输入到最终答案的若干轮。宿主介入点：`prepareRequest`（每次 provider 请求前）、`finishTurn`（轮次定稿后、`turn_end` 前）、`prepareNextTurn`（确定有下一轮时）、`beforeToolCall` / `afterToolCall`。
- **Durable 核心规则（spec 开篇）**：Session 原子提交不可变 entries、整条 task record 与 Chord 跟踪的 documents；只有已提交状态可被观察，deferred commit 是唯一例外（§4.1）。
- **Task** 是附着在一个 conversation 上的持久状态机，按 phase 推进，每个持久步骤整体替换 `checkpoint`；状态为 `pending / running / waiting / sleeping / completing / terminal`；每个 task 都有 owner（它的 conversation 或另一个 task）。
- **一次工具调用就是一个 task（`pi.tool`）**：`call` phase 解析工具、校验、跑 `beforeTool`、提交 intent `{ phase: "execute", arguments, replay }`、执行、提交结果；`execute` phase 只会被恢复路径进入，重放规则在那里生效。

## 重要模式

### 模块边界

1.1 推荐的三分法——model adapter 只管 provider 兼容与消息格式，agent runtime 只管循环、工具调用、停止条件、事件与错误语义，host integration 管文件、权限、确认、配置、命令与 UI——在 1.4 依然成立，并被 Pi 执行得更彻底：agent-core 1.0.0 的 breaking change 移除了 `AgentHarness`、会话与存储、durable runtime、pico3、harness tools、compaction、skills、prompt templates、system prompt helpers、telemetry schema，`./node`、`./harness/*`、`./experimental/pico3` 子路径一并删除。

新增的一条：**持久化层不是 loop 之上的一层，而是与 loop 平行的另一个运行时**。v0.84 的 `harness.md` 在实现计划里写明要把现有 `agent-loop.ts` 重构成导出的 phases 并在其上建 harness；1.x 的 `pi-durable` 则自带 `pi.generation` / `pi.tool` / `pi.compaction` 三个内建 task，与 agent-core 只共享 pi-ai 与 transcript 契约。代价看得见：`packages/durable/src/harness/generation.ts` 里有"像 pi-agent-core 的 agent loop 那样记录请求的 thinking level"这类注释，两份轮次语义靠人工对齐（推论：走同样拆分的自研 harness 要为两份实现准备共享的契约测试）。

### Agent loop

`packages/agent/src/agent-loop.ts` 仍是核心学习文件。1.1 记录的要点全部仍然成立：内部用 `AgentMessage[]`，到 LLM 边界才经 `transformContext()` → `convertToLlm()` 转换；工具默认并行，任一工具声明 `executionMode: "sequential"` 则整批顺序；参数先 schema 校验再执行；`beforeToolCall` 可阻断、`afterToolCall` 可改写；结果消息按 assistant 中调用的源顺序落盘（完成事件按完成顺序发出）；一批结果全部 `terminate: true` 才提前结束；事件序列 `agent_start … agent_end` 不变。

自 `a69bef78` 以来的变化：

- **停止判定收敛到 `finishTurn`（0.87.0）**。0.84.0 刚加入的 `shouldStopAfterTurn` 在 0.87.0 删除。`finishTurn` 对正常、error、aborted 响应都会调用（后两者的决定被忽略，仍是硬退出）。返回 `{ action: "end" }` 在 `turn_end` 后结束 run，不再轮询 steering / follow-up，也不跑 `prepareNextTurn`；返回 `{ action: "continue" }` 只"保证再有一次 provider 请求"——工具结果或排队消息若本就会触发请求就算满足，否则 loop 发一次只带上下文的请求。README 明写无条件 `continue` 会死循环。
- **`prepareRequest`（0.87.0）** 在每次会话型 provider 请求前运行（含第一次），可替换上下文、模型与 thinking level，不轮询队列。coding agent 用它把会话存储的投影装成规范上下文（下节）。
- **`prepareNextTurn` 只在确定开始下一轮时运行（0.84.4）**，收尾工作移到 `agent_end`。
- **工具装载变成 transcript 声明**。`context.tools` 是可执行集合，transcript 里的 system message 声明模型可以调用什么；每次请求前 `declareToolChanges()` 比较两者，把差异写成 `toolsAdded` / `toolsRemoved` 补丁，保证重放结果恰好等于可执行集合。
- **`runToolCall()`**（`a69bef78` 时尚不存在）让"工具调用工具"走与模型发起的调用完全相同的步骤：参数修复、schema 校验、`beforeToolCall`、执行、`afterToolCall`。codemode 脚本与 MCP bridge 的嵌套调用因此不绕过权限钩子。
- 1.1 漏记、但 `a69bef78` 已有的一条：`stopReason === "length"` 的 assistant 消息里的工具调用**一律不执行**，逐个返回"参数可能被截断，请完整重发"的错误结果——流式参数由尽力而为的 JSON 修复器定稿，截断的参数可能通过校验却不完整。

核心经验不变：loop 必须事件化、边界清晰。新增一条：**轮次级的继续 / 结束决策只放在一个钩子里**，语义是"保证至少一次请求"而不是"强制再来一次"，这样它与工具结果、steering、follow-up 的正常调度合流而不叠加。

### Harness/session 层

1.1 描述的 `packages/agent/src/harness/agent-harness.ts` 已不存在（1.0 起已移除；路径上的后继是 `packages/durable/src/harness/harness.ts`，API 完全不同）。1.4 有两个宿主，回答同一组问题的方式不同。

**coding agent：`AgentSession` + `SessionManager`**（`packages/coding-agent/src/core/agent-session.ts`，interactive / print / RPC 共用）。

- 会话是 JSONL 树（`id` / `parentId`）：`/tree` 在同一文件内换分支，`/fork`、`/clone` 另起会话文件；compaction 插入摘要 entry 而保留原始 entry；离开分支时可生成 branch summary。
- **会话存储是 provider 上下文的唯一来源（0.87.0）**：直接赋值 `agent.state.messages` 不再改变后续请求历史；`AgentSession` 在 `prepareRequest` 里用 `buildSessionProjection().messages` 覆盖上下文，`context.tools` 只保留可执行实现。
- **只追加的上下文编辑（0.87.0）**：`ContextEditEntry` 以 `replacement: null` 省略、或以新内容替换某条早先 entry 对模型的贡献，原始 entry、UI、导出与用量统计都不变；编辑相对分支生效，导航到编辑之前即恢复原貌。
- **prompt 与工具随 transcript 走（0.86.0）**：首次请求持久化一条带全部 section 与工具声明的 system message，之后的变化是按名补丁，因而能跨 resume 与分支导航保留并尽量保住缓存前缀。extension 的 `context` 处理器从 0.87.0 起看不到 system message，Pi 在它们之后恢复 prompt 与工具状态（修复了过滤消息时把 prompt 与工具声明一起丢掉的缺陷）。
- 结构性操作仍要求空闲：`navigateTree()` 在 streaming 或 compaction 中直接抛错，手动 `compact()` 先 abort 当前 run，`Agent.reset()` 在活动 run 中拒绝（0.84.1），1.2.0 起 run 启动期间（含 `before_agent_start`）就算 busy。

**pi-durable：`Harness`**（`packages/durable/src/harness/harness.ts`，spec §2.2、§6）。

- conversation 句柄无状态；`submit()` 在**持久接纳**后返回而非在结算后；`requestId` 在同一 conversation 内去重，崩溃后用同一 `requestId` 重试会拿回原 submission。
- 对 busy 对话的写入不被拒绝，而是进入 `pi.inbox`，在轮次边界（`postTools` / `final`）按 ID 顺序确定性地放置；只改展示、不改模型上下文的写入立即落盘。
- 1.1 的"turn snapshot"原则在这里成为条款：generation 的 prepare 每次请求解析一次 agent，把该轮的 prompt、offered tools、model 与请求选项写进 `request` 检查点；运行中的变更在下一次 prepare 生效（§2.2、§7.1 的读者表）。

1.1 总结的"结构性操作需要 idle"现在有两种实现：**拒绝直到空闲**（coding agent）与**接纳后在边界放置**（durable inbox）。后者把结构性写入变成普通的排队 submission，顺序由边界规则决定而不依赖调用方时机（判断：持久化宿主应选后者，"拒绝"在崩溃恢复后没有人来重试）。

### Skills

- 实现位置：`packages/agent/src/harness/skills.ts`（1.0 起已移除）→ `packages/coding-agent/src/core/skills.ts`。`packages/coding-agent/docs/skills.md` 已重写，语义不变。
- 遵循 Agent Skills 规范：启动时只把 name、description 与路径放进系统提示词，任务匹配时模型再读 `SKILL.md`；`/skill:name` 强制加载；`disable-model-invocation: true` 只允许显式命令触发；`allowed-tools` 字段标为 experimental。
- 发现位置：用户 `~/.pi/agent/skills`、项目 `.pi/skills`，外加 `~/.agents/skills` 与项目 `.agents/skills`（从 cwd 沿祖先目录查找，到仓库根为止），以及 package、settings、CLI 指定目录。
- 校验：name 只含小写字母、数字、连字符且 ≤64 字符，description ≤1024 字符；格式错误或缺 description 的不加载；重名保留先发现者并告警。
- 项目级 skill 受 project trust 管控（`.pi/skills` 与项目 `.agents/skills` 都在受保护资源清单里），文档要求授信前审阅 skill 及其附带脚本。
- 在 `pi-durable` 里，skill 只是一个带 prompt section 的普通 extension；"子 agent 不该看到 skills"就是不选这个 extension，没有任何 section 需要判断自己是否运行在子 agent 里（spec §7.4）。

可复用原则沿用 1.1：名称短而稳定、description 写触发场景、大段参考放 `references/`、skill 自带的可执行脚本按供应链风险审查。

### Resource loader 与系统提示词

- `packages/coding-agent/src/core/resource-loader.ts`：每个目录取第一个存在的 `AGENTS.override.md` / `AGENTS.md` / `AGENTS.MD` / `CLAUDE.md` / `CLAUDE.MD`；先加载 agentDir 的全局文件，再按从根到 cwd 的顺序加载祖先目录；嵌在主仓库内的 linked worktree 会遮蔽主仓库的同名上下文文件，避免同一份约定加载两次。
- 加载分两遍：先以"项目不受信"加载用户级与 CLI 扩展，再由 `resolveProjectTrust` 决定是否加载项目设置、`.pi/mcp.json` 与 `.pi` 下的扩展 / skills / prompts / themes / system-prompt 文件。**上下文文件不受 project trust 管控**：除非关闭上下文加载，`AGENTS.md` 一类文件总会加载，`packages/coding-agent/docs/security.md` 要求即使拒绝授信也把其中的指令当作不可信输入。
- `packages/coding-agent/src/core/system-prompt.ts`：系统提示词变成**有序的具名 section**（`preamble`、`tools`、`rules`、`docs`、`addendum`、`project_context`、`skills`、`cwd` 与自定义 section，除 `preamble` 外都包在同名标签里），对应 transcript 中的 `SystemMessage.sections`，变化由 `diffSystemPromptSections()` 生成补丁。
- 1.1 写的"只有在读文件工具可用时才注入 skill 元数据"被细化（2.0 修订）：`read` 或 `bash` 任一被声明即注入（0.85.0 修复了只启用 bash 时 skill 不可用）；读取器被选中但被 `prepareLoadout` 隐藏、只能经 codemode 间接调用时，skill 仍注入但提示不点名任何工具（1.0.4）。原则不变——prompt 只声明当前能力能支撑的东西——只是"能力"要算上间接可达。
- 前缀缓存纪律进入实现：section 渲染必须对相同输入确定（嵌入时间戳会每轮追加补丁、击穿 provider 缓存，spec §7.4、§12）；MCP 服务器清单放在 `mcp_servers` section，变化时追加补丁而不改工具声明，codemode 的工具描述也不再随 MCP 连接变化（0.99.2）。

### Extensions 与权限

`packages/coding-agent/examples/extensions/permission-gate.ts` 与 `dynamic-tools.ts` 在两个 commit 间字节相同，1.1 的结论继续成立：危险 bash 在工具执行前的 `tool_call` 钩子上硬拦截（无 UI 时默认阻断）；工具可在会话启动或命令触发时动态注册。1.4 的变化集中在三点。

- **Pi 明确不提供内建权限系统**。根 README 写明不限制文件、进程、网络或凭据访问；`packages/coding-agent/docs/security.md` 说它不会在每次工具调用前请求批准，project trust 只决定启动时加载哪些项目资源，观察 transcript、project trust、审查改动都不构成安全边界，需要边界就用容器、VM 或沙箱。这与本仓库"权限放在工具执行边界、不靠 prompt"的结论一致，并补了一句更硬的：边界由操作系统或虚拟化提供，不由 harness 提供。
- **闸门 fail-closed 成为契约**。`user_bash` 处理器出错时阻断命令而不是回落到本地执行（0.86.0 breaking）；extensions 文档要求安全决策做不出来时 gate 处理器 fail closed；`AgentSession` 把 `tool_call` 处理器抛错转成阻断；`pi-durable` 中 `beforeTool` 抛错同样是阻断，其余 hook 抛错只报告并继续（spec §7.2、§10.1）。
- **工具的可见性、调用者与可执行性被拆开**。0.99.0 起工具有 `exposure`：`direct`（向模型声明且可被工具调用）、`model-only`（只向模型声明、不可被工具调用，用于编排工具或询问用户的工具）、`codemode`（不声明，仅脚本可调）、`deferred`（等 `tool_search` 加载）、`hidden`（注册但不可达）。`ctx.executeTool()` 发起的嵌套调用与所有 MCP 调用都经过同一套 `tool_call` / `tool_result` 处理器并携带 `parentToolCallId`，权限扩展因此覆盖脚本与 MCP。MCP `annotations`（`readOnlyHint` 等）只是未经验证的提示，供权限扩展决定确认哪些调用。`pi-durable` 用 `callers`（`model` / `tools`）与 `modelTools` 表达同一件事，并规定这些过滤只能收窄、不能扩大已启用的工具集。

`pi-durable` §12 另记了一条安全相关的 footgun：**守卫可以被选择掉**。extension 按 conversation 整体选择，没有注册表级的 hook 或 wrapper；用数组显式选择 extension 的 conversation 若漏选权限扩展，就在没有它的情况下运行（判断：按会话选择的守卫在结构上是 opt-out 的，安全守卫应装在会话与子 agent 都无法取消选择的层）。

### Subagent

- coding agent：`examples/extensions/subagent/README.md` 字节未变——子 agent 仍是隔离的 `pi` 子进程，支持 single / parallel / chain，项目级 agent 定义需要信任或确认。根 README 明说 Pi 跳过了 sub-agents 与 plan mode，它们是扩展示例而非内建功能。
- `pi-durable`（spec §7.3）：子 agent 是 **task 拥有的 conversation**。tool 在 `api.commit()` 里以 `ownership: { kind: "task", taskId }` 创建子对话，子对话一次性复制 owner 的 `pi.agent`（之后 owner 的修改不再传递）；replay-safe 的 subagent tool 重跑时先用 `scanConversations({ ownerTaskId })` 找回已有子对话，再用由 task ID 派生的 `requestId`（`subagent:${taskId}`）提交，所以重跑既不会另开一个子 agent，也不会重复投递。中止或失败的调用级联中止子对话；子对话仍有工作时，调用方停在 `completing`。常驻子 agent 由一个 background anchor task 拥有，父对话的 Esc 与 idle 等待不会越过它；每条消息由一个 background reporter task 投递，两个由 task ID 派生的 request ID 保证子对话收到一次、父对话收到一次回答。
- spec 特意写明 owner 关系**不是访问控制能力**（§2）：ownership 只用于归属、中止级联与 idle 遍历。

1.1 的原则（subagent 用于隔离上下文与工具权限；并行要求子任务独立；子 agent 只回压缩后的结论；项目级 agent 定义按不可信配置处理）不变，新增两条：**owned work 不得比 owner 活得久**、**中止向下级联且自底向上执行**（见下节）。

### 持久化执行：pi-durable

`packages/durable/README.md` 第一行是 "**Experimental.** The API changes without notice between releases."；npm 首个版本 0.0.1 发布于 2026-09-19，1.0.0 与其他包同在 2026-10-01 发布。规范 `packages/durable/docs/spec.md` 自称 normative。以下按 spec 节号记录对本仓库有用的部分。

#### 三类记录与不变量（§1–§3）

- **不可变 entries**：会话全局有序 ID，写入后不改、不复用；fork 通过 `parent.at` 截断并共享祖先 entry，不复制。
- **整条 task record**：每次状态变化整条替换。
- **Chord 跟踪的 documents**：类型化 JSON 状态，scope（session / conversation / task）决定归属与寿命，conversation 文档另声明 history（`latest` / `rewindable`）与 fork 语义（`asOf` / `current` / `initial`）；每个定义都必须显式给出 `checkpointWhen`（何时写完整 base，1.4.0 起无默认值）。内建文档：`pi.agent`（只存名字不存代码，代码在使用时按名从注册表解析）、`pi.provider`（每个 conversation 独立的 provider 侧会话 UUID）、`pi.live`（运行中的 generation 与工具进度）、`pi.inbox`、`pi.usage`。
- §1 的硬不变量里最值得抄的三条：一次 Session commit 跨所有记录原子；**外部效应永远不在 Session 的变更事务里执行**；Storage 的任何错误对打开的 Session 都是致命的，Session 自闭、重开后从已提交状态恢复（§10.1：调用抛错时是否已提交未知，所以宿主重提交要复用 `requestId`）。
- 用量：每条 `pi.assistant` / `pi.tool-result` entry 带自己的 usage，同一提交把它加进该 conversation 的 `pi.usage`；失败与中止的尝试也计入，fork 从零开始，子对话的花费只在子对话里计一次（§8.6）。

#### 任务检查点：持久化程序计数器的后继（§5.1、§5.4）

- phase handler 可以围绕一次效应做多次提交，但每个持久检查点都是整体替换；`TaskRuntime.commit()` 返回的下一状态与回调里的 entries、文档、子 task 原子提交。
- 每个 phase 之前调度器在 Session 线上跑一次 step：**phase 返回而检查点未变，任务直接 `faulted`**——"没有取得持久进展"被当作 bug，而不是重跑的理由。
- open 时残留的 `running` 改回 `pending`；task 定义在 reservation 时按名从当前注册表解析，缺失、比存储版本旧或迁移失败都让任务停在原状态并 **blocked**，永不因代码缺失而被终结；phase 边界上定义对象若被替换且能接手，就交接给新定义。
- **崩溃循环保护（1.4.0）**：open 为每个被崩溃、驱逐或重置截断的任务计一次 `restarts`（正常 close 不计），任务自己提交一个不同的新状态即清零；达到 `settings.restartLimit`（默认 5）就停放为 `blocked: restart_limit`、报告一次 `task_parked`，等宿主调用 `retryTask(id)`。spec 给的理由很具体：在下一个检查点之前稳定耗尽内存或 CPU 的工作，否则会被无限恢复、无限崩溃。

#### Effect sandwich 保留，预铸 id 不再是它的一部分（§5.1、§5.2）

§5.2 只有三行：提交 intent phase → 执行外部效应 → 提交结果或下一 phase。紧接着的一句才是重点：**在 intent phase 重开意味着效应可能已经发生**，handler 要么安全重试、要么轮询外部句柄、要么记录中断；provider 的 deferred 响应就表达为一个带句柄与下次轮询时间的持久 phase。幂等键不再由框架预铸，而是 phase 作者的责任：spec 的示例在 intent 检查点里写入 `key: newKey()`，效应侧按 key 幂等；task ID 与由它派生的 request ID 是框架提供的天然键。需要保持稳定的非确定值（随机数、时间戳、可变配置的读数）先写进 memo、检查点或 task input——memo 是存在 task 信封里的小型"先写者胜"值，候选写入与读回胜者是同一次提交（§5.2、§7.3）。

#### 按工具的重放授权：只能否决（§7.3、§8.4）

intent 提交时记录最终参数与解析出的 `replay`（缺省 `unsafe`）。重开时，**只有存储的 intent 策略与当前声明（按 `call` 时的方式重新解析）都是 `safe`，工具才重跑**：当前的 `unsafe` 可以否决存储的 `safe`，当前的 `safe` 永远不能把存储的 `unsafe` 升级，不再能解析到的工具按 `unsafe` 处理。其余情况用持久化的部分输出合成 `interrupted` 错误结果（"可能已部分执行"）并以 `failed` 结束——`failed` 本身带取消意图，这次调用拥有的、已无人监督的子对话随之被中止。实现与规范一致：`packages/durable/src/harness/tool.ts` 的 `execute` phase 条件就是 `replay === "safe" && tool?.replay === "safe"`。

三个容易漏掉的边界：

- 内建 `read` / `write` / `edit` / `bash` / `powershell` 都没有声明 `replay`，即全部 `unsafe`；声明 `safe` 的只有 `codemode` 与 `tool_search`。默认值极其保守。
- **恢复路径不重跑 `beforeTool`**，直接用存储的最终参数执行（§7.3、§8.4）。重新检查的只有工具是否仍在当前 agent 的工具集里（取消选择或卸载即等于否决）与工具自身的 replay 声明；崩溃后才装上的权限扩展、被切换的 plan-mode 文档拦不住这次重跑。对照：generation 的恢复会重跑 `beforeRequest`（§8.3）。
- 重跑时 `api.env` 按 conversation 当前的 `cwd` 重新构建，可能与第一次不同（§12）。

这条规则不是 1.x 才有：v0.84 的 `harness.md` 已写明恢复的工具只有在持久化声明与当前声明都为 `safe` 时重放，1.1 只记下了"按工具声明重放策略"这一半；1.x 把它写成显式的 veto 语义并给出实现。评估见工程启发 3。

#### 中断被诚实地表达（§2.1、§5.4、§7.3）

- 上下文推导为每个缺结果的调用合成错误结果（fork 截断处、被打断的尾部），丢弃没有前置调用的结果；`aborted` / `error` / `deferred` 的 assistant 消息不进入后续请求（§2.1）。非持久路径也有护栏：pi-ai 的 `packages/ai/src/api/transform-messages.ts` 在 provider 边界为孤立调用插入 "No result provided"。
- 结局分得很细：`aborted` 表示任务自己的 abort handler 跑过并决定了结果；`orphaned` 表示没有任何任务代码跑过（定义缺失时被中止），它启动的外部效应可能没被清理；创建者只在内存里等待、重启后不会被续上的工作用 `abandonOnRestart` 标记（1.2.0），重启后以 `abortReason: "restart"` 中止，未开始的嵌套调用得到 `abandoned`，已在执行的得到 `interrupted`。

#### 流与睡眠（§4.1、§5.6、§8.3）

- 部分回答写进 `pi.live`，但恢复从不续流：`request` phase 先把遗留的已提交 partial 转成一条 `aborted` 的 `pi.assistant` entry，再用相同的已提交消息与相同的钉住模型、thinking level、流选项**重发**。流进度是 Harness 仅有的两类 deferred commit 之一（另一类是工具运行输出）：先发布给观察者，最迟在 `settings.progress.persistWithinMs`（默认 1,000 ms）或下一次读取 `pi.live` 的提交时落盘，崩溃最多丢约一秒的流内容（此条属 1.4.0 之后的 `[Unreleased]`，此前每次 100 ms 落盘）。
- **phase 里没有 sleep（1.4.0 删除 `TaskRuntime.sleep()`）**：phase 在崩溃或 close 后从头重跑，内存里的等待会占住一个 invocation，phase 内算出的截止时间每次重跑都会后移。等待只能以 `sleepUntil(until, checkpoint)` 结束当前 phase，等待之后的工作放进下一个 phase、所需数据放进检查点；内建的重试退避与 deferred 轮询也都改成了持久 sleep。spec 随即补一句：sleep 之前的工作不是 exactly-once。
- `Harness.wake()` / `onWake` 告诉宿主何时还需要一个运行中的进程（`active` 或最早的 `at`）。spec 的示例宿主是可被驱逐的 Cloudflare Durable Object，不在本仓库范围内；可迁移的是契约本身：本地宿主可以把它交给 launchd / systemd timer 一类调度器来拉起进程、续跑到期的 sleep（推论，Pi 未提供本地示例）。

#### 结构化并发（§5.4、§5.5）

tasks 与 conversations 构成一棵所有权树，两条规则：**中止向下流**（live owner 的中止标记或 held 的非 `completed` 结局会标记它的 ordinary owned work，background task 是边界）；**owned work 不得比 owner 的完成活得久**（owner 提交终态时若仍有 live owned work，就停在 `completing`：结局已定，要等下面排空才成为 `terminal`）。中止**自底向上**执行：abort handler 只在 owned work 不再 live 后启动，因而能看到下面的最终结局；abort handler 不能创建 owned 子任务，补偿只能内联完成或交给 background task。会闭合等待图中环路的 `waiting`（`failFast` / `allSettled`）在提交时即被拒绝并指出环。

#### 嵌套调用与 codemode 的确定性回放（§7.3、§7.6）

- `api.executeTool()` 发起的嵌套调用是调用方 task 拥有的独立 `pi.tool` task，调用 ID 为 `<callId>/<key>`（缺省 key 是调用序号，1.2.0）；replay-safe 的调用方重跑时按相同顺序或相同 key 调用，会重新挂回已有的嵌套 task 而不是新建。spec 原意：**这不是 exactly-once**——被崩溃打断的嵌套调用按自己的 replay 策略重跑或返回 `interrupted`，有外部效应的 replay-safe 工具仍需自己的幂等。
- 持久化 codemode（1.2.0）：脚本是内存里的 VM 状态，靠**确定性回放**跨重启——给定相同的启动数据、时钟、种子，并按相同顺序交付相同的结果，VM 发出相同的调用。每个结果先写进 journal 再交付，重跑时按 journal 重放、按 key 挂回嵌套调用，然后继续实时执行。模块版本（`CODEMODE_MODULE_VERSION`）或 VM 指纹变了、截止时间过了、或脚本发散（调用不同或顺序不同），重跑就拒绝回放并以错误结束，用源码注释的话说，是不让升级前开始的调用被不同的代码回放。

#### 非目标被重写（§13）

新清单：没有整 Session DOM；除 deferred commit 外没有"可见但未持久"的发布；没有 Session 内核级语义事件日志；没有 session 级 rewindable 文档；没有自动检查点启发式；没有第三方视图的自动挂载；没有 CRDT / 离线多写者合并；没有任意 Chord 操作到 SQL 的翻译；没有 JSONL 全局压缩或自动修复损坏；没有早期 harness 原型的兼容层；没有在单进程内强制终止不合作的扩展代码。旧清单的"exactly-once 外部效应"与"provider 流恢复"不再列在 §13，改为正文相关处的局部声明（§5.6、§7.3、§8.3）；"单进程写"从带 fenced lease 的后端约束变成宿主责任——README："One process owns a storage at a time; there is no cross-process locking"。

#### 一致性套件（§10、`/testing`）

`@earendil-works/pi-durable/testing` 导出存储一致性套件（覆盖 memory、SQLite、JSONL；1.1.0 起要求扫描遵守 `order`）与执行环境一致性套件（1.0.3 起，1.0.4 又加了三条 `watch()` 行为），自定义 `Storage` / `ExecutionEnv` 必须通过。自定义后端的契约是可运行的测试，而不是文档里的列表。

#### 1.1 模型的历史对照

1.1 分析的是 v0.84 线的 `packages/agent/docs/harness.md`（1.0 起已移除）。补记一个事实：agent-core 0.84.0 的 CHANGELOG 写明当时的 `AgentHarness` v2 是 "compile-complete scaffold"，未完成的操作路径以 `HarnessNotImplemented` 拒绝——1.1 读的是一份领先于实现的设计规范。另更正 1.1 的一处解读：v0.84 的"预铸 id"预留的是 harness 自己的响应 entry 与 usage 行 ID（使合成的中断结果落在预留位置），并不是向外部系统查询"做了没有"的幂等键；后者是本仓库的引申（`analysis/20-mcp-2026-07-28-revision.md` 对它的引用应按此理解）。

| 1.1 术语（v0.84 `harness.md`） | v1.4 `pi-durable` |
| --- | --- |
| entries：只写一次的树 | 不可变 entries，会话全局有序 ID；fork 以 `parent.at` 共享祖先 |
| registers：可变的命名空间单元 | Chord documents（scope / history / fork 语义）+ 整条 task record |
| usage ledger：只追加的用量行 | usage 落在不可变 entry 上，同一提交汇总进 `pi.usage` 文档 |
| 持久化程序计数器：每步整体覆写 `op.state/{operationId}` | 每个持久步骤整体替换 task `checkpoint`；不推进检查点的 phase 直接 `faulted` |
| effect sandwich + 预铸输出 id | §5.2 intent phase → 效应 → 结果；不再预铸，幂等键写入检查点或由 task ID 派生 |
| `replay: "never" \| "safe"`（缺省 `never`），恢复时持久与当前声明都须为 `safe` | `replay: "safe" \| "unsafe"`（缺省 `unsafe`），显式 veto 语义并已实现 |
| lanes：共享树上的具名游标 | conversations、forks、task 拥有的子对话；中止沿所有权树级联 |
| 非目标：exactly-once、provider 流恢复、多写者（SQLite fenced lease）、复制、可变写入历史、删除 | §13 新清单；exactly-once 与流恢复改为局部声明；单写者成为宿主责任 |

## 工程启发

1. **两种持久形状回答两个问题**。"发生了什么、模型看到了什么"用只追加 + 投影：coding agent 的 JSONL 树与 `buildSessionProjection()`、durable 的 entries 与 §2.1 上下文推导，二者都用只追加的上下文编辑代替改写历史。"执行走到哪"用整块检查点（durable task）。1.1 的"Pi 覆写当前态 vs DeepSeek 事件溯源"更准确的说法是：Pi 在会话层也是事件溯源式的，只在执行层用整体替换。自研 harness 不必二选一，按问题分层。
2. **判断二：1.0 的拆分说明持久执行应放在 loop 之外、作为可选的独立运行时**。证据链：v0.84 计划把 agent-core 的 loop 重构成 phases 并在其上建 harness；1.0 反过来把整个 harness 移出核心，`pi-durable` 自带 generation / tool task、不 import agent-core，并标为 experimental；旗舰本地 CLI 到 1.4 也不依赖它，只做持久会话（只追加 transcript、resume、分支、规范上下文），被打断的工具调用由 provider 边界的合成结果兜底（推论：coding agent 恢复会话时依赖这一层）。从 0.84.0（08-06）的 lane-based Session v4 到 1.0.0（10-01）的 `pi-durable`，不到两个月持久模型的核心数据结构被整体替换一次（0.84.0 本身已替换过更早的 legacy 模型），而同期 loop 的变化都是带迁移说明的增量调整（`shouldStopAfterTurn` → `finishTurn`）。含义：loop 保持纯内存，只暴露请求、轮次、工具三类钩子；需要 resume 的宿主先做持久会话，它覆盖了大多数本地 CLI 的需求；只有进程寿命短于工作寿命时（会崩溃或被驱逐的长任务、跨重启的 sleep、常驻子 agent）才引入持久执行，并把它放在独立模块之后，允许整体重写而不触碰 loop。代价要算清：两份轮次语义需要人工对齐，持久执行还带来迁移、崩溃循环、存储一致性、单写者等一整套新问题。
3. **判断一：veto-only 重放授权是"授权不从序列化状态继承"的新实例，但只覆盖一个轴**。它把"可以不经询问再执行一次"这项许可变成"存储值 ∧ 当前值"：让工具变得不安全的代码改动胜过陈旧记录，当前代码也无权把一次按旧语义记录的调用升级为可重放；解析不到的代码按 `unsafe` 处理，codemode 再用模块版本与 VM 指纹钉住回放。这与 `skills/secure-ai-agents/SKILL.md` 和 `analysis/02-agent-framework-patterns.md` 记录的原则一致，形状上与 `analysis/18-deepseek-harness.md` 的单调 `ToolGuard`（只能否决、不能放行）相同，而且实现成本只是一个合取。边界在于：Pi 把 `beforeTool` 的决定当作持久 intent 的一部分，恢复时不重新评估，崩溃后才生效的策略变更拦不住一次 replay-safe 的重跑。Pi 的缓解是结构性的——默认全部 `unsafe`，`safe` 的只有 `tool_search`（只改 `modelTools`）与 codemode（外部效应全部经由嵌套调用发生，而新的嵌套调用会重新走 `beforeTool`）。自研时应补上：重放前重跑确定性的策略守卫，但不重新询问已消费的人工批准（批准按单次使用处理）；或把直接产生效应的工具一律声明为不可重放。
4. **中断要能被表达，措辞要诚实**。`interrupted`（可能已部分执行）、`abandoned`（未开始）、`orphaned`（没有任何任务代码跑过，效应可能未清理）、`aborted`（自己的 abort handler 决定）是不同的结局；混成一个"失败"，恢复决策与审计都会出错。
5. **可恢复的步骤里不等待**。等待是持久状态（`sleeping`），不是 `await`；否则重跑会重置截止时间并占住执行槽。
6. **恢复循环需要熔断器**。只对崩溃计数、正常 close 不计、任何持久进展清零、到阈值停放并交给人——`restartLimit` 是可以原样照抄的小机制。
7. **每一步都必须取得持久进展**。"检查点不变即 fault"把"无限重跑同一步"从运行时现象变成可检测的 bug。
8. **守卫不能是可选的**。按会话选择 extension 的模型让守卫在结构上可以被漏选（§12）；安全守卫应装在会话与子 agent 都无法取消选择的层。ownership 也不等于授权。
9. **可见、可调用、可执行是三件事**。`exposure` / `callers` / `modelTools` 只收窄不扩大；有的 provider 无法真正撤回工具声明（pi-ai README：OpenAI Responses 的 additional tools 只能用文字宣布移除），对已移除工具的调用要在执行层失败——真正的约束必须在执行边界。由此看，本仓库 `skills/design-agent-tools/SKILL.md` 中"code mode 与原生工具调用在同一轮互斥"的规则过强：Pi 的 `codemode.mode` 默认 `on`，codemode 与已声明的工具在同一轮共存，`only` 才隐藏其他工具；Pi 防止滥用靠的是每个工具显式的调用者范围（codemode 自身 `callers: ["model"]`，脚本不能再起脚本）加上两条路径共用一套钩子（判断；混用是否导致模型在两条路径间摇摆，源码中没有评测证据，待核验）。
10. **prompt 是具名 section 的补丁序列**。确定性的渲染、追加式的变化、稳定的工具描述，是前缀缓存的工程前提，与 `analysis/20-mcp-2026-07-28-revision.md` 的确定性 `tools/list` 同一条线。

## 适用场景

- **`pi-agent-core` + 自己的宿主**：应用内的进程内工具循环；持久化、权限与 UI 由宿主负责，用 `prepareRequest` 注入规范上下文，用 `finishTurn` 控制继续与结束。
- **`pi-coding-agent`**：本地 CLI 编码 agent，需要可分支的会话、扩展、MCP 与 codemode。它没有内建权限系统，需要边界时整体放进容器或沙箱。
- **`pi-durable`**：进程寿命短于工作寿命的宿主——会崩溃或被驱逐的长任务、跨重启的 sleep、常驻子 agent、需要严格结构化取消的多步效应（例如一次结账拥有多笔支付）——并且能承受实验性 API 的频繁破坏性变更。
- **不适合**：只需单次工具循环的小功能；需要稳定 API 的生产集成（`pi-durable`）；多个进程同时写同一份存储（没有跨进程锁，§13 也不做多写者合并）。

## 注意

- **实验性范围**：`pi-durable` 整包标为 Experimental，其中 Agent Events 另标 Experimental；coding agent 的 virtual models（0.99.0）与 skill 的 `allowed-tools` 字段也是实验性的。约束式采样已在 0.86.0 脱离 `PI_EXPERIMENTAL`，成为内建工具的默认行为。
- **破坏性节奏**：0.87.0 到 1.0.0 只隔十天（中间是 0.99.x），minor 版本仍带 breaking change。`pi-durable` 1.2.0 把 `ToolTaskInput` / `ToolTaskResult` 改为 tagged union 并把 `pi.tool` 升到 version 2；1.4.0 删除 `TaskRuntime.sleep()`、新增 `sleeping` 状态、取消 `checkpointWhen` 的默认值，并让 SQLite 自动迁移到 schema 2——迁移后的数据库无法被 1.3.0 及更早版本打开，部署无法回滚越过 1.4.0。
- **持久性默认值**：SQLite 为 WAL + `synchronous = NORMAL`，进程崩溃不丢提交，断电或宿主故障可能丢最新一笔；JSONL 默认不 fsync，只保证普通进程崩溃一致性，且把全部历史常驻内存；deferred commit 最多丢约一秒的流内容。
- **单写者是宿主责任**：一个存储同一时间只能由一个进程打开，`pi-durable` 不提供跨进程锁；新旧 Harness 不得同时持有同一 Session（§7.5）；只读查看用 `readOnly`。
- **恢复不重跑 `beforeTool`，并按当前 `cwd` 重建环境**（见上）。
- **钉住的 commit 在 1.4.0 之后**：spec 已包含 `[Unreleased]` 的 deferred commits 与 `Storage.commit(writes, adopt, context)`；规范以 pi-ai PR #9548 的 `SystemMessage` 契约为前提。
- **范围**：`pi-durable` 自带 IndexedDB 与 Cloudflare Durable Object 存储，README 以 Durable Object 作为可驱逐宿主的范例；云部署不在本仓库范围内，这里只吸收对本地自研 harness 同样成立的部分（存储契约、`wake()` 契约、重放与中止规则）。
- **失效路径**（1.1 引用，1.0 起不存在）：`packages/agent/src/harness/agent-harness.ts` → 后继 `packages/durable/src/harness/harness.ts`（API 不同；CLI 宿主仍是 `packages/coding-agent/src/core/agent-session.ts`）；`packages/agent/src/harness/skills.ts` → `packages/coding-agent/src/core/skills.ts`；`packages/agent/docs/harness.md` → `packages/durable/docs/spec.md` 与 `packages/durable/README.md`。

## v0.78 → v0.84 增量（1.1 记录，2.0 修订）

1.0 快照（v0.75.3）之后到 v0.84.2 的窗口里，命中本仓库关注面的四条：

- **约束式工具采样**（v0.82.0）：工具可声明 prefer / require 严格 JSON Schema 采样，或使用 Lark / regex 语法。1.1 写的"模型能力元数据会阻止向不支持的模型发出该请求、能力不足时提前失败"只对 `strict: "require"` 成立（2.0 更正）：`strict: "prefer"` 在不支持时回落为普通工具调用。0.86.0 起内建 `read` / `bash` / `powershell` / `edit` / `write` 默认 strict-prefer，可用 `constrainedSampling: false` 退出；0.99.2 与 1.2.0 又在 Anthropic 拒绝 schema 关键字或严格工具集超限时自动降级为非严格并重试一次（`require` 工具保持严格）。
- **终止性工具批次**（v0.84.1）：`BeforeToolCallResult.terminate` 让被阻断的调用也参与"整批终止"规则，不再多花一次模型调用；与 `analysis/18-deepseek-harness.md` 的 `concludeTurn()` 是同一原语。仍成立；`pi-durable` 1.4.0 把 `ToolControl.terminate` 改为 `boolean` 与之对齐。
- **可配置默认工具集**（v0.84.2）：仍成立，0.99.0 起支持 `+name` / `-name` 增量写法。
- **`AGENTS.override.md`**（v0.84.0）：按目录替换而非追加上下文文件。仍成立，是 resource loader 的首选候选。

## v0.84 → v1.4 增量（2026-10-25 核验）

日期取自各包 CHANGELOG；GitHub release notes 只覆盖 coding agent。

| 版本（日期） | 变化 | 影响本文 |
| --- | --- | --- |
| 0.84.4（08-28） | `prepareNextTurn` 只在确定开始下一轮时运行；工具结果越过自动压缩阈值时在同一 run 内先压缩再请求 | Agent loop |
| 0.85.0（09-04） | 只启用 bash 时 skill 也可用；`SessionManager.inMemory()` 可恢复外部存储的 entries | Resource loader、Harness/session |
| 0.86.0（09-19） | `TranscriptContext`：prompt 与工具声明进入 transcript，跨 resume 与分支保留；内建工具默认 strict-prefer 约束采样；`user_bash` fail-closed；prompt cache warming | 核心抽象、Resource loader、Extensions |
| 0.87.0（09-21） | 删除 `shouldStopAfterTurn`，新增 `finishTurn` / `prepareRequest` / `peekQueuedMessages()`；`ContextEditEntry`；`SessionManager` 成为规范上下文；`turn_end` / `agent_before_settle` 可执行边界；`context` 处理器看不到 system message | Agent loop、Harness/session |
| 0.99.0（09-29） | codemode（QuickJS）、`tool_search`、内建 MCP；`exposure`、`namespace`、`annotations`、`outputSchema` + `structuredContent`、`prepareLoadout()`、`ctx.executeTool()`；实验性 virtual models | Extensions 与权限 |
| 0.99.2（09-30） | MCP 默认 `codemode` exposure，codemode 描述不随服务器连接变化，服务器清单作为 `mcp_servers` section 追加；Anthropic 拒绝的 schema 关键字回落非严格 | Resource loader、v0.78 → v0.84 修订 |
| 1.0.0（10-01） | agent-core 移除整个实验性 harness；`pi-durable` 1.0.0 首发 | 全文 |
| 1.0.3–1.0.4（10-05） | durable：执行环境一致性套件、argv 形式 `exec()`、`watch()`；coding agent：被 `prepareLoadout` 隐藏的工具不再出现在规则与 skill 提示中 | Resource loader、持久化执行 |
| 1.1.0（10-07） | durable：扫描 `order`、task `startedAt` / `endedAt`、`durationMs`、首条 system message 与压缩后基线前置以保住缓存 | 持久化执行 |
| 1.2.0（10-12） | durable：带 key 的嵌套调用、`structuredOutput`、`callers` / `modelTools` / deferred 工具、`abandonOnRestart`、持久化 codemode、任何 Storage 错误都使 Session 失败；coding agent：`reachesTools`、Anthropic 严格工具集超限时非严格重试、移除未发布的 server/client/plugin 栈与对 chord 的依赖 | 持久化执行、Extensions |
| 1.3.0（10-15） | 恢复的会话保留其激活工具 | Harness/session |
| 1.4.0（10-21） | durable：持久 sleep（删除 `TaskRuntime.sleep()`）、`restartLimit`（默认 5）、`wake()` / `onWake`、`afterFailedRun`、IndexedDB 存储、单向 SQLite schema 2 迁移、`checkpointWhen` 必填；agent-core：`identity` | 持久化执行、注意 |
| 1.4.0 之后（`[Unreleased]`，已含于钉住的 commit） | durable：deferred commits（流进度最迟约 1 s 落盘）、`Storage.commit` 的 `adopt` 回调、`readOnly` 查看器 | 持久化执行 |

## 对最终 skill 的影响

1.0 / 1.1 的既有影响仍然有效（形态先行；model / tools / state / memory / approval / events 分界；schema-first 与可修复错误；预算与检查点；progressive disclosure；合成中断结果；与能力清单同等醒目的非目标清单）。1.1 的"持久化程序计数器 + 预铸 id 的 effect sandwich"与"能力不足时提前失败"两处，本轮按 2.0 的事实修订。

本轮（suite 2.3.0）实际落地：

- `skills/design-ai-agent/SKILL.md`（`## Durable Execution and Side Effects`）：intent 携带幂等键（或由持久 task id 派生），在 intent 阶段恢复时假定效应可能已发生；"发生了什么 / 模型看到什么"只追加并投影、"执行走到哪"用整任务检查点，两者分层而非二选一；不推进检查点的步骤即故障；持久执行是 loop 旁的可选运行时，只在进程寿命短于工作寿命时引入；重放策略缺省不安全、只能被当前声明否决、重放前重跑当前确定性策略检查；步骤内不等待；重启次数上限。
- `skills/implement-ts-agents/SKILL.md`：Version Reality Check 记 Pi 1.x 把持久执行移出核心；持久层清单改用 pi-durable 的词汇（去掉 lanes 与预铸 id，改为 conversations / forks / task 拥有的子对话、持久 sleep、重启上限停放），并注明 experimental。
- `skills/secure-ai-agents/SKILL.md`：重放许可"存储值 ∧ 当前值"写入单调拒绝的组合规则；重放前重跑确定性检查、人工批准单次使用；守卫装在会话、插件与子 agent 都无法取消选择的层，所有权不是授权。
- `skills/design-agent-tools/SKILL.md`：code mode 改为按工具声明调用方（互斥只是最粗的一种形式）；约束式采样区分 prefer 与 require（prefer 回落，并在 provider 拒绝 schema 时自动降级）；"上下文只追加"一节以 Pi 的 transcript 内工具声明与追加式上下文编辑为证据之一。
- `skills/test-ai-agents/SKILL.md`：恢复测试增加"记录为可重放而当前声明不可重放 → interrupted""崩溃循环停放""不推进检查点 → 故障"。
- `skills/review-ai-agents/SKILL.md`：增加"守卫可被取消选择""只凭记录的 safe 标志重放、不看当前声明与当前策略"；code mode 一项改为"调用方策略缺失或未在执行时强制"。
- `skills/build-ai-agents/references/source-map.md`：替换三条失效路径，补 `packages/durable/src/harness/tool.ts` 与 `packages/coding-agent/src/core/skills.ts`。

提议但本轮未采纳：

- 回放钉住代码版本或指纹（secure）：属于 codemode 的实现细节，留在本文。
- "可恢复步骤内的 sleep"作为独立审查项（review）：已由 design-ai-agent 的"步骤内不等待"覆盖。
- 自定义存储与执行环境必须跑一致性套件（test）：并入由 `analysis/28-claude-agent-sdk.md` 推动的"持久化适配器的一致性测试要覆盖投递语义"一条。
