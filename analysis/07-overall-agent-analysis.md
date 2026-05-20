# AI Agent 总体分析总结

> 分析版本：1.1 ｜ 最后更新：2026-05-20 ｜ 覆盖来源：全部 7 个代码项目 + Anthropic Building Effective Agents / Anthropic Writing Effective Tools for Agents / OpenAI Practical Guide to Building Agents（版本见 `analysis/SOURCE_INDEX.md`）

这份报告把已分析的 7 个代码项目（Pi、OpenAI Agents JS、LangGraphJS、MCP TS SDK、Vercel AI SDK、Spring AI Examples、LangChain4j）和 3 篇权威文章/指南（Anthropic Building Effective Agents、Anthropic Writing Effective Tools for Agents、OpenAI Practical Guide to Building Agents）放在一起，回答一个问题：跨这些来源，关于"怎样做一个有效的 agent"，哪些结论是收敛的、哪些是有条件的。代码项目回答"怎么实现"，文章回答"该不该做、做到什么程度、如何上线和优化"，两者拼起来才是完整的工程判断。它是 `analysis/01..06`、`08..09` 之上的一层归纳，`analysis/04` 仍专注 skill 设计取舍，本文件不替代它。

## 综合结论

- **形态选择先于框架选择**。所有来源都指向同一件事：先判断任务需要的最小形态，再选语言/框架去落地。Anthropic 文章把它讲成原则（最简优先），Pi / OpenAI Agents JS / LangGraph / Vercel 用不同实现验证了同一判断。
- **agent 的本质是"模型 + 环境反馈 + 显式停止"的循环**。Pi 的 `agent-loop.ts`、OpenAI Agents JS 的 `runLoop`、Vercel 的 `ToolLoopAgent`、文章的 autonomous agent 定义完全一致：每步要拿 ground truth，循环必须有预算/停止条件。
- **工具质量决定 agent 上限**。schema-first tool 只是起点；工具还要有清晰边界、可区分命名、模型友好的返回上下文、可修复错误、token 预算和真实任务 eval。Anthropic tool 文章把这点讲得最直接，MCP/TS/Java 项目提供实现证据。
- **边界比循环更重要**。权限在工具执行边界、敏感上下文走 typed context 而不是 prompt、UI/model 消息分离、guardrails 分层部署——这几条在 TS、Java、文章里反复出现，是最稳的可复用准则。
- **复杂度要被需求拉动，不能被框架推动**。durable graph、subagent、MCP、vector memory 都只在需求出现时才引入；文章的"能用 workflow 就别上 agent"是这条的权威背书。

## 形态选择光谱

从轻到重，每一档给出触发条件、代表来源、过度工程的反例：

| 形态 | 何时用 | 代表来源 | 过度工程反例 |
| --- | --- | --- | --- |
| 确定性代码 | 不需要模型判断，传统自动化没有明显摩擦 | Anthropic / OpenAI 文章（最简优先、先验证适用性） | 给固定规则套个 LLM |
| 单次模型调用 | 纯生成/分类/抽取/摘要，无外部动作 | 文章；LangChain4j AI Service | 为一次分类起 tool loop |
| 结构化 workflow（chain/routing/parallel/orchestrator/evaluator） | 步骤基本可枚举、要可预测性 | Spring AI agentic-patterns；Anthropic 五模式；OpenAI 单 agent loop | 步骤已知却让模型自由发挥 |
| tool loop（ReAct） | 模型要动态选少量工具，能在一轮请求内完成 | Pi、OpenAI Agents JS、Vercel ToolLoopAgent | 简单链式任务硬塞自治循环 |
| durable graph/workflow | 需要 checkpoint、resume、长任务、跨进程审批 | LangGraphJS；Vercel WorkflowAgent | in-memory 够用却上 graph runtime |
| subagent / multi-agent | 需要隔离上下文或工具权限、专业分工值回延迟；复杂条件或工具重叠已压垮单 agent | Pi subagent；OpenAI agent-as-tool / handoff | 单任务拆多 agent 徒增延迟和失败面 |
| MCP 能力边界 | 能力要被多个 client/agent 复用，且能控制 tool overload | MCP TS SDK；Anthropic tool 文章 | 把业务 workflow 整个塞进 MCP tool，或一次暴露大量重叠工具 |

## 跨来源共识矩阵

| 主题 | Anthropic Agent 文章 | Anthropic Tool 文章 | OpenAI 指南 | TS 项目（Pi/OpenAI/LangGraph/Vercel/MCP） | Java 项目（Spring AI/LC4j） | 收敛结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 何时上 agent | 能 workflow 就别 agent，能单次就别 workflow | 工具应匹配真实任务而不是盲目扩面 | 复杂判断、难维护规则、非结构化数据才优先 agent | tool loop 只在需动态选工具时用 | AI Service 默认单次，agentic 才编排 | 形态按"步骤可不可预测 + 自动化摩擦"选，默认最简 |
| 工具契约 | ACI 当公共 API 设计 | tool 名称、namespace、schema、响应、错误都为 agent 优化 | tools 分 data/action/orchestration，并需标准化定义 | schema-first（Zod）、description 写给模型 | `@Tool`/record/接口、typed executor | 工具 schema 优先，描述面向模型，handler 面向系统，并用 eval 验证可用性 |
| 停止/预算 | 显式停止条件防失控 | 记录 token、tool count、runtime、错误；截断要可继续 | run loop 有退出条件；失败阈值触发人工 | `stopWhen`/step limit/terminate 标记 | 链路有限步、显式终止 | 任何循环都要有步数/成本/超时/checkpoint，并记录停止原因 |
| 权限/审批 | 沙箱 + 护栏 + 人类检查点 | tool overload 需 allowlist/active tools 控制 | layered guardrails + tool risk rating + human intervention | beforeToolCall 拦截、toolApproval、HITL | DI 层做权限、函数回调边界 | 权限放工具执行边界；高风险动作分级、审批或移交人 |
| 状态边界 | transparency：规划步骤可见 | 工具返回高信号上下文，少暴露低层内部细节 | instructions/guardrails 与工具能力分层 | turn snapshot、runtimeContext/toolsContext、UI/model 分离 | session/record 分层 | 域/运行时/模型/UI 消息要分开，避免泄漏 |
| 渐进式披露 | 简单接口、按需暴露 | 少而高价值工具，concise/detailed 响应按需切换 | 单 agent 优先，工具过载再拆 agent | Pi skill 先给名称描述再读内容 | LC4j skills 同思路 | skill/工具按任务暴露，别一次塞满上下文 |
| 评测与优化 | sandbox + 真实反馈 | 真实任务 eval、transcript 分析、held-out 测试 | 先强模型建 baseline，再降成本 | fake model tests、trace、replay | service/test 分层 | tool/prompt/model 变更要有可比较的 eval 或回放证据 |

## 分歧与取舍

这些点没有唯一答案，需按项目条件选择：

- **抽象框架 vs 重框架**：文章建议直接基于 LLM API 起步、把框架当起点；LangGraph/Vercel 提供了重框架的便利。取舍：原型和可控流程用轻方案，需要 checkpoint/replay/审批再上 durable runtime。
- **in-memory vs durable**：Pi/OpenAI/Vercel ToolLoopAgent 默认进程内；LangGraph 默认可持久化。取舍：有合规、长耗时、跨进程恢复需求才 durable，否则进程内更简单。
- **单 agent vs multi-agent**：Anthropic 和 Pi 都提醒 subagent 增加延迟与失败面；OpenAI 补充了更具体的触发条件：复杂分支、prompt 模板难维护、工具相似/重叠导致选择失败。只有这些收益大于复杂度时才拆。
- **handoff vs agent-as-tool**：移交控制权用 handoff，委托子任务取结果用 agent-as-tool（OpenAI Agents JS 的明确区分），不要混用。
- **工具合并 vs 工具拆分**：Anthropic tool 文章鼓励避免 endpoint sprawl，但工具也不能大到隐藏权限和失败边界。取舍标准是自然任务边界 + eval 表现 + 审计/审批清晰度。

## 对 skill 的总体指导

截至 1.2.0，上面的收敛结论沉淀进 `build-ai-agents`：

- `SKILL.md` Architecture Rules 增加"最简优先"判定链，作为形态选择的第一道闸。
- `SKILL.md` Build Workflow 增加 use-case qualification、eval/model baseline、真实任务工具评测和 human intervention 条件。
- `references/agent-architecture.md` 新增 `Workflow vs Agent` 小节与对应决策表行，把光谱写进 skill。
- `references/agent-architecture.md` 补充单 agent 优先、manager vs handoff、多 agent 拆分触发条件。
- `references/anti-patterns.md` 强化"在固定 workflow 更可靠时却做自治 agent"。
- `references/context-and-tools.md` 把 ACI 写成显式准则，并扩展到 tool 选择、命名、响应、错误、token 和 eval。
- `references/security-and-safety.md` 补充 layered guardrails、tool risk rating、失败阈值和高风险动作的人类介入。
- 这些都是 additive 强化，不改 skill 契约（故 1.1.0 和 1.2.0 都是 MINOR）。

## 后续可分析方向

留给下一次迭代的线索（均为权威来源，尚未单独分析）：

- Google Agent Development Kit docs：另一套工程化 agent 框架的形态与边界设计。
- ReAct：经典 tool-use / reasoning-action 论文，可为 tool loop 形态补充原始理论来源。
- Reflexion：失败反馈、语言化记忆和自我改进循环，可补充 eval/optimizer 与 memory 风险边界。
- Toolformer：工具使用学习的经典论文，可补充"模型如何学会调用工具"的研究视角。

按既定流程：新增来源时建下一个 `10-...md`、在 `SOURCE_INDEX.md` 的 Articles and Papers 表加行、更新本文件的共识矩阵、追加 `CHANGELOG.md`。
