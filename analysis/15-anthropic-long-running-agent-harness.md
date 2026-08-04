# Anthropic 长任务 Agent Harness 联合分析

> 分析版本：1.0 ｜ 最后更新：2026-08-04 ｜ 覆盖来源：Anthropic《Effective harnesses for long-running agents》（发布 2025-11-26，抓取 2026-08-04）+ `cwc-long-running-agents`（commit `ad107a974bced5244f74dd283dbf2bfd3baee3a1`）｜ 版本见 `analysis/SOURCE_INDEX.md` ｜ 快照：`raw/docs/anthropic-effective-harnesses-long-running-agents.md`

`analysis/10-learn-claude-code.md` 已经覆盖 compaction、memory、task graph 和 worktree，但那些机制主要解释“一个 session 内或相邻 session 如何延续”。Anthropic 文章与配套仓库把 long-running harness 的完成条件做得更结构化：**默认失败的任务 contract、agent 维护的交接、fresh-context evaluator 和 evidence gate**。

文章提供实验动机与 initializer/coding 两阶段模式；当前配套仓库则把 2026 年演进后的机制落成可读 hooks 和 evaluator subagent。两者联合说明：跨窗口可靠性不能只依赖 compaction，必须把连续性与完成判定外部化。

## 核心抽象

- **Compaction ≠ continuity**。摘要可以降低 token，但不能保证完整保留未完成项、环境健康、验收证据与决策原因；跨 session 连续性必须落到文件、git 与可执行 contract。
- **Default-FAIL contract**。所有功能初始为未通过，完成是状态迁移而不是 agent 的自然语言判断；只有观察证据后才允许改变状态。
- **Builder 与 evaluator 认知隔离**。builder 看过实现过程，容易被自己的意图和局部成功锚定；fresh-context evaluator 只看规格、diff 与证据，更接近新接手者和真实验收者。
- **Clean handoff 是每次运行的交付物**。session 不仅要产出代码，还要留下可启动、可测试、可回滚、下一 session 能迅速理解的工作区。
- **Operator control 是 harness 原语**。长时间无人值守运行需要 kill switch、一次性 steering 通道、预算和“无进展即停止”，而不是只能杀进程或重新开局。

## 重要模式

### Initializer / Coding 两阶段

initializer 把模糊目标展开成 feature contract、启动脚本、进度文件与初始 commit；后续 coding session 固定执行“重新定位 → smoke test → 选一项 → 实现 → E2E 证据 → 更新进度 → commit”。两类角色可共享同一底层 harness，仅以初始指令区分。

### 证据先于完成状态

仓库的 `track-read.sh` 记录 agent 实际打开过的截图或日志，`verify-gate.sh` 在写结果文件前检查证据读取记录。它是教学 gate，不是安全边界，但准确展示了一个重要原则：完成状态的 mutation 应依赖可追踪 observation，而非 prompt 自律。

### Fresh-context evaluator

`agents/evaluator.md` 没有 Write/Edit 工具，只读取规格、diff 与证据，以稳定的 `PASS` / `NEEDS_WORK` 协议返回结果。外层 loop 把失败意见写成下一 builder session 的输入。这里的独立性来自上下文隔离与工具收窄，而不是换一个人格描述。

### 双通道交接

`PROGRESS.md` 提供语义状态，git log/commit 提供事实与回滚点。任何单通道都不够：进度文件可能陈旧，git commit 又不一定说明下一步与已知问题；二者互相校验。

### Stop/Steer Hooks

`AGENT_STOP` 文件能阻断后续工具调用，`STEER.md` 把操作者指令一次性注入并清空。它们说明长任务控制面可以很小，但必须独立于模型是否愿意检查消息。

## 工程启发

- 长任务的最小持久化集合不是“所有聊天记录”，而是：完成 contract、进度/决策、可重复启动方式、git checkpoint、验收证据和预算/停止状态。
- fresh-session test 应成为一类独立测试：启动新 agent 上下文，只给仓库资产，检查它能否定位现状、恢复环境、选对下一项并发现已有破损。
- “独立 evaluator”必须约束信息与工具：若它继承 builder 全部上下文或可悄悄修复问题，评估独立性就被破坏。
- contract 文件本身要防篡改：生产实现应校验 schema、绑定 criterion 与 evidence、记录谁改变状态，并阻止通过 shell 等旁路改写。
- 每次 model 升级都应做 harness ablation：逐项移除 prompt 约束、hook 或辅助文件，验证哪些仍是 load-bearing，避免旧模型补丁永久累积。

## 适用场景

- 跨多个 context window、小时或天运行的软件构建、迁移、研究和数据处理任务。
- 经常出现半完成状态、重复摸索启动方式、过早宣布完成或 builder 自评过宽的 agent。
- 需要无人值守但仍要可观察、可暂停、可重定向的长任务。
- 对一次性、短时、容易人工验收的任务，这套 contract/evaluator/交接可能过重。

## 注意

- 配套 hooks 明确是教学样例：`verify-gate.sh` 可被 Bash 改写绕过，证据与 criterion 未一一绑定，`commit-on-stop.sh` 也可能静默失败。
- evaluator 保留 Bash 读取能力并非强只读 sandbox；高风险场景需要真正的权限隔离。
- feature list 的粒度与排序质量决定 loop 是否能稳定推进；巨型、耦合或不可独立验证的 feature 仍会产生半成品。
- 文章以 Web 应用为主；其他领域必须重新定义可观察证据和 clean state。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：在长任务设计中加入外部化 contract、initializer/coding 阶段、双通道交接和 operator control。
- `skills/test-ai-agents/SKILL.md`：新增 fresh-context evaluator、fresh-session recovery test、证据绑定与 clean-handoff 验收。
- `skills/review-ai-agents/SKILL.md`：检查完成状态是否默认失败、是否可被旁路篡改，以及 evaluator 是否真正隔离。
- `skills/build-ai-agents/references/source-map.md`：登记文章、配套仓库、commit 与核心 hook/evaluator 文件。
- `analysis/07-overall-agent-analysis.md`：把“compaction 不等于 continuity”和“完成判定外部化”加入跨来源共识。

