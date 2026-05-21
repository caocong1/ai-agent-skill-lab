# Changelog

本文件记录本仓库各 skill 与分析报告的版本变更。除非另注，`## [X.Y.Z]` 形式的条目默认指 `build-ai-agents`；其他 skill 的条目以 `## <skill 名称> [X.Y.Z]` 形式标注。

版本号遵循语义化版本（SemVer），作用于 skill 契约：

- MAJOR：skill 结构 / 契约的破坏性变更（模式名、交付物格式、reference 文件移除或重命名）。
- MINOR：新增能力、新增 reference、新增对指导有实质影响的分析来源。
- PATCH：措辞澄清、小幅补充，不改变契约。

各 skill 的当前版本记录在对应 `SKILL.md` frontmatter 的 `version` 字段；逐来源的分析版本与最后更新时间记录在 `analysis/SOURCE_INDEX.md`。再分析某个来源的新版本时：更新该来源在 `SOURCE_INDEX.md` 的行、对应分析文件头部的元数据块，并在本文件追加一条记录；仅当指导内容变化时才提升 skill 版本。

## [1.3.0] - 2026-05-21

### 新增

- 新增教学型仓库分析 `analysis/10-learn-claude-code.md`：shareAI-lab《Learn Claude Code》20 课渐进式 harness 教程。覆盖 harness vs agent 的本体论框架、agent loop 一以贯之的演进、四层 context compaction 管线、memory 三段流程（selection/extraction/consolidation）、permission/hooks/skill loading/system prompt assembly/error recovery、task graph、background tasks、cron、worktree-isolated agent teams、autonomous claim-from-board 与 MCP 接入。
- 新增源仓库快照 `raw/repos/learn-claude-code/`（commit `1baf1aca5af439694cb3a1772c0b1ab44b482a01`）作为 gitlink。

### 变更（skill 优化）

- `SKILL.md`：Architecture Rules 首条改写为"区分 agent 与 harness"——agent 的能力来自模型训练，工程师的工作是把 harness 建好；并把 harness 内含的工具/知识/上下文/权限/观测显式列出。
- `references/agent-architecture.md`：新增 `Agent vs Harness Boundary` 小节，把 harness engineering 的工程职责（tools / knowledge / context / permissions / trajectory）作为 skill 的工程心智模型；`Loop Design` 增补 hook 扩展点（pre/post tool）作为不改主循环的扩展机制。
- `references/context-and-tools.md`：`Compaction Strategy` 扩写为"cheap-first → expensive-last 多层管线"：snip → micro-replace → tool-result budget → 显式 LLM 摘要 → reactive 应急；`Long Document Handling` 加入 tool-result 持久化与句柄引用思路；新增 memory 三段流程（selection / extraction / consolidation）作为 memory 写入与回读的设计骨架。
- `references/security-and-safety.md`：补充"按任务隔离工作目录（worktree / sandbox dir）"作为多 agent 并行执行与不可逆动作的隔离手段；补充"trajectory 是 PII/secrets 的扩散面，输出与日志按相同准则脱敏"。
- `references/testing-observability.md`：补充长任务 / 后台执行 / cron 触发的观测要点（运行 id、注入回执、超时与重试上下限），并把"失败分级 + 退避 + fallback 模型"加入错误恢复模式。
- `references/source-map.md`：补记 learn-claude-code 仓库与本地路径，并把"教学型来源（教学化简实现，可直读 200–1000 行）"与生产框架来源区分清楚。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 learn-claude-code 行（repos 表）、重点阅读文件块与 Official Links 条目。
- `analysis/07-overall-agent-analysis.md`：把 learn-claude-code 纳入跨来源共识矩阵；`形态选择光谱` 补充"教学型 harness 实现"作为研究/学习参考；`后续可分析方向` 移除已落地候选，新增 Claude Code 官方文档、Anthropic Agents SDK 等候选。
- `docs/index.html`：分析来源表新增 learn-claude-code 行，footer 更新到 skill 1.3.0；`<style>` 与 `<script>` 未触碰。
- `README.md`：当前资料集新增 learn-claude-code 条目，版本说明更新到 1.3.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| Learn Claude Code (shareAI-lab) | repo | `1baf1ac` | 1.0 | 2026-05-21 |

## [1.2.0] - 2026-05-20

### 新增

- 新增权威文章分析 `analysis/08-anthropic-writing-effective-tools.md`：Anthropic《Writing Effective Tools for Agents》，覆盖 tool 选择、命名空间、返回上下文、token 效率、tool description/spec 优化和工具评测闭环。
- 新增权威指南分析 `analysis/09-openai-practical-guide-building-agents.md`：OpenAI《A Practical Guide to Building Agents》，覆盖 agent 适用场景、三要素（model/tools/instructions）、单 agent 到多 agent 编排、guardrails 与 human intervention。
- 新增两个 paraphrased digest 快照：`raw/docs/anthropic-writing-effective-tools.md` 与 `raw/docs/openai-practical-guide-building-agents.md`。

### 变更（skill 优化）

- `SKILL.md`：`Build Workflow` 与 `Dual-Use Rubric` 强化“先建 eval 基线再扩工具/拆 agent”、工具风险分级、模型选择与 human intervention 触发条件。
- `references/context-and-tools.md`：把 tool 设计从“schema/description”扩展为“面向 agent 的工具产品设计”：高价值工具选择、命名空间、响应格式、token 预算、错误响应与真实任务评测。
- `references/agent-architecture.md`：补充用例筛选、单 agent 优先、何时拆分 multi-agent、manager vs handoff 的适用边界。
- `references/security-and-safety.md`：补充 layered guardrails、tool risk rating、失败阈值与高风险动作的人类介入策略。

### 文档

- `analysis/SOURCE_INDEX.md`：新增两篇文章的来源版本、分析版本和重点阅读文件。
- `analysis/07-overall-agent-analysis.md`：把 OpenAI 与 Anthropic tool 文章纳入跨来源共识矩阵，更新形态选择与后续候选。
- `docs/index.html`：分析来源表新增两篇文章，footer 更新到 skill 1.2.0。
- `README.md`：当前资料集新增两篇权威文章，版本说明更新到 1.2.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| Anthropic, Writing Effective Tools for Agents | article | 发布 2025-09-11 / 抓取 2026-05-20 | 1.0 | 2026-05-20 |
| OpenAI, A Practical Guide to Building Agents | article | 发布未标注 / 抓取 2026-05-20 | 1.0 | 2026-05-20 |

## iterate-skill-lab [1.0.1] - 2026-05-20

### 修复

- 重写 `Kickoff` 流程（原 `Inputs to Confirm Up Front` 段落），不再要求用户一次性给出 5 个输入才能开始。改为：skill 先调研 `analysis/SOURCE_INDEX.md` 的 `Official Links` 与 `analysis/07-overall-agent-analysis.md` 的 `## 后续可分析方向`，提出 2–4 个候选来源并给出推荐与默认模式/版本/综合更新判断，由用户挑选或接受默认。仅"来源身份完全无法推断"才是硬阻塞。
- 修复用户报告：直接 `/iterate-skill-lab` 不带参数时，skill 之前会列出 5 个必填项后停下；现在会主动给候选与推荐。

## iterate-skill-lab [1.0.0] - 2026-05-19

新增项目专属维护 skill `skills/iterate-skill-lab/`，把 `build-ai-agents 1.1.0` 这次迭代用到的更新方式沉淀为可复用流程：新增/更新来源 → 元数据 → 综合 → `build-ai-agents` 优化 → 文档 → 分步 commit → 草稿 PR。后续遇到新的 AI agent 论文、文章、框架或重要更新，按该 skill 的 `add-source` / `update-source` / `skill-only` 模式执行。

## [1.1.0] - 2026-05-19

### 新增

- 新增权威文章分析 `analysis/06-anthropic-building-effective-agents.md`：Anthropic《Building Effective Agents》，覆盖 workflow 与 agent 的判定框架、五种 workflow 模式、自治 agent 循环、simplicity / transparency / ACI。
- 新增原文快照 `raw/docs/anthropic-building-effective-agents.md`。
- 新增总体综合报告 `analysis/07-overall-agent-analysis.md`，跨 7 个代码项目 + 1 篇权威文章给出形态选择光谱与跨来源共识矩阵。
- 新增 `CHANGELOG.md`（本文件）。
- `SKILL.md` frontmatter 新增 `version` 字段（1.1.0）。
- `analysis/SOURCE_INDEX.md` 新增逐来源 `来源版本 / 分析版本 / 最后更新` 列，并新增 `Articles and Papers` 表。
- 每个分析报告文件头部新增 `分析版本 / 最后更新 / 来源版本` 元数据块。

### 变更（skill 优化）

- `SKILL.md`：`Architecture Rules` 增加“最简优先：deterministic > 单次调用 > workflow > 自治循环”判定；`Build Workflow` 强调能用固定 workflow 或单次调用就不要做自治 agent。
- `references/agent-architecture.md`：新增 `Workflow vs Agent` 小节；决策表新增“开放式任务 / 步骤不可预测 / 工具可信 → 自治循环”行；`Loop Design` 增加 environment feedback 与显式停止条件。
- `references/anti-patterns.md`：强化 `Over-Engineered Agent`，明确“在固定 workflow 更可靠 / 更透明时却做自治 agent”。
- `references/context-and-tools.md`：Tool Description Rubric 增加 ACI 准则（把 agent-computer interface 当公共 API 一样设计）。
- `references/source-map.md`：补充文章快照与抓取日期说明。

### 文档

- `docs/index.html`：分析来源表新增 Anthropic Building Effective Agents 行；footer 显示 skill 版本与 CHANGELOG 链接。
- `README.md`：新增权威文章来源说明与 `版本与变更` 小节。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| Pi | repo | `4943c1d` | 1.0 | 2026-05-18 |
| OpenAI Agents JS | repo | `629d35a` | 1.0 | 2026-05-18 |
| LangGraphJS | repo | `bd72a89` | 1.0 | 2026-05-18 |
| MCP TypeScript SDK | repo | `22595b9` | 1.0 | 2026-05-18 |
| Vercel AI SDK | repo | `aa5a1e5` | 1.0 | 2026-05-18 |
| Spring AI Examples | repo | `2a6088d` | 1.0 | 2026-05-18 |
| LangChain4j | repo | `6185599` | 1.0 | 2026-05-18 |
| Anthropic, Building Effective Agents | article | 发布 2024-12-19 / 抓取 2026-05-19 | 1.0 | 2026-05-19 |

## [1.0.0] - 2026-05-18

基线版本：首个稳定 skill，经过一轮 Claude 只读评审强化（见 `analysis/05-claude-review-and-applied-changes.md`）。

### 包含

- `build-ai-agents` skill：`SKILL.md` + 10 个 references（agent-architecture、typescript-patterns、java-patterns、mcp-patterns、review-playbook、anti-patterns、security-and-safety、context-and-tools、testing-observability、source-map）。
- 支持 build / extend / review 三种模式与中文审查报告契约。
- 已分析 7 个代码项目：Pi、OpenAI Agents JS、LangGraphJS、MCP TypeScript SDK、Vercel AI SDK、Spring AI Examples、LangChain4j（来源分析见 `analysis/01..03`，skill 设计取舍见 `analysis/04`）。
