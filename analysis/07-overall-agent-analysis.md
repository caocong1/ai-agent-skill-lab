# AI Agent 总体分析总结

> 分析版本：1.0 ｜ 最后更新：2026-05-19 ｜ 覆盖来源：全部 7 个代码项目 + Anthropic Building Effective Agents（版本见 `analysis/SOURCE_INDEX.md`）

这份报告把已分析的 7 个代码项目（Pi、OpenAI Agents JS、LangGraphJS、MCP TS SDK、Vercel AI SDK、Spring AI Examples、LangChain4j）和 1 篇权威文章（Anthropic Building Effective Agents）放在一起，回答一个问题：跨这些来源，关于"怎样做一个有效的 agent"，哪些结论是收敛的、哪些是有条件的。代码项目回答"怎么实现"，文章回答"该不该做、做到什么程度"，两者拼起来才是完整的工程判断。它是 `analysis/01..06` 之上的一层归纳，`analysis/04` 仍专注 skill 设计取舍，本文件不替代它。

## 综合结论

- **形态选择先于框架选择**。所有来源都指向同一件事：先判断任务需要的最小形态，再选语言/框架去落地。Anthropic 文章把它讲成原则（最简优先），Pi / OpenAI Agents JS / LangGraph / Vercel 用不同实现验证了同一判断。
- **agent 的本质是"模型 + 环境反馈 + 显式停止"的循环**。Pi 的 `agent-loop.ts`、OpenAI Agents JS 的 `runLoop`、Vercel 的 `ToolLoopAgent`、文章的 autonomous agent 定义完全一致：每步要拿 ground truth，循环必须有预算/停止条件。
- **边界比循环更重要**。schema-first tool、权限在工具执行边界、敏感上下文走 typed context 而不是 prompt、UI/model 消息分离——这几条在 TS、Java、文章里反复出现，是最稳的可复用准则。
- **复杂度要被需求拉动，不能被框架推动**。durable graph、subagent、MCP、vector memory 都只在需求出现时才引入；文章的"能用 workflow 就别上 agent"是这条的权威背书。

## 形态选择光谱

从轻到重，每一档给出触发条件、代表来源、过度工程的反例：

| 形态 | 何时用 | 代表来源 | 过度工程反例 |
| --- | --- | --- | --- |
| 确定性代码 | 不需要模型判断 | 文章（最简优先） | 给固定规则套个 LLM |
| 单次模型调用 | 纯生成/分类/抽取/摘要，无外部动作 | 文章；LangChain4j AI Service | 为一次分类起 tool loop |
| 结构化 workflow（chain/routing/parallel/orchestrator/evaluator） | 步骤基本可枚举、要可预测性 | Spring AI agentic-patterns；文章五模式 | 步骤已知却让模型自由发挥 |
| tool loop（ReAct） | 模型要动态选少量工具，能在一轮请求内完成 | Pi、OpenAI Agents JS、Vercel ToolLoopAgent | 简单链式任务硬塞自治循环 |
| durable graph/workflow | 需要 checkpoint、resume、长任务、跨进程审批 | LangGraphJS；Vercel WorkflowAgent | in-memory 够用却上 graph runtime |
| subagent / multi-agent | 需要隔离上下文或工具权限、专业分工值回延迟 | Pi subagent；OpenAI agent-as-tool | 单任务拆多 agent 徒增延迟和失败面 |
| MCP 能力边界 | 能力要被多个 client/agent 复用 | MCP TS SDK | 把业务 workflow 整个塞进 MCP tool |

## 跨来源共识矩阵

| 主题 | Anthropic 文章 | TS 项目（Pi/OpenAI/LangGraph/Vercel/MCP） | Java 项目（Spring AI/LC4j） | 收敛结论 |
| --- | --- | --- | --- | --- |
| 何时上 agent | 能 workflow 就别 agent，能单次就别 workflow | tool loop 只在需动态选工具时用 | AI Service 默认单次，agentic 才编排 | 形态按"步骤可不可预测"选，默认最简 |
| 工具契约 | ACI 当公共 API 设计 | schema-first（Zod）、description 写给模型 | `@Tool`/record/接口、typed executor | 工具 schema 优先，描述面向模型，handler 面向系统 |
| 停止/预算 | 显式停止条件防失控 | `stopWhen`/step limit/terminate 标记 | 链路有限步、显式终止 | 任何循环都要有步数/成本/超时/checkpoint |
| 权限/审批 | 沙箱 + 护栏 + 人类检查点 | beforeToolCall 拦截、toolApproval、HITL | DI 层做权限、函数回调边界 | 权限放工具执行边界，不靠 prompt 自觉 |
| 状态边界 | transparency：规划步骤可见 | turn snapshot、runtimeContext/toolsContext、UI/model 分离 | session/record 分层 | 域/运行时/模型/UI 消息要分开，避免泄漏 |
| 渐进式披露 | 简单接口、按需暴露 | Pi skill 先给名称描述再读内容 | LC4j skills 同思路 | skill/工具按任务暴露，别一次塞满上下文 |

## 分歧与取舍

这些点没有唯一答案，需按项目条件选择：

- **抽象框架 vs 重框架**：文章建议直接基于 LLM API 起步、把框架当起点；LangGraph/Vercel 提供了重框架的便利。取舍：原型和可控流程用轻方案，需要 checkpoint/replay/审批再上 durable runtime。
- **in-memory vs durable**：Pi/OpenAI/Vercel ToolLoopAgent 默认进程内；LangGraph 默认可持久化。取舍：有合规、长耗时、跨进程恢复需求才 durable，否则进程内更简单。
- **单 agent vs multi-agent**：文章和 Pi 都提醒 subagent 增加延迟与失败面；只有上下文/权限隔离收益大于复杂度时才用。
- **handoff vs agent-as-tool**：移交控制权用 handoff，委托子任务取结果用 agent-as-tool（OpenAI Agents JS 的明确区分），不要混用。

## 对 skill 的总体指导

本轮把上面的收敛结论沉淀进 `build-ai-agents`（与 `analysis/06` 对最终 skill 的影响一节、`CHANGELOG.md` 1.1.0 一致）：

- `SKILL.md` Architecture Rules 增加"最简优先"判定链，作为形态选择的第一道闸。
- `references/agent-architecture.md` 新增 `Workflow vs Agent` 小节与对应决策表行，把光谱写进 skill。
- `references/anti-patterns.md` 强化"在固定 workflow 更可靠时却做自治 agent"。
- `references/context-and-tools.md` 把 ACI 写成显式准则。
- 这些都是additive 强化，不改 skill 契约（故为 MINOR 1.1.0）。

## 后续可分析方向

留给下一次迭代的线索（均为权威来源，尚未单独分析）：

- OpenAI, A Practical Guide to Building Agents：偏产品/运营视角的判定与 guardrails，可与本文章互补。
- Anthropic, Writing Effective Tools for AI Agents：深化 ACI/工具质量，直接强化 `context-and-tools.md`。
- Google Agent Development Kit docs：另一套工程化 agent 框架的形态与边界设计。

按既定流程：新增来源时建 `08-...md`、在 `SOURCE_INDEX.md` 的 Articles and Papers 表加行、更新本文件的共识矩阵、追加 `CHANGELOG.md`。
