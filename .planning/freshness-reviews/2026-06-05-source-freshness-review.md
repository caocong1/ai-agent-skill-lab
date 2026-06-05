# 来源新鲜度审查报告 — 2026-06-05（SEED-001 首次审查）

> 审查日期：2026-06-05 ｜ 触发：SEED-001（来源快照接近一个季度 + 本次自治运行）｜ 范围：small
> 方法：每来源对抗式核验 + skill/分析层冻结假设扫描 ｜ 关联：`[[SEED-001-source-freshness-review]]`、`CHANGELOG.md` [1.5.1]、`analysis/SOURCE_INDEX.md` `## 新鲜度审查`

## 概述

本次审查覆盖 lab 已学习的 **13 个来源**（9 个代码仓库 + 3 篇权威文章 + 1 篇多来源研究综述）。结论：

- **全部可达**；所有快照均在一个季度内（最早 2026-05-18，阈值 2026-03-05），**无 stale-by-time**。
- 11 个来源相对快照存在 upstream 漂移，但经对抗式核验，**仅 Vercel AI SDK 为实质性变更**（命中已分析表面），已标记待再分析；其余为补丁级 / 纯增量，不影响已分析模式。
- 复用 skill 在 SEED-001 的核心关切（不冻结 provider 专有字段）上**已做得很好**：零硬编码 model ID、零价格、零 rate-limit 数字、无 vendor-compat 表。仅有少量"把随时间漂移的现状当作 durable 结论"的措辞，已在本次一并收口。

## 方法

- **仓库漂移**：`git ls-remote <url> HEAD` 比对记录 commit；`git ls-remote --tags` 推断最新发布与是否 major 跳版。
- **实质性判定**：对漂移仓库再用 WebFetch（releases / CHANGELOG）+ WebSearch 判断已分析的模式（API、核心抽象、默认值、弃用 / 移除）是否变化；保守判定，仅有具体证据才记 materially_changed。
- **对抗式核验**：对每个"实质变更"判定，再派一个独立的怀疑性 agent 复核（默认推翻，除非有命名级证据）。
- **文章 / 综述**：WebFetch 复核发布 / 修订日期与内容；WebSearch 找有无更新版或被取代版。
- **skill / 分析层冻结假设扫描**：grep + 通读 `skills/build-ai-agents/SKILL.md` + 全部 `references/*`，以及 `analysis/*.md`，找硬编码 model ID、价格、rate-limit、provider 专有字段被当作通用真理、随时间漂移的"现状"被当作 durable 指导等。

## 逐来源结论

| 来源 | 类型 | 记录快照 | current HEAD / latest | 状态 | 处置 |
| --- | --- | --- | --- | --- | --- |
| Pi | repo | `4943c1d6` / v0.75.3 / 2026-05-18 | `89a92207` / v0.78.1 | 漂移-非实质 | 可选 re-snapshot；无需再分析 |
| OpenAI Agents JS | repo | `629d35af` / ~v0.11.4 / 2026-05-18 | `5ffee544` / v0.11.6 | 漂移-非实质 | 可选 re-snapshot |
| LangGraphJS | repo | `bd72a897` / 2026-05-18 | `f552c058` / 1.3.5 | 漂移-非实质 | 可选 re-snapshot；2.x 出现再审 |
| MCP TypeScript SDK | repo | `22595b96` / 2026-05-18 | `ab552c30` / v1.29.0 稳定线 | 漂移-非实质 | main 为 v2 pre-alpha；稳定 v2 落地（~Q3 2026）再 re-snapshot |
| **Vercel AI SDK** | repo | `aa5a1e53` / ai@7.0.0-canary.142 / 2026-05-18 | `d66ae028` / canary.165 | **实质变更** | **再分析 + re-snapshot**（见下） |
| Spring AI Examples | repo | `2a6088db` / 2026-05-18 | `2a6088db`（同一 commit）| 零漂移 | 无需处置；下季度再审 |
| LangChain4j | repo | `6185599e` / ~1.15.0 / 2026-05-18 | `c9f52740` / 1.15.1 | 漂移-非实质 | 可选 re-snapshot；2.x 出现再审 |
| Learn Claude Code | repo | `1baf1aca` / 2026-05-21 | `3d018a0d` | 漂移-非实质 | 刷新 snapshot 指针即可 |
| Hello-Agents | repo | `66401d9f` / 2026-05-22 | `248aa248` / V1.0.2 | 漂移-非实质 | 机会性 re-snapshot（新增 SFT/DPO/Rerank、FastGPT 内容）|
| Anthropic, Building Effective Agents | article | 发布 2024-12-19 / 抓取 2026-05-19 | 未改 | Fresh | 例行刷新抓取日期即可 |
| Anthropic, Writing Effective Tools | article | 发布 2025-09-11 / 抓取 2026-05-20 | 未改 | Fresh | 例行刷新；有 3 篇姊妹文可作未来候选 |
| OpenAI, Practical Guide to Building Agents | article | 抓取 2026-05-20 | 未改（canonical 页 403，CDN PDF 可达）| Fresh | 待 403 解除后复核以升 confidence |
| 检索策略研究综述 | synthesis | 综合 2024–2026 / 抓取 2026-06-02 | 结论未失效 | Fresh | 下次再综述折入 "compilation-stage knowledge layer"（Pinecone Nexus）作增量 |

## 关键发现

### 1. Vercel AI SDK — 唯一实质性变更（待再分析）

v7 canary 上 **`onFinish` → `onEnd` 重命名**（PR 15245，2026-05-27 合入，保留别名 = 软破坏），横跨 `Agent` / `ToolLoopAgent` / `WorkflowAgent` / `streamText` / `generateText`，并引入 **per-step 聚合 + `finalStep`** 新语义；另有 `ToolLoopAgent.allowSystemInMessages`（canary.149）与 streaming-UI helpers 弃用（`fullStream` / `toUIMessageStream` / `toTextStreamResponse`）。命中本 lab 已分析的核心表面，故判定实质变更、需再分析。因仍是 v7 canary（预发布），建议比季度更勤地复核。

### 2. Pi — 对抗式核验推翻初判（误归纠正）

初判称 Pi v0.77.0 的 "tool-allowlist / factory 迁移、移除 `readTool`/`bashTool` 等" 为命中 lab focus 的破坏性变更。**复核（逐字读 CHANGELOG）发现该破坏性变更实为 v0.68.0**，早于记录的 v0.75.3 快照；v0.75.4–v0.78.1 漂移窗口内仅增量（`--exclude-tools`、`streamingBehavior`、`ctx.mode`/`ctx.getSystemPromptOptions`）。故 Pi 降级为漂移-非实质。这条说明对抗式复核值得做——单 agent 的"看起来很吓人"判定被证据推翻。

### 3. 复用 skill 体质良好（SEED-001 核心关切）

skill 扫描：**零**硬编码 model ID（无 gpt-*/claude-*/gemini-* 等）、**零**价格 / 成本数字、**零**固定 rate-limit/TPM/RPM 数字、**无** "OpenAI-compatible / 适配所有 provider" 类 vendor-compat 断言。出现的框架专有 API 名（`stopWhen`、`prepareStep`、`ToolLoopAgent`、`isError` 等）都正确地限定在 "Vercel AI SDK Pattern / OpenAI Agents JS Pattern" 等标注小节内，或作为 review-playbook 的 grep 种子词，未被当作跨 provider 通用真理。`source-map.md` 已是 SEED-001 想要的范式：本地路径标注为 lab-only、给 upstream 链接兜底、并要求"按宿主项目已安装版本核对 API"。

## 本次落地（CHANGELOG [1.5.1]）

仅做轻量审计留痕 + 措辞收口（patch），不做广泛 re-learning：

- **审计留痕**：`SOURCE_INDEX.md` `更新时间`→2026-06-05 + 新增 `## 新鲜度审查` 小节；本报告；`CHANGELOG.md` [1.5.1]；skill 版本 1.5.0→1.5.1（`SKILL.md` / `index.html` footer / `README.md`）。
- **skill 措辞收口（SEED-001 体质）**：
  - `references/context-and-tools.md`：reactive compaction 触发由 `prompt_too_long` 字面值改为按行为命名（"context-window / length-exceeded error"），字面值降为示例并提示查 provider 当前错误分类。
  - `references/testing-observability.md`：模型层两类失败由 `max_tokens reached` / `prompt_too_long` 字面名改为按行为命名（"输出在 token 预算处被截断" / "输入超出上下文窗口"），注明字段名按 provider 而异。
  - `references/mcp-patterns.md`：MCP/A2A/ANP 成熟度排名降级为带日期观测，保留 "默认 MCP、按需升级" 决策规则。
- **分析层措辞收口**：`analysis/07`（综合结论 + 矩阵，MCP 成熟度，含 `分析版本` 1.4→1.5）、`analysis/11`（A2A/ANP 早期）、`analysis/02`（MCP SDK v2 pre-alpha 分支态锚定到 commit）、`analysis/12`（ripgrep "事实标准" 市场地位、查询扩展 "约 10 倍" 数字）——一律保留 durable 决策规则 / 能力事实，把随时间漂移的 "现状" 锚定到日期或降为带保留的观测。

## 待办（不在本次落地）

1. **Vercel AI SDK 再分析**：用 `update-source` 模式 re-snapshot 到当前 v7 canary commit，更新 `analysis/02`（及涉及的 references/typescript-patterns）以反映 `onFinish`→`onEnd` / `finalStep` / `allowSystemInMessages` / streaming-UI helper 弃用，并推进其 SOURCE_INDEX 行的 `来源版本` / `最后更新`。
2. **例行 re-snapshot（纯增量，无需再分析）**：Pi v0.78.1、OpenAI Agents JS v0.11.6、LangGraphJS 1.3.5、LangChain4j 1.15.1、Learn Claude Code / Hello-Agents 最新 commit，可在下次常规同步时一并刷新。
3. **观察**：MCP TS SDK 稳定 v2（~Q3 2026）落地后 re-snapshot；检索综述下次再综述时折入 "compilation-stage knowledge layer / context architecture"（Pinecone Nexus，VentureBeat 2026-05）作增量。

## SEED-001 状态

**维持 dormant**（递归触发型看护，非一次性任务）。本次仅消费了 "快照接近一个季度" 这一触发；其触发集还包括 "新里程碑" 与 "新增 provider-API 集成指导"。已在 seed frontmatter 记录 `last_reviewed: 2026-06-05`。下个季度或下次 provider-API 集成里程碑重新触发。
