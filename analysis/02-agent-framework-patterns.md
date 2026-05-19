# Agent Framework Patterns

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
- MCP SDK 主分支可能处于 v2 pre-alpha；生产项目要确认版本线。

工程启发：

- MCP server 是把既有系统能力提供给多个 agent/client 的好边界。
- 不要把业务 workflow 全塞进 MCP tool；MCP tool 应该是小而可组合的能力。
- client 侧应显式筛选工具，而不是把 server 上所有工具都给模型。
- remote MCP 需要 auth、tenant isolation、rate limit、审计日志和 SSRF 防护。

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

