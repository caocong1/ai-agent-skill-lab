# SkillOpt 源码与方法分析

> 分析版本：1.1 ｜ 最后更新：2026-10-25 ｜ 来源：Microsoft SkillOpt（commit `84b36cd5`，发布线仍为 v0.2.0，详见 `analysis/SOURCE_INDEX.md`）
>
> 1.1 变更：核心训练循环（`gate.py` / `reflect.py` / `skill.py`）未变；SkillOpt-Sleep 新增五项与本仓库直接相关的机制——优化器反馈边界、按血缘的划分暴露账本、逐任务不回退闸、真正生效的夜间 token 预算、排除自身生成的会话，外加一个成对 A/B 统计工具。见 `## v0.2 之后的 SkillOpt-Sleep 增量`。另修正一条自 2026-06-15 起已失效、上一轮审查漏掉的引用路径。

SkillOpt 与本仓库此前分析的 agent runtime / tool framework 不同：它不是一个应用 agent 框架，而是把 **skill 文档本身** 当成可优化的外部状态。此前 `build-ai-agents` 主要回答“如何设计和实现 agent harness”；SkillOpt 补上了另一个问题：“当一个 skill / prompt / 操作规程已经在真实任务里暴露出反复失败，如何像训练模型一样系统地改进它，但不改模型权重？”

这个来源与 `analysis/10-learn-claude-code.md`、`analysis/11-hello-agents.md` 的“经验沉淀 / 记忆 / 自进化”主题相接，但更强调可验证的优化纪律：训练集用于反思，验证集用于 gate，测试集用于最终报告；编辑是有界的文本 patch；部署时只消费 compact skill artifact，不引入额外推理时调用。

## 核心抽象

- **Skill document 是可训练状态**：SkillOpt 把自然语言 skill 看作 frozen agent 的外部参数。模型、后端和执行 harness 固定，优化对象是指导模型如何搜证、用工具、校验和输出的文本程序。
- **优化循环对应深度学习训练循环**：rollout 像 forward pass，任务 evaluator 像 loss，reflect 像 backward pass，edit patch 像 gradient，edit selection / learning rate 控制步幅，validation gate 像验证集早停。
- **优化器与目标执行者分离**：target model 执行任务并产出轨迹，optimizer model 分析轨迹并提出编辑。强 optimizer + frozen/cheap target 是主形态；这与“用更复杂 prompt 逼同一个弱模型自我纠错”不同。
- **部署 artifact 是文本**：最终产物是 `best_skill.md` 这样的 compact skill。运行时不需要带上 optimizer 记忆或额外优化调用，因此 skill 改进不会增加正常 agent inference 成本。
- **Sleep 是使用期的离线巩固**：SkillOpt-Sleep 把同一思想用于本地 coding agent：收集历史 session，挖掘 recurring tasks，离线 replay，反思有界 edit，用真实 held-out task gate，最后 staging proposal，等用户 adopt。

## 重要模式

### Rollout → Reflect → Aggregate → Select → Update → Gate

SkillOpt 的主 loop 是值得迁入本仓库的 skill 优化骨架：

1. `rollout`：目标 agent 用当前 skill 执行一批任务，记录轨迹、得分、失败原因、token、latency 和工具调用。
2. `reflect`：优化器模型分析失败与成功 minibatch，提炼可迁移规则，而不是记住单题答案。
3. `aggregate`：合并语义相近 edit，避免重复 patch。
4. `select`：按重要性排序，在 textual learning rate 预算内只保留少量 edit。
5. `update`：对 skill 文档执行 add / delete / replace 等有界更新。
6. `gate`：在 held-out validation split 上比较候选 skill 与当前 skill，只有提升才接受。

这个模式比“让模型直接重写整个 prompt”更适合长期维护，因为它保留了可审计的编辑、被拒绝的方向和稳定的回滚点。

### 数据拆分防过拟合

SkillOpt-Sleep 把使用期优化明确拆成 train / val / test：

- train：真实任务 + dream-augmented variants，用于反思和产生候选 edit；
- val：真实任务，用于 gate；
- test：真实任务，用于最终 held-out 报告。

关键规则是 synthetic/dream task 可以帮助发现规律，但不能进入 val/test。对本仓库 skill 来说，这意味着“用几条用户失败案例修改 skill”时，也要至少保留一小组没参与反思的真实用例来验收。

### Textual Learning Rate 与有界编辑

SkillOpt 把 `learning_rate` 映射成“每步最多应用多少条文本 edit”。这条抽象非常适合 skill 维护：

- 早期可以较 aggressive 地探索多个规则；
- 后期应降低 edit 数，避免已有好规则被大改写破坏；
- edit budget 也让 reviewer 能看清每次 skill 行为变化的真实来源。

对于本仓库的复合 skill，最重要的是避免“为了新增来源而大段百科化扩写”。更合理的做法是把来源结论落到少数可执行决策规则、路由规则或检查项里。

### Gate、Rejected Buffer、Slow/Meta Update

SkillOpt 的 gate 把反思从“自我感觉更好”变成“候选规则必须赢过当前规则”。被拒绝 edit 也不是垃圾，而是下次优化的负反馈，帮助避免重复走坏方向。

Slow update 和 meta skill 处理更长周期的记忆：前者比较跨 epoch 的行为变化，把纵向经验写成 protected guidance；后者给 optimizer 留跨 epoch 策略记忆。迁到 Codex skill 维护时，不需要原样实现这些机制，但要保留思想：短期 edit 不应随意改写长期原则；长期原则必须来自多轮证据，而不是单次失败。

### Staged Adoption

SkillOpt-Sleep 的工程形态很适合本仓库借鉴：离线运行只 staging proposal，不直接改 live skill；adopt 再备份和写入。这一点能防止“自动优化”变成不可追踪的 prompt 漂移。

## 工程启发

- **复合 skill 需要路由，而不是堆叠**：SkillOpt 的最终 artifact 通常是 compact skill；这支持本次把 `build-ai-agents` 改成路由器，把架构、工具、MCP、TS、Java、review、安全、测试、优化拆成独立 child skills。常见任务只加载 1-2 个 focused skills，比一个大而全正文更接近 SkillOpt 的部署精神。
- **skill 优化应有 baseline**：任何 prompt / skill / tool-description 改动都可能改变 agent 行为。修改前先保存 golden task 或 transcript，修改后比较质量、工具选择、成本与安全结果。
- **子 skill 触发边界就是可优化接口**：每个 child skill 的 `description` 相当于 trigger-time classifier 输入。描述越清晰，agent 越少误加载；这也是 token 成本优化的一部分。
- **强 optimizer 不等于上线强模型**：可以用强模型离线分析轨迹和写 edit，再把 compact skill 交给较便宜的 target/runtime 使用。这个想法与“先用强模型建立 baseline，再下调模型”互补。
- **自进化必须有安全闸**：SkillOpt 改的是文本规则，仍然可能删除审批、扩大工具权限或弱化安全约束。skill 优化需要安全守卫：禁止为了分数移除权限、验证、租户隔离、审计或人类介入规则。

## 适用场景

- 一个 agent skill / prompt 在相似任务上反复失败，需要从 transcript 中提炼规则。
- 工具描述或上下文组装策略改动后，要验证是否真的提升工具选择、准确率或成本。
- 团队维护多项目共享 skill，需要用 held-out real tasks 阻止 prompt drift。
- 本地 coding agent 想从历史 session 中离线学习偏好和常见任务，但不能静默改 live skill。
- 大而全 skill 需要拆成更小的 deployable artifacts，同时保留总入口。

## 注意

- SkillOpt 不是 agent runtime；不要把它用于替代工具执行、权限边界、state persistence 或 MCP capability layer。
- 小 eval 的 gate 可能对指标不敏感。硬分数太粗时可用 soft score 或 mixed score，但权重必须事先声明。
- LLM judge 会带来评估偏差；高风险场景优先使用确定性判分、人工抽检或可复现 golden task。
- Dream / synthetic task 可以用于探索，但不要进入最终验收集。
- 自动编辑 skill 的能力必须 staging + review；直接写入生产 skill 会制造不可审计的行为漂移。

## v0.2 之后的 SkillOpt-Sleep 增量

（2026-10-25 核验，上游 `84b36cd5`；依据 `docs/sleep/README.md`、`docs/sleep/evalkit.md` 与对应 PR。）

### 优化器反馈边界：被优化的工件不能学到判定器本身

评分证据与优化器反馈被拆成两条通道：`fail_reason` / `judge_rationale` 这类原始评分证据只进审计面（diagnostics、`evidence.jsonl`）；reflection、对比反思与 slow update 只消费一个语义投影 `optimizer_feedback`。README 给的例子是规则判定器：挖出来的检查是一条正则，旧流程会把"正则没匹配上"原样喂给反思，于是提出的 skill 修改就去**模仿那条正则**；现在反思只看到检查的语义描述，提案里不再出现正则。若某条检查的描述原样抄了它的正则，直接拒收。非规则判定器（精确匹配、rubric）没有可安全导出的语义解释，失败时一律只给一句通用反馈——这是 fail-closed 的取舍，作者明说它**堵住了判定器泄漏，但没有证明优化质量因此不受影响**。

这条对本仓库的含义比 SkillOpt 本身更宽：凡是"用评测结果去改 prompt / skill / 工具描述"的回路，都面临**优化对象学到评测器而不是学到行为**的风险。评测细节应该只进审计记录，进优化回路的是对"用户可见行为哪里不对"的描述。

### 划分暴露账本：一旦进过训练，就永远不能当验证或测试

夜间循环把每个任务的划分暴露情况持久化，独立于有上限的回忆档案：一个任务（或它记录在案的派生任务）一旦进过训练，之后重新挖到它也不能把它放进验证或测试；进过验证的任务同样不能再被当作"干净的测试覆盖"。若已无不相交的验证池，gate 报告泄漏并**拒绝认证**这批修改。这是把"train/val/test 不相交"从一次性的切分动作，变成跨多轮持续执行的约束——持续学习场景里，泄漏是随时间累积出来的，不是切分那一刻发生的。

### 逐任务不回退闸（可选）

`gate_no_regression` 默认关闭；打开后，每个验证任务在所选指标上都必须持平或提升，缺失结果或非有限分数同样阻断候选。总分提升而个别任务退化的修改因此会被拒。

### 夜间预算：一个"已声明但未接线"的预算

`max_tokens_per_night`（默认 40 万）在 2026-10-18 合入的 #317 之前**只是声明、从未生效**。现在循环在每个会启动新模型工作的步骤前检查预算；已开始的步骤总会跑完（所以不是硬上限，一晚最多超出一步的开销）；跳过的步骤写进报告；不同后端的计数口径不同，部分调用（如 CLI 后端的任务挖掘与对比反思）不计入。本仓库此前在 `skills/optimize-agent-skills/SKILL.md` 里写"在预算下回放"，而在当时的快照里这个预算什么也不做——**声明了却没接线的预算，比没有预算更危险，因为它让人以为有护栏**。

### 排除自身生成的会话

Codex 后端的每次调用都带一个固定前缀，harvest 据此排除引擎自己产生的尝试、判定、反思与工具会话（#287，2026-10-23）。否则优化器会从自己的产出里学习，形成自我强化的回路。

### 成对 A/B 统计工具

`skillopt_sleep.evalkit`（#242，2026-08-29）：在同一份固定任务清单上把两种条件按任务配对，二值结果做 McNemar 检验，成功率差给出 bootstrap 置信区间；多个 seed 重复时把**任务**当作独立的聚类单位重采样，不把重复 seed 当独立样本（因此此时不报 McNemar）；提供 A/A 自检。README 要求任何"B 比 A 好"的结论都走这个工具，而不是引用一次运行的单元格。夜间 gate 本身不变。

### 数据边界与失效路径

- 真实后端会把截断后的会话片段发给所选模型提供方，用于挖掘、回放、判定与反思；README 明说出站提示**不保证不含密钥**，给出的可审阅流程是：先 harvest 到任务文件、人工检查/脱敏、标记 reviewed，再用真实后端回放。
- `docs/sleep/CONTROLLABLE_DREAMING.md` 已于 2026-06-15 删除（本仓库快照之后一天，上一轮审查漏掉），内容并入 `docs/sleep/README.md`（How it works / Nightly token budget / experience replay & dream rollouts / Optimizer feedback boundary 各节）与 `docs/sleep/evalkit.md`。

## 对最终 skill 的影响

1.1 新增：

- `skills/optimize-agent-skills/SKILL.md`：评测细节只进审计记录、进优化回路的只是行为层面的反馈；按血缘持续执行的划分暴露账本（进过训练的任务及其派生永不进入验证/测试，无干净验证池则拒绝认证）；可选的逐任务不回退闸；每个声明的预算都要有一个"它真的会停"的测试；harvest 排除优化器自身生成的会话；"B 优于 A"的结论必须是按任务配对的统计。
- `skills/test-ai-agents/SKILL.md`：新增按任务配对比较（二值结果用 McNemar、以任务为聚类单位的 bootstrap 置信区间、重复 seed 不当独立样本、A/A 自检）。

1.0 既有：

- `skills/build-ai-agents/SKILL.md`：从单体执行 skill 改成 suite router，保留旧入口名，按任务路由到 focused child skills，降低默认加载 token。
- 新增 `skills/design-ai-agent/`：承接原 `agent-architecture.md` 的 agent 形态、harness、loop/state/memory/approval 决策。
- 新增 `skills/design-agent-tools/`：承接原 `context-and-tools.md` 的 prompt、context、retrieval、compaction、memory pipeline、tool schema/description 指导。
- 新增 `skills/build-mcp-capabilities/`：承接原 `mcp-patterns.md` 的 MCP server/client、resources/prompts/tools、transport 和协议谱系指导。
- 新增 `skills/implement-ts-agents/` 与 `skills/implement-java-agents/`：承接原 TS/Java framework patterns，使实现任务只加载对应语言 guidance。
- 新增 `skills/review-ai-agents/`、`skills/secure-ai-agents/`、`skills/test-ai-agents/`：把审查、安全和测试/观测从单体 reference 变成可单独触发的 workflow skills。
- 新增 `skills/optimize-agent-skills/`：吸收 SkillOpt 的 rollout/reflect/aggregate/select/update/gate、train/val/test、textual learning rate、strong optimizer vs frozen target、staged adoption 思想，用于后续 skill/prompt 优化。
- 所有 suite skills 使用 `metadata.version: 2.0.0`，并新增 `agents/openai.yaml`；`iterate-skill-lab` 同步改为 `metadata.version` 约定，避免通用 validator 因顶层 `version` 失败。
- `skills/build-ai-agents/references/` 只保留 `source-map.md` 作为共享来源索引，迁出的 reference 内容进入对应 child skill，避免重复维护。
