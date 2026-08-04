# Anthropic《Effective harnesses for long-running agents》结构化摘要

- 来源 URL：https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- 发布日期：2025-11-26
- 抓取日期：2026-08-04
- 抓取方式：官方网页只读抓取（WebFetch/open）
- 配套仓库：https://github.com/anthropics/cwc-long-running-agents
- 版权说明：本文档是基于官方文章的中文结构化转述，不是原文镜像，不包含大段逐字复制。

## 问题定义

长任务必须跨越多个 context window 与离散 session。新 session 不天然拥有上一 session 的工作记忆；单靠 compaction 仍可能丢失细节、留下半完成状态，或让后续 agent 因看到部分成果而过早宣布完成。

文章把问题拆成两部分：第一次运行要建立后续工作所需的环境与完成定义；每次后续运行只推进一个有限目标，并为下一次运行留下清晰、可恢复的状态。

## 两类 session 角色

- **Initializer session**：把高层需求展开成结构化 feature list，创建启动脚本、进度文件与初始 git commit，并验证基本环境可运行。
- **Coding session**：先重新认识工作区，再选择一个未完成 feature，完成实现与验证，最后留下进度记录和可恢复的 git checkpoint。
- 两者主要由初始 prompt 区分，系统 prompt、工具集合和底层 agent harness 可以相同；因此它更像阶段角色而非两个完全不同的 agent runtime。

## 外部化连续性

- 结构化 feature list 把“整体完成”的含义从模型印象变成可枚举 contract；所有条目默认失败，只有拿到证据后才能改为通过。
- progress 文件记录已完成、进行中、下一步和关键发现；git history 提供第二条可审计、可回滚的状态链。
- 每次 session 开始先确认工作目录、读取进度和 git log、选择最高优先级未完成项，并执行基础 smoke test；若接手环境已经损坏，先恢复而不是叠加新功能。
- 每次只做一个 feature，减少 context 耗尽时留下跨文件、跨功能的半成品。

## 验证策略

- 代码 diff、单元测试或 `curl` 并不足以证明用户可见功能完成；对 Web 应用应给 agent 浏览器自动化与截图能力，从用户路径做端到端验证。
- 完成状态要绑定证据。文章实验中使用结构化 JSON，是为了减少 agent 随意重写完成定义的倾向。
- 验证工具也有盲点；浏览器原生弹窗等不可观察区域仍可能产生未发现错误，因此工具可见性本身是 harness 风险。

## 失败模式与对应机制

- 一次尝试整个项目 → initializer 生成完整 feature contract，后续 session 每次只做一项。
- 留下未记录的坏状态 → 新 session 先读进度、看 git、跑 smoke test；旧 session 结束时提交并更新进度。
- 过早标记完成 → 只有经过实际验证的 feature 才能从失败改为通过。
- 每次重新摸索启动方式 → initializer 写可重复执行的启动脚本，后续 session 固定先读取并使用。

## 开放问题

- 单个通用 coding agent 与测试、QA、清理等专门 agent 的相对收益仍需实证。
- 结论主要来自全栈 Web 应用，迁移到科研、金融建模或其他长任务时需要重新定义 contract、证据和 clean-state 条件。
- 配套仓库在文章之后继续演进，增加 fresh-context evaluator、证据 gate、operator steering 与 kill switch；这些属于后续实现证据，不应倒灌成原文章当时已经验证的结论。
