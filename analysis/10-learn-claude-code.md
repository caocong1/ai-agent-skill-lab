# Learn Claude Code (shareAI-lab) 分析

> 分析版本：1.1 ｜ 最后更新：2026-08-23 ｜ 来源：Learn Claude Code（commit `f9e8b280`，详见 `analysis/SOURCE_INDEX.md`）
>
> 1.1 变更：上游从 **20 课重构为 17 课并整体重编号**，`s10_system_prompt` / `s11_error_recovery` / `s17_autonomous_agents` / `s18_worktree_isolation` / `s19_mcp_plugin` / `s20_comprehensive` 均已不存在，其内容被并入其他课。新增 `## 17 课重构后的编目`、`## 三课新增内容` 两节。原有的核心抽象与工程启发核对后仍成立。

这是本仓库分析的第 8 个代码项目，性质和之前 7 个有明显差异：它不是一个被实际部署的 agent SDK，而是一份 20 课渐进式教学仓库，把 Claude Code 风格 harness 的每一个机制独立成一节课、每节课配一个可单独运行的 `code.py`。前 7 个项目（Pi、OpenAI Agents JS、LangGraphJS、MCP TS SDK、Vercel AI SDK、Spring AI Examples、LangChain4j）侧重"生产级框架的设计抽象"；本仓库则相反——把所有抽象拆掉，每节课只用 200–2000 行 Python 直白复述一个 harness 机制，到 `s20_comprehensive` 才把所有机制串到一个循环里。

这份分析的目的是把它的教学性视角吸收回 `build-ai-agents`：第一是它对 **agent 与 harness 的本体论区分**——"agency 来自模型训练，harness 才是工程师的工作面"——给本仓库一直在用的"框架只是起点"提供了更锋利的哲学表达；第二是它对 **harness 内部机制的穷举式编目**（loop / tool / permission / hook / plan / subagent / skill / context compact / memory / system prompt / error recovery / task graph / background / cron / agent team / protocol / autonomous / worktree / mcp / 综合），可以反向校验本仓库 reference 是否漏覆盖；第三是它的 **教学化简实现**（cheap-first 多层 compaction、selection/extraction/consolidation 三段 memory、mailbox + claim-from-board 多 agent）直接落地了一些此前在生产框架中只看到接口、没看到端到端骨架的概念。

## 核心抽象

- **Agent = trained model；Harness = engineered environment**。本仓库把"建 agent"和"建 harness"切成两件事，并旗帜鲜明地把读者定位为 harness 工程师：你不在写智能，你在为智能搭建可工作的世界。Harness 显式由 `Tools + Knowledge + Observation + Action Interfaces + Permissions` 组成。这一区分让"过度工程 agent"的反模式有了更清晰的对照——把 if/else 与 prompt chain 当 agency，是把 harness 的工作误当成 agent 本身。
- **One loop, many mechanisms**。所有 20 课共用同一个 `while stop_reason == "tool_use"` 循环；新增能力是围绕循环挂载机制，而不是改循环。s01 的 ~130 行 loop 一直延续到 s20 的 2000 行综合实现都没有被替换。本仓库用一句话概括："The loop belongs to the agent. The mechanisms belong to the harness."
- **Trajectory 是 harness 的隐式产出**。每一次 agent 在 harness 中跑出来的行动序列既是产品行为，也是下一代模型的训练原料——这把工具/上下文/日志的脱敏义务从"安全合规"延伸到"训练数据卫生"。

## 重要模式

20 节课的每个机制都是一种独立可读、可被回译到生产框架的模式。下面按"本仓库以前覆盖薄"的优先级挑出值得吸收的部分：

- **Hook system（s04）**：在 loop 周围挂 `PreToolUse`/`PostToolUse` 等 hook 点而不改 loop 本身。本仓库之前用 Pi 的 `beforeToolCall/afterToolCall` 表达过同一思想，但没作为通用扩展机制单列。教学版强调"hook 是扩展形态，不是 loop 重写"。
- **Plan-then-execute via TodoWrite（s05）**：把"列计划"做成一个工具，agent 在执行前显式写下 todo 列表，再分步执行。它是 chain-of-thought 的工程化版本：计划被持久化为 tool result，可以被人读、被压缩、被回放。
- **Skill loading 的两层结构（s07）**：layer 1 在系统 prompt 注入 `name + 一句话描述`（廉价），layer 2 通过 `load_skill(name)` 在需要时把整份 SKILL.md 注入为 tool_result（昂贵）。这与 Pi 的 progressive disclosure 完全一致，但教学实现把"前后两次注入的 token 估计"写到了注释里，让读者能直接判断何时升级到 layer 2。
- **Cheap-first 多层 context compaction（s08）**：四层依次执行——`snip_compact`（消息条数 > 50 时截中段）→ `micro_compact`（把老的 tool_result 换成 placeholder）→ `tool_result_budget`（把大 tool 输出落盘并用句柄引用）→ `compact_history`（一次 LLM 总结）→ `reactive_compact`（API 返回 prompt_too_long 时应急压一次）。"cheap first, expensive last" 是核心原则；这种分层管线比"满了就喊 LLM 总结"既省钱又少损信息。
- **Memory 三段流程（s09）**：selection（哪些会话片段值得留）→ extraction（从片段里抽出可结构化的事实）→ consolidation（把抽出的事实合并、去重、归档到 `.memory/MEMORY.md`）。本仓库之前在 `skills/design-ai-agent/SKILL.md` 的 Memory Design 只列了"用哪几种 memory"，没拆"怎么决定写什么"。
- **System prompt 的 runtime 拼装（s10）**：按 `identity / tools / workspace / memory / …` 等 section 在每次调用前拼装，并对相同 context 缓存。这把"系统提示词"从"静态字符串"变成"按需 section 组合"，与 reference 里"keep prompts layered"是同一原则，但更具体。
- **Error recovery 三路径 + 指数退避（s11）**：
  - 路径 1：`max_tokens` 用尽 → 先升档 8K→64K（首次不 append），再 max 3 次"continuation prompt"接龙；
  - 路径 2：`prompt_too_long` → 触发 reactive compact 再重试一次；
  - 路径 3：429/529 → exponential backoff + jitter，连续 3 次 529 切换 fallback 模型。
  另有 `with_retry` 装饰器与 `RecoveryState` 跟踪。这把 reference 里"失败分级"具体化为可直接抄的工程参数。
- **Task system（s12）**：`TaskRecord` 包含 `id / subject / description / status / owner / blockedBy`，文件落盘（`.tasks/<id>.json`），并提供 `can_start / claim_task`。它把"任务图"和"loop 状态"严格分离，是后续多 agent 协作的基础。
- **Background tasks（s13）**：长耗时工具放后台线程，agent 不阻塞；完成后通过 notification queue 把结果作为新 message 注入下一轮。它给出了"agent + 异步工具"的最小教学骨架。
- **Cron scheduler（s14）**：把 trigger 从"用户输入"扩展到"时间到点"，并保持 session-scoped 持久化。它让 autonomous agent 的"自启动"具备最小落地形态。
- **Agent teams via mailbox（s15–s17）**：teammate 在独立线程里跑各自的简化 loop；通信走 `.mailboxes/*.jsonl` 文件邮箱；s16 加 shutdown handshake 与 plan approval；s17 让 teammate 不等分派，主动 `claim` 任务图里能做的工作（"自组织"）。这套实现把"多 agent"从 SDK 概念变成可独立运行的 demo，方便读者亲手感受 latency / 失败面增加。
- **Worktree isolation（s18）**：用 `git worktree` 给每个 task 起一个独立目录，`WorktreeRecord` 把 task id 绑到目录，避免并行 agent 互踩文件。这是"sandbox" 在编码 agent 场景的具体形态。
- **MCP plugin（s19）**：教学化的 MCP client，把 transport / channel routing / tool 注入到统一 tool pool；接到本地工具 namespace 后由 agent 用与本地工具一致的方式调用。

## 工程启发

- **把"agent vs harness"作为讨论的第一刀**。任何"我们要不要做 agent"的问答先回到这条：你是要训模型还是要建环境？这能直接消解"用 if/else + prompt chain 拼一个 agent"这类错位讨论。
- **20 课的清单是 harness 设计 review 的 checklist**。审一个真实 agent 项目时，可以按这 20 节问：loop / tool / permission / hook / plan / subagent / skill / compact / memory / system prompt / error / task / background / cron / team / protocol / autonomous / worktree / mcp / 综合——哪些缺、哪些过度、哪些被误并到一个抽象里。
- **多层 compaction 不止省钱，更是信息完整性策略**。"先 snip 再 micro 再 LLM 总结"明确把"廉价的结构性裁剪"与"昂贵的语义压缩"分开，避免一上来就 LLM 总结导致细节丢失。
- **memory 应该按"三段流程"建实现**，不要只决定"用哪种 memory 容器"。selection / extraction / consolidation 任何一段缺失都会让 memory 要么噪声大、要么遗忘正确事实。
- **error recovery 是 first-class 工程话题**：max_tokens、prompt_too_long、429/529 应被预先设计为三条互不相干的恢复路径，而不是一个统一 try/except。
- **trajectory 即产品**：harness 输出的行动序列既是审计资料，也是未来训练资料；脱敏与一致性 logging 要被当作"产品输出"而非"运维信息"对待。
- **教学化简实现的可移植性**：本仓库刻意省略 event bus、规则化 permission、resume/fork、worktree 生命周期与 MCP runtime（transport/OAuth/订阅）。借鉴时要先确认目标系统的非功能要求，再决定哪些机制需要从教学版补齐到生产版。

## 适用场景

- **设计阶段** 想给"agent harness"画一张 0→1 的能力清单：用本仓库 20 节作脚手架，按需选 4–8 个机制做 v1。
- **review 阶段** 想检查一个号称"自治 agent"的项目是否其实只是 prompt-chain：用 "agent vs harness"的二分法定位它真正在做什么。
- **优化阶段** 长上下文 cost/latency 失控：直接对照 s08 的 cheap-first 管线，先做 snip / micro / budget，再考虑 LLM compaction。
- **教学/培训** 给团队建 harness 工程的共同语言：本仓库的章节命名（"hook around the loop"、"plan before drift"、"context always fills up"）很适合做内部 wiki 的术语锚点。
- **不适合** 直接复制到生产环境的 mailbox/worktree/cron 代码；它们的目的是把概念讲清楚，不是高可用实现。

## 注意

- **它是 paraphrase 而不是 ground truth**：作者明确说明 mailbox JSONL 协议与各机制实现是教学版本，不代表 Claude Code 内部的实际实现细节。引用为"实现思路"可以，引用为"Claude Code 源码"不可以。
- **强观点表达**：README 对"prompt-plumbing/no-code agent platform"用了较强烈的判断。本仓库吸收时应保留其工程判断（不要把流水线伪装成 agency），但避免将这种修辞挪入 skill 文本——保持 reference 的中立、可执行风格。
- **legacy 12 课 vs 当前 20 课双轨**：仓库当前同时维护两套；如果未来追踪上游更新，要明确盯当前 `s01–s20` 而不是 `docs/` / `agents/` legacy 版（章节号会错位）。
- **教学版的 default 不能直接当生产 default**：例如 teammate 的 10 轮上限、bash 黑名单关键词的过滤策略、mailbox 文件锁；生产环境替换前必须重新评估。
- **MCP 章节是简化版本**：未覆盖 transport 完整生命周期、OAuth、资源订阅与轮询——生产实现请回到 `analysis/02-agent-framework-patterns.md` 与 MCP TS SDK。
- **作者的"agency 来自训练"立场不要被误读成"工具不重要"**。本仓库强调的恰恰相反：因为工具/上下文/边界决定了模型能不能把训练得来的能力发挥出来，harness 工程的价值才被抬高。

## 17 课重构后的编目

1.0 分析基于 20 课编目。上游现为 17 课，且不是简单删减而是**重编号 + 重新分层**：

| 现编号 | 主题 | 相对 1.0 |
| --- | --- | --- |
| s01–s09 | agent loop / tool use / permission / hooks / todo_write / subagent / skill loading / context compact / memory | 编号未变 |
| s10 | task system | 原 s12 |
| s11 | background tasks | 原 s13 |
| s12 | cron scheduler | 原 s14 |
| s13 | agent teams | 原 s15（并入 worktree 隔离）|
| s14 | MCP plugin | 原 s19 |
| **s15** | **integrated harness** | 新（取代原 s20 comprehensive，内容显著扩写）|
| **s16** | **workflow runtime** | 新 |
| **s17** | **goal loop** | 新（取代原 s17 autonomous agents）|

已消失的 `s10_system_prompt` 与 `s11_error_recovery` 不是被删掉，而是**从独立课降为集成 harness 里的一个位置**——system prompt 组装与错误恢复现在出现在 s15 的循环位点表里。这个重构方向本身是一条信息：**这两件事不是可以单独学的机制，而是循环里的固定工位**。

> 引用本仓库时请注意：`SOURCE_INDEX.md` 与 `source-map.md` 中曾指向旧编号的路径已在本轮修正。

## 三课新增内容

### s15 集成 harness：一张"组件在循环里的位置表"

s15 的价值不在于引入新机制，而在于它给出了**每个机制从循环的哪个位点进入**的完整对照表：用户输入前后的 `UserPromptSubmit` hooks、LLM 前的 cron 队列 / 后台通知注入 / 压缩管线 / memory+skills+MCP 组装、模型调用处的错误恢复、工具执行前的 `PreToolUse` + 权限、工具分发处的动态工具池组装、执行后的 `PostToolUse`、以及本轮无 `tool_use` 时的 `Stop` hooks。

本仓库此前的 harness 描述是分散的能力清单，这张表提供的是**装配顺序**。它带来四条此前没有写清的判断：

- **权限是一个 hook，不是工具执行行里的 if**。permission、日志、审计挂在同一个 `PreToolUse` 点上，lead / 一次性 subagent / 队友的调用都走这一个点。
- **不要把 MCP server 自己写的 description 当授权依据**。宿主维护一份**精确的已知只读工具名单**，名单外的 MCP 工具一律询问用户。这是一条很硬的安全判断：工具的自述来自不可信方，不能用来决定它需不需要审批。
- **只有前台用户轮次可以弹交互确认；异步轮次直接拒绝需要确认的操作**，不与主 CLI 争抢输入。这解决了一个很常见的实现 bug——后台任务弹出一个没人看得见的确认框然后卡死。
- **worktree 只改变工具的默认工作目录，不是安全沙箱**；`remove_worktree()` 保留在宿主侧、模型不可调用，破坏性移除需要另行取得用户确认。

另有三条机制细节值得记：

- **两层计划共存**：`todo_write` 是会话内的整表替换清单，task graph 是跨会话、有稳定 ID、按单条记录更新生命周期的任务文件。两者目标相近但**替换语义不同**，不能混用一套实现。
- **两种委派共存**：一次性 `task` subagent 解决上下文隔离（独立 `messages[]`，中间过程丢弃，只回摘要）；持久队友解决长期并行协作（`WORK → result → IDLE`）。队友**每次调用模型前先读收件箱**，因此直接消息与关机请求不会被连续的 tool-use 轮次饿死——这是把控制信令与工作循环解耦的具体做法。没有 assignment 的队友不能使用文件或 Shell 工具。
- **认领或释放 task 会改变 assignment version，使旧的 plan approval 失效**。这与 `analysis/18-deepseek-harness.md` 的 revisioned CAS 是同一条：授权绑定在版本上，状态一变授权自动作废。
- **cron 的一次性任务是至少一次交付**：先持久化为 `pending_delivery` 再入队，保留到包含该 prompt 的模型调用成功为止；失败放回队列，重启后重新入队。明写交付语义（at-least-once）而不是含糊其辞，是可靠性设计的基本礼貌。
- **后台命令在独立进程组中运行**，退出或 `SIGTERM` 时停掉整个组；但**另建 session 的进程可以逃逸**——这条限制被明写出来，与"worktree 不是沙箱"是同一种诚实。

### s16 workflow runtime：模型决定单步，脚本决定编排

s16 在 s15 的工具池里加了一个 `Workflow` 工具，一次 `tool_use` 跑完一整套编排。它与 `analysis/18-deepseek-harness.md` 的 workflow engine 是**同一个抽象的第二次独立出现**：在模型循环之上再加一层脚本编排，并用 journal 支持续跑。

两者在同一个安全点上也做了相同选择：**模型不提交可执行代码或元数据**。s16 的模型可见 schema 只接受 `name` / `args` / `resume_from_run_id`，脚本与元数据来自宿主管理的 registry，并在执行脚本前完成校验（DeepSeek 的说法是"`meta`/`args` 在任何脚本文本被求值之前先按纯 JSON 校验"）。

除此之外有四条独立于 DeepSeek 的贡献：

- **`parallel` 与 `pipeline` 的语义差别被说清了**：`parallel` 是**等齐屏障**（下一步需要上一阶段的全部结果时用），`pipeline` 是**每个 item 独立分阶段推进、不等齐**（item A 到第 3 阶段时 item B 可能还在第 1 阶段）。这是一个很容易被实现者混为一谈的区别。
- **稳定调用键必须来自内容哈希，不能来自完成计数器**。因为并发完成顺序不确定，用"第几个完成"当 key，两次运行的缓存就会错位。key 由 `kind|label|prompt|schema` 算稳定哈希。**这是全篇最锋利的一条**——它是任何"并发 + 可续跑"系统都会踩的坑。
- **子 agent 的输出也不可信**：`agent({schema})` 要求返回匹配 schema 的 JSON，运行时解析校验，不合法**重试一次**，仍不合法则报错。课程原文把它点成 s05"工具参数不可全信"的对偶——输入输出两侧都要校验。
- **中间结果留在变量里，不进对话历史**。这是 workflow 相对"让模型一轮轮凑"的核心成本优势，也解释了为什么它与 Code Mode / Programmatic Tool Calling（`analysis/02-agent-framework-patterns.md`）是同一族解法。

存储侧：快照 + journal + lock 三件套，新运行用**排他式文件创建**预留 runId，run lock 在整个执行与最终持久化期间持有，另一个进程无法并发 resume 同一次运行。`meta.name` 被要求是 1–64 字符的安全 slug，因为它会进入本地产物文件名——**凡是进入路径的字符串都要按路径安全校验**。

### s17 goal loop：轮次结束 ≠ 目标达成

s17 给出了本仓库长期缺失的那块拼图的最小实现：**模型不再调用工具，只代表这一轮想停；目标是否完成，交给一个独立判断器**。

实现形状是一个**会话级 Stop hook**，而不是主循环之外的第二条退出路径：

- 有 `tool_results` 就继续下一轮（与 s01 相同）；
- 没有时先跑 `evaluate_after_turn(messages)`；判定为 `block` 就把**理由作为一条 user 消息追加回同一份 `messages[]`**，继续下一轮；
- 没有活跃目标时 hook 直接放行，退出条件退化成 s01。

判断器的约束设计得很克制，也很值得抄：

- 判断器是**另一次独立的模型调用**，与干活的模型分开；
- 判断器**没有工具**，不能读文件、不能重跑测试，只能依据对话中已经出现的内容；
- 返回一个闭合三元组 `{ok, reason, impossible}`——`impossible` 给了"目标无法达成"一条独立出口，而不是让它伪装成"还没完成"从而无限循环；
- 送给判断器的内容保留最近的完整消息，单条过长时只保留首尾，避免一条工具结果占满整次判断请求。

由此推出一条对主模型的**提示词义务**：system prompt 必须要求主模型"运行验证命令后，把命令和结果明确写进对话"。判断器只能看见对话，所以**证据必须被显式写入对话才存在**。这与 `analysis/15-anthropic-long-running-agent-harness.md` 的 evidence gate 是同一条，但这里给出了它在提示词层的落地方式。

课程自己划的边界同样重要：**"Goal Loop 不是测试框架"**——它判断的是"验证结果是否已经出现在工作记录中"，不是"验证结果是否为真"。真正的验证仍由工具执行。

最后一条工程判断：**轮次预算属于主循环的全局限制，不要给 Goal 偷偷加一个固定预算**。预算应该只有一处，否则两个上限会互相掩盖。

与另外两个来源合看，这构成本轮最强的一条跨来源共识：DeepSeek Harness 的 goal domain（持久 phase + revisioned CAS + `GoalActivation` 故意不持久化）、learn-claude-code 的 s17、以及 Anthropic 的 evaluator（`analysis/19-anthropic-harness-design-long-running-apps.md`）**互不相干地得出同一个结论：完成判定必须由执行方之外的东西给出**。

## 对最终 skill 的影响

本文件推动 1.3.0 的具体改动（与 `analysis/07` 综合报告、`CHANGELOG.md` 1.3.0 一致）：

- `SKILL.md`：
  - `Architecture Rules` 首条改写为"区分 agent 与 harness"，并明确 harness 由 tools / knowledge / context / permissions / observation 组成；其余条目维持"最简优先"语义不变。
- `skills/design-ai-agent/SKILL.md`：
  - 新增 `Agent vs Harness Boundary` 小节，把 harness engineering 的五项工程职责写成 skill 的工程心智模型，并引用本文件。
  - `Loop Design` 增补"hook 扩展点（pre/post tool）在不修改 loop 主体的前提下添加策略与观测"。
- `skills/design-agent-tools/SKILL.md`：
  - `Compaction Strategy` 扩写为 cheap-first → expensive-last 多层管线（snip → micro-replace → tool-result budget → LLM summary → reactive），并把"将大 tool_result 落盘 + 句柄引用"显式写入；
  - 新增 `Memory Pipeline` 小节，把 memory 写入回读拆成 selection / extraction / consolidation 三段。
- `skills/secure-ai-agents/SKILL.md`：
  - `Review Checklist` 增"按任务隔离工作目录（worktree / sandbox dir）以避免并行 agent 互踩与高风险动作扩散"；
  - `Threat Model` 后增一条"trajectory（行动序列）作为日志与训练原料同样需要按 PII/secrets 规则脱敏"。
- `skills/test-ai-agents/SKILL.md`：
  - `Observability Events` 增"后台任务运行 id / 完成通知注入回执 / cron 触发记录"；
  - `Tool Error Strategy` 增"模型 token / 限流 / 模型不可用的三路径恢复 + 指数退避 + fallback 模型"。
- `skills/build-ai-agents/references/source-map.md`：
  - 新增 learn-claude-code 仓库行（commit + 本地路径）与"教学型来源 vs 生产框架来源"的简短说明，并补上几个核心 `s0x/code.py` 文件路径。
- `analysis/07-overall-agent-analysis.md`：
  - 跨来源共识矩阵新增 learn-claude-code 列；形态选择光谱新增"教学型 harness 实现作为学习/原型脚手架"；`后续可分析方向` 移除已落地候选并新增 Claude Code 官方文档、Anthropic Agents SDK、ReAct/Reflexion 论文。

1.1 追加：

- **轮次结束 ≠ 目标达成**：需要"做到某个可验证状态"的任务，应在轮末加一个独立完成闸（会话级 Stop hook），判定器无工具、只读对话、返回 `{ok, reason, impossible}`。
- 证据必须被显式写进对话，否则独立判定器看不见——这要落到主模型的 system prompt 里。
- 权限应挂在 `PreToolUse` 这一个点上；不要把外部工具的自述当授权依据；异步轮次不得弹交互确认。
- 固定流程用脚本编排 + journal 续跑；模型只提供名称与参数，不提供可执行代码或元数据。
- 并发 + 可续跑的缓存键必须来自调用内容的稳定哈希，不能来自完成顺序计数器。
- `parallel`（等齐屏障）与 `pipeline`（不等齐、逐 item 推进）要分清并各自命名。
