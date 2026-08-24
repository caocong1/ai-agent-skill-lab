# AI Agent 总体分析总结

> 分析版本：2.2 ｜ 最后更新：2026-08-23 ｜ 覆盖来源：全部 14 个代码项目 + 6 篇权威文章/指南 + 1 份协议规范修订 + 检索策略研究综述（向量 RAG vs Agentic，多来源）（版本见 `analysis/SOURCE_INDEX.md`）

这份报告把已分析的 13 个代码项目、5 篇权威文章/指南和 1 篇研究综述放在一起，回答一个问题：跨这些来源，关于“怎样做一个有效的 agent”，哪些结论是收敛的、哪些是有条件的。生产框架回答“怎么实现”，通用指南回答“该不该做”，教学仓库回答“最小骨架是什么”，SkillOpt 回答“如何验证式自我改进”；本次新增的 OpenAI Harness Engineering、Anthropic 长任务 harness、OpenAI Codex 与 mini-swe-agent 则共同回答“模型之外的工程环境到底包括哪些层、怎样证明额外 scaffold 有价值”；2026-08 刷新新增的 DeepSeek Harness、MCP 2026-07-28 规范修订与 Anthropic 2026-03 harness 设计文章，则补上了此前三个盲区——**副作用与重放的治理、prompt 前缀的经济学、完成判定归属谁**。它是 `analysis/01..06`、`08..20` 之上的一层归纳，`analysis/04` 仍专注早期 skill 设计取舍，`analysis/21` 是对本仓库自身设计的重思、不是来源分析，本文件不替代它们。

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

- **副作用治理需要三件事，缺一不可**：崩溃后知道"做没做"（Pi 的 effect sandwich：预铸输出 id + 提交意图 → 执行 → 提交结算）、重试时"不重复做"（MCP MRTR 把重试变成一等公民，从而把幂等性从最佳实践提升为正确性前提）、做完之后"能撤销"（LangChain4j 1.19 的 agentic 级 tool action compensation）。只做重试与审批的实现，覆盖的只是三分之二。
- **恢复时权限与凭据必须重新取得，不能从序列化状态继承**。三个来源独立给出同一条：Pi 的 `replay: "never" | "safe"` 与合成的 interrupted 结果，DeepSeek 的 `GoalActivation` 故意不持久化以强制人工重新授权，OpenAI Agents JS 在无法证明"哪个响应拥有这个待决输出"时以 `UserError` fail-closed、并规定序列化凭据在恢复时一律不被信任。**状态可以恢复，授权不可以**。
- **prompt 前缀的稳定性是一项成本，不是洁癖**。MCP 2026-07-28 把"`tools/list` 应确定性排序"写进规范，理由直接写成提高 LLM prompt cache 命中率；DeepSeek Harness 要求每个包的 README 必须写 `#### KV Cache effect` 一节。含义是：凡是每轮可能变的东西（工具集合的顺序、skill 列表、环境快照、时间戳）要么固定顺序，要么挪到前缀之后。
- **完成判定必须由执行方之外的东西给出**。DeepSeek 的 goal domain（持久 phase + revisioned CAS）、learn-claude-code s17 的 goal loop（会话级 Stop hook + 无工具的独立判定器 + 闭合三元组 `{ok, reason, impossible}`）、Anthropic 2026-03 的 evaluator（GAN 式生成/评估分离，因为 agent 会自信地夸奖自己的产出）——三个互不相干的来源得出同一结论。同一份材料里也有反例：DeepSeek 的 Ralph 工具**自陈**"完成是 worker 的自我声明，没有独立评估者"。
- **"模型写程序调工具"已是独立出现两次的抽象**。DeepSeek 的 Code Mode（`ctx.codeRuntime`，工具作为绑定命名空间注入）与 OpenAI Agents JS v0.14.0 的 Programmatic Tool Calling（模型生成托管 JavaScript 协调工具并压缩中间结果）解决同一个成本问题：N 次工具调用意味着 N 次往返和 N 份中间结果进上下文。关键约束是它**与原生 tool loop 互斥**——DeepSeek 在 `mode:'code'` 下把模型的原生直接调用拒为 `UNKNOWN_TOOL`，否则模型会在两条路径间摇摆。
- **harness 里的每个组件都是一条带日期的假设，需要定期重扫**。Anthropic 2026-03 把这条写成明规则（Sonnet 4.5 需要 context reset，Opus 4.5 让它被整个删除；Opus 4.6 让 sprint 被整个删除）。MCP 规范给了协议级的同款实例：Roots / Sampling / Logging 被弃用，理由分别是"server 现在可以直接调 LLM API"、"tool 参数已经够用"、"生态补上了 OpenTelemetry"——**三条都不是被更好的设计取代，而是被周边能力变强淘汰的**。
- **非目标清单应与能力清单同等醒目**。Pi 的 harness 文档明确列出不做 exactly-once 外部副作用、流恢复、多写者、复制等；MCP 2026-07-28 删除 SSE 流恢复并规定断流即重发新请求。两个互不相干的设计对"流恢复"做出同一取舍，说明这是普遍判断而非偏好：与其做一个只在部分故障下生效的恢复机制，不如把"重发"做成唯一路径，真正需要跨断连存活的长任务交给可轮询的任务句柄。
- **契约需要弃用政策，不只是 SemVer**。MCP 采纳的 Active / Deprecated / Removed 三态 + 最短 12 个月窗口 + 集中登记表，比在 changelog 里写一句 deprecated 强得多：SemVer 只告诉下游"这次是不是 breaking"，弃用登记表告诉下游"下次哪里会 breaking"。

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
| Code Mode / Programmatic Tool Calling | 一次任务要串起多个工具，且中间结果又大又不需要进上下文 | DeepSeek `ctx.codeRuntime`；OpenAI Agents JS Programmatic Tool Calling | 与原生 tool loop 同时开启，让模型在两条路径间摇摆；或把 `isolation` 标签当成安全承诺 |
| 脚本编排 runtime（模型之上再加一层） | 编排路径事前已知、要并行、要稳定结构、要断点续跑 | DeepSeek workflow engine；learn-claude-code s16 | 路径其实依赖上一步发现什么，却硬写成固定脚本 |
| goal gate（完成闸） | 任务目标是"做到某个可验证状态"，而不是"回答一个问题" | learn-claude-code s17；DeepSeek goal domain；Anthropic evaluator | 用轮次结束当完成信号；或给 goal 另开一套隐藏的轮次预算 |
| 插件树 harness（micro-kernel + profile/bundle） | 同一套能力要按场景（CLI / web / 无头）组装成不同产品，且组合需要可 dump、可审计 | DeepSeek Harness（Cordis 插件树 + `--dump-config`） | 只有两三个场景却先上插件内核；或让插件既是能力定义又是能力提供方，模糊 capability seam |
| 持久化执行 harness | 进程可能崩溃，且任务涉及外部副作用 | Pi `harness.md`（三存储 + 持久化程序计数器 + effect sandwich） | 用重放消息数组冒充恢复；或恢复时直接沿用序列化里的凭据与审批 |
| 教学型 harness 实现 | 想看清某个机制（compaction、memory 三段、错误恢复、mailbox）的最小骨架，或给团队建立 harness 设计共同语言 | Learn Claude Code 17 课 | 把教学版默认值（teammate 轮上限、bash 黑名单、文件邮箱）直接搬到生产 |
| 教学型全栈编目 | 给团队建立"理论 / 范式 / 框架 / 进阶 / 案例"的共同语言；review 时拿最小三件套（Message / Config / Agent）作为"必要抽象基线" | Hello-Agents 16 章 | 把章节内 Coze / Dify yaml、赛博小镇好感度数值、HelloAgents 自建框架原样搬到生产 |
| skill / prompt 文本空间优化 | agent harness 已有真实轨迹，skill/prompt/tool 描述反复出现可归纳失败，需要离线迭代但不改模型权重 | SkillOpt（rollout → reflect → bounded edit → validation gate → best_skill） | 让模型直接重写整份 skill，或用 synthetic/dream 任务当最终验收 |
| 训练侧 agency（SFT / RL 微调） | inference-time 优化（prompt / 工具 / 上下文 / 记忆）已穷尽且与 BFCL / GAIA 等公开基准还有可量化差距 | Hello-Agents 第 11 章 Agentic-RL（LoRA SFT + GRPO） | 一缺工具调用准确率就跳去训练，没先把工具描述 / namespace / eval 做完 |

## 跨来源共识矩阵

| 主题 | Anthropic Agent 文章 | Anthropic Tool 文章 | OpenAI 指南 | TS 项目（Pi/OpenAI/LangGraph/Vercel/MCP） | Java 项目（Spring AI/LC4j） | Learn Claude Code | Hello-Agents | Harness 专题（OpenAI文章/Anthropic/Codex/mini） | 2026-08 刷新（DeepSeek / MCP 2026-07-28 / Anthropic 2026-03） | 收敛结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 何时上 agent | 能 workflow 就别 agent | 工具匹配真实任务 | 复杂判断、难维护规则、非结构化数据 | tool loop 只在需动态选工具时用 | AI Service 默认单次 | prompt chain 不是 agency | 流程驱动 vs AI Native | mini 提供最小 baseline；复杂 harness 要由需求和 eval 拉动 | DeepSeek 用 profile/bundle 按场景组装能力树；Anthropic 2026-03 按模型代际删组件 | 默认最简，prompt-plumbing 不是 agency |
| harness 边界 | 框架只是起点 | ACI 是模型接口 | model/tools/instructions | loop/state/tool runtime | service/DI/session | tools/knowledge/context/observation/permissions | Message/Config/Agent | runtime + continuity + repository/organization feedback 三层 | DeepSeek 以 capability seam（定义+提供+消费三角色）划界，并用 Model Experience README 强制写出模型可见面 | harness 是模型之外让能力可执行、可持续、可验证的完整工程环境 |
| 工具契约 | ACI 当公共 API | 名称/schema/响应/错误为 agent 优化 | data/action/orchestration | schema-first、动态 tools | typed executor | hook 不改 loop | 工具基类与注册 | Codex step snapshot 保证 advertised tools 与执行一致；mini 以 bash 消融专用 ACI | MCP 要求 `tools/list` 确定性排序（prompt cache）；Code Mode / PTC 让工具成为程序绑定命名空间 | 工具接口要清晰且用 eval 证明价值，动态 surface 必须快照一致 |
| 停止/预算 | 显式停止条件 | token/tool/runtime/error | 失败阈值触发人工 | stopWhen/step limit | 有限步 | 轮数上限 | 死循环防护 | Anthropic kill switch/无进展停止；mini step/cost/time；Codex stop hook | DeepSeek turn/step/round 三级 + `concludeTurn()`；s17 要求预算只放主循环一处 | 每层 loop 都要有预算、停止原因和 operator control |
| 权限/审批 | 沙箱 + 检查点 | active tool gating | layered guardrails | approval/HITL | DI 边界 | handler 前 permission + worktree | TerminalTool sandbox | Codex 集中 approval→sandbox→attempt→有条件 escalation；mini bash-only 扩大权限面 | DeepSeek 单调 guard（返回类型无 allow）+ `ApprovalOutcome` 四元组；恢复时不继承序列化凭据 | 权限在执行边界；sandbox denial 不得静默提权 |
| 状态边界 | 规划可见 | 高信号 tool context | instructions/guardrails 分层 | turn snapshot、UI/model 分离 | session/record | section prompt + 句柄 | Message/Config/Agent | Codex 分 turn/step/tool call；rollout 是兼容面；Anthropic progress+git | DeepSeek 事件溯源 + `deriveMessages()` 投影（model-visible ⟺ logged）；Pi 三存储 + 持久化程序计数器 | 域/运行时/模型/UI/trace 分离，并明确生命周期所有权 |
| 长任务连续性 | 留停止与恢复空间 | 截断后可继续 | 跨会话才用 memory | checkpoint/resume | 外部存储 | compaction/memory/task graph | 四级记忆 | compaction 不够；default-FAIL contract、progress+git、fresh-session smoke test | Pi effect sandwich + 按工具重放策略 + 合成 interrupted 结果；MCP 用可轮询任务句柄替代可恢复流 | continuity 依赖外部化 contract、checkpoint、证据和 clean handoff |
| 渐进式披露 | 简单接口 | 少而高价值工具 | 单 agent 优先 | Pi skill 分层 | LC4j skills | catalog→load | GSSC | OpenAI 短 AGENTS.md 作地图、结构 docs 作 system of record；Codex 指令有 provenance/budget | DeepSeek agent scope 两级最具体优先；spill seam 把大结果换成不透明 locator | 先给地图与能力目录，再按任务加载权威内容 |
| 上下文压缩 | 留压缩空间 | 返回 token 节制 | loop 内截断 | transformContext/prepareStep | 手工管理 | cheap-first 多层 | GSSC | Codex 区分 pre/mid-turn compaction 并保留 continuation；Anthropic 强调摘要不能替代交接 | DeepSeek 用锁包住整个 compaction 操作（孤儿锁可检测）+ `surfaceOp: replace`；Anthropic 2026-03 用 reset 而非 compaction 消除 context anxiety | 压缩解决 token，continuity 解决跨 session 状态，二者不可混同 |
| 评测与优化 | 真实反馈 | held-out tool eval | 强模型 baseline | fake model/trace/replay | service tests | 独立最小用例 | BFCL/GAIA | fresh-context evaluator、证据 gate、linear trajectory、model×harness 联合报告与 ablation | Anthropic 2026-03 generator/evaluator 分离 + few-shot 分数拆解校准 + 读分歧改 prompt；OpenAI Agents JS 直接发货 `ScriptedModel` | 变更要有可比较 eval；区分模型、harness、环境和评测贡献 |
| 仓库可读性 | transparency | targeted context | instructions 分层 | repo tools | 项目约定 | system prompt sections | ContextBuilder | OpenAI repository-as-record + observability + mechanical invariants + garbage collection | DeepSeek 把 Model Experience README 契约与 Agent Notes 三态目录做成机械 gate | coding-agent readiness 包括知识地图、可启动环境、可观察验收和机械边界 |
| 错误恢复 | 累积失败需护栏 | 可修复错误 | 超阈值给人 | 中断/拒绝/重试 | 异常分类 | token/context/provider 三路径 | 调用重试 | Codex streaming retry、sandbox denial 分类、context rollover；Anthropic fresh session 先修坏交接 | DeepSeek Code Mode 的正交失败分类（exception/timeout/abort/worker-exit/invalid-output/output-limit）；重放歧义时 fail-closed | 按错误类型恢复，恢复路径同样受权限、预算和 telemetry 约束 |
| 协议选择 | 不在范围 | MCP 接外部能力 | MCP orchestration | MCP server/client | MCP annotations | 教学 MCP | MCP/A2A/ANP | Codex 按输入和环境动态准备 MCP/skills/plugins | MCP 2026-07-28 无状态化 + MRTR + `server/discover`；SDK v2 是换包名；三个下游 3 周内落地 | 按互操作性/灵活性/性能选，并控制动态 tool overload |
| 训练侧 agency | 不在范围 | 不在范围 | 不在范围 | 不在范围 | 不在范围 | 不在范围 | SFT + GRPO | mini 减少 scaffold 以观察模型；harness 文章聚焦 inference-time 环境 | 不在范围 | 先消融并穷尽 harness，再用可量化差距决定是否训练 |
| 文档检索策略 | 简单 retrieval | targeted search | retrieval tool | provider memory/store | RAG | grep/read | 向量 RAG | OpenAI repo 地图 + progressive docs；Codex 层级指令有 byte budget | MCP `CacheableResult` 的 `ttlMs` / `cacheScope` 把缓存新鲜度与作用域写进协议契约 | 按规模/查询类型路由，并让权威来源、provenance、budget 可见 |
| skill / prompt 自优化 | 不在范围 | transcript 分析 | 先 baseline | skill runtime | skills 形态 | session 经验 | 自进化分类 | OpenAI 把重复反馈编译成 docs/lint/skill；mini 要求模型升级后 re-simplify | Anthropic 2026-03：evaluator 本身也是要被优化的 skill，靠“读分歧、改 QA prompt”迭代 | SkillOpt gate 文本 edit；组织反馈按证据从说明升级到机械约束 |

| KV cache / prompt 前缀经济学 | — | token 效率 | — | 动态 tool surface 需快照一致 | — | system prompt 分段组装 | GSSC | Codex 指令有 byte budget | **MCP 规范要求 `tools/list` 确定性排序以提高 prompt cache 命中率；DeepSeek 每个包 README 必写 `#### KV Cache effect`** | 进入前缀的东西必须顺序稳定，否则整段缓存作废 |
| 持久化执行与副作用治理 | — | — | — | LangGraph checkpoint/resume；LC4j 1.19 补偿动作 | 事务 / Saga 语义天然 | cron 至少一次交付；workflow journal 续跑 | — | Codex rollout | **Pi effect sandwich + 按工具重放策略；MCP MRTR 让幂等从最佳实践变成正确性前提** | 崩溃后知道做没做 + 重试不重复做 + 做完能撤销，三者缺一不可 |
| 完成判定归属 | 显式停止条件 | — | 失败阈值给人 | `stopWhen` 只判轮次 | — | **s17 goal loop：无工具的独立判定器 + `{ok, reason, impossible}`** | — | Anthropic default-FAIL contract + fresh-context evaluator | **DeepSeek goal domain（持久 phase + revisioned CAS）；Anthropic 2026-03 generator/evaluator 分离** | 轮次结束 ≠ 目标达成；判定权必须离开执行方 |
| 契约演进政策 | — | — | — | SemVer + 弃用别名 | SemVer | — | — | — | **MCP 三态特性生命周期 + 最短 12 个月弃用窗口 + 集中登记表** | SemVer 说“这次破不破”，弃用登记表说“下次哪里会破” |

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
- **evaluator 是投资还是开销**：Anthropic 2026-03 明确写出它取决于**任务难度相对模型能力的位置**——任务在模型能力之内时评估器只是开销，处在能力边缘时它抓住"最后一公里"。可操作判据是：先跑一批任务测 generator 单独的通过率，再决定要不要付这笔钱。
- **compaction vs context reset**：这不是"谁更好"，而是**按模型代际选择**。模型有 context anxiety 倾向时（会在接近感知上限时草草收尾），reset + 结构化交接优于 compaction，因为摘要保留了连续性却不给一块干净白板；模型没有这个倾向时，reset 只是白白丢弃有用上下文。
- **事件溯源 vs 覆写当前态**：DeepSeek 用事件流 + `deriveMessages()` 投影推导当前态，Pi 用整体覆写的持久化程序计数器直接存当前态。两者都对，区别是**谁承担推导成本**：前者写入小、恢复需要重放投影；后者写入大、恢复只读一个 register 然后 switch，没有重放语义因而也没有"重放到一半不一致"的中间态。
- **协议无状态化的代价转移**：MCP 删掉会话之后，协议不再替你记任何跨调用状态，代价是句柄的铸造、鉴权、过期与 GC 全部变成服务端自建设施。复杂度没有消失，只是从协议层挪到了实现层——这个转移对可水平扩展的服务是划算的，对单机单用户工具则是纯增负担。

## 对 skill 的总体指导

截至 2.2.0，上面的收敛结论沉淀进一个复合 skill suite：

- `skills/build-ai-agents/SKILL.md` 从单体执行 skill 改成路由器，保留旧入口名，按任务只加载相关 child skill，避免每次 agent 任务都吞下全部参考资料。
- `skills/design-ai-agent/` 承接形态选择、agent vs harness、workflow vs agent、loop/state/memory/approval 决策；2.1.0 起用 runtime / session continuity / repository feedback 三层解释 harness，并加入 minimal baseline、fresh-session continuity 与 model-upgrade ablation。
- `skills/design-agent-tools/` 承接 prompt/context、long-document handling、retrieval、compaction、memory pipeline、tool schema/description 和 ACI。
- `skills/build-mcp-capabilities/` 承接 MCP server/client、resources/prompts/tools、transport、安全和 MCP/A2A/ANP 协议谱系。
- `skills/implement-ts-agents/` 与 `skills/implement-java-agents/` 分别承接 TypeScript 与 Java/Spring/LangChain4j 框架落地模式。
- `skills/review-ai-agents/`、`skills/secure-ai-agents/`、`skills/test-ai-agents/` 把审查、安全、测试/观测从 reference 变成可单独触发的 workflow skills；2.1.0 增加 repository legibility、clean handoff、fresh-context evaluator、step snapshot、sandbox escalation 与 harness ablation。
- `skills/optimize-agent-skills/` 吸收 SkillOpt：skill/prompt 迭代要有 rollout evidence、bounded edit、train/val/test、validation gate、strong optimizer vs frozen target、staged adoption。
- `skills/build-ai-agents/references/source-map.md` 作为唯一保留的共享 source map，记录本地快照、commit、官方链接和高价值文件。
- `SKILL.md` frontmatter 使用 `metadata.version`；suite 当前版本为 2.2.0。
- 2.2.0 起，上述九条 2026-08 收敛结论按主题分派：副作用治理与重放归 `design-ai-agent` 与 `implement-ts-agents`；prompt 前缀经济学归 `design-agent-tools`；完成判定归属归 `design-ai-agent` / `test-ai-agents` / `review-ai-agents`；MCP 新基线整体归 `build-mcp-capabilities`；恢复时不继承授权、缓存作用域越权与外部工具自述不作授权依据归 `secure-ai-agents`；harness 假设保质期的例行重扫归 `design-ai-agent` 与 `optimize-agent-skills`。
- 对本仓库自身设计前提的重新审视（这套 skill 的分层、来源经济学、可证伪性与保质期）见 `analysis/21-lab-design-rethink-2026-08.md`，它是元层文件，不承担来源分析职责。

## 后续可分析方向

留给下一次迭代的线索（均为权威来源，尚未单独分析）：

- Claude Code 官方文档：与 Learn Claude Code 教学版互参，能把"教学化简实现"对回"产品化的 harness 形态"。
- Anthropic Agent SDK / Claude Agent SDK 文档：harness 工程的 SDK 级抽象，可补充与本仓库已有 TS/Java agent SDK 的对照。
- OpenAI Codex 官方安全与 AGENTS.md 文档：把本次源码事实对回稳定的产品契约，补充不同平台 sandbox、权限 profile 与 instruction precedence 的用户侧语义。
- Google Agent Development Kit docs：另一套工程化 agent 框架的形态与边界设计。
- ReAct：经典 tool-use / reasoning-action 论文，可为 tool loop 形态补充原始理论来源（Hello-Agents 第 4 章只是工程实现，原论文仍值得单独分析）。
- Reflexion：失败反馈、语言化记忆和自我改进循环，可补充 eval/optimizer 与 memory 风险边界。
- Toolformer：工具使用学习的经典论文，可补充"模型如何学会调用工具"的研究视角。
- GRPO 原始论文（DeepSeek-Math）：Hello-Agents 第 11 章给出了工程实现，原论文可补"为什么用 group relative 替代 critic 网络"的理论基础。
- BFCL / GAIA 评估基准论文：Hello-Agents 第 12 章引用其作为评估基准，但 leaderboard 设计与评估方法论本身值得单独读；也可与 SkillOpt 式 skill 优化 gate 联动。
- Anthropic Contextual Retrieval：把"contextual embeddings + BM25 + 重排"做成单源深挖，补本仓库检索维度的厂商一手招法（`analysis/12` 已综述，未单独分析）。
- DeepMind LIMIT / NoLiMa 论文：单向量召回的维度天花板与长上下文有效长度远小于标称的硬证据，可为检索选型补理论基线。

- OpenAI Codex 深度核验：记录快照之后已漂移 +858 commits 且 release 正文为空，2026-08-23 审查判为"待核验"。下轮以 `update-source` 模式重新快照后再判定 `analysis/16` 是否需要推进。
- **Programmatic Tool Calling 官方文档**：Code Mode 已在两个来源独立出现，但两者都是实现视角；官方指南能补上"哪些工具适合被程序编排、哪些不适合"的选型判据。
- **MCP Extensions 与 MCP Apps**：2026-07-28 引入的扩展框架与 Apps 尚未单独分析，它决定了"核心之外的能力怎么演进"，与本仓库的 `build-mcp-capabilities` 直接相关。
- **Client ID Metadata Documents**：取代 DCR 的新客户端注册机制，是 agent ↔ 授权服务器关系的实质变化，值得与既有的 MCP 授权分析合并深挖。
- **Saga / TCC 在 agent 场景的落地**：LangChain4j 1.19 的 tool action compensation 只是一个实现点，补偿语义与 agent 的不确定性如何结合（补偿动作本身失败怎么办、模型能否决定补偿范围）尚无来源覆盖。

按既定流程：新增来源时建下一个递增编号分析文件、在 `SOURCE_INDEX.md` 的对应表加行、更新本文件的共识矩阵、追加 `CHANGELOG.md`。
