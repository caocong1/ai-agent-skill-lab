# Anthropic 长任务应用开发 Harness 设计分析

> 分析版本：1.0 ｜ 最后更新：2026-08-23 ｜ 来源：Anthropic《Harness design for long-running application development》（发布 2026-03-24，抓取 2026-08-23）｜ 快照：`raw/docs/anthropic-harness-design-long-running-apps.md`

这是 `analysis/15-anthropic-long-running-agent-harness.md`（2025-11-26《Effective harnesses for long-running agents》）的直接续作，但换了一个视角：15 号文章讲的是**如何让一个 agent 跨 session 稳定推进**（contract、progress、git、fresh-session 验证）；本文讲的是**如何让多个角色分工产出高质量成果**（planner / generator / evaluator），并且第一次正面回答了 15 号文章留下的缺口——完成度不能由做事的那个 agent 自己认定。

它同时给了本仓库一条此前没有明确写下的元规则：**harness 里的每一个组件都编码了一条"模型自己做不到什么"的假设，而这些假设有保质期**。这条规则直接作用于本仓库既有的 harness ablation 指导（`analysis/17-mini-swe-agent.md`），把"消融"从一次性动作变成随模型升级的例行动作。

## 核心抽象

- **生成与评估必须由不同 agent 承担**。核心证据是一个具体失败模式：让 agent 评估自己的产出时，它会自信地夸奖平庸的工作。分离之后，生成器可以宽松，评估器可以苛刻——这是 GAN 的直觉在 agent 编排上的应用。
- **三角色分工：planner / generator / evaluator**。planner 把 1–4 句需求展开成产品规格，且**只做产品语境与高层技术设计**，不做细节实现，以免规格层错误级联；generator 实现并自评；evaluator 驱动真实运行的应用做端到端验证并评分。
- **Sprint contract**：每个 sprint 前由生成器与评估器协商交付物与成功标准，通过**文件**顺序读写沟通。它在"高层用户故事"与"可测试实现"之间架桥，而不提前锁定技术方案。
- **Context reset ≠ compaction**。reset 是完全清空历史；compaction 是摘要。作者选 reset 的理由很具体：compaction 保留了连续性，但不给 agent 一块干净白板，**context anxiety 因此仍然存在**。reset 的代价是必须有结构化交接产物承载状态。
- **主观质量可以被评分**，前提是把它拆成命名标准（design quality / originality / craft / functionality）并用带分数拆解的 few-shot 样例校准评估器，以压住迭代之间的**分数漂移**。
- **harness 组件是有保质期的假设**。Sonnet 4.5 需要 context reset，Opus 4.5 自己消除了 context anxiety，reset 被整个删除；Opus 4.6 能在 2 小时以上的构建里保持连贯，**sprint 这一构造被整个删除**。

## 重要模式

### 评估器的调优回路是"读分歧、改 prompt"

文中给出的方法非常朴素也非常可执行：**读评估器的日志，找出它的判断与人类判断分歧的样例，然后更新 QA prompt 去解决这些分歧**。这把 evaluator 从"再加一个 LLM 判官"变成了一个有明确迭代信号的组件——分歧样例就是它的训练集。

它与 `analysis/13-skillopt.md` 的 rollout → reflect → update → gate 是同一个形状，只是作用对象从"执行技能"换成了"评估标准"。评估器本身也是需要被优化的 skill。

### 评估器要看到"运行中的东西"，不是 diff

评估器通过 Playwright MCP 打开真实页面、模拟用户操作、截图，然后再评分。它产出的是颗粒化、可执行的条目（"矩形填充工具只在起点和终点放置瓦片，没有填充区域 —— FAIL"），而不是一句"质量不错"。这与 15 号文章的结论一致：diff、单测和 `curl` 不足以证明用户可见功能完成。

### 评估器的性价比是一个函数，不是一个常量

文章明确写出评估器的成本收益取决于**任务难度相对模型能力的位置**：任务在模型能力之内时，评估器只是开销；任务处在能力边缘时，它抓住"最后一公里"的缺失功能与边缘情况。

这条比"永远加一个 evaluator"有用得多——它给了一个可操作的判据：先测一批任务，看 generator 单独的通过率落在哪个区间，再决定要不要付评估器的钱。

### 迭代曲线不单调

分数总体随迭代改善，但作者经常更偏爱某个中间版本而非最后一版。工程含义是：**保留每次迭代的产物并可回退**，不要假设"最后一次一定最好"。这对任何用 evaluator 驱动多轮改写的流水线都适用。

### 标准的措辞会塑造产出

加入"最好的设计是博物馆级的"这类表述，会把设计推向某种特定的视觉收敛。评分标准不是中立的观察窗口，它同时是一条 prompt。写 rubric 时要意识到自己在同时定义"什么算好"和"往哪个方向走"。

### 成本是设计约束，不是脚注

单人 20 分钟构建约 $9；完整三角色 harness 约 6 小时、$200+；后期 DAW 案例 3.8 小时、$124.70。把这些数字写进文章本身，等于承认 harness 复杂度有明确的价格标签，"要不要上 evaluator"是一个预算决策而不只是架构偏好。

## 工程启发

- **不要让做事的 agent 判定自己做完了**。这是 15 号文章 default-FAIL contract 与本文 evaluator 的同一条结论的两个层面：contract 让完成需要证据，evaluator 让证据由别人检查。`analysis/18-deepseek-harness.md` 里的 Ralph 工具自陈"完成是 worker 的自我声明，没有独立评估者"，正好是缺了这一层的对照组。
- **长任务的上下文策略要按"模型是否有 context anxiety"分档**：模型有焦虑倾向时，reset + 结构化交接优于 compaction；模型没有时，reset 只是白白丢弃有用上下文。这意味着 compaction 与 reset 不是替代关系而是**按模型代际选择的两种策略**。
- **把 harness 里每个组件登记成一条带日期的假设**。形如"我们加 X，是因为模型做不到 Y（记录于模型版本 M）"。模型升级时，这份清单就是消融清单。本仓库应把它写成 skill 里的一条例行规则，而不是一句原则。
- **规格分层：产品语境交给 planner，技术细节留给 generator**。过早在规格里写实现，会让一个规格错误在下游放大。
- **协商式契约优于单向下发**。sprint contract 由生成器与评估器共同确定交付物与成功标准，比"planner 单向下发任务卡"更能避免不可测的验收条件。
- **rubric 需要校准数据**。few-shot 分数拆解不是可选装饰，它是抑制 score drift 的机制；没有它，同一个评估器在长流水线里会慢慢改变标准。

## 适用场景

- 用 agent 做**主观质量导向**的产出（前端设计、文案、报告、UI 交互），需要把"好"变成可评分对象。
- 长时间（小时级）自主构建，且交付物有用户可见行为可以被端到端驱动。
- 已经有 generator 单独跑但质量不稳定、且愿意为评估付出可观 token 成本的场景。
- **不适合**：任务明显在模型能力之内（评估器纯属开销）；没有可自动驱动的用户可见界面（评估器退化成第二个读 diff 的 LLM）；预算敏感的高频短任务。

## 注意

- 文章是**单一作者的工程实践报告**，样本是若干应用构建，不是对照实验。四条设计标准与具体分数校准方式适用于该作者的审美偏好，迁移时需要自己重建校准集。
- **模型版本强绑定**。context reset 对 Sonnet 4.5 有效、对 Opus 4.5 不必要；sprint 对 Opus 4.6 不必要。任何直接照抄的组件都要先验证当前模型是否还需要它。
- 成本数字来自特定时间点的定价与模型，不能作为持久结论。
- "评估器发现的问题"仍然是模型判断，不是形式化验证；它降低而非消除了 victory declaration 的风险。
- Playwright MCP 式的浏览器验证仍有盲区（原生弹窗等），与 15 号文章记录的工具可见性风险相同。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：新增 generator/evaluator 分离与"自评不可信"、planner 只做产品语境与高层设计、协商式 sprint contract、context reset vs compaction 的按模型代际选择，以及"harness 组件是有保质期的假设、每次模型升级重做消融"的例行规则。
- `skills/test-ai-agents/SKILL.md`：新增 evaluator rubric 的命名标准化、few-shot 分数拆解校准与 score drift 控制、"读分歧改 prompt"的评估器调优回路、evaluator 性价比按任务难度相对模型能力判定、保留并可回退中间迭代产物。
- `skills/review-ai-agents/SKILL.md`：审查面增加"完成判定是否由执行方自己给出"与"harness 组件是否还有现存理由"。
- `skills/build-ai-agents/references/source-map.md`：登记本文与快照路径。
- `analysis/07-overall-agent-analysis.md`：把"独立评估者"与"harness 假设保质期"纳入跨来源共识矩阵。
