# Changelog

本文件记录本仓库各 skill 与分析报告的版本变更。除非另注，`## [X.Y.Z]` 形式的条目默认指 `build-ai-agents`；其他 skill 的条目以 `## <skill 名称> [X.Y.Z]` 形式标注。

版本号遵循语义化版本（SemVer），作用于 skill 契约：

- MAJOR：skill 结构 / 契约的破坏性变更（模式名、交付物格式、reference 文件移除或重命名）。
- MINOR：新增能力、新增 reference、新增对指导有实质影响的分析来源。
- PATCH：措辞澄清、小幅补充，不改变契约。

各 skill 的当前版本记录在对应 `SKILL.md` frontmatter 的 `version` 字段；逐来源的分析版本与最后更新时间记录在 `analysis/SOURCE_INDEX.md`。再分析某个来源的新版本时：更新该来源在 `SOURCE_INDEX.md` 的行、对应分析文件头部的元数据块，并在本文件追加一条记录；仅当指导内容变化时才提升 skill 版本。

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
