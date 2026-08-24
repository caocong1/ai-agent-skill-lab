# Agent Framework Patterns

> 分析版本：1.1 ｜ 最后更新：2026-08-23 ｜ 覆盖来源：OpenAI Agents JS / LangGraphJS / Vercel AI SDK / MCP TypeScript SDK（版本见 `analysis/SOURCE_INDEX.md`）
>
> 1.1 变更：新增 `## 2026 年中的版本事实与新抽象`。原有各节的模式描述核对后仍成立，但**版本面已大幅移动**——Vercel AI SDK v7 转正、OpenAI Agents JS 走到 v0.17、MCP TS SDK v2 换了包名。新节记录这些事实与它们带来的三个新抽象；旧节保留为形态层描述。

这一节把 OpenAI Agents JS、LangGraphJS、Vercel AI SDK 和 MCP TypeScript SDK 放在一起比较。它们解决的问题不完全相同：OpenAI Agents JS 更像标准 agent SDK，LangGraphJS 更像 durable workflow/graph runtime，Vercel AI SDK 更偏 TS 应用和流式 UI，MCP 是 agent 能力协议。

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
- HITL 不能只靠 UI 状态，必须能把 run state 序列化并恢复。
- approval 的输出要回到模型上下文，让模型知道工具被拒绝或被批准。

## LangGraphJS

适合学习“agent 不是单一循环，而是可回放、可中断、有状态图”的场景。

核心抽象：

- `StateGraph`: 节点和边构成明确流程。
- `MessagesAnnotation`: 常见的消息状态。
- `ToolNode`: 统一执行工具调用。
- `MemorySaver`/checkpointer: 每个 super-step 后保存状态。
- `Command`: 用于 resume、goto、跨父图 handoff。

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
- `WorkflowAgent`: durable/resumable agent，运行在 workflow 中。
- `createAgentUIStreamResponse`: 把 agent 流转换为 UI 消息流。

适用场景：

- Next.js/React/Vue/Svelte/Angular 应用要快速构建 agent UI。
- tool output 需要流式显示。
- 简单 agent 不需要独立 durable runtime。
- 生产长任务需要迁移到 `WorkflowAgent` 或其他 durable workflow。

工程启发：

- 默认 step limit 是必要的安全措施；移除 step limit 要非常谨慎。
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
- 在本分析锁定的 commit（2026-05-18 快照）时，MCP SDK 主分支处于 v2 pre-alpha——版本线随时变化，生产前务必确认当前发布线（撰写时 v1.x 仍为推荐生产线）。

工程启发：

- MCP server 是把既有系统能力提供给多个 agent/client 的好边界。
- 不要把业务 workflow 全塞进 MCP tool；MCP tool 应该是小而可组合的能力。
- client 侧应显式筛选工具，而不是把 server 上所有工具都给模型。
- remote MCP 需要 auth、tenant isolation、rate limit、审计日志和 SSRF 防护。

## 2026 年中的版本事实与新抽象

> 本节记录 2026-08-23 新鲜度审查（`.planning/freshness-reviews/2026-08-23-source-freshness-review.md`）核验到的版本面移动。**本节按 GitHub Releases 正文分析，未刷新 `raw/repos/` 下的本地快照**，实现前请以宿主项目实际安装的版本为准。

### 版本基线（2026-08-23 核验）

| 包 | 记录快照时 | 现在 | 性质 |
| --- | --- | --- | --- |
| `ai`（Vercel AI SDK）| v7.0.0-canary.142 | **`ai@7.0.77` stable**（v7.0.0 于 2026-06-25 发布）| 预发布转正 + 破坏性变更 |
| `@openai/agents` | ~v0.11.4 | **v0.17.0** | 六个 minor，含三个新抽象 |
| `@langchain/langgraph` | 1.3.x 线 | **1.4.12** | 1.x 线内推进 |
| `@modelcontextprotocol/sdk` | 1.x | **停在 `1.30.0`** | 单体包不再前进 |
| `@modelcontextprotocol/{core,client,server,...}` | 不存在 | **`2.0.0`（2026-07-27）** | v2 是**换包名**，不是升版本号 |

### MCP TS SDK 的 v2 是包名重组，不是版本升级

这条容易搞错，且错了会直接导致依赖装不上：v2 以一组**新的 scoped 包**发布（`@modelcontextprotocol/core` / `client` / `server` / `server-legacy` / `node` / `express` / `hono` / `fastify` / `codemod`），旧的单体包 `@modelcontextprotocol/sdk` 停在 `1.30.0` 且不会升到 2.x。迁移动作是**改 import 来源**，不是改版本号。协议层的对应变更见 `analysis/20-mcp-2026-07-28-revision.md`。

OpenAI Agents JS v0.15.0 给了一份可照抄的共存范式：本地 MCP 连接内部改用 v2 客户端并协商 2026-07-28 协议，**同时保留对 v1 服务端的兼容回落**，使用方（`MCPServerStdio` / `MCPServerStreamableHttp` / `MCPServerSSE`）不需要自己桥接两套包。跨协议世代的迁移应该由**适配层**吞掉，而不是让每个调用点各写一遍分支。

### 新抽象一：Programmatic Tool Calling —— 模型写程序来调工具

OpenAI Agents JS v0.14.0 支持模型生成托管 JavaScript 来协调多个符合条件的工具，并**压缩它们的中间结果**；program call 在 streaming、session、replay 与序列化 `RunState` 中都被完整保留。

这与 `analysis/18-deepseek-harness.md` 记录的 DeepSeek Harness Code Mode（`ctx.codeRuntime`，工具作为绑定命名空间注入）是**同一个抽象的第二次独立出现**。两者解决的是同一个成本问题：N 个工具调用意味着 N 次模型往返和 N 份中间结果进上下文；让模型写一段程序，往返变成 1 次，中间结果留在运行时里不进上下文。

设计上要注意的是它**不是 tool loop 的替代，而是一种模式**：DeepSeek 明确规定 `mode:'code'` 下模型的原生直接调用会被拒为 `UNKNOWN_TOOL`——两种模式不能同时开着，否则模型会在两条路径间摇摆。

### 新抽象二：重放歧义下的 fail-closed

v0.15.0–v0.17.0 连续三个版本在做同一件事——**当"这次恢复是否安全"无法被证明时，失败而不是猜**：

- 序列化的、带输出的审批检查点，在 SDK **无法证明哪个响应拥有这个待决终态工具输出**时，以 `UserError` 失败；建议用活的 `RunState` 继续，或从安全输入重新开始。
- 非流式模型重放需要显式 `approveUnsafeReplay: true` 才允许。
- **序列化的凭据与不安全的挂载授权在恢复时一律不被信任**。
- 带凭据的容器内挂载必须由应用显式确认精确的有效挂载路径（`Manifest.withInContainerMountCredentialExposureAcknowledged()`），或就"环境性/外部权威"做更宽的确认。
- 输出 guardrail 拒绝一个已完成的函数工具结果时，SDK 在自己拥有的重放表面上把内容替换为固定文案，清洗当前 guardrail 元数据，并保留此前已接受的历史；文档同时明确这**不会撤销外部副作用，也不会抹掉应用自己的副本**。

最后那句边界声明是这组设计里最诚实的一处：它说清了这个机制**只覆盖 SDK 拥有的表面**。凡是安全机制，都应该同样明写自己覆盖不到哪里。

这条与 Pi 的 `replay: "never" | "safe"`（`analysis/01-pi-source-analysis.md`）和 DeepSeek 的 `GoalActivation` 故意不持久化（`analysis/18`）指向同一条原则：**权限与凭据不能从序列化状态里继承，恢复后必须重新取得**。

### 新抽象三：确定性测试设施

v0.16.0 引入 `@openai/agents/testing`（及 core / realtime 对应入口）：`ScriptedModel`、`scriptedSandboxSession()`、`ScriptedRealtimeTransport`，让 runner、sandbox 与 Realtime 流程能在**没有真实模型、没有沙箱、没有 WebRTC/WebSocket**的条件下被驱动。

这是框架层第一次把"agent 的确定性测试"当作一等公民发货。本仓库 `skills/test-ai-agents` 此前建议的是自建 fake model，现在可以直接指向框架自带设施——并把"框架是否提供 scripted model"列为选型时的一个考察点。

### 其余命中已分析表面的变更

- **Vercel AI SDK v7 的破坏性变更**：`stepCountIs` → `isStepCount`；**全包 ESM-only**（移除 CommonJS 导出）；移除 `ToolCallOptions`（改用 `ToolExecutionOptions`）与 `experimental_customProvider`；`experimental_telemetry` 转正且 `*TelemetryIntegration` → `*Telemetry`；回调事件数据重构（含此前记录的 `onFinish` → `onEnd`）；`StepResult` 的 response messages 收窄为该 step 内产生的消息；新增 provider references / 上传 provider skills 与顶层 `reasoning` 参数。ESM-only 是这批里最容易在落地时被绊倒的一条。
- **敏感数据日志默认关闭**（Agents JS v0.14.0）：模型与工具数据不再默认写日志，需 `setSensitiveDataLoggingEnabled(true)` 显式开启。安全默认值应该是"默认不记录"，观测需求靠显式开关满足。
- **取消传播与静默收敛**（v0.14.0）：取消信号会传播到流式/非流式函数工具以及 MCP 工具请求，且**流的完成会等待后台工作与清理落定**再 resolve。这与 `analysis/18` 的"dispose 必须到达静默态"是同一条。
- **Guardrail 批次完整结算**（v0.17.0）：同一批启动的 guardrail 会**先全部落定**，再由 runner 抛出 tripwire 或执行失败；已完成的兄弟结果仍留在 run state 里。这避免了"第一个失败就丢掉其他诊断信息"。
- **默认模型会变**（v0.15.0）：未显式指定 model 的 agent 使用的默认模型随版本改变。生产代码应显式指定模型，不要依赖框架默认值——这是一条比具体型号更耐久的结论。

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
| 需要在一次模型往返里编排多个工具并压缩中间结果 | Programmatic Tool Calling / Code Mode | 减少往返与上下文占用，但与原生 tool loop 互斥 |
| 需要在崩溃后恢复且涉及外部副作用 | 持久化 harness + 按工具重放策略 | 见 `analysis/01-pi-source-analysis.md` |
