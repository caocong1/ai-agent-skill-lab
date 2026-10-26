# Agent Framework Patterns

> 分析版本：1.2 ｜ 最后更新：2026-10-25 ｜ 覆盖来源：OpenAI Agents JS / LangGraphJS / Vercel AI SDK / MCP TypeScript SDK ｜ 版本见 `analysis/SOURCE_INDEX.md`
>
> 1.2 变更：新增 `## 2026-10 版本事实与新抽象（2026-10-25 核验）`。四个来源都在 2026-10-25 re-snapshot 的 commit 上直接读文件核验（1.1 只读了 release 正文）。四处已经不成立的表述就地更正：MCP 快照说明、"单体包不再前进"、"Code Mode 与原生 tool loop 互斥"、Pi 重放策略的取值。架构选择表随之调整。
>
> 1.1 变更：新增 `## 2026 年中的版本事实与新抽象`。原有各节的模式描述核对后仍成立，但**版本面已大幅移动**——Vercel AI SDK v7 转正、OpenAI Agents JS 走到 v0.17、MCP TS SDK v2 换了包名。新节记录这些事实与它们带来的三个新抽象；旧节保留为形态层描述。

这一节把 OpenAI Agents JS、LangGraphJS、Vercel AI SDK 和 MCP TypeScript SDK 放在一起比较。它们解决的问题不完全相同：OpenAI Agents JS 更像标准 agent SDK，LangGraphJS 更像 durable workflow/graph runtime，Vercel AI SDK 更偏 TS 应用和流式 UI，MCP 是 agent 能力协议。

1.2 这一轮，四个来源有两个共同方向。第一，它们都在收紧"从序列化状态或外部输入取得权限与控制流"的路径，延续了 `analysis/01-pi-source-analysis.md` 的按工具重放策略和 `analysis/18-deepseek-harness.md` 的 `GoalActivation` 不持久化。第二，"谁可以调用这个工具"从模式级开关下放成了逐工具声明，这直接修正了本仓库从 `analysis/18-deepseek-harness.md` 引出的 Code Mode 规则。MCP 侧的协议背景见 `analysis/20-mcp-2026-07-28-revision.md`。

## OpenAI Agents JS

适合学习标准 TS agent SDK 应该如何暴露 API。

核心抽象：

- `Agent`: 名称、instructions、model、tools、handoffs。
- `tool`: 名称、描述、schema、execute。
- `run`: 执行 agent，并处理 tool loop、handoff、guardrail、session、trace。
- `RunState`: 支持 human-in-the-loop 的中断、持久化、恢复。
- agent-as-tool: 把专业 agent 包成父 agent 的工具。

重要模式：

- tool 定义要 schema-first，通常用 Zod。
- tool approval 可以让危险工具先返回 interruption，再由外部系统 approve/reject。
- handoff 适合“移交控制权”，agent-as-tool 适合“委托子任务并返回结果”。
- 并行不是神秘机制，很多场景直接 `Promise.all(run(...))` 后合成即可。

工程启发：

- SDK 的 `run.ts` 应该是 orchestration facade，复杂细节下沉到 run loop、tool、guardrail、session 模块。
- HITL 不能只靠 UI 状态，必须能把 run state 序列化并恢复。（1.2 补：序列化的 run state 本身不经认证，等同于执行权限，必须由可信侧保管并单次消费，见下文"新模式一"。）
- approval 的输出要回到模型上下文，让模型知道工具被拒绝或被批准。

## LangGraphJS

适合学习“agent 不是单一循环，而是可回放、可中断、有状态图”的场景。

核心抽象：

- `StateGraph`: 节点和边构成明确流程。
- `MessagesAnnotation`: 常见的消息状态。
- `ToolNode`: 统一执行工具调用。
- `MemorySaver`/checkpointer: 每个 super-step 后保存状态。
- `Command`: 用于 resume、goto、跨父图 handoff。（1.2 注：1.4.21 起只认 `new Command(...)` 构造的实例，形似 Command 的普通 JSON 一律按 state 处理，见下文"新模式三"。）

适用场景：

- 多步骤任务需要 checkpoint 和 replay。
- 人工审批、人类输入或外部事件会打断流程。
- 需要查看历史状态、fork 状态、从某一步恢复。
- 多 agent 之间有明确 supervisor 或 swarm handoff。

工程启发：

- ReAct loop 适合简单自治，graph 适合可控流程。
- 如果业务有合规、审批、长耗时、失败重试，优先考虑 durable graph/workflow。
- handoff 可以建模为特殊 tool，但本质是控制流转移，不只是文本返回。

## Vercel AI SDK

适合学习 TS/Next 应用层 agent，尤其是流式 UI 和前端集成。

核心抽象：

- `ToolLoopAgent`: in-memory tool loop agent。
- `tool`: schema-first tool，可支持 async generator 输出中间状态。
- `runtimeContext`: agent 共享运行时状态。
- `toolsContext`: 每个工具独立的敏感上下文，例如 API key、tenant、权限。
- `stopWhen`/`prepareStep`: 控制循环停止、动态工具、动态模型、消息压缩。
- `toolApproval`: 手动或自动审批。
- `WorkflowAgent`: durable/resumable agent，运行在 workflow 中。（1.2 注：它由独立版本线的 `@ai-sdk/workflow` 提供，2.x 起要求 Workflow 5。）
- `createAgentUIStreamResponse`: 把 agent 流转换为 UI 消息流。

适用场景：

- Next.js/React/Vue/Svelte/Angular 应用要快速构建 agent UI。
- tool output 需要流式显示。
- 简单 agent 不需要独立 durable runtime。
- 生产长任务需要迁移到 `WorkflowAgent` 或其他 durable workflow。

工程启发：

- 默认 step limit 是必要的安全措施；移除 step limit 要非常谨慎。（1.2 注：默认值因入口而异，`WorkflowAgent.stream()` 没有默认上限，见下文"新模式五"。）
- `prepareStep` 是做上下文压缩、动态工具选择、模型升级的合理位置。
- 敏感上下文不要塞进 prompt，应该通过 typed tool context 注入。
- UI 消息和 model 消息要区分，尤其是工具调用、approval 和恢复流。

## MCP TypeScript SDK

MCP 不是 agent runtime，而是能力和上下文协议。它解决的是“agent 如何发现并调用外部系统能力”的问题。

核心抽象：

- server exposes tools/resources/prompts。
- client lists and calls tools/resources/prompts。
- tools 是 model-controlled actions。
- resources 是 application-controlled context。
- prompts 是 user-controlled templates。
- transports 包括 stdio 和 Streamable HTTP。

重要细节：

- stdio 适合本地开发和本地工具进程；生产远程服务更适合 HTTP transport。
- tool handler 返回 `content`，有结构化输出时返回 `structuredContent`。
- 工具执行错误应尽量作为 tool result 的 `isError:true` 返回，让模型能自我修复；连接、协议、参数 schema 错误才作为协议错误。
- server instructions 可描述工具组合方式，但不要重复每个 tool description。
- 1.0/1.1 锁定的 commit `22595b96`（提交于 2026-05-15，2026-05-18 抓取）上，MCP SDK 主分支处于 v2 pre-alpha，撰写当时 v1.x 仍为推荐生产线。（1.2 更正：这个快照早于 2026-07-28 协议实现，即 2026-06-26 合入的 PR #2286。现状已经反转：v2 自 2026-07-27 起是稳定线，v1.x 只做维护，见下文。）

工程启发：

- MCP server 是把既有系统能力提供给多个 agent/client 的好边界。
- 不要把业务 workflow 全塞进 MCP tool；MCP tool 应该是小而可组合的能力。
- client 侧应显式筛选工具，而不是把 server 上所有工具都给模型。
- remote MCP 需要 auth、tenant isolation、rate limit、审计日志和 SSRF 防护。

## 2026 年中的版本事实与新抽象

> 本节记录 2026-08-23 新鲜度审查（`.planning/freshness-reviews/2026-08-23-source-freshness-review.md`）核验到的版本面移动。**本节按 GitHub Releases 正文分析，未刷新 `raw/repos/` 下的本地快照**，实现前请以宿主项目实际安装的版本为准。（1.2：四个来源已在 2026-10-25 re-snapshot 的 commit 上重新核验，见下一节。）

### 版本基线（2026-08-23 核验）

| 包 | 记录快照时 | 现在 | 性质 |
| --- | --- | --- | --- |
| `ai`（Vercel AI SDK）| v7.0.0-canary.142 | **`ai@7.0.77` stable**（v7.0.0 于 2026-06-25 发布）| 预发布转正 + 破坏性变更 |
| `@openai/agents` | ~v0.11.4 | **v0.17.0** | 六个 minor，含三个新抽象 |
| `@langchain/langgraph` | 1.3.x 线 | **1.4.12** | 1.x 线内推进 |
| `@modelcontextprotocol/sdk` | 1.x | **停在 `1.30.0`** | 单体包不再前进（1.2 更正：只是不升 2.x；1.x 维护版仍在发布，2026-10-23 为 1.32.2）|
| `@modelcontextprotocol/{core,client,server,...}` | 不存在 | **`2.0.0`（2026-07-27）** | v2 是**换包名**，不是升版本号 |

### MCP TS SDK 的 v2 是包名重组，不是版本升级

这条容易搞错，且错了会直接导致依赖装不上：v2 以一组**新的 scoped 包**发布（`@modelcontextprotocol/core` / `client` / `server` / `server-legacy` / `node` / `express` / `hono` / `fastify` / `codemod`），旧的单体包 `@modelcontextprotocol/sdk` 停在 `1.30.0` 且不会升到 2.x。（1.2 更正：不升 2.x 仍然成立，但 1.x 维护版还在继续发布；列表里的 `server-legacy` 也不是新功能包，而是冻结的 v1 代码，见下文。）迁移动作是**改 import 来源**，不是改版本号。协议层的对应变更见 `analysis/20-mcp-2026-07-28-revision.md`。

OpenAI Agents JS v0.15.0 给了一份可照抄的共存范式：本地 MCP 连接内部改用 v2 客户端并协商 2026-07-28 协议，**同时保留对 v1 服务端的兼容回落**，使用方（`MCPServerStdio` / `MCPServerStreamableHttp` / `MCPServerSSE`）不需要自己桥接两套包。跨协议世代的迁移应该由**适配层**吞掉，而不是让每个调用点各写一遍分支。

### 新抽象一：Programmatic Tool Calling —— 模型写程序来调工具

OpenAI Agents JS v0.14.0 支持模型生成托管 JavaScript 来协调多个符合条件的工具，并**压缩它们的中间结果**；program call 在 streaming、session、replay 与序列化 `RunState` 中都被完整保留。

这与 `analysis/18-deepseek-harness.md` 记录的 DeepSeek Harness Code Mode（`ctx.codeRuntime`，工具作为绑定命名空间注入）是**同一个抽象的第二次独立出现**。两者解决的是同一个成本问题：N 个工具调用意味着 N 次模型往返和 N 份中间结果进上下文；让模型写一段程序，往返变成 1 次，中间结果留在运行时里不进上下文。

设计上要注意的是它**不是 tool loop 的替代，而是一种模式**：DeepSeek 明确规定 `mode:'code'` 下模型的原生直接调用会被拒为 `UNKNOWN_TOOL`。1.1 据此写了"两种模式不能同时开着，否则模型会在两条路径间摇摆"。**1.2 更正：这半句不成立。** DeepSeek 当时同时提供 `both` 模式，"摇摆"是本仓库自己的推论。跨框架的现行做法是逐工具声明调用方，见下文"新模式二"。

### 新抽象二：重放歧义下的 fail-closed

v0.15.0–v0.17.0 连续三个版本在做同一件事——**当"这次恢复是否安全"无法被证明时，失败而不是猜**：

- 序列化的、带输出的审批检查点，在 SDK **无法证明哪个响应拥有这个待决终态工具输出**时，以 `UserError` 失败；建议用活的 `RunState` 继续，或从安全输入重新开始。
- 非流式模型重放需要显式 `approveUnsafeReplay: true` 才允许。
- **序列化的凭据与不安全的挂载授权在恢复时一律不被信任**。
- 带凭据的容器内挂载必须由应用显式确认精确的有效挂载路径（`Manifest.withInContainerMountCredentialExposureAcknowledged()`），或就"环境性/外部权威"做更宽的确认。
- 输出 guardrail 拒绝一个已完成的函数工具结果时，SDK 在自己拥有的重放表面上把内容替换为固定文案，清洗当前 guardrail 元数据，并保留此前已接受的历史；文档同时明确这**不会撤销外部副作用，也不会抹掉应用自己的副本**。

最后那句边界声明是这组设计里最诚实的一处：它说清了这个机制**只覆盖 SDK 拥有的表面**。凡是安全机制，都应该同样明写自己覆盖不到哪里。

这条与 Pi 的 `replay: "never" | "safe"`（`analysis/01-pi-source-analysis.md`；1.2 注：pi-durable 现在的取值是 `"safe" | "unsafe"`，省略时为 `unsafe`）和 DeepSeek 的 `GoalActivation` 故意不持久化（`analysis/18`）指向同一条原则：**权限与凭据不能从序列化状态里继承，恢复后必须重新取得**。

### 新抽象三：确定性测试设施

v0.16.0 引入 `@openai/agents/testing`（及 core / realtime 对应入口）：`ScriptedModel`、`scriptedSandboxSession()`、`ScriptedRealtimeTransport`，让 runner、sandbox 与 Realtime 流程能在**没有真实模型、没有沙箱、没有 WebRTC/WebSocket**的条件下被驱动。

这是框架层第一次把"agent 的确定性测试"当作一等公民发货。本仓库 `skills/test-ai-agents` 此前建议的是自建 fake model，现在可以直接指向框架自带设施——并把"框架是否提供 scripted model"列为选型时的一个考察点。

### 其余命中已分析表面的变更

- **Vercel AI SDK v7 的破坏性变更**：`stepCountIs` → `isStepCount`；**全包 ESM-only**（移除 CommonJS 导出）；移除 `ToolCallOptions`（改用 `ToolExecutionOptions`）与 `experimental_customProvider`；`experimental_telemetry` 转正且 `*TelemetryIntegration` → `*Telemetry`；回调事件数据重构（含此前记录的 `onFinish` → `onEnd`）；`StepResult` 的 response messages 收窄为该 step 内产生的消息；新增 provider references / 上传 provider skills 与顶层 `reasoning` 参数。ESM-only 是这批里最容易在落地时被绊倒的一条。
- **敏感数据日志默认关闭**（Agents JS v0.14.0）：模型与工具数据不再默认写日志，需 `setSensitiveDataLoggingEnabled(true)` 显式开启。安全默认值应该是"默认不记录"，观测需求靠显式开关满足。
- **取消传播与静默收敛**（v0.14.0）：取消信号会传播到流式/非流式函数工具以及 MCP 工具请求，且**流的完成会等待后台工作与清理落定**再 resolve。这与 `analysis/18` 的"dispose 必须到达静默态"是同一条。
- **Guardrail 批次完整结算**（v0.17.0）：同一批启动的 guardrail 会**先全部落定**，再由 runner 抛出 tripwire 或执行失败；已完成的兄弟结果仍留在 run state 里。这避免了"第一个失败就丢掉其他诊断信息"。
- **默认模型会变**（v0.15.0）：未显式指定 model 的 agent 使用的默认模型随版本改变。生产代码应显式指定模型，不要依赖框架默认值——这是一条比具体型号更耐久的结论。

## 2026-10 版本事实与新抽象（2026-10-25 核验）

> 本节的依据：在 2026-10-25 re-snapshot 的 commit 上直接读上游文件（blobless 浅克隆加 `gh api`），再用各包 CHANGELOG 和 npm 发布时间交叉核对。审查记录见 `.planning/freshness-reviews/2026-10-25-source-freshness-review.md`。所述机制默认运行在本地进程内。涉及托管组件的地方，逐条写明哪些能迁移到自建本地 harness。

### 版本基线

| 包 | 1.1 记录（2026-08-23）| 现在 | 性质 |
| --- | --- | --- | --- |
| `@openai/agents` | v0.17.0 | **0.21.0**（2026-10-20，commit `be4f1f9a`）| 四个 minor；`RunState` schema 升到 1.23 |
| `ai`（Vercel AI SDK）| 7.0.77 | **7.0.153**（2026-10-24，commit `6147ecd9`）| 7.0.78–7.0.153 全部标为 patch，其中含新功能和一处类型破坏 |
| `@ai-sdk/workflow` | 未单列 | **2.0.85**；2.0.0（2026-08-19）改用 Workflow 5，放弃 Workflow 4 | 独立版本线，`WorkflowAgent` 在这里 |
| `@ai-sdk/harness` / `code-mode` / `policy-opa` | 漏记 | 1.0.164 / 1.0.110 / 1.0.153 | 全部 experimental，三者都在 1.1 之前已发布 |
| `@langchain/langgraph` | 1.4.12 | **1.5.2**（2026-10-21，commit `c6675bf0`）| 1.5.0 改了 checkpoint saver 契约 |
| `@modelcontextprotocol/{core,client,server,server-legacy}` | 2.0.0 | **2.4.0**（2026-10-23，commit `951fe560`）| 2.1–2.4 四个 minor |
| `@modelcontextprotocol/sdk` | 1.30.0 | **1.32.2**（2026-10-23）| 维护线，只实现到 2025-11-25 规范 |

落地时最容易绊倒的，是三条"版本号不说明兼容性"的实例：

- **patch 不等于兼容**。`ai@7.0.149` 新增了 finish reason `interrupted`，含义是流在没有完成信号时结束：保留部分输出，停掉工具执行、agent 续跑和 UI 自动跟进，迟到的工具结果和审批也不再引发后续。官方的兼容性说明承认，它可能让 exhaustive switch 与 `Record<FinishReason, …>` 的类型检查失败。
- **minor 改了存储契约**。LangGraph 1.5.0 要求第三方 saver 持久化 `taskPath`，并按新的排序键返回 pending writes。含 delta writes 的未完成 superstep（不论来自中断、错误、崩溃还是 drain），必须先用旧运行时跑完，再升级写入方。
- **minor 改了实例生命周期**。MCP TS SDK 2.3.0 起，一个 `Server` 同时只服务一个连接，无 session 的 transport 只服务一个请求。手写"每个请求新建 transport、共用一个 server 对象"的应用，升级后第二个请求就会失败（`ALREADY_CONNECTED`）。

npm dist-tag 也不能当版本事实用。`ai` 的 `beta`（7.0.0-beta.187，2026-06-24）和 `canary`（7.0.0-canary.176，2026-06-15）是 v7 GA 之前留下的 tag，不存在 7.1.x 或 8.x。`@langchain/langgraph` 的 `next`、`rc`、`alpha` 同样早已过期。

### MCP TS SDK：v1.x 只维护，`server-legacy` 不是兼容桥

- **事实**：v1.x 分支的 README 自称维护线，实现到 2025-11-25 规范，并明说 2026-07-28 不打算进入 v1.x。v2 发布（2026-07-27）之后，v1.x 至少还会得到六个月的缺陷与安全修复。
- **事实**：`@modelcontextprotocol/server-legacy` 首发于 2026-06-25（2.0.0-alpha.2）。它的 README 自标 Deprecated：这是 v1 代码的冻结副本，只为迁移而存在，不再加功能，计划在 v3 移除。内容只有 `SSEServerTransport` 和 `mcpAuthRouter` 一类 OAuth 授权服务器助手。2025 代的 Streamable HTTP 客户端由 v2 自己服务：`createMcpHandler` 缺省 `legacy: 'stateless'`，改成 `legacy: 'reject'` 则只接现代协议。只有限定使用 HTTP+SSE 传输的老客户端还需要它。
- **判断**：把 `server-legacy` 当成"给老客户端用的桥"会选错依赖。跨代兼容在 v2 主包里，而且是逐请求、无状态地做。
- **2.1–2.4 中与本地 harness 有关的变化**（本地 harness 多数时候是 MCP **客户端**）：
  - 列表聚合：不带 cursor 的 `list*()` 会一直跟随 `nextCursor` 到最后一页（2.2.0）；`listMaxPages`（缺省 64）是硬上限，触顶直接抛错，不缓存半截结果。OpenAI Agents JS 0.20.0 的 MCP 自动发现同样缺省 64 页，触顶抛 `ToolListPageLimitError`，遇到重复 cursor 也抛错。
  - 连接远程服务器：只跟随同源且保持方法的重定向（2.3.0）；构造机器对机器 provider 时不传 `expectedIssuer` 已被弃用（2.2.0）；客户端支持 DPoP（2.1.0）；服务端的 `requireBearerAuth` 可以设 `expectedResource` 做受众校验（2.3.0）。
  - 服务端侧：逐工具、资源、prompt 的 `scopeChallenge` 在 handler 运行和 SSE 建立之前回 403 `insufficient_scope`（2.1.0）；请求体缺省上限 4 MiB，批量最多 100 条，缺 `MCP-Protocol-Version` 的现代 POST 回 400 与 `-32020`（2.1.0）。
- **事实**：Vercel `@ai-sdk/mcp` 2.0.81 起，在 Streamable HTTP 上会一直等 `server/discover` 的响应，不再在 1 秒后退回 `initialize`。此前，冷启动慢的纯现代服务器会被降级到旧握手，然后拒绝这个握手。stdio 和自定义 transport 仍保留 1 秒探测。**判断**：协商探测超时不是"对端是旧版本"的证据。把超时当成能力信号，会把一台可用的新服务器降级成不可用。`server/discover` 的协议语义见 `analysis/20-mcp-2026-07-28-revision.md`。
- **路径**：本仓库记录的三条路径从 2026-06 起就已失效，上一轮审查漏检了。`examples/server/src/simpleStatelessStreamableHttp.ts` 于 2026-06-26 随 #2286 删除，替代者是 `examples/stateless-legacy/server.ts`。`docs/server.md` 和 `docs/client.md` 于 2026-06-30 随 #2397 删除，分别由 `docs/get-started/first-server.md`、`docs/servers/tools.md`、`docs/serving/http.md` 和 `docs/get-started/first-client.md`、`docs/clients/connect.md`、`docs/clients/calling.md` 替代。

### 新模式一：审批状态的保管 → 服务"授权不从序列化状态继承"

**事实（OpenAI Agents JS）**。文档新增了"Keep approval state on the server"一节（PR #1951，2026-09-20；见 `docs/src/content/docs/guides/human-in-the-loop.mdx`，配套示例 `examples/agent-patterns/human-in-the-loop-server.ts`）：

- 序列化的 `RunState` 含审批决定、待决工具调用及其参数、应用上下文。`RunState.fromString()` 只负责恢复，**既不认证**快照，也不认证提交者。schema 校验和 tool-call 指纹都不算认证。只删掉审批记录，或用 `contextStrategy: 'replace'` 换掉上下文，也不能让不可信的快照变安全——其余字段照样控制执行。
- 审批界面只拿到经授权的展示信息和不透明的决定 id。服务端从会话中间件认证审批人，按存储的 run 做授权，只接受与已存储待决请求相符的"决定 id + 布尔值"；客户端送来的替换调用、参数、审批记录或状态一律不接受。
- 反序列化之前，**原子地**核对归属并消费这条待决请求；并发或重放的提交不得把同一个快照恢复两次。文档同时写明：消费只防重复提交，**不保证工具副作用 exactly-once**；恢复前要先对账已完成或结果不确定的副作用。

配套的运行时收紧（0.19.0–0.20.0）：条件审批绑定到隔离后的**归一化输入**；持久化审批恢复时，按**当前**策略重新评估；没有"初始输入校验已完成"证据的已开始检查点（包括旧快照）被拒绝；恢复的 MCP 调用绑定到原接收方；审批恢复之后的模型调用计入 `maxTurns`。

**事实（Vercel AI SDK）**。从消息历史重建的审批会重新做 schema 校验并重新评估策略，但文档明说：没有额外保护时，客户端可以给一个符合 schema 的输入伪造一份像样的审批，绕过人工环节。`experimental_toolApprovalSecret` 用 HMAC 把审批绑定到工具名、tool call ID 和输入参数（`WorkflowAgent` 还绑定审批 ID），签名缺失或无效就拒绝执行。它最晚在 v7 GA 之前的 7.0.0-canary.170 就已存在（本仓库此前漏记），7.0.84 进入 `ToolLoopAgent` 设置，7.0.86 进入 `WorkflowAgent`。`WorkflowAgent` 只持久化并下发签名，密钥只在签名与校验步骤内从环境变量读取。另有两条单次性规则：每个 tool call 只处理第一份审批响应（7.0.149）；被之后的用户消息取代的待决审批作废（7.0.123）。没有配置密钥时，行为与以前相同——安全模式是 opt-in，而且是 experimental。

**判断**。对同一个问题，两家给了两种保管模型。Agents JS 让状态永远不离开可信存储，不可信的一侧只回传"id + 布尔值"。Vercel 的设计让消息历史经客户端往返，于是给审批加 MAC。前者更强：MAC 只提供完整性，不提供机密性，也不防重放——Agents JS 文档明写，完整性校验既不加密，防重放也要另做。Vercel 的"首个响应生效"和"被用户消息取代即作废"覆盖的是同一份历史内的重复；整份已签名历史被再次提交时会不会再执行一遍，本次没有在代码层核验（待核验）。

这把 `skills/secure-ai-agents/SKILL.md` 已有的"授权不从序列化状态继承"，细化成四项可以检查的义务：**保管**（谁持有快照）、**单次消费**（原子的 check-and-consume）、**输入绑定**（审批绑定归一化输入）、**恢复时重评**（按当前策略，而不是审批当时的策略）。外加一条必须写明的非保证：消费不等于 exactly-once。这一条要和 `analysis/01-pi-source-analysis.md` 的 effect sandwich 对账衔接。

**向本地 harness 的迁移（推论）**。"服务端"对应 harness 进程，以及模型和它运行的工具都写不到的存储；"客户端"对应任何进程外的审批界面（IDE 插件、本地 Web UI、聊天机器人、手机通知），也包括 agent 工作区里的任何文件。所以，可恢复快照不放在工作区里；审批界面只收展示文本和决定 id，只回布尔值。SEP-2640 对 skill 缓存的要求（只有宿主能写，模型和它运行的脚本都不能写，见"新模式四"）是同一原则的协议级先例。不迁移的部分：Vercel 文档里"所有 serverless 实例共享同一个密钥"是部署形态问题。

### 新模式二：按工具声明调用方 → 服务 Code Mode

| 来源 | 声明粒度与字段 | 取值 | 缺省 | 在哪里强制 |
| --- | --- | --- | --- | --- |
| OpenAI Agents JS | 每个工具的 `allowedCallers` | `'direct'` / `'programmatic'`，可同时 | `['direct']` | 执行前在 SDK 本地复核（`ensureToolCallerAllowed`，违规抛 `ModelBehaviorError`），同时作为 `allowed_callers` 发给 provider |
| Vercel AI SDK | 调用参数 `experimental_toolCallers`（7.0.43 起，以工具名为键）| `'code_mode'` / `DIRECT_TOOL_CALL` | 没有条目即只能直调 | 只列了 `code_mode` 的工具，不再作为直调工具暴露给模型 |
| Claude API（程序化工具调用）| 每个工具的 `allowed_callers` | `"direct"` / `"code_execution_20260120"`（与 `_20260521` 互通）| `["direct"]` | **不是硬拦截**：只决定呈现方式，并与 `tool_choice` 互相校验；客户端仍须能处理任何工具的直调。官方建议每个工具只选一种 |
| Pi | coding agent 的 `exposure`；pi-durable 的 `callers: ("model" \| "tools")[]` | `direct` / `model-only` / `codemode` / `deferred` / `hidden` | 内置工具为 `direct`（既声明给模型，也能被脚本调用，即两条路都开）；MCP 服务器为 `codemode` | 运行时按集合解析：只把含 `model` 的工具提供给模型，嵌套调用只在含 `tools` 的工具里解析；codemode 工具本身是 `["model"]`，脚本不能再启动脚本 |
| DeepSeek Harness | 每个 agent preset 的 `mode` | `native` / `ptc`（`both` 在 v0.2.1-alpha.1 移除）| 部署默认 | `ptc` 下，没有 parent token 的直调在策略流水线之前就被判为 `UNKNOWN_TOOL` |

各家的程序运行位置不同。Agents JS 和 Claude API 的程序跑在 provider 托管的执行环境里，被调用的客户端工具仍在本地执行。Vercel code mode（QuickJS，需 Node 22+）、Pi codemode（QuickJS）和 DeepSeek PTC（缺省每次调用新开 Node 进程）都在本地。托管运行时本身不迁移；能迁移的是逐工具声明，以及 Claude API 在每个 `tool_use` 上携带的 `caller` 来源字段（其中 `tool_id` 指回发起这次调用的代码执行）。

**1.1 的规则错在哪里（事实）**。本仓库写的是"Code Mode 与原生 tool loop 同一轮必须互斥，否则模型会在两条路径间摇摆"。对照原文：

- 在当时的快照 `b150a551` 上，DeepSeek 的 `mode` 取值是 `native | code | both`，`both` 下原生调用照常执行，只有 `code` 拒绝直调。它给出的拒绝理由是：一个注定失败的调用不该被任何策略或审批看到；拒绝信息还要指回正确的调用路径。"摇摆"一说原文没有，是本仓库的推论。
- DeepSeek 在 2026-10-05 移除了 `both`（见 `.agents/notes/implemented/simplification/2026-10-05-native-or-ptc-presentation.md`），理由是**简化**：混合呈现把同一能力重复广告一遍，还多出一组排序、准入、配置与测试组合。笔记同时声明，想恢复它，得先拿出具体需求和证据。它的 `dsh-tools` README 至今把"呈现方式按 agent 而不是按工具"列为已知限制。
- 另外四个来源都按工具声明，其中三个缺省只允许直调。

**判断：逐工具调用方声明细化了"同轮互斥"，并取代它成为一般规则；agent 级的模式互斥作为更粗的一种配置继续成立（两者并存），但它不是安全要求。** 两者防住的失败不同：

| 机制 | 防住的失败 | 防不住的 |
| --- | --- | --- |
| 逐工具声明 + 执行边界复核 | ① 需要审批或要问用户的工具在程序里被调用，审批无处浮出。Vercel 直接拒绝程序内需要审批的嵌套调用，并要求这类工具只留直调；Pi 为"要问用户"的工具提供 `model-only`。② 程序专用的工具被模型直调，绕过程序里的过滤，大结果直接进上下文。③ 脚本递归启动脚本（Pi 把 codemode 工具设为 `["model"]`）。④ 如果每个工具只选一种，同一个工具就不会有两份描述 | 程序运行时自带的环境权限。DeepSeek 的 Node PTC 在 OS 沙箱内保留直接的文件、网络和子进程操作；它自陈实验性 Auto review 的缺口正在这里：PTC 程序里的直接 Node 副作用不经过 inner-tool review。调用方声明只管经过派发器的调用 |
| agent 级模式互斥 | ① 同一能力的重复广告（token 与前缀成本）；② harness 内部的组合爆炸；③ 会话内的呈现漂移——DeepSeek 在组装 agent 时固定呈现，前缀在整个会话内稳定 | 无法在一个 agent 里表达"审批类工具直调、批量读取类工具走程序"，只能拆成两个 agent；DeepSeek 因此必须让 PTC 程序能在嵌套调用处等待审批（它的执行超时把嵌套审批等待算在内）|

由此得到的规则（替换 1.1 的表述）：

1. 每个工具声明允许的调用方：缺省只允许直调，每个工具尽量只选一种（依据是 Claude API 的建议和 DeepSeek 的重复广告论据）。
2. 在执行边界复核调用方，不指望提示词或 provider 去执行这份声明。Claude API 明说它不是安全边界；Agents JS 在本地复核。
3. 需要审批或用户交互的工具保持直调，除非程序运行时能在嵌套调用处挂起并等待审批。
4. 程序运行时不得有环境权限：没有文件系统、网络、进程和动态求值（Vercel 和 Pi 都逐项列明）。做不到时，就把 OS 沙箱当作真正的边界，并明确工具级的闸门看不到这些直接副作用。
5. 会话内的调用方分配和工具目录保持稳定，变化以追加的方式呈现。Vercel 的 `toolDiscovery: 'conversation'` 把目录放进用户消息，保持 `code_mode` 工具定义不变；Pi 把 MCP 服务器摘要作为新的一段追加到对话里，而不去改工具声明。
6. 不要预设能省 token。DeepSeek 写明 PTC 是用 SDK 文本换工具 schema，不承诺普遍减少；Claude API 建议先在有代表性的真实流量上对比计费的输入 token。

### 新模式三：重放顺序取自逻辑路径，外部数据永不成为控制流 → 服务持久化执行与安全

**事实（LangGraphJS）**：

- 1.5.0：同一个 superstep 里多个任务写同一个 `DeltaChannel` 时，写入按 `(task_path, task_id, idx)` 应用和重放，不再按 task id 排序。task id 是包含 checkpoint id 的 uuid5 哈希，所以旧顺序每次运行都会打乱并行写入者，也和 Python 版不一致。saver 契约随之改变：`putWrites` 接收 `taskPath`，`getTuple`/`list` 必须按 `writesSortKey` 返回 pending writes；忽略它的第三方 saver 会按旧顺序重放，可能重建出与运行时不同的通道值。
- 1.4.21：`isCommand` 不再接受普通对象。形如 `{ lg_name: "Command", goto, update }` 的 JSON 输入按普通 state 处理，只有 `new Command(...)` 构造的实例才是控制指令。
- 1.4.16 / 1.5.1：`interrupt(value, { responseSchema })` 用 Zod schema 校验 resume 载荷并返回解析结果；原始 JSON Schema 按原样透传给客户端渲染（CHANGELOG 只说 Zod schema 会做校验）。多答案 resume 中某个答案校验失败时，同一步的其他任务会先跑完，再抛 `ZodError`；此前，被中途终止的任务如果已经产生副作用，会在下一次 resume 时再跑一遍。`isInvalidResume(error)` 用来区分这类错误。
- 1.4.0：`RunControl` 在 superstep 之间协作式 drain（保存 checkpoint 后抛 `GraphDrained`，不取消正在运行的工作）；新增节点级超时和错误处理器。

**判断**。下面两条原则对任何自建的持久化 harness 都成立：

1. **重放顺序必须来自跨运行稳定的逻辑位置**，例如图中的任务路径、程序里的调用位置，而不能来自每次运行新铸的 id 或完成顺序。`skills/review-ai-agents/SKILL.md` 已有"resume 缓存键取自完成顺序"一条，这是它在写入合并上的对应物。
2. **控制指令按类型和来源识别，永远不按形状识别**。来自模型、用户、工具或 resume 载荷的 JSON，长得再像命令也只是数据；这与 SEP-2640 的"skill 是数据，不是指令"同族。resume 载荷要在中断点按 schema 校验，而且校验失败不能中止已经产生副作用的兄弟任务。

不迁移的部分：`DeltaChannel` 本身和 saver 的迁移步骤是 LangGraph 内部的事。

### 新模式四：经 MCP 分发 skill，摘要只证一致、不证可信 → 服务 skill 供应链

**事实**。SEP-2640（Status: Final，Extensions Track，标识 `io.modelcontextprotocol/skills`）把一个 skill 的每个文件暴露为 MCP 资源（约定用 `skill://`），并提供 `skills/list`、`skills/get` 和 `resources/directory/read`。列表条目要么对 skill 的**全部**文件给出 `{uri, digest, size}`，要么显式标为 `"dynamic"`。MCP TS SDK 2.4.0 实现了它（#3047，2026-10-20 合入）。服务端有 `SkillsExtension`（其 `attach(server)` 标为 experimental）和 `loadSkills(folder)`。客户端的 `SkillsClient.read()` 校验大小和 SHA-256 摘要，并逐字段比对 `SKILL.md` 的 frontmatter，任何一项不符就抛 `SkillVerificationError`，原因分为 `unlisted`、`size`、`digest`、`frontmatter`；`"dynamic"` 条目跳过摘要校验，返回 `verified: false`。SDK 文档（`docs/clients/skills.md`）把审批、记录来源、遵守上限（512 个文件、16 MiB）以及"加载时才读文件、列举时不读"列为宿主的责任。

SEP 的安全一节是本次最值得收的部分：

- 摘要不签名，而且和内容来自同一台服务器。匹配只证明两者一致，不证明可信，中间人可以同时改写两者——**不得把摘要匹配当作安全边界**。
- MCP 来源的 skill 内容是不可信输入。进入模型上下文时要带来源标记，不得与本地 skill 无从区分。
- 没有逐个 skill 的用户批准，不得让 skill 引起宿主侧的代码执行：hooks 和 frontmatter 脚本要么忽略，要么纳入审批；模型按这个 skill 行事期间发出的代码执行调用，同样要过审批。
- MCP 来源 skill 的 frontmatter `allowed-tools` 一律忽略，除非用户为这个 skill 明确批准；批准一个 skill 不覆盖它目录里嵌套的 skill。
- 资源读取按来源隔离：A 服务器的 skill 不能引发对 B 的读取。服务器用宿主分配的标签识别，而不用它自报的 `serverInfo.name`。同名 skill 按来源分命名空间，不得静默遮蔽本地 skill。
- **内容绑定的审批**：持久化的批准绑定到批准当时完整的 `resources` 集合（每个 uri 和 digest），之后任何变化都视为撤销，必须重新询问。
- 缓存要么只有宿主能写（模型和它运行的脚本都不能写）且不原地修改，要么每次读取都重算摘要。缓存目录不得落在本地 skill 的发现路径里；缓存的字节永远按"来自 MCP"对待，不会因为落盘就升级为本地 skill 的信任级别。

**判断**。这是本仓库的 skill 供应链第一次拿到协议级的规范。`analysis/01-pi-source-analysis.md` 只写了"skill 中的可执行脚本是供应链风险、需要审查"；SEP 把它细化成了可以实现的机制：审批绑定内容摘要的集合，身份是"来源标签 + uri"，frontmatter 不得授予权限，缓存不因落盘而升级信任。还要看清摘要校验保护的范围：它保护的是**批准之后**内容不被换掉，不能证明批准时的内容可信，因为清单和正文都出自同一台服务器。

**向本地 harness 的迁移（推论）**：同样的规则适用于任何不是用户亲手写的 skill 来源，例如 git 克隆来的 skill 包或从 registry 安装的 skill。具体是：批准绑定到完整文件集的内容哈希，变更就重新询问；外来 skill 的 `allowed-tools` 不得扩大权限；外来 skill 不进入自动发现路径。

### 新模式五：同一框架不同入口的默认循环预算不同 → 服务循环预算

**事实**：

- Vercel：`ToolLoopAgent` 缺省 `isStepCount(20)`。7.0.135 起，默认上限截停一个本可继续的循环时会打警告，显式设置 `stopWhen` 就不再警告。`WorkflowAgent.generate()`（7.0.128 新增）缺省 20 步，`WorkflowAgent.stream()` 没有缺省上限，文档明说它可能产生无限次模型调用。循环控制总览页仍写着"`WorkflowAgent` 不应用缺省的 step 上限"，与同一套文档里 `generate()` 小节的说法矛盾。
- OpenAI Agents JS：`DEFAULT_MAX_TURNS = 10`。0.20.0 起，审批恢复之后的模型调用计入 `maxTurns`；按这条 fix 的措辞推断，此前恢复出来的调用不占预算。
- 发现预算：见上文 MCP 一节，两处缺省都是 64 页，触顶即抛错。
- 流缓冲预算：Agents JS 0.19.0 把 agent-as-tool 的流回调限制在 1024 个待处理事件（`onStreamMaxPendingEvents`，设为 `null` 才恢复无界）。

**判断**：

- 预算要按**入口**显式设置，并且**跨恢复延续**。缺省值是框架某个版本的事实，不是设计：同一个类的两个方法可以有不同的缺省，文档也可能写错。
- 截断会改变语义的上限，触顶时要响亮地失败。半截的工具列表就是一个错误的能力面，所以两家的发现上限都抛错；输出循环被截停则是安全的方向，所以 Vercel 只打警告。
- 停止原因必须是封闭集合，同时给未知值留出处理路径——`interrupted` 证明新的停止原因会出现在 patch 版里。

### 新抽象：harness 作为适配器（`@ai-sdk/harness`，experimental）

**事实**。`@ai-sdk/harness` 1.0.0 与 `ai@7.0.0` 同一天（2026-06-25）发布，本仓库 1.1 漏记了。`HarnessAgent` 把现成的 agent runtime 放到同一个 AI SDK 表面之后：Claude Code、Codex、Pi 的适配器同日发布 1.0.0，之后陆续有 ACP（08-07）、Cursor（08-25）、GitHub Copilot（09-09），以及 Cline、Deep Agents、fx、Grok Build、OpenCode。`generate()` 与 `stream()` 返回和 `generateText`、`streamText` 相同的结果类型；没有对应 AI SDK 部件的事件（工作区文件变更、压缩）以动态的 provider-executed 工具部件呈现。harness 抽象和 provider/model 抽象相互独立。

适配器的能力矩阵并不一致。内置工具审批：Claude Code 和 Pi 支持，Codex、Cursor、Copilot 不支持。历史访问：所有适配器都不提供。运行位置分三类：sandbox bridge（Claude Code、Codex 等，文档要求真实的网络沙箱，示例是云端的 `@ai-sdk/sandbox-vercel`）、host process（Pi、Cline、fx，可以配进程内虚拟文件系统的 `@ai-sdk/sandbox-just-bash`），以及经 ACP 的沙箱（Cursor、Copilot、Grok Build）。

**判断**。harness 第一次成了应用之下可插拔的单元，就像 model 早先成为可插拔单元一样。对自建 harness 的启示：想被别人驱动，事件流就要能投影到一个公共流类型，并给没有公共类型的事件留出口。代价写在能力矩阵里：公共表面是交集，而审批和历史访问恰恰是适配器分歧最大的地方——依赖适配器做审批的应用，继承的是最弱那个适配器的语义。范围说明：bridge 类适配器在文档里推荐的沙箱是云服务，不在本仓库范围内；host process 类在本地运行。能迁移的只有适配器模式和事件投影。

### 其余命中已分析表面的变更

- **策略即代码，但无匹配即放行**（`@ai-sdk/policy-opa` 1.0.0，2026-06-25，漏记）：把工具审批规则写成 OPA/Rego，输入是 `{ tool, args, messages, runtimeContext }`，可以做"已经写入 N 次之后要审批""同一会话里第二次不可逆操作直接拒绝"之类基于历史的检查。策略后端出错时 fail closed，返回 denied；但**没有规则匹配时归一为 `not-applicable` 并按放行处理**，想默认拒绝，必须在策略里显式写 `default decision := { "decision": "deny" }`。这与本仓库"审批结果是封闭集合、缺省拒绝"的规则相反，接入时要显式补上。
- **工具调用并发可配**（Vercel 7.0.140）：缺省所有本地调用并发执行；`toolCallConcurrency` 同样作用于从历史恢复的已批准调用。
- **原生 tool search**（Vercel 7.0.104）；`experimental_evaluate` 改名为 `experimental_decide`（7.0.128）。
- **Agents JS 的守卫与沙箱**：新增服务器级 MCP 工具 guardrail，guardrail 拦截文案可以自定义（0.17.1）；输出 guardrail 没跑完时，未经审查的最终输出不写入 session 历史（0.19.0）；UnixLocal 文件操作要求可信的 Python 3 文件保护，且不允许关闭，Docker 的文件 API 改在运行中的容器内执行（0.18.0–0.20.0）；沙箱的 Git 输入不再可能被解释成宿主 Git 选项（0.17.1）；Runloop 沙箱 provider 及其公开 API 在 0.21.0 移除。
- **LangGraphJS 文档迁址**：权威文档在 docs.langchain.com（`/oss/javascript/langgraph/interrupts`、`/persistence`，旧的 `/durable-execution` 会 308 跳到 `/persistence`；多 agent 在 `/oss/javascript/langchain/multi-agent`）。本仓库记录的三页 `docs/docs/*` 在仓库里仍然存在，但已是旧的 mkdocs 源（HITL 页最后修改于 2025-04-24），不再权威。OpenAI Agents JS 与 Vercel AI SDK 记录的 7 条和 13 条路径，在新 commit 上全部存在。

## 架构选择表

| 需求 | 首选形态 | 原因 |
| --- | --- | --- |
| 单次结构化生成 | model wrapper | 不需要 agent loop |
| 需要模型自主调用少量工具 | ReAct/tool loop | 简单直接，容易接入 |
| 需要前端流式工具状态 | Vercel ToolLoopAgent 或自建 streaming loop | UI message 支持较完整 |
| 需要审批、恢复、长任务 | durable graph/workflow | 可 checkpoint、resume、audit |
| 多个专业角色协作 | supervisor/subagent | 隔离上下文和工具权限 |
| 外部系统能力要被多个 agent 复用 | MCP server | 标准化能力边界 |
| Java/Spring 服务内 agent | Spring AI 或 LangChain4j | 类型安全、DI、注解/接口风格 |
| 需要在一次模型往返里编排多个工具并压缩中间结果 | Programmatic Tool Calling / Code Mode | 减少往返与上下文占用；按工具声明调用方（缺省仅直调）并在执行边界复核，需审批的工具留在直调（1.2 改：1.1 写作"与原生 tool loop 互斥"）|
| 需要在崩溃后恢复且涉及外部副作用 | 持久化 harness + 按工具重放策略 | 见 `analysis/01-pi-source-analysis.md` |
| 审批界面与 harness 不在同一进程或同一信任域 | 可信侧保管快照 + 原子单次消费；状态必须经客户端往返时再加签名审批 | 序列化状态不经认证；签名只给完整性，不防重放 |
| 复用现成 agent runtime 而不自写 loop | harness 适配器（如 `HarnessAgent`）| 统一流类型；审批、历史访问与运行位置随适配器而异 |
| 从远端服务器加载 skill | SEP-2640 + 内容绑定审批 | 摘要只证一致、不证可信 |

## 对最终 skill 的影响

本轮（suite 2.3.0）实际落地：

- `skills/design-agent-tools/SKILL.md`：code mode 改为按工具声明调用方并在执行时强制（provider 的调用方声明可能只是提示）；删去"否则模型会摇摆"的理由；需要审批的工具除非程序能在嵌套调用处挂起等待审批，否则只留直调；程序代码在 OS 隔离的进程里运行、崩溃后不自动回放、可触达的副作用一律过同一审批。
- `skills/secure-ai-agents/SKILL.md`：序列化 run state 是可执行授权——服务端持有、不放在 agent 可写处、逐条原子消费；可解析不等于已认证；签名只证完整性、不证新鲜度；消费一个决定不等于副作用 exactly-once；策略引擎"无规则命中"必须等于拒绝；批准绑定签发时的输入；远程 skill 的摘要不是信任边界（批准绑定完整摘要集合、忽略远程 skill 的工具预授权、缓存不获得本地 skill 的信任）；列表分页设上限。
- `skills/build-mcp-capabilities/SKILL.md`：`server-legacy` 只在 HTTP+SSE 老客户端与 v1 OAuth 助手时需要；`server/discover` 超时不是对端为旧版的证据；单体 1.x 只维护；无状态模式每请求一个 server 实例；按工具 scope challenge 与 issuer / resource 绑定；分页上限；Skills 扩展摘要的确切含义。
- `skills/implement-ts-agents/SKILL.md`：Version Reality Check 更新到 2026-10（Vercel 7.0.x 的 patch 带功能、`interrupted`、入口不同的默认步数、`@ai-sdk/workflow` 单独发版、陈旧的 beta / canary 标签、MCP SDK 现状）；OpenAI Agents JS 的 run state 保管、条件审批绑定输入、恢复后的调用计入 `maxTurns`；Vercel 的审批语义、签名不防重放、策略适配器默认值、`@ai-sdk/harness`；LangGraphJS 的"数据不当控制流"、Zod responseSchema、并行写回放顺序与升级步骤、文档迁移；新增两类测试。
- `skills/review-ai-agents/SKILL.md`：搜索种子增加 `RunState.fromString` / `approveUnsafeReplay` 与调用方声明；反模式增加"调用方策略未在执行时强制""策略引擎无命中即放行"。
- `skills/design-ai-agent/SKILL.md`：内嵌形态写入"把多个本地 runtime 放到同一个流接口后面的适配器"；花费上限跨恢复延续。
- `skills/test-ai-agents/SKILL.md`：增加"快照重复提交只恢复一次""伪造或改动的审批被拒""程序专用工具被直调被拒""并行写在多次运行中按同一顺序回放"。

提议但本轮未采纳：

- 审批通道只回"决定 id + 布尔值"（secure）：属于实现层建议，留在本文。
- 截断会改变语义的上限必须抛错、停止原因是封闭集合并为未知值留出口、让别人驱动自己的 harness 时把事件流投影到公共流类型（design-ai-agent）：受 `design-ai-agent` 的体积预算限制（Agent Skills 规范建议正文 5000 tokens 以内），暂留本文。
