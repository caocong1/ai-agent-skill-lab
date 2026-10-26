# Source Index

更新时间：2026-08-23（新增 DeepSeek Harness、Anthropic 2026-03 harness 设计文章、MCP 2026-07-28 规范修订；推进 Pi / OpenAI Agents JS+Vercel AI+MCP SDK / Spring AI+LangChain4j / learn-claude-code 四组分析至 1.1；2026-08-23 执行 SEED-001 第二次来源新鲜度审查，详见下方 `## 新鲜度审查`）。所有仓库均以 shallow clone 方式保存在 `raw/repos/`。

逐来源的 `来源版本 / 分析版本 / 最后更新` 在下方表格维护；再分析某来源新版本时，更新该来源所在行 + 对应分析文件头部元数据块 + `CHANGELOG.md`。`来源版本` 对仓库是 commit，对文章是发布/抓取日期，对协议规范是规范修订日期。`分析版本` 是本仓库对该来源的分析报告版本，与 skill 版本独立。

**协议规范类来源必须有独立的版本行**：2026-08-23 审查发现，MCP 规范此前只以一条 Official Links 链接存在、没有版本行，导致 2025-11-25 → 2026-07-28 这一修订对漂移检测完全不可见。凡是本仓库依赖其结论的上游规范，都要在下方 `## Specifications` 建行。

## Repositories

| 项目 | 本地路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Pi | `raw/repos/pi` | `d5b3de22d0e24a3e9c38a9410d3329b099717283`（v1.4.x 线，npm `@earendil-works/pi-*` 1.4.0） | 2.0 | 2026-10-25 | agent loop、harness、skills、resource loader、extensions、subagents ｜ 2.0：1.0 把持久化执行移出核心、交给实验包 `pi-durable`（intent → 效应 → 结果、整任务检查点、重放只能被当前声明否决不能被升级、恢复不重跑 `beforeTool`、崩溃循环保护、持久 sleep、结构化并发）；tool `exposure`/callers 与 codemode；约束式采样 prefer 与 require 之分 |
| OpenAI Agents JS | `raw/repos/openai-agents-js` | `be4f1f9aa4ad4f03cc5db5fdd57d0d0136923570`（`@openai/agents` 0.21.0） | 1.2 | 2026-10-25 | Agent、tools、handoffs、guardrails、interruptions、RunState ｜ 1.1 新增 Programmatic Tool Calling、重放歧义 fail-closed、`ScriptedModel` 测试设施、MCP v2 协商 ｜ 1.2 新增审批状态保管（`RunState` 解析不等于认证、服务端持有、逐条原子消费）、条件审批绑定归一化输入、审批恢复后的模型调用计入 `maxTurns` |
| LangGraphJS | `raw/repos/langgraphjs` | `c6675bf03f353ff32fb2ee0a82adb3541c0aee40`（`@langchain/langgraph` 1.5.2） | 1.2 | 2026-10-25 | graph orchestration、checkpoint、thread、HITL、multi-agent handoff ｜ 1.2：并行写按逻辑任务路径回放、`isCommand` 不再接受普通对象（数据永不当控制流）、`interrupt` 的 responseSchema；文档已迁至 docs.langchain.com |
| MCP TypeScript SDK | `raw/repos/modelcontextprotocol-typescript-sdk` | `951fe5603a7ec0b2dcb6a0b95d92cd86f93ad9e5`（scoped `@modelcontextprotocol/{core,client,server}` 2.4.0；单体 `@modelcontextprotocol/sdk` 1.32.2 为只维护线） | 1.2 | 2026-10-25 | MCP server/client、tool/resource/prompt、stdio/http transport ｜ ⚠ v2 是**换包名**不是升版本号 ｜ 1.2：单体 1.x 不会实现 2026-07-28、`server-legacy` 是冻结的 v1 迁移垫片（计划 v3 移除）、Skills over MCP（SEP-2640）读取时校验摘要、无状态模式每请求一个 server 实例、按工具的 scope challenge、列表分页上限 |
| Vercel AI SDK | `raw/repos/vercel-ai` | `6147ecd94b16c0cd14580e9725517fabff4cbdf4`（`ai@7.0.153`；`@ai-sdk/workflow` 单独发版） | 1.2 | 2026-10-25 | ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP adapter ｜ v7 破坏面见 1.1 ｜ 1.2：`@ai-sdk/harness`（把多个本地 harness 放到同一个流接口后面）、签名审批与审批语义（首个回应有效、被后续用户消息取代即作废）、按工具声明调用方、`interrupted` finish reason、默认步数上限因入口而异 |
| Spring AI Examples | `raw/repos/spring-ai-examples` | `e499007e2b4074561c015b057b31c026d1f02f14`（对齐 Spring AI 2.1.0-SNAPSHOT；框架 2.0.2 GA / 2.1.0-RC1） | 1.2 | 2026-10-25 | Java agentic patterns、function callback、MCP annotations ｜ 1.2：2.1 RC 弃用 `ChatMemory` 家族改用事件溯源 session、工具调用确认（无状态暂停、策略 OR 组合只能加确认）、`defaultTools()`；钉住的 MCP Java SDK 尚未实现 2026-07-28（2.1 GA 后复核） |
| LangChain4j | `raw/repos/langchain4j` | `7948fba82672cdff5ec4219b0600693221ad855d`（1.22.0） | 1.2 | 2026-10-25 | Java AI service、tool executor/provider、agentic sequence、skills ｜ 1.1 新增 MCP 2026-07-28 客户端与 agentic 级补偿动作 ｜ 1.2：按异常类型决定错误是否对模型可见（`ToolErrorVisibleToLlm`，2.0 计划默认不可见）、DecisionModel、异步方法默认值不同、1.19.1 为误发布 |
| Learn Claude Code | `raw/repos/learn-claude-code` | `ce8f9f186058939da54c9d6fead78dfb5d0fd6c3`（17 课结构未变） | 1.2 | 2026-10-25 | harness vs agent 区分、17 课渐进式编目、cheap-first 多层 compaction、memory 三段流程、worktree 隔离、mailbox + claim-from-board 多 agent ｜ 1.1 新增 s15 集成 harness、s16 workflow runtime、s17 goal loop ｜ 1.2：s08 压缩顺序更正（先落盘、超限才替换、无恢复路径不做有损替换），并把三处 commit 记录统一（此前 gitlink 实际停在 `1baf1aca`） |
| Hello-Agents (Datawhale) | `raw/repos/hello-agents` | `66401d9f54d989f3d35b32ae411faf0fb472164f` | 1.0 | 2026-05-22 | 流程驱动 vs AI Native Agent、16 章全栈编目、自建 HelloAgents 框架（Message/Config/Agent）、四级记忆 + RAG、GSSC 上下文工程、协议谱系（MCP/A2A/ANP）、Agentic-RL（SFT + GRPO）、BFCL/GAIA 评估、TODO 驱动深度研究、赛博小镇 |
| SkillOpt (Microsoft) | `raw/repos/skillopt` | `84b36cd5564e8893569e50e37f02a81d10b55e27`（发布线仍为 v0.2.0） | 1.1 | 2026-10-25 | skill 文档作为可训练外部状态、rollout/reflect/aggregate/select/update/gate、held-out validation、SkillOpt-Sleep ｜ 1.1：优化器反馈边界（评测细节只进审计）、按血缘的划分暴露账本、逐任务不回退闸、夜间预算真正生效、harvest 排除自身会话、成对 A/B 统计工具 |
| Anthropic cwc-long-running-agents | `raw/repos/cwc-long-running-agents` | `ad107a974bced5244f74dd283dbf2bfd3baee3a1` | 1.0 | 2026-08-04 | default-FAIL contract、fresh-context evaluator、evidence gate、agent-maintained handoff、kill switch、operator steering |
| OpenAI Codex | `raw/repos/openai-codex` | `970111f6cb62cc02fe36a82ea7d71b37a2889c97`（main 2026-10-23；最新稳定版 rust-v0.164.0） | 1.1 | 2026-10-25 | turn/step/tool-call 生命周期、step snapshot、dynamic tools、AGENTS.md provenance、compaction、approval/sandbox/retry、rollout ｜ 1.1：Guardian（策略与人之间的模型审批层）、step 设置快照、授权绑定签发它的 turn、越沙箱重试必须重审且部分放宽、工具目录只追加、每段上下文带 provenance、目标续跑无进展上限 |
| mini-swe-agent | `raw/repos/mini-swe-agent` | `a83fcae82d2a08f0ee0c688f9d137b3566c097f8` | 1.0 | 2026-08-04 | bash-only action、linear trajectory、stateless execution、environment adapter、benchmark-first minimal harness ｜ 2026-08-23 核验：漂移至 v2.4.6，仅补丁（失败但计费的调用计入 `cost_limit`、tool-call 解析错误不再伪装成截断）|
| DeepSeek Harness | `raw/repos/deepseek-harness` | `1f81c047fc48fa190a683e469daa699857e9afe8`（`dsh-v0.2.1-rc.3`，prerelease） | 1.1 | 2026-10-25 | Cordis 插件树 + profile/bundle、capability seam、事件溯源 session log 与投影、turn/step/round、单调 `ToolGuard`、`ApprovalOutcome` 四元组、spill seam、compaction 锁、goal domain、workflow engine、Model Experience README 契约 ｜ 1.1：Code Mode 改名 PTC、运行时不变量层被删除、system prompt 入日志并追加在缓存历史之后、unknown outcome 工具结果、契约政策翻转（已发布的会话数据即义务，每个破坏性变更附升级指南）、实验性 Auto review 及其 PTC 绕过缺口、Ralph 降为实验；更正 1.0 把 guard 画在审批之前的顺序 |

## Articles and Papers

非代码来源的权威文章/论文。快照保存在 `raw/docs/`，分析报告在 `analysis/`。

| 来源 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Anthropic, Building Effective Agents | `raw/docs/anthropic-building-effective-agents.md` | 发布 2024-12-19 / 抓取 2026-05-19 | 1.0 | 2026-05-19 | workflow 与 agent 判定、五种 workflow 模式、自治 agent 循环、simplicity/transparency/ACI |
| Anthropic, Writing Effective Tools for Agents | `raw/docs/anthropic-writing-effective-tools.md` | 发布 2025-09-11 / 抓取 2026-05-20 | 1.0 | 2026-05-20 | tool 选择、命名空间、返回上下文、token 效率、tool description/spec、工具评测 |
| OpenAI, A Practical Guide to Building Agents | `raw/docs/openai-practical-guide-building-agents.md` | 发布未标注 / 抓取 2026-05-20 | 1.0 | 2026-05-20 | agent 适用性、model/tools/instructions、单 agent 优先、多 agent 编排、guardrails、人类介入 |
| OpenAI, Harness Engineering | `raw/docs/openai-harness-engineering.md` | 发布 2026-02-11 / 抓取 2026-08-04 | 1.0 | 2026-08-04 | repository-as-system-of-record、agent legibility、可观测环境、机械架构约束、反馈编译、持续垃圾回收 |
| Anthropic, Effective Harnesses for Long-Running Agents | `raw/docs/anthropic-effective-harnesses-long-running-agents.md` | 发布 2025-11-26 / 抓取 2026-08-04 | 1.0 | 2026-08-04 | initializer/coding session、外部化连续性、default-FAIL feature contract、progress + git、fresh-session E2E 验证 |
| Anthropic, Harness Design for Long-Running Application Development | `raw/docs/anthropic-harness-design-long-running-apps.md` | 发布 2026-03-24 / 抓取 2026-08-23 | 1.0 | 2026-08-23 | GAN 式 generator/evaluator 分离（自评不可信）、planner/generator/evaluator 三角色、协商式 sprint contract、context reset vs compaction 按模型代际选择、可评分的主观 rubric + few-shot 分数拆解校准、读分歧改 QA prompt 的评估器调优回路、evaluator 性价比取决于任务难度相对模型能力、**harness 组件是有保质期的假设** |

## Specifications

本仓库依赖其结论的上游协议规范。快照保存在 `raw/docs/`（paraphrased digest），分析报告在 `analysis/`。`来源版本` 记为规范修订日期 + 抓取日期；规范类来源建独立行的原因见本文件开头。

| 规范 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| MCP Specification | `raw/docs/mcp-2026-07-28-specification.md` | 修订 2026-07-28（前一版 2025-11-25）/ 抓取 2026-08-23 | 1.0 | 2026-08-23 | 无状态核心（移除 `initialize` / `notifications/initialized` / `Mcp-Session-Id`）、`server/discover`、MRTR（`InputRequiredResult` / `inputRequests` / `inputResponses`）、必填 `resultType`、`subscriptions/listen`、tasks 转扩展并改轮询、`extensions` 框架、`CacheableResult`（`ttlMs` / `cacheScope`）、`tools/list` 确定性排序与 prompt cache、`Mcp-Method` / `Mcp-Name` 头与 `x-mcp-header`、错误码分区政策、OAuth 收紧（`iss` / issuer 绑定 / `application_type` / DCR 弃用）、Roots / Sampling / Logging 弃用、三态特性生命周期与 12 个月弃用窗口 |

## Research Syntheses

多来源 web 研究综合（非单一仓库 / 单篇文章）。快照保存在 `raw/docs/`（paraphrased digest，含源 URL 与可靠度分层），分析报告在 `analysis/`。`来源版本` 记为综合时间窗 + 抓取日期；`最后更新` 按再综述时间推进，不随单个上游来源的小改动走。

| 来源 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| 检索策略研究综述（向量 RAG vs Agentic 检索） | `raw/docs/retrieval-strategy-research.md` | 综合 2024–2026 多源（约 55 源 + 对抗式核验）/ 抓取 2026-06-02 | 1.0 | 2026-06-02 | 检索按语料规模分层 + 查询类型路由、agentic 检索 vs 向量 RAG vs 长上下文、查询扩展 + 精确匹配兜底、混合+重排为生产标准、检索失败的静默性、grep 工具层盘点 |

## 新鲜度审查

逐次新鲜度审查（SEED-001）记录于此。审查只核验“上游相对快照是否漂移、漂移是否实质”，**不等于再分析**；除非某来源被实际再分析，否则上方表格的 `来源版本` / `最后更新` 维持其分析快照不变。

### 2026-06-05（SEED-001 首次审查）

- 覆盖：13 个来源（9 仓库 + 3 文章 + 1 研究综述）；全部可达；所有快照均在一个季度内（最早 2026-05-18，阈值 2026-03-05），无 stale-by-time。
- 结论：仅 **Vercel AI SDK** 为实质性变更（v7 canary `onFinish`→`onEnd` + finalStep 聚合语义，PR 15245，命中已分析表面）→ 标记待再分析。其余 10 个漂移来源为补丁级/纯增量，无破坏已分析模式的变更；Spring AI Examples 零漂移；3 篇文章与检索综述内容未变。
- 误归纠正：Pi 的 tool-allowlist/factory 破坏性迁移在 v0.68.0（早于 v0.75.3 快照），不在 v0.75.4–v0.78.1 漂移窗口内（对抗式核验推翻初判）。
- 逐来源（current HEAD / latest release / 状态）：
  - Pi：`89a92207` / v0.78.1 / 漂移-非实质
  - OpenAI Agents JS：`5ffee544` / v0.11.6 / 漂移-非实质
  - LangGraphJS：`f552c058` / 1.3.5 / 漂移-非实质
  - MCP TypeScript SDK：`ab552c30` / v1.29.0 稳定线（main 为 v2 pre-alpha）/ 漂移-非实质
  - Vercel AI SDK：`d66ae028` / ai@7.0.0-canary.165 / **实质变更，待再分析**
  - Spring AI Examples：`2a6088db` / 无 tag / 零漂移
  - LangChain4j：`c9f52740` / 1.15.1 / 漂移-非实质
  - Learn Claude Code：`3d018a0d` / 无 tag / 漂移-非实质
  - Hello-Agents：`248aa248` / V1.0.2 / 漂移-非实质
  - Anthropic Building Effective Agents：发布 2024-12-19，未改 / Fresh
  - Anthropic Writing Effective Tools：发布 2025-09-11，未改 / Fresh
  - OpenAI Practical Guide to Building Agents：未改 / Fresh
  - 检索策略研究综述：综合 2026-06-02，结论未失效 / Fresh
- 同批落地的措辞收口（SEED-001 体质）见 `CHANGELOG.md` [1.5.1]；完整报告见 `.planning/freshness-reviews/2026-06-05-source-freshness-review.md`。
- 待办：Vercel AI SDK 再分析 + re-snapshot；其余可在下次常规同步 re-snapshot（纯增量，无需再分析）。

### 2026-08-23（SEED-001 第二次审查）

- 覆盖：14 仓库 + 6 文章/规范 + 1 研究综述。**5 个实质性变更**（上次仅 1 个）。
- 主因高度集中：**MCP 规范 2026-07-28 修订**在三周内同时驱动 MCP TS SDK v2 包名重组、OpenAI Agents JS 的 v2 协商、LangChain4j 的 2026-07-28 客户端——一个上游规范修订扇出到三个下游。
- 逐来源（current HEAD / latest / 状态）：
  - Pi：`a470b121` / v0.84.2 / **实质变更** → 已 re-snapshot 至 `a69bef78`，`analysis/01` → 1.1
  - OpenAI Agents JS：`89df1ac2` / v0.17.0 / **实质变更** → `analysis/02` → 1.1
  - Vercel AI SDK：`9d9a73f1` / `ai@7.0.77` stable / **实质变更** → `analysis/02` → 1.1（消费 2026-06-05 遗留待办）
  - MCP TypeScript SDK：`3924de99` / `@modelcontextprotocol/sdk@1.30.0` + 新包 `…/{core,client,server}@2.0.0` / **实质变更** → `analysis/02` → 1.1
  - Spring AI Examples：`74164123`（+11 commits，全部 Spring AI 2.0 对齐）/ **实质变更** → `analysis/03` → 1.1
  - LangChain4j：`b8b809ed` / 1.19.0 / **实质变更** → `analysis/03` → 1.1
  - Learn Claude Code：`f9e8b280`（20 课 → 17 课重构）/ **实质变更** → `analysis/10` → 1.1
  - LangGraphJS：`f8bdf16d` / `@langchain/langgraph@1.4.12` / 漂移-非实质
  - Hello-Agents：`45dd84e6` / V1.0.3（官方自述结构与体量变化不大）/ 漂移-非实质
  - SkillOpt：`0389ace5` / v0.2.0（Sleep 在记录快照时已覆盖）/ 漂移-非实质
  - mini-swe-agent：`25941c89` / v2.4.6（仅补丁）/ 漂移-非实质
  - Anthropic cwc-long-running-agents：`ad107a97` / 零漂移
  - OpenAI Codex：`a8468330`（+858 commits，release 正文为空）/ **漂移-待核验**，下轮以 `update-source` 模式重新快照后判定
  - 4 篇既有文章与检索综述：内容未变 / Fresh
- **发现 10 条失效引用路径**（本 seed 首次抓到硬错误）：learn-claude-code 重编号导致 9 条、Pi 的 `agent-harness.md` → `harness.md` 1 条。均已修复。
- 方法改进（已并入下次审查）：①核对引用路径是否仍存在，不只查仓库漂移；②monorepo 用 npm dist-tags 判定发布线，git tag 只作辅助（本次 MCP SDK 的 `v2.0.0-beta.1` tag 差点误导为"v2 仍在 beta"，实际新 scoped 包已于 2026-07-27 正式发布）；③上游规范建独立版本行；④无法低成本核验的记为"待核验"，不做乐观判定。
- 完整报告见 `.planning/freshness-reviews/2026-08-23-source-freshness-review.md`；落地见 `CHANGELOG.md` [2.2.0]。
- 待办：OpenAI Codex 深度核验；LangGraphJS / Hello-Agents / SkillOpt / mini-swe-agent 例行 re-snapshot；Vercel AI 与 OpenAI Agents JS 的本地树刷新。

## Official Links

Canonical link list for the reusable skill lives in `skills/build-ai-agents/references/source-map.md`; this section keeps a lab-level copy for source acquisition history.

- Pi: https://github.com/earendil-works/pi
- OpenAI, A Practical Guide to Building Agents: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- Anthropic, Building Effective Agents: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic, Writing Effective Tools for AI Agents: https://www.anthropic.com/engineering/writing-tools-for-agents
- OpenAI Agents JS: https://github.com/openai/openai-agents-js
- OpenAI Agents JS docs: https://openai.github.io/openai-agents-js/
- LangGraphJS: https://github.com/langchain-ai/langgraphjs
- LangGraphJS docs: https://langchain-ai.github.io/langgraphjs/
- MCP TypeScript SDK: https://github.com/modelcontextprotocol/typescript-sdk
- MCP specification: https://modelcontextprotocol.io/specification/latest
- MCP docs: https://modelcontextprotocol.io/docs
- Vercel AI SDK: https://github.com/vercel/ai
- Vercel AI SDK docs: https://ai-sdk.dev/docs
- Spring AI examples: https://github.com/spring-projects/spring-ai-examples
- Spring AI docs: https://docs.spring.io/spring-ai/reference/
- LangChain4j: https://github.com/langchain4j/langchain4j
- LangChain4j docs: https://docs.langchain4j.dev/
- Learn Claude Code (shareAI-lab): https://github.com/shareAI-lab/learn-claude-code
- Learn Claude Code site: https://learn.shareai.run
- Hello-Agents (Datawhale): https://github.com/datawhalechina/Hello-Agents
- Hello-Agents site: https://datawhalechina.github.io/hello-agents/
- Google Agent Development Kit docs: https://google.github.io/adk-docs/
- SkillOpt (Microsoft): https://github.com/microsoft/SkillOpt
- SkillOpt project page: https://microsoft.github.io/SkillOpt/
- SkillOpt arXiv paper: https://arxiv.org/abs/2605.23904
- OpenAI, Harness Engineering: https://openai.com/index/harness-engineering/
- Anthropic, Effective Harnesses for Long-Running Agents: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic cwc-long-running-agents: https://github.com/anthropics/cwc-long-running-agents
- OpenAI Codex: https://github.com/openai/codex
- mini-swe-agent: https://github.com/SWE-agent/mini-swe-agent
- DeepSeek Harness: https://github.com/deepseek-ai/deepseek-harness
- Anthropic, Harness Design for Long-Running Application Development: https://www.anthropic.com/engineering/harness-design-long-running-apps
- MCP specification 2026-07-28 changelog: https://modelcontextprotocol.io/specification/2026-07-28/changelog
- MCP deprecated features registry: https://modelcontextprotocol.io/specification/2026-07-28/deprecated
- MCP feature lifecycle policy: https://modelcontextprotocol.io/community/feature-lifecycle
- Claude Code docs: https://docs.claude.com/claude-code
- Anthropic Agent SDK docs: https://docs.claude.com/agent-sdk
- 检索策略综述关键源 — Anthropic Contextual Retrieval: https://www.anthropic.com/news/contextual-retrieval
- 检索策略综述关键源 — Latent Space《Claude Code》(agentic search 弃用向量索引的一手陈述): https://www.latent.space/p/claude-code
- 检索策略综述关键源 — LlamaIndex《Did filesystem tools kill vector search》(规模拐点基准): https://www.llamaindex.ai/blog/did-filesystem-tools-kill-vector-search
- 检索策略综述关键源 — 长上下文 vs RAG 生产决策框架: https://tianpan.co/blog/2026-04-09-long-context-vs-rag-production-decision-framework
- grep 工具层 — ripgrep: https://github.com/BurntSushi/ripgrep
- grep 工具层 — ast-grep: https://ast-grep.github.io/
- grep 工具层 — ripgrep-all (rga): https://github.com/phiresky/ripgrep-all

## 重点阅读文件

Pi:

- `packages/agent/src/agent-loop.ts`
- `packages/agent/src/harness/agent-harness.ts`
- `packages/agent/src/harness/skills.ts`
- `packages/agent/docs/harness.md`（v0.84 线；由 `agent-harness.md` 重命名并大幅扩写，持久化执行 harness 的权威文档）
- `packages/coding-agent/docs/skills.md`
- `packages/coding-agent/src/core/agent-session.ts`
- `packages/coding-agent/src/core/resource-loader.ts`
- `packages/coding-agent/src/core/system-prompt.ts`
- `packages/coding-agent/examples/extensions/permission-gate.ts`
- `packages/coding-agent/examples/extensions/dynamic-tools.ts`
- `packages/coding-agent/examples/extensions/subagent/README.md`

OpenAI Agents JS:

- `packages/agents-core/src/run.ts`
- `packages/agents-core/src/runner/runLoop.ts`
- `packages/agents-core/src/tool.ts`
- `examples/docs/agents/agentWithTools.ts`
- `examples/agent-patterns/human-in-the-loop.ts`
- `examples/agent-patterns/agents-as-tools.ts`
- `examples/agent-patterns/parallelization.ts`

LangGraphJS:

- `README.md`
- `examples/streaming/src/agents/hitl-agent.ts`
- `examples/streaming/src/agents/simple-tool-graph.ts`
- `docs/docs/agents/human-in-the-loop.md`
- `docs/docs/agents/multi-agent.md`
- `docs/docs/concepts/persistence.md`

MCP TypeScript SDK:

- `README.md`
- `packages/server/src/server/mcp.ts`
- `packages/client/src/client/client.ts`
- `examples/server-quickstart/src/index.ts`
- `examples/server/src/simpleStatelessStreamableHttp.ts`
- `docs/server.md`
- `docs/client.md`

Vercel AI SDK:

- `packages/ai/README.md`
- `content/docs/03-agents/01-overview.mdx`
- `content/docs/03-agents/02-building-agents.mdx`
- `content/docs/03-agents/03-workflows.mdx`
- `content/docs/03-agents/04-loop-control.mdx`
- `content/docs/03-agents/06-tool-approvals.mdx`
- `content/docs/03-agents/06-memory.mdx`
- `content/docs/03-agents/06-subagents.mdx`
- `content/docs/03-agents/07-workflow-agent.mdx`
- `content/docs/03-ai-sdk-core/16-mcp-tools.mdx`
- `examples/next-agent/agent/weather-agent.ts`
- `examples/next-agent/app/api/chat/route.ts`
- `examples/next-agent/tool/weather-tool.ts`

Spring AI Examples:

- `agentic-patterns/README.md`
- `agentic-patterns/chain-workflow/src/main/java/com/example/agentic/ChainWorkflow.java`
- `agentic-patterns/orchestrator-workers/src/main/java/com/example/agentic/OrchestratorWorkers.java`
- `agentic-patterns/evaluator-optimizer/src/main/java/com/example/agentic/EvaluatorOptimizer.java`
- `misc/spring-ai-java-function-callback/src/main/java/com/example/java_ai_function_callback/SpringAiJavaFunctionCallbackApplication.java`
- `model-context-protocol/mcp-annotations/mcp-annotations-server/src/main/java/org/springframework/ai/mcp/sample/server/providers/ToolProvider.java`

LangChain4j:

- `langchain4j/src/main/java/dev/langchain4j/service/tool/DefaultToolExecutor.java`
- `langchain4j/src/main/java/dev/langchain4j/service/tool/ToolProvider.java`
- `langchain4j-agentic/src/test/java/dev/langchain4j/agentic/carrentalassistant/AssistantMain.java`
- `langchain4j-skills/src/main/java/dev/langchain4j/skills/Skills.java`
- `langchain4j-skills/src/test/resources/skills/test-skill/SKILL.md`

Anthropic Building Effective Agents:

- `raw/docs/anthropic-building-effective-agents.md`（原文快照）
- `analysis/06-anthropic-building-effective-agents.md`（分析报告）

Anthropic Writing Effective Tools for Agents:

- `raw/docs/anthropic-writing-effective-tools.md`（结构化摘要快照）
- `analysis/08-anthropic-writing-effective-tools.md`（分析报告）

OpenAI Practical Guide to Building Agents:

- `raw/docs/openai-practical-guide-building-agents.md`（结构化摘要快照）
- `analysis/09-openai-practical-guide-building-agents.md`（分析报告）

Learn Claude Code (shareAI-lab)（教学型 harness 编目；每节课配独立 `code.py`）:

> ⚠ 上游在 `f9e8b280` 处由 20 课重构为 **17 课并整体重编号**。下列路径对应该 commit；引用旧编号（`s10_system_prompt` / `s11_error_recovery` / `s17_autonomous_agents` / `s18_worktree_isolation` / `s19_mcp_plugin` / `s20_comprehensive`）的文档均已失效并在 2026-08-23 修正。

- `raw/repos/learn-claude-code/README.md`
- `raw/repos/learn-claude-code/s01_agent_loop/code.py`
- `raw/repos/learn-claude-code/s04_hooks/code.py`
- `raw/repos/learn-claude-code/s05_todo_write/code.py`
- `raw/repos/learn-claude-code/s07_skill_loading/code.py`
- `raw/repos/learn-claude-code/s08_context_compact/code.py`
- `raw/repos/learn-claude-code/s09_memory/code.py`
- `raw/repos/learn-claude-code/s10_task_system/code.py`
- `raw/repos/learn-claude-code/s11_background_tasks/code.py`
- `raw/repos/learn-claude-code/s12_cron_scheduler/code.py`
- `raw/repos/learn-claude-code/s13_agent_teams/code.py`
- `raw/repos/learn-claude-code/s14_mcp_plugin/code.py`
- `raw/repos/learn-claude-code/s15_integrated_harness/README.zh.md`（组件在循环里的位置表）
- `raw/repos/learn-claude-code/s16_workflow_runtime/README.zh.md`（journal 续跑 + 内容哈希调用键）
- `raw/repos/learn-claude-code/s17_goal_loop/README.zh.md`（会话级 Stop hook + 无工具独立判定器）
- `analysis/10-learn-claude-code.md`（分析报告）

Hello-Agents (Datawhale)（教学型全栈编目；16 章中文教程 + 配套代码 + Extra-Chapter）:

- `raw/repos/hello-agents/README.md`
- `raw/repos/hello-agents/docs/chapter4/第四章 智能体经典范式构建.md`（ReAct / Plan-and-Solve / Reflection 经典范式手写实现）
- `raw/repos/hello-agents/docs/chapter6/第六章 框架开发实践.md`（AutoGen / AgentScope / CAMEL / LangGraph 框架对比）
- `raw/repos/hello-agents/docs/chapter7/第七章 构建你的Agent框架.md`（HelloAgents 自建框架 Message/Config/Agent）
- `raw/repos/hello-agents/docs/chapter8/第八章 记忆与检索.md`（四级记忆 + RAG + 高级检索策略）
- `raw/repos/hello-agents/docs/chapter9/第九章 上下文工程.md`（ContextBuilder 与 GSSC 流水线、NoteTool / TerminalTool）
- `raw/repos/hello-agents/docs/chapter10/第十章 智能体通信协议.md`（MCP / A2A / ANP 协议谱系与自定义 MCP server）
- `raw/repos/hello-agents/docs/chapter11/第十一章 Agentic-RL.md`（GSM8K + LoRA SFT + GRPO 训练通路）
- `raw/repos/hello-agents/docs/chapter12/第十二章 智能体性能评估.md`（BFCL + GAIA 评估基准）
- `raw/repos/hello-agents/docs/chapter14/第十四章 自动化深度研究智能体.md`（TODO 驱动深度研究范式）
- `raw/repos/hello-agents/docs/chapter15/第十五章 构建赛博小镇.md`（NPC + 好感度 + Godot 集成案例）
- `raw/repos/hello-agents/code/chapter11/`（Agentic-RL 训练 pipeline 8 个 py 脚本）
- `raw/repos/hello-agents/code/chapter9/`（ContextBuilder / NoteTool / 代码库维护 demo）
- `raw/repos/hello-agents/Extra-Chapter/Extra01-面试问题总结.md`（Agent 求职面试题库）
- `raw/repos/hello-agents/Extra-Chapter/Extra05-AgentSkills解读.md`（Agent Skills vs MCP 对比）
- `raw/repos/hello-agents/Extra-Chapter/Extra10-Agent自进化.md`（Agent 自进化四类闭环）
- `analysis/11-hello-agents.md`（分析报告）

检索策略研究综述（向量 RAG vs Agentic 检索；多来源综合，非单一仓库 / 文章）:

- `raw/docs/retrieval-strategy-research.md`（多来源 paraphrased digest 快照）
- `analysis/12-retrieval-strategy-vector-vs-agentic.md`（分析报告）

SkillOpt (Microsoft)（skill/prompt 文本空间优化；仓库 + 论文 + Codex 插件）:

- `raw/repos/skillopt/README.md`
- `raw/repos/skillopt/docs/guide/training-loop.md`（rollout → reflect → aggregate → select → update → gate）
- `raw/repos/skillopt/docs/guide/skill-document.md`（skill document 作为 prompt weights）
- `raw/repos/skillopt/docs/guide/dl-analogy.md`（DL ↔ SkillOpt 映射）
- `raw/repos/skillopt/docs/reference/config.md`（optimizer/target/backend/eval knobs）
- `raw/repos/skillopt/skillopt/engine/trainer.py`（主训练循环）
- `raw/repos/skillopt/skillopt/evaluation/gate.py`（validation gate）
- `raw/repos/skillopt/skillopt/optimizer/skill.py`（有界 edit 应用与 protected region）
- `raw/repos/skillopt/skillopt/gradient/reflect.py`（minibatch trajectory reflection）
- `raw/repos/skillopt/docs/sleep/CONTROLLABLE_DREAMING.md`（train/val/test、multi-rollout、budget、slow update）
- `raw/repos/skillopt/plugins/codex/skills/skillopt-sleep/SKILL.md`（Codex sleep cycle skill）
- `analysis/13-skillopt.md`（分析报告）

OpenAI Harness Engineering（组织级 coding-agent harness 经验）:

- `raw/docs/openai-harness-engineering.md`（官方文章结构化摘要）
- `analysis/14-openai-harness-engineering.md`（分析报告）

Anthropic 长任务 Agent Harness（官方文章 + hooks/evaluator 配套仓库）:

- `raw/docs/anthropic-effective-harnesses-long-running-agents.md`（官方文章结构化摘要）
- `raw/repos/cwc-long-running-agents/README.md`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/CLAUDE.md`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/agents/evaluator.md`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/hooks/track-read.sh`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/hooks/verify-gate.sh`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/hooks/commit-on-stop.sh`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/hooks/kill-switch.sh`
- `raw/repos/cwc-long-running-agents/claude-code-config/.claude/hooks/steer.sh`
- `analysis/15-anthropic-long-running-agent-harness.md`（联合分析报告）

OpenAI Codex（生产级 coding-agent harness）:

- `raw/repos/openai-codex/codex-rs/core/src/session/turn.rs`
- `raw/repos/openai-codex/codex-rs/core/src/session/step_context.rs`
- `raw/repos/openai-codex/codex-rs/core/src/tools/orchestrator.rs`
- `raw/repos/openai-codex/codex-rs/core/src/tools/approvals.rs`
- `raw/repos/openai-codex/codex-rs/core/src/tools/sandboxing.rs`
- `raw/repos/openai-codex/codex-rs/core/src/agents_md.rs`
- `raw/repos/openai-codex/codex-rs/core/src/compact.rs`
- `raw/repos/openai-codex/codex-rs/core/src/rollout.rs`
- `analysis/16-openai-codex-harness.md`（分析报告）

mini-swe-agent v2（极简、benchmark-first coding harness）:

- `raw/repos/mini-swe-agent/README.md`
- `raw/repos/mini-swe-agent/src/minisweagent/agents/default.py`
- `raw/repos/mini-swe-agent/src/minisweagent/environments/local.py`
- `raw/repos/mini-swe-agent/src/minisweagent/config/default.yaml`
- `raw/repos/mini-swe-agent/docs/advanced/control_flow.md`
- `raw/repos/mini-swe-agent/tests/agents/test_default.py`
- `analysis/17-mini-swe-agent.md`（分析报告）

DeepSeek Harness（`dsh`；Cordis 插件树 micro-kernel）:

- `raw/repos/deepseek-harness/docs/architecture.md`（插件树、profile/bundle 组合、capability seam）
- `raw/repos/deepseek-harness/docs/defensive-patterns.md`（正交结果独立上报、双向遵守公共契约、dispose 到达静默、回调异常在分发器内被围堵、spawn 时清洗环境变量）
- `raw/repos/deepseek-harness/docs/subsystems/`（session log 与投影、工具管线、approval、compaction、goal、workflow、teams）
- `raw/repos/deepseek-harness/packages/workflow/tool-ralph/`（fresh child agent per round、不可变目标、共享工作区为权威、有界结构化交接；自陈缺独立评估者）
- 各包 `README.md` 结尾的 `## Model Experience` 契约（`#### What the model sees` / `#### Token effect` / `#### KV Cache effect`）与 `## Known Limitations and Deferred Work`
- `raw/repos/deepseek-harness/.agents/notes/`（proposed / implemented / rejected 三态，`## Alternatives considered` 必填）
- `analysis/18-deepseek-harness.md`（分析报告）

Anthropic Harness Design for Long-Running Application Development:

- `raw/docs/anthropic-harness-design-long-running-apps.md`（结构化摘要快照）
- `analysis/19-anthropic-harness-design-long-running-apps.md`（分析报告）

MCP Specification 2026-07-28:

- `raw/docs/mcp-2026-07-28-specification.md`（结构化摘要快照）
- `analysis/20-mcp-2026-07-28-revision.md`（分析报告）

本仓库自身设计重思（元层，非来源分析）:

- `analysis/21-lab-design-rethink-2026-08.md`（六条根基前提的压力测试、易腐 vs 耐久轴、三处自我违反、可证伪条件）
- `scripts/check-lab-invariants.sh`（约定的机械闸）
