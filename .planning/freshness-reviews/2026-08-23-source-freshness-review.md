# 来源新鲜度审查报告 — 2026-08-23（SEED-001 第二次审查）

> 审查日期：2026-08-23 ｜ 触发：SEED-001（快照超过一个季度 + 本次 harness 2026 刷新自治运行）｜ 范围：medium（超出 seed 预估的 small）
> 方法：每来源 `git ls-remote` 漂移比对 + npm dist-tags + GitHub Releases 正文核验 ｜ 关联：`[[SEED-001-source-freshness-review]]`、`CHANGELOG.md` [2.2.0]、`analysis/SOURCE_INDEX.md` `## 新鲜度审查`

## 概述

本次审查覆盖 lab 已学习的 **14 个代码仓库 + 6 篇文章/规范 + 1 篇研究综述**（DeepSeek Harness 与 Anthropic 2026-03-24 文章是本轮新增，随本轮一并入册）。结论与 2026-06-05 那次显著不同：

- 上次 13 个来源里只有 **1 个**实质性变更；这次 **5 个**实质性变更，其中 3 个直接命中已分析表面。
- 触发原因高度集中：**MCP 规范 2026-07-28 修订**同时驱动了 MCP TS SDK v2 包名重组、OpenAI Agents JS 的 v2 协商、LangChain4j 的 2026-07-28 客户端——一个上游规范修订在三个下游同时落地。
- **Vercel AI SDK v7 已从 canary 转为 stable**（`ai@7.0.77`），2026-06-05 标记的"待再分析"从可选变成必须。
- Spring AI 示例仓整体对齐到 **Spring AI 2.0**。
- learn-claude-code 从 20 课重构为 **17 课**并整体重编号，导致 `SOURCE_INDEX.md` 与 `source-map.md` 的多条 `重点阅读文件` 路径**已经失效**——这是本次发现的唯一"文档指向不存在文件"的硬错误。

## 方法

- **仓库漂移**：对每个上游 `git ls-remote <url> HEAD` 与 `--tags --refs`，与 `SOURCE_INDEX.md` 记录的 commit 比对。
- **发布线判定**：monorepo（Vercel AI、LangGraphJS、MCP SDK、OpenAI Agents JS）改用 npm `dist-tags` 判定真实发布版本，避免被同仓其他包的 tag 误导。
- **实质性判定**：读 GitHub Releases 正文；只有当变更命中**本仓库已分析的表面**（核心抽象、API 名、默认值、弃用/移除）才记为实质变更，否则记漂移-非实质。
- **路径有效性**：对 `SOURCE_INDEX.md` / `source-map.md` 的 `重点阅读文件` 列表逐条比对上游当前目录树。
- **保守原则**：无法在合理成本内核验的，记为"漂移-待核验"并延后，不做乐观判定。

## 逐来源结论

### 代码仓库

| 来源 | 记录快照 | current HEAD / latest | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| **Pi** | `4943c1d6` / 2026-05-18 | `a470b121` / v0.84.2 | **实质变更** | 已 re-snapshot 到 `a69bef78`；`analysis/01` → 1.1 |
| **OpenAI Agents JS** | `629d35af` / ~v0.11.4 | `89df1ac2` / v0.17.0 | **实质变更** | `analysis/02` → 1.1（不 re-snapshot 本地树，按 release 正文分析）|
| **Vercel AI SDK** | `aa5a1e53` / v7 canary.142 | `9d9a73f1` / `ai@7.0.77` stable | **实质变更** | `analysis/02` → 1.1；消费 2026-06-05 遗留待办 |
| **MCP TypeScript SDK** | `22595b96` / 2026-05-18 | `3924de99`；`@modelcontextprotocol/sdk@1.30.0` + `@modelcontextprotocol/{core,client,server}@2.0.0` | **实质变更** | `analysis/02` → 1.1；见下方"包名重组"|
| **Spring AI Examples** | `2a6088db` / 2026-05-18 | `74164123`（+11 commits，全部为 Spring AI 2.0 对齐）| **实质变更** | `analysis/03` → 1.1 |
| **LangChain4j** | `6185599e` / ~1.15.0 | `b8b809ed` / 1.19.0 | **实质变更** | `analysis/03` → 1.1（MCP 2026-07-28 客户端 + tool action compensation）|
| **Learn Claude Code** | `1baf1aca` / 2026-05-21 | `f9e8b280`（20 课 → 17 课重构）| **实质变更** | `analysis/10` → 1.1；修复失效路径 |
| LangGraphJS | `bd72a897` / 2026-05-18 | `f8bdf16d` / `@langchain/langgraph@1.4.12` | 漂移-非实质 | 1.x 线内小版本推进；可选 re-snapshot |
| Hello-Agents | `66401d9f` / 2026-05-22 | `45dd84e6` / V1.0.3 | 漂移-非实质 | 官方自述"整体章节结构与内容体量变化不大"；可选 re-snapshot |
| SkillOpt | `c1ac570d` / 2026-06-14 | `0389ace5` / v0.2.0 | 漂移-非实质 | v0.2.0 的 SkillOpt-Sleep 在记录快照时已覆盖；可选 re-snapshot |
| mini-swe-agent | `a83fcae8` / 2026-08-04 | `25941c89` / v2.4.6 | 漂移-非实质 | 仅补丁（配置 UTF-8、tool-call 解析错误不再伪装成截断、失败但计费的调用计入 `cost_limit`）|
| Anthropic cwc-long-running-agents | `ad107a97` / 2026-08-04 | `ad107a97` | 零漂移 | 无需处置 |
| OpenAI Codex | `9873cba8` / 2026-08-04 | `a8468330`（+858 commits）| **漂移-待核验** | releases 正文为空，无法低成本判定；本轮不再分析，下轮以 `update-source` 模式重新快照后判定 |
| DeepSeek Harness | 本轮新增 | `b150a551` / `dsh` 0.1.1-rc.2 | 新增 | `analysis/18`（本轮）|

### 文章 / 规范 / 综述

| 来源 | 记录快照 | 现状 | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| **MCP 规范** | 此前只记 `specification/latest` 链接，无版本行 | 2026-07-28 修订（前一版 2025-11-25）| **实质变更** | 本轮新增 `analysis/20` + `raw/docs/mcp-2026-07-28-specification.md`，并在 SOURCE_INDEX 建独立行 |
| Anthropic, Harness Design for Long-Running Application Development | 本轮新增 | 发布 2026-03-24 | 新增 | `analysis/19`（本轮）；是 2025-11-26 文章的续作 |
| Anthropic, Building Effective Agents | 发布 2024-12-19 / 抓取 2026-05-19 | 未改 | Fresh | 刷新抓取日期 |
| Anthropic, Writing Effective Tools | 发布 2025-09-11 / 抓取 2026-05-20 | 未改 | Fresh | 刷新抓取日期 |
| OpenAI, Practical Guide to Building Agents | 抓取 2026-05-20 | 未改 | Fresh | — |
| OpenAI, Harness Engineering | 发布 2026-02-11 / 抓取 2026-08-04 | 未改 | Fresh | — |
| Anthropic, Effective Harnesses for Long-Running Agents | 发布 2025-11-26 / 抓取 2026-08-04 | 未改 | Fresh | 已被 2026-03-24 续作补充，两篇并存 |
| 检索策略研究综述 | 抓取 2026-06-02 | 结论未失效 | Fresh | 下次再综述时折入 compilation-stage knowledge layer |

## 关键发现

### 1. 一个规范修订同时驱动三个下游（本次最强信号）

MCP 2026-07-28 是本轮的**因**，不只是又一个来源：

- **MCP TS SDK** 把 v2 拆成新的 scoped 包 `@modelcontextprotocol/{core,client,server,...}@2.0.0`（2026-07-27 发布），而旧的单体包 `@modelcontextprotocol/sdk` 停在 `1.30.0`。含义是**旧包名不会升到 2.x**，迁移是换包名而不是升版本号——任何写着"升级到 SDK 2.0"的指导都是错的。
- **OpenAI Agents JS v0.15.0** 的本地 MCP 连接改用 v2 客户端并协商 2026-07-28，同时**保留对 v1 服务端的兼容回落**，`MCPServerStdio` / `MCPServerStreamableHttp` / `MCPServerSSE` 的使用方不需要自己桥接两套 SDK 包。这是一份可直接照抄的**双协议共存迁移范式**。
- **LangChain4j 1.19.0** 加入按 2026-07-28 实现的 MCP 客户端（PR 5881）。

判断：MCP 的这次修订不是纸面变更，生态在 3 周内已经在三个独立实现里落地。本仓库的 `build-mcp-capabilities` 必须按新基线重写，而不是加注脚。

### 2. Vercel AI SDK v7 转正，且破坏面比 2026-06-05 预判的更宽

`ai@7.0.0` 于 2026-06-25 发布，当前 `latest` 为 `ai@7.0.77`（2026-08-22）。命中已分析表面的破坏性变更至少包括：

- `stepCountIs` → **`isStepCount`** 重命名；
- **全包 ESM-only**，移除 CommonJS 导出（`require()` 使用方必须改 `import`）；
- 移除 `ToolCallOptions`（改用 `ToolExecutionOptions`）、移除 `experimental_customProvider`；
- `experimental_telemetry` 转正，`*TelemetryIntegration` → `*Telemetry`；
- 回调事件数据重构（2026-06-05 记录的 `onFinish`→`onEnd` 属于这一批）；
- `StepResult` 的 response messages 收窄为"该 step 内产生的消息"；
- 新增 provider references / 上传 provider skills、顶层 `reasoning` 参数。

核对结果：`skills/implement-ts-agents/SKILL.md` 的示例已经写的是 `isStepCount(10)`，未受影响；skill 中未出现 `onFinish` / `ToolCallOptions` / `experimental_telemetry`。**skill 层零命中**，只需在 `analysis/02` 记录版本事实与 ESM-only 这一条落地约束。

### 3. OpenAI Agents JS 六个 minor 版本里出现了三条 lab 级别的模式

不是例行迭代，是新抽象：

- **Programmatic Tool Calling**（v0.14.0）：模型生成托管 JavaScript 来协调多个工具并**压缩中间结果**，且 program call 在 streaming / session / replay / 序列化 `RunState` 中都被保留。这与 `analysis/18-deepseek-harness.md` 的 Code Mode 是同一个抽象的第二次独立出现。
- **重放歧义下 fail-closed**（v0.15.0–v0.17.0）：序列化的、带输出的审批检查点在 SDK 无法证明"哪个响应拥有这个待决终态工具输出"时，**以 `UserError` 失败**而不是猜；非流式模型重放需要显式 `approveUnsafeReplay: true`；序列化凭据与不安全的挂载授权**在恢复时一律不被信任**；带凭据的容器内挂载必须由应用显式确认精确挂载路径（`Manifest.withInContainerMountCredentialExposureAcknowledged()`）。
- **确定性测试设施**（v0.16.0）：`@openai/agents/testing` 提供 `ScriptedModel`、`scriptedSandboxSession()`、`ScriptedRealtimeTransport`，让 runner / sandbox / Realtime 流程可以在无真实模型、无 WebRTC 的条件下被测试。

另有两条安全默认值翻转值得记：**敏感模型与工具数据日志默认关闭**（v0.14.0，需 `setSensitiveDataLoggingEnabled(true)` 显式开启），以及运行取消现在会传播到函数工具与 MCP 工具，且流的完成会**等待后台工作与清理落定**。

### 4. learn-claude-code 重构导致本仓库出现失效路径（唯一硬错误）

上游从 20 课重构为 17 课并整体重编号。以下课程**已不存在**：`s10_system_prompt`、`s11_error_recovery`、`s17_autonomous_agents`、`s18_worktree_isolation`、`s19_mcp_plugin`、`s20_comprehensive`。新的编号是 `s10_task_system` / `s11_background_tasks` / `s12_cron_scheduler` / `s13_agent_teams` / `s14_mcp_plugin`，并新增 `s15_integrated_harness` / `s16_workflow_runtime` / `s17_goal_loop`。

受影响文件：`analysis/SOURCE_INDEX.md`（第 217–225 行区间的 9 条路径）与 `skills/build-ai-agents/references/source-map.md`（第 123–130 行区间的 8 条路径）。这类错误 2026-06-05 那次没有查，因为当时只查了"仓库是否漂移"，没查"我们引用的具体路径是否还在"。**方法上的改进已并入本次流程**（见下方"方法改进"）。

另外同一处还有一条 Pi 的失效路径：`packages/agent/docs/agent-harness.md` 已重命名为 `packages/agent/docs/harness.md`。

### 5. Spring AI 2.0 与 LangChain4j 的补偿语义

- Spring AI 示例仓的 11 个 commit 全部是"对齐 Spring AI 2.0"，包括 MCP 示例的整体对齐与冗余项目清理。Java 侧的分析基线（`analysis/03`）建立在 1.x 上，需要在头部标注版本事实。
- LangChain4j 1.19.0 引入 **agentic system 级别的 tool action compensation**（PR 5823）。这是本仓库此前没有覆盖的形状：不是"重试"也不是"审批"，而是**为已执行的工具动作登记补偿动作**，在上层失败时回滚。它与 Pi 的 effect sandwich、MCP 的 MRTR 幂等要求同属一个问题域（副作用的可撤销性），值得进入综合分析。

### 6. 一条被证伪的初判

初查 `git ls-remote --tags | sort -V | tail` 时，MCP TS SDK 的最新 tag 显示为 `v2.0.0-beta.1`，据此差点记为"v2 仍在 beta"。改查 npm dist-tags 后发现 **`@modelcontextprotocol/core@2.0.0` 等新包已于 2026-07-27 正式发布**，只是没有对应的 `v2.0.0` git tag。教训：**monorepo 的发布状态要以包注册表为准，不能以 git tag 为准**。这条已写入方法。

## 方法改进（并入下次审查）

1. **查路径有效性，不只查仓库漂移**。每次审查必须把 `SOURCE_INDEX.md` 与 `source-map.md` 的 `重点阅读文件` 逐条与上游当前目录树比对。本次发现 10 条失效路径，全部来自"仓库没删、但文件被重命名/重编号"。
2. **monorepo 用 npm dist-tags 判定发布线**，git tag 只作辅助。
3. **把"上游规范修订"当作独立来源类型**登记。MCP 规范此前只在 Official Links 里有一条链接、没有版本行，导致 2025-11-25 → 2026-07-28 这一跨越在上次审查里完全不可见。规范类来源必须有 `来源版本` 行才能被漂移检测覆盖。
4. **无法低成本核验的来源，明确记为"漂移-待核验"并延后**，不做乐观判定（本次 Codex 即按此处理）。

## 本次落地

见 `CHANGELOG.md` [2.2.0]。要点：3 个新来源分析（18/19/20）、1 篇设计重思（21）、5 篇分析版本推进（01/02/03/07/10）、9 个 skill 更新、SOURCE_INDEX 路径修复与新增行。

## 待办（不在本次落地）

1. **OpenAI Codex 深度核验**：+858 commits 未判定。下轮以 `update-source` 模式重新快照到当时 HEAD，再判定 `analysis/16` 是否需要推进。
2. **例行 re-snapshot（纯增量）**：LangGraphJS、Hello-Agents、SkillOpt、mini-swe-agent。
3. **Vercel AI / OpenAI Agents JS 的本地树刷新**：本轮按 release 正文分析，未刷新 `raw/repos/` 下的本地快照；下次常规同步时一并更新 gitlink。
4. **观察**：MCP TS SDK v2 包线的稳定度与 v1 单体包的弃用节奏；MCP 规范的 12 个月弃用窗口（Roots / Sampling / Logging）到期时间。

## SEED-001 状态

**维持 dormant**。本次消费的触发是"快照超过一个季度"。实际范围为 medium 而非 seed 预估的 small——原因是这次赶上了一个**上游规范修订带动多个下游同时变更**的窗口。seed 的 `scope: small` 估计对"平静季度"成立，对"规范修订季度"不成立，已在 seed 的 Review Log 里记下这条。
