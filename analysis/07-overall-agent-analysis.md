# AI Agent 总体分析总结

> 分析版本：2.1 ｜ 最后更新：2026-08-04 ｜ 覆盖来源：全部 13 个代码项目 + 5 篇权威文章/指南 + 检索策略研究综述（向量 RAG vs Agentic，多来源）（版本见 `analysis/SOURCE_INDEX.md`）

这份报告把已分析的 13 个代码项目、5 篇权威文章/指南和 1 篇研究综述放在一起，回答一个问题：跨这些来源，关于“怎样做一个有效的 agent”，哪些结论是收敛的、哪些是有条件的。生产框架回答“怎么实现”，通用指南回答“该不该做”，教学仓库回答“最小骨架是什么”，SkillOpt 回答“如何验证式自我改进”；本次新增的 OpenAI Harness Engineering、Anthropic 长任务 harness、OpenAI Codex 与 mini-swe-agent 则共同回答“模型之外的工程环境到底包括哪些层、怎样证明额外 scaffold 有价值”。它是 `analysis/01..06`、`08..17` 之上的一层归纳，`analysis/04` 仍专注早期 skill 设计取舍，本文件不替代它。

## 综合结论

- **形态选择先于框架选择**。所有来源都指向同一件事：先判断任务需要的最小形态，再选语言/框架去落地。Anthropic 文章把它讲成原则（最简优先），Pi / OpenAI Agents JS / LangGraph / Vercel 用不同实现验证了同一判断。
- **agent 的本质是"模型 + 环境反馈 + 显式停止"的循环**。Pi 的 `agent-loop.ts`、OpenAI Agents JS 的 `runLoop`、Vercel 的 `ToolLoopAgent`、Learn Claude Code 各课不变的 `while stop_reason == "tool_use"` 循环、文章的 autonomous agent 定义完全一致：每步要拿 ground truth，循环必须有预算/停止条件。
- **agency 来自模型训练，harness 来自工程**。Learn Claude Code 把这条立场化得最锋利：循环本身永远不变，新增能力是围绕循环挂载机制；harness 由 tools / knowledge / context / observation / permissions 五项组成，是工程师的工作面，与"训练 agent"严格区分。这与 Anthropic"框架只是起点"、OpenAI"agent = model + tools + instructions"是同一论点的不同强度表达。
- **harness 至少有三层**。第一层是 turn/runtime（loop、tools、context、sandbox、approval）；第二层是跨 session continuity（rollout、progress、checkpoint、contract、resume）；第三层是 repository/organization feedback system（规格、架构地图、可启动环境、observability、lint、review 规则与持续垃圾回收）。只实现第一层不能自动获得长任务可靠性或组织级自治（见 `analysis/14..16`）。
- **compaction 不等于 continuity，完成判定必须外部化**。长任务需要 default-FAIL contract、progress + git 双通道交接、fresh-session smoke test 和独立 evaluator；否则摘要再好也会出现半成品接力、过早完成和 builder 自评偏差（见 `analysis/15`）。
- **复杂 harness 必须用消融证明价值**。mini-swe-agent 的 bash-only、linear-history、stateless execution 提供可解释基线；模型升级后应逐项移除专用工具、prompt 补丁或 hook，只有 eval 仍显示增益的机制才继续保留（见 `analysis/17`）。
- **工具质量决定 agent 上限**。schema-first tool 只是起点；工具还要有清晰边界、可区分命名、模型友好的返回上下文、可修复错误、token 预算和真实任务 eval。Anthropic tool 文章把这点讲得最直接，MCP/TS/Java 项目提供实现证据。
- **边界比循环更重要**。权限在工具执行边界、敏感上下文走 typed context 而不是 prompt、UI/model 消息分离、guardrails 分层部署、并行 agent 按任务隔离工作目录——这几条在 TS、Java、文章和教学版里反复出现，是最稳的可复用准则。
- **复杂度要被需求拉动，不能被框架推动**。durable graph、subagent、MCP、vector memory 都只在需求出现时才引入；文章的"能用 workflow 就别上 agent"是这条的权威背书。
- **训练侧 agency 是兜底通路，不是起点**。inference-time（prompt / 工具 / 上下文 / 记忆 / 评估）穷尽后，再考虑 SFT / RL 微调；Hello-Agents 第 11 章给出了完整的 SFT + GRPO 最小训练通路，但教程同样强调"反过来做（一缺什么就训练）会陷入算力陷阱"。BFCL / GAIA 等公开基准在量化 inference-time 天花板时尤其有用。
- **协议要按谱系而非单点选**。MCP / A2A / ANP 三档分别对应不同的互操作性、灵活性、性能要求；按谱系（互操作性 / 灵活性 / 性能 / 生态成熟度）而非单点决策——agent-to-agent 直连或去中心化服务发现是真实场景时尤需如此。成熟度排名随版本周期变动，是会过期的"现状"而非 durable 结论：截至 2026-06 源快照，MCP 采纳与工具链最成熟、可作默认，但实现前请复核 A2A / ANP 的当前成熟度。
- **文档检索按规模与查询类型分层，不默认上向量库**。小语料（约 < 20 万 token / 单项目几十文件）用 agentic grep/read 或全量上下文；越过拐点、或需语义 / 跨全库 / 高频低延迟 / 多租户隔离时才上 hybrid 向量+重排（且先 pgvector，专用向量库留给十亿级）。检索失败常是静默的——纯向量漏精确串（编号 / 型号 / 条款号 / 否定词）、纯关键词漏同义改写——故精确串走精确匹配兜底、自然语言查询前加查询扩展（见 `analysis/12-retrieval-strategy-vector-vs-agentic.md`）。这是"复杂度被需求拉动，不被框架推动"在检索维度的体现。
- **skill/prompt 优化也要像工程变更一样 gate**。SkillOpt 把 skill 文档当作 frozen agent 的可训练外部状态：rollout 真实任务、反思轨迹、提出有界文本 edit、用 held-out validation gate 接受/拒绝，再导出 compact artifact。对本仓库的含义是：prompt、tool description、skill 规则都不是"随手润色"，而是行为变更，应该有 baseline、验证集、拒绝记录和 staged adoption（见 `analysis/13-skillopt.md`）。

## 形态选择光谱

从轻到重，每一档给出触发条件、代表来源、过度工程的反例：

| 形态 | 何时用 | 代表来源 | 过度工程反例 |
| --- | --- | --- | --- |
| 确定性代码 | 不需要模型判断，传统自动化没有明显摩擦 | Anthropic / OpenAI 文章（最简优先、先验证适用性） | 给固定规则套个 LLM |
| 单次模型调用 | 纯生成/分类/抽取/摘要，无外部动作 | 文章；LangChain4j AI Service | 为一次分类起 tool loop |
| 结构化 workflow（chain/routing/parallel/orchestrator/evaluator） | 步骤基本可枚举、要可预测性 | Spring AI agentic-patterns；Anthropic 五模式；OpenAI 单 agent loop | 步骤已知却让模型自由发挥 |
| tool loop（ReAct） | 模型要动态选少量工具，能在一轮请求内完成 | Pi、OpenAI Agents JS、Vercel ToolLoopAgent | 简单链式任务硬塞自治循环 |
| 极简 benchmark harness | 需要可解释、跨模型/环境可比较的 coding-agent 基线 | mini-swe-agent（bash-only + linear trajectory） | 未建立 baseline 就堆 planner、memory、专用工具和多 agent |
| durable graph/workflow | 需要 checkpoint、resume、长任务、跨进程审批 | LangGraphJS；Vercel WorkflowAgent | in-memory 够用却上 graph runtime |
| long-running session harness | 任务跨多个 context/session，完成可拆成可验证 contract | Anthropic long-running harness（initializer/coding、progress + git、fresh evaluator） | 只循环同一个 prompt 或只依赖 compaction，未定义 clean handoff |
| repository/organization harness | coding agent 覆盖复现、实现、E2E、review、CI 与持续维护 | OpenAI Harness Engineering；OpenAI Codex | 只有一份巨型 AGENTS.md，却无可启动环境、observability 和机械约束 |
| subagent / multi-agent | 需要隔离上下文或工具权限、专业分工值回延迟；复杂条件或工具重叠已压垮单 agent | Pi subagent；OpenAI agent-as-tool / handoff | 单任务拆多 agent 徒增延迟和失败面 |
| MCP 能力边界 | 能力要被多个 client/agent 复用，且能控制 tool overload | MCP TS SDK；Anthropic tool 文章 | 把业务 workflow 整个塞进 MCP tool，或一次暴露大量重叠工具 |
| 教学型 harness 实现 | 想看清某个机制（compaction、memory 三段、错误恢复、mailbox）的最小骨架，或给团队建立 harness 设计共同语言 | Learn Claude Code 20 课 | 把教学版默认值（teammate 轮上限、bash 黑名单、文件邮箱）直接搬到生产 |
| 教学型全栈编目 | 给团队建立"理论 / 范式 / 框架 / 进阶 / 案例"的共同语言；review 时拿最小三件套（Message / Config / Agent）作为"必要抽象基线" | Hello-Agents 16 章 | 把章节内 Coze / Dify yaml、赛博小镇好感度数值、HelloAgents 自建框架原样搬到生产 |
| skill / prompt 文本空间优化 | agent harness 已有真实轨迹，skill/prompt/tool 描述反复出现可归纳失败，需要离线迭代但不改模型权重 | SkillOpt（rollout → reflect → bounded edit → validation gate → best_skill） | 让模型直接重写整份 skill，或用 synthetic/dream 任务当最终验收 |
| 训练侧 agency（SFT / RL 微调） | inference-time 优化（prompt / 工具 / 上下文 / 记忆）已穷尽且与 BFCL / GAIA 等公开基准还有可量化差距 | Hello-Agents 第 11 章 Agentic-RL（LoRA SFT + GRPO） | 一缺工具调用准确率就跳去训练，没先把工具描述 / namespace / eval 做完 |

## 跨来源共识矩阵

| 主题 | Anthropic Agent 文章 | Anthropic Tool 文章 | OpenAI 指南 | TS 项目（Pi/OpenAI/LangGraph/Vercel/MCP） | Java 项目（Spring AI/LC4j） | Learn Claude Code | Hello-Agents | Harness 专题（OpenAI文章/Anthropic/Codex/mini） | 收敛结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 何时上 agent | 能 workflow 就别 agent | 工具匹配真实任务 | 复杂判断、难维护规则、非结构化数据 | tool loop 只在需动态选工具时用 | AI Service 默认单次 | prompt chain 不是 agency | 流程驱动 vs AI Native | mini 提供最小 baseline；复杂 harness 要由需求和 eval 拉动 | 默认最简，prompt-plumbing 不是 agency |
| harness 边界 | 框架只是起点 | ACI 是模型接口 | model/tools/instructions | loop/state/tool runtime | service/DI/session | tools/knowledge/context/observation/permissions | Message/Config/Agent | runtime + continuity + repository/organization feedback 三层 | harness 是模型之外让能力可执行、可持续、可验证的完整工程环境 |
| 工具契约 | ACI 当公共 API | 名称/schema/响应/错误为 agent 优化 | data/action/orchestration | schema-first、动态 tools | typed executor | hook 不改 loop | 工具基类与注册 | Codex step snapshot 保证 advertised tools 与执行一致；mini 以 bash 消融专用 ACI | 工具接口要清晰且用 eval 证明价值，动态 surface 必须快照一致 |
| 停止/预算 | 显式停止条件 | token/tool/runtime/error | 失败阈值触发人工 | stopWhen/step limit | 有限步 | 轮数上限 | 死循环防护 | Anthropic kill switch/无进展停止；mini step/cost/time；Codex stop hook | 每层 loop 都要有预算、停止原因和 operator control |
| 权限/审批 | 沙箱 + 检查点 | active tool gating | layered guardrails | approval/HITL | DI 边界 | handler 前 permission + worktree | TerminalTool sandbox | Codex 集中 approval→sandbox→attempt→有条件 escalation；mini bash-only 扩大权限面 | 权限在执行边界；sandbox denial 不得静默提权 |
| 状态边界 | 规划可见 | 高信号 tool context | instructions/guardrails 分层 | turn snapshot、UI/model 分离 | session/record | section prompt + 句柄 | Message/Config/Agent | Codex 分 turn/step/tool call；rollout 是兼容面；Anthropic progress+git | 域/运行时/模型/UI/trace 分离，并明确生命周期所有权 |
| 长任务连续性 | 留停止与恢复空间 | 截断后可继续 | 跨会话才用 memory | checkpoint/resume | 外部存储 | compaction/memory/task graph | 四级记忆 | compaction 不够；default-FAIL contract、progress+git、fresh-session smoke test | continuity 依赖外部化 contract、checkpoint、证据和 clean handoff |
| 渐进式披露 | 简单接口 | 少而高价值工具 | 单 agent 优先 | Pi skill 分层 | LC4j skills | catalog→load | GSSC | OpenAI 短 AGENTS.md 作地图、结构 docs 作 system of record；Codex 指令有 provenance/budget | 先给地图与能力目录，再按任务加载权威内容 |
| 上下文压缩 | 留压缩空间 | 返回 token 节制 | loop 内截断 | transformContext/prepareStep | 手工管理 | cheap-first 多层 | GSSC | Codex 区分 pre/mid-turn compaction 并保留 continuation；Anthropic 强调摘要不能替代交接 | 压缩解决 token，continuity 解决跨 session 状态，二者不可混同 |
| 评测与优化 | 真实反馈 | held-out tool eval | 强模型 baseline | fake model/trace/replay | service tests | 独立最小用例 | BFCL/GAIA | fresh-context evaluator、证据 gate、linear trajectory、model×harness 联合报告与 ablation | 变更要有可比较 eval；区分模型、harness、环境和评测贡献 |
| 仓库可读性 | transparency | targeted context | instructions 分层 | repo tools | 项目约定 | system prompt sections | ContextBuilder | OpenAI repository-as-record + observability + mechanical invariants + garbage collection | coding-agent readiness 包括知识地图、可启动环境、可观察验收和机械边界 |
| 错误恢复 | 累积失败需护栏 | 可修复错误 | 超阈值给人 | 中断/拒绝/重试 | 异常分类 | token/context/provider 三路径 | 调用重试 | Codex streaming retry、sandbox denial 分类、context rollover；Anthropic fresh session 先修坏交接 | 按错误类型恢复，恢复路径同样受权限、预算和 telemetry 约束 |
| 协议选择 | 不在范围 | MCP 接外部能力 | MCP orchestration | MCP server/client | MCP annotations | 教学 MCP | MCP/A2A/ANP | Codex 按输入和环境动态准备 MCP/skills/plugins | 按互操作性/灵活性/性能选，并控制动态 tool overload |
| 训练侧 agency | 不在范围 | 不在范围 | 不在范围 | 不在范围 | 不在范围 | 不在范围 | SFT + GRPO | mini 减少 scaffold 以观察模型；harness 文章聚焦 inference-time 环境 | 先消融并穷尽 harness，再用可量化差距决定是否训练 |
| 文档检索策略 | 简单 retrieval | targeted search | retrieval tool | provider memory/store | RAG | grep/read | 向量 RAG | OpenAI repo 地图 + progressive docs；Codex 层级指令有 byte budget | 按规模/查询类型路由，并让权威来源、provenance、budget 可见 |
| skill / prompt 自优化 | 不在范围 | transcript 分析 | 先 baseline | skill runtime | skills 形态 | session 经验 | 自进化分类 | OpenAI 把重复反馈编译成 docs/lint/skill；mini 要求模型升级后 re-simplify | SkillOpt gate 文本 edit；组织反馈按证据从说明升级到机械约束 |

## 分歧与取舍

这些点没有唯一答案，需按项目条件选择：

- **抽象框架 vs 重框架**：文章建议直接基于 LLM API 起步、把框架当起点；LangGraph/Vercel 提供了重框架的便利。取舍：原型和可控流程用轻方案，需要 checkpoint/replay/审批再上 durable runtime。
- **in-memory vs durable**：Pi/OpenAI/Vercel ToolLoopAgent 默认进程内；LangGraph 默认可持久化。取舍：有合规、长耗时、跨进程恢复需求才 durable，否则进程内更简单。
- **单 agent vs multi-agent**：Anthropic 和 Pi 都提醒 subagent 增加延迟与失败面；OpenAI 补充了更具体的触发条件：复杂分支、prompt 模板难维护、工具相似/重叠导致选择失败。只有这些收益大于复杂度时才拆。
- **handoff vs agent-as-tool**：移交控制权用 handoff，委托子任务取结果用 agent-as-tool（OpenAI Agents JS 的明确区分），不要混用。
- **工具合并 vs 工具拆分**：Anthropic tool 文章鼓励避免 endpoint sprawl，但工具也不能大到隐藏权限和失败边界。取舍标准是自然任务边界 + eval 表现 + 审计/审批清晰度。
- **极简 vs 生产 harness**：mini-swe-agent 证明 bash-only + linear history 可以成为强基线；Codex 证明真实产品还要处理 step snapshot、dynamic tools、streaming、approval/sandbox、rollout 和多环境。取舍不是选阵营，而是先跑最小 baseline，再逐项用真实任务证明生产机制的增益。
- **compaction vs 外部交接**：Pi/Learn Claude Code/Codex 都实现 context compaction；Anthropic 长任务研究显示 compaction 无法替代 feature contract、progress、git checkpoint 与 fresh-session 验证。前者解决单窗口 token，后者解决跨 session continuity。
- **builder 自评 vs 独立 evaluator**：单 agent 自测更便宜；fresh-context evaluator 能减少实现意图造成的确认偏差。高价值或长任务应隔离 evaluator 上下文并收窄工具，短任务可以用确定性测试代替第二个 agent。

## 对 skill 的总体指导

截至 2.1.0，上面的收敛结论沉淀进一个复合 skill suite：

- `skills/build-ai-agents/SKILL.md` 从单体执行 skill 改成路由器，保留旧入口名，按任务只加载相关 child skill，避免每次 agent 任务都吞下全部参考资料。
- `skills/design-ai-agent/` 承接形态选择、agent vs harness、workflow vs agent、loop/state/memory/approval 决策；2.1.0 起用 runtime / session continuity / repository feedback 三层解释 harness，并加入 minimal baseline、fresh-session continuity 与 model-upgrade ablation。
- `skills/design-agent-tools/` 承接 prompt/context、long-document handling、retrieval、compaction、memory pipeline、tool schema/description 和 ACI。
- `skills/build-mcp-capabilities/` 承接 MCP server/client、resources/prompts/tools、transport、安全和 MCP/A2A/ANP 协议谱系。
- `skills/implement-ts-agents/` 与 `skills/implement-java-agents/` 分别承接 TypeScript 与 Java/Spring/LangChain4j 框架落地模式。
- `skills/review-ai-agents/`、`skills/secure-ai-agents/`、`skills/test-ai-agents/` 把审查、安全、测试/观测从 reference 变成可单独触发的 workflow skills；2.1.0 增加 repository legibility、clean handoff、fresh-context evaluator、step snapshot、sandbox escalation 与 harness ablation。
- `skills/optimize-agent-skills/` 吸收 SkillOpt：skill/prompt 迭代要有 rollout evidence、bounded edit、train/val/test、validation gate、strong optimizer vs frozen target、staged adoption。
- `skills/build-ai-agents/references/source-map.md` 作为唯一保留的共享 source map，记录本地快照、commit、官方链接和高价值文件。
- `SKILL.md` frontmatter 使用 `metadata.version`；suite 当前版本为 2.1.0。

## 后续可分析方向

留给下一次迭代的线索（均为权威来源，尚未单独分析）：

- Claude Code 官方文档：与 Learn Claude Code 教学版互参，能把"教学化简实现"对回"产品化的 harness 形态"。
- Anthropic Agent SDK / Claude Agent SDK 文档：harness 工程的 SDK 级抽象，可补充与本仓库已有 TS/Java agent SDK 的对照。
- Anthropic《Harness Design for Long-Running Application Development》：配套仓库已引用的 2026-03 后续文章，可补 planner/sprint contract/rubric 与本次长任务联合分析之间的版本演进。
- OpenAI Codex 官方安全与 AGENTS.md 文档：把本次源码事实对回稳定的产品契约，补充不同平台 sandbox、权限 profile 与 instruction precedence 的用户侧语义。
- Google Agent Development Kit docs：另一套工程化 agent 框架的形态与边界设计。
- ReAct：经典 tool-use / reasoning-action 论文，可为 tool loop 形态补充原始理论来源（Hello-Agents 第 4 章只是工程实现，原论文仍值得单独分析）。
- Reflexion：失败反馈、语言化记忆和自我改进循环，可补充 eval/optimizer 与 memory 风险边界。
- Toolformer：工具使用学习的经典论文，可补充"模型如何学会调用工具"的研究视角。
- GRPO 原始论文（DeepSeek-Math）：Hello-Agents 第 11 章给出了工程实现，原论文可补"为什么用 group relative 替代 critic 网络"的理论基础。
- BFCL / GAIA 评估基准论文：Hello-Agents 第 12 章引用其作为评估基准，但 leaderboard 设计与评估方法论本身值得单独读；也可与 SkillOpt 式 skill 优化 gate 联动。
- Anthropic Contextual Retrieval：把"contextual embeddings + BM25 + 重排"做成单源深挖，补本仓库检索维度的厂商一手招法（`analysis/12` 已综述，未单独分析）。
- DeepMind LIMIT / NoLiMa 论文：单向量召回的维度天花板与长上下文有效长度远小于标称的硬证据，可为检索选型补理论基线。

按既定流程：新增来源时建下一个递增编号分析文件、在 `SOURCE_INDEX.md` 的对应表加行、更新本文件的共识矩阵、追加 `CHANGELOG.md`。
