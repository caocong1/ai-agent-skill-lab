# AI Agent 总体分析总结

> 分析版本：1.3 ｜ 最后更新：2026-05-22 ｜ 覆盖来源：全部 9 个代码项目 + Anthropic Building Effective Agents / Anthropic Writing Effective Tools for Agents / OpenAI Practical Guide to Building Agents（版本见 `analysis/SOURCE_INDEX.md`）

这份报告把已分析的 9 个代码项目（Pi、OpenAI Agents JS、LangGraphJS、MCP TS SDK、Vercel AI SDK、Spring AI Examples、LangChain4j、Learn Claude Code、Hello-Agents）和 3 篇权威文章/指南（Anthropic Building Effective Agents、Anthropic Writing Effective Tools for Agents、OpenAI Practical Guide to Building Agents）放在一起，回答一个问题：跨这些来源，关于"怎样做一个有效的 agent"，哪些结论是收敛的、哪些是有条件的。生产框架（Pi / OpenAI / LangGraph / Vercel / MCP / Spring AI / LangChain4j）回答"怎么实现"，权威文章回答"该不该做、做到什么程度、如何上线和优化"，教学型仓库（Learn Claude Code 窄而深 / Hello-Agents 宽而长）回答"把这些机制各自最小化或全栈编目给我看一遍"——三类拼起来才是完整的工程判断。它是 `analysis/01..06`、`08..11` 之上的一层归纳，`analysis/04` 仍专注 skill 设计取舍，本文件不替代它。

## 综合结论

- **形态选择先于框架选择**。所有来源都指向同一件事：先判断任务需要的最小形态，再选语言/框架去落地。Anthropic 文章把它讲成原则（最简优先），Pi / OpenAI Agents JS / LangGraph / Vercel 用不同实现验证了同一判断。
- **agent 的本质是"模型 + 环境反馈 + 显式停止"的循环**。Pi 的 `agent-loop.ts`、OpenAI Agents JS 的 `runLoop`、Vercel 的 `ToolLoopAgent`、Learn Claude Code 各课不变的 `while stop_reason == "tool_use"` 循环、文章的 autonomous agent 定义完全一致：每步要拿 ground truth，循环必须有预算/停止条件。
- **agency 来自模型训练，harness 来自工程**。Learn Claude Code 把这条立场化得最锋利：循环本身永远不变，新增能力是围绕循环挂载机制；harness 由 tools / knowledge / context / observation / permissions 五项组成，是工程师的工作面，与"训练 agent"严格区分。这与 Anthropic"框架只是起点"、OpenAI"agent = model + tools + instructions"是同一论点的不同强度表达。
- **工具质量决定 agent 上限**。schema-first tool 只是起点；工具还要有清晰边界、可区分命名、模型友好的返回上下文、可修复错误、token 预算和真实任务 eval。Anthropic tool 文章把这点讲得最直接，MCP/TS/Java 项目提供实现证据。
- **边界比循环更重要**。权限在工具执行边界、敏感上下文走 typed context 而不是 prompt、UI/model 消息分离、guardrails 分层部署、并行 agent 按任务隔离工作目录——这几条在 TS、Java、文章和教学版里反复出现，是最稳的可复用准则。
- **复杂度要被需求拉动，不能被框架推动**。durable graph、subagent、MCP、vector memory 都只在需求出现时才引入；文章的"能用 workflow 就别上 agent"是这条的权威背书。
- **训练侧 agency 是兜底通路，不是起点**。inference-time（prompt / 工具 / 上下文 / 记忆 / 评估）穷尽后，再考虑 SFT / RL 微调；Hello-Agents 第 11 章给出了完整的 SFT + GRPO 最小训练通路，但教程同样强调"反过来做（一缺什么就训练）会陷入算力陷阱"。BFCL / GAIA 等公开基准在量化 inference-time 天花板时尤其有用。
- **协议要按谱系而非单点选**。MCP / A2A / ANP 三档分别对应不同的互操作性、灵活性、性能要求；MCP 当前最成熟默认，但 agent-to-agent 直连或去中心化服务发现是真实场景时，需要按谱系而不是单点决策。

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
| 教学型 harness 实现 | 想看清某个机制（compaction、memory 三段、错误恢复、mailbox）的最小骨架，或给团队建立 harness 设计共同语言 | Learn Claude Code 20 课 | 把教学版默认值（teammate 轮上限、bash 黑名单、文件邮箱）直接搬到生产 |
| 教学型全栈编目 | 给团队建立"理论 / 范式 / 框架 / 进阶 / 案例"的共同语言；review 时拿最小三件套（Message / Config / Agent）作为"必要抽象基线" | Hello-Agents 16 章 | 把章节内 Coze / Dify yaml、赛博小镇好感度数值、HelloAgents 自建框架原样搬到生产 |
| 训练侧 agency（SFT / RL 微调） | inference-time 优化（prompt / 工具 / 上下文 / 记忆）已穷尽且与 BFCL / GAIA 等公开基准还有可量化差距 | Hello-Agents 第 11 章 Agentic-RL（LoRA SFT + GRPO） | 一缺工具调用准确率就跳去训练，没先把工具描述 / namespace / eval 做完 |

## 跨来源共识矩阵

| 主题 | Anthropic Agent 文章 | Anthropic Tool 文章 | OpenAI 指南 | TS 项目（Pi/OpenAI/LangGraph/Vercel/MCP） | Java 项目（Spring AI/LC4j） | Learn Claude Code | Hello-Agents | 收敛结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 何时上 agent | 能 workflow 就别 agent，能单次就别 workflow | 工具应匹配真实任务而不是盲目扩面 | 复杂判断、难维护规则、非结构化数据才优先 agent | tool loop 只在需动态选工具时用 | AI Service 默认单次，agentic 才编排 | "prompt chain + if/else 不是 agent"；agent 是模型在循环里基于环境反馈决策 | "流程驱动 Agent（Coze/Dify/n8n）vs AI Native Agent"是方法论差异；前者本质是软件开发，后者才以模型判断为核心 | 形态按"步骤可不可预测 + 自动化摩擦"选，默认最简；prompt-plumbing 不是 agency |
| 工具契约 | ACI 当公共 API 设计 | tool 名称、namespace、schema、响应、错误都为 agent 优化 | tools 分 data/action/orchestration，并需标准化定义 | schema-first（Zod）、description 写给模型 | `@Tool`/record/接口、typed executor | tool handler 字典 + 显式 input_schema，hook 在不改 loop 的前提下加策略 | 工具基类 + 注册机制 + 多源搜索 + 自定义工具开发模板 | 工具 schema 优先，描述面向模型，handler 面向系统，并用 eval 验证可用性 |
| 停止/预算 | 显式停止条件防失控 | 记录 token、tool count、runtime、错误；截断要可继续 | run loop 有退出条件；失败阈值触发人工 | `stopWhen`/step limit/terminate 标记 | 链路有限步、显式终止 | `stop_reason != tool_use` 退出；teammate/loop 有显式轮数上限 | ReAct 章节明确写死循环防护与调用失败重试 | 任何循环都要有步数/成本/超时/checkpoint，并记录停止原因 |
| 权限/审批 | 沙箱 + 护栏 + 人类检查点 | tool overload 需 allowlist/active tools 控制 | layered guardrails + tool risk rating + human intervention | beforeToolCall 拦截、toolApproval、HITL | DI 层做权限、函数回调边界 | `PermissionRule` 在 handler 前置；worktree 给每任务独立目录 | TerminalTool 内置沙箱与安全机制 | 权限放工具执行边界；高风险动作分级、审批或移交人；并行 agent 隔离工作目录 |
| 状态边界 | transparency：规划步骤可见 | 工具返回高信号上下文，少暴露低层内部细节 | instructions/guardrails 与工具能力分层 | turn snapshot、runtimeContext/toolsContext、UI/model 分离 | session/record 分层 | section-based system prompt 拼装；tool_result 大对象落盘换句柄 | Message / Config / Agent 三件套分离；NoteTool 把结构化笔记当持久化层 | 域/运行时/模型/UI 消息要分开，避免泄漏；prompt 与上下文按 section/句柄按需注入 |
| 渐进式披露 | 简单接口、按需暴露 | 少而高价值工具，concise/detailed 响应按需切换 | 单 agent 优先，工具过载再拆 agent | Pi skill 先给名称描述再读内容 | LC4j skills 同思路 | skill catalog 注入名称+一句话，`load_skill` 才注入全文 | GSSC 流水线（Gathering/Structuring/Scoring/Compression）按相关性评分再压缩 | skill/工具按任务暴露，别一次塞满上下文 |
| 上下文压缩 | 简单接口、留好压缩空间 | 工具返回保持 token 节制 | run loop 内做压缩与截断 | LangGraph state、Pi `transformContext`、Vercel `prepareStep` | DI/session 内手工管理 | 四层 cheap-first：snip → micro-replace → tool-result budget → LLM 摘要 → reactive 应急 | GSSC 在"上下文组装时"前置压缩；cheap-first 在"上下文过载时"应急 | 上下文压缩要分层（廉价裁剪先于昂贵 LLM 摘要）+ 组装时的前置 GSSC + 应急回退 + 大输出落盘句柄 |
| 记忆设计 | 简单 retrieval 起步 | 不在范围 | 长任务 / 跨会话才用 memory | retrieval、provider memory、 LangGraph store | 用 DI/session/外部存储 | 三段流程：selection（什么值得记）→ extraction（结构化抽取）→ consolidation（合并去重） | 四级容器：工作 / 短期 / 长期 / 永久 + MemoryTool + 高级 RAG（重排序 / 多跳 / 语义路由） | memory 是流程也是层次：三段流程决定"怎么写"，四级容器决定"放哪一层"，两者互补；并按租户隔离 |
| 错误恢复 | 累积失败需护栏 | 错误应可被模型修正或可继续 | 失败阈值 → 人工 | OpenAI/Vercel：可中断 / 拒绝 / 重试 | service 层异常分类 | 三路径：max_tokens 升档+continuation；prompt_too_long → reactive compact；429/529 → 指数退避 + fallback 模型 | ReAct/PlanAndSolve 章节内含死循环防护与调用失败重试模板 | 错误按类型分路径恢复；退避要带 jitter；模型不可用要有 fallback；超阈值升给人 |
| 评测与优化 | sandbox + 真实反馈 | 真实任务 eval、transcript 分析、held-out 测试 | 先强模型建 baseline，再降成本 | fake model tests、trace、replay | service/test 分层 | 每节课 standalone `code.py` 自带最小用例，可读可跑 | BFCL（工具调用准确率）+ GAIA（端到端通用助手）作为公开基准；评估闭环驱动 Agentic-RL 训练 | tool/prompt/model 变更要有可比较的 eval 或回放证据；建自定义 eval 前先看 BFCL / GAIA 等公开基准能否对齐 |
| 协议选择 | 不在范围 | MCP 是接入外部能力的协议层 | MCP 作为 orchestration 工具的标准化通道 | MCP TS SDK：server / client / transport 完整实现 | Spring AI MCP annotations | 简化 MCP 客户端教学版（s19） | MCP / A2A / ANP 三档谱系，按互操作性 / 灵活性 / 性能取舍 | MCP 是当前最成熟默认；A2A 用于 agent 直连、ANP 用于去中心化服务发现；按场景升级而非平替 |
| 训练侧 agency | 不在范围 | 不在范围 | 不在范围（focus 推理侧） | 不在范围 | 不在范围 | 不在范围 | Agentic-RL：GSM8K + LoRA SFT（学会思考）+ GRPO（无需 critic 的策略优化） + 评估闭环 | inference-time（prompt/工具/上下文/记忆）穷尽后再考虑训练侧；BFCL/GAIA 量化差距驱动 SFT/RL 决策 |

## 分歧与取舍

这些点没有唯一答案，需按项目条件选择：

- **抽象框架 vs 重框架**：文章建议直接基于 LLM API 起步、把框架当起点；LangGraph/Vercel 提供了重框架的便利。取舍：原型和可控流程用轻方案，需要 checkpoint/replay/审批再上 durable runtime。
- **in-memory vs durable**：Pi/OpenAI/Vercel ToolLoopAgent 默认进程内；LangGraph 默认可持久化。取舍：有合规、长耗时、跨进程恢复需求才 durable，否则进程内更简单。
- **单 agent vs multi-agent**：Anthropic 和 Pi 都提醒 subagent 增加延迟与失败面；OpenAI 补充了更具体的触发条件：复杂分支、prompt 模板难维护、工具相似/重叠导致选择失败。只有这些收益大于复杂度时才拆。
- **handoff vs agent-as-tool**：移交控制权用 handoff，委托子任务取结果用 agent-as-tool（OpenAI Agents JS 的明确区分），不要混用。
- **工具合并 vs 工具拆分**：Anthropic tool 文章鼓励避免 endpoint sprawl，但工具也不能大到隐藏权限和失败边界。取舍标准是自然任务边界 + eval 表现 + 审计/审批清晰度。

## 对 skill 的总体指导

截至 1.4.0，上面的收敛结论沉淀进 `build-ai-agents`：

- `SKILL.md` Architecture Rules 增加"最简优先"判定链，作为形态选择的第一道闸；首条改写为"区分 agent 与 harness"，明确 harness 由 tools / knowledge / context / observation / permissions 组成。
- `SKILL.md` Build Workflow 增加 use-case qualification、eval/model baseline（含 BFCL / GAIA 公开基准）、真实任务工具评测、human intervention 条件，以及"inference-time 穷尽后再考虑 SFT/RL 训练侧通路"的进入条件。
- `references/agent-architecture.md` 新增 `Workflow vs Agent` 与 `Agent vs Harness Boundary` 小节，把光谱与工程心智模型一并写进 skill；`Loop Design` 增补 hook 扩展点；补充单 agent 优先、manager vs handoff、多 agent 拆分触发条件；并补充"流程驱动平台 vs AI Native Agent 是方法论差异"。
- `references/anti-patterns.md` 强化"在固定 workflow 更可靠时却做自治 agent"。
- `references/context-and-tools.md` 把 ACI 写成显式准则，并扩展到 tool 选择、命名、响应、错误、token 和 eval；`Compaction Strategy` 改成 cheap-first → expensive-last 多层管线，并并列引用 GSSC（Gathering / Structuring / Scoring / Compression）作为"上下文组装时的前置压缩"；`Memory Pipeline` 把 selection/extraction/consolidation 三段流程与"工作 / 短期 / 长期 / 永久"四级容器视角并列。
- `references/mcp-patterns.md` 协议选择部分新增 A2A / ANP 谱系，按互操作性 / 灵活性 / 性能取舍。
- `references/security-and-safety.md` 补充 layered guardrails、tool risk rating、失败阈值、高风险动作的人类介入，以及"按任务隔离工作目录（worktree / sandbox dir）"与"trajectory 与日志同等脱敏"。
- `references/testing-observability.md` 增补长任务 / 后台 / cron 触发的观测要点与错误恢复三路径模板；`Eval Strategy` 把 BFCL（工具调用）与 GAIA（端到端通用助手）作为"建自定义 eval 前先看公开基准"的默认参考。
- `references/source-map.md` 把 Learn Claude Code 与 Hello-Agents 都归到"教学型来源"分类，分别标注"窄而深 + harness 机制穷举"与"广覆盖 + 训练侧"角色。
- 这些都是 additive 强化，不改 skill 契约（故 1.1.0、1.2.0、1.3.0、1.4.0 都是 MINOR）。

## 后续可分析方向

留给下一次迭代的线索（均为权威来源，尚未单独分析）：

- Claude Code 官方文档：与 Learn Claude Code 教学版互参，能把"教学化简实现"对回"产品化的 harness 形态"。
- Anthropic Agent SDK / Claude Agent SDK 文档：harness 工程的 SDK 级抽象，可补充与本仓库已有 TS/Java agent SDK 的对照。
- Google Agent Development Kit docs：另一套工程化 agent 框架的形态与边界设计。
- ReAct：经典 tool-use / reasoning-action 论文，可为 tool loop 形态补充原始理论来源（Hello-Agents 第 4 章只是工程实现，原论文仍值得单独分析）。
- Reflexion：失败反馈、语言化记忆和自我改进循环，可补充 eval/optimizer 与 memory 风险边界。
- Toolformer：工具使用学习的经典论文，可补充"模型如何学会调用工具"的研究视角。
- GRPO 原始论文（DeepSeek-Math）：Hello-Agents 第 11 章给出了工程实现，原论文可补"为什么用 group relative 替代 critic 网络"的理论基础。
- BFCL / GAIA 评估基准论文：Hello-Agents 第 12 章引用其作为评估基准，但 leaderboard 设计与评估方法论本身值得单独读。

按既定流程：新增来源时建下一个 `12-...md`、在 `SOURCE_INDEX.md` 的对应表加行、更新本文件的共识矩阵、追加 `CHANGELOG.md`。
