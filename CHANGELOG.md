# Changelog

本文件记录本仓库各 skill 与分析报告的版本变更。除非另注，`## [X.Y.Z]` 形式的条目默认指 `build-ai-agents`；其他 skill 的条目以 `## <skill 名称> [X.Y.Z]` 形式标注。

版本号遵循语义化版本（SemVer），作用于 skill 契约：

- MAJOR：skill 结构 / 契约的破坏性变更（模式名、交付物格式、reference 文件移除或重命名）。
- MINOR：新增能力、新增 reference、新增对指导有实质影响的分析来源。
- PATCH：措辞澄清、小幅补充，不改变契约。

各 skill 的当前版本记录在对应 `SKILL.md` frontmatter 的 `metadata.version` 字段；逐来源的分析版本与最后更新时间记录在 `analysis/SOURCE_INDEX.md`。再分析某个来源的新版本时：更新该来源在 `SOURCE_INDEX.md` 的行、对应分析文件头部的元数据块，并在本文件追加一条记录；仅当指导内容变化时才提升 skill 版本。

## [2.2.0] - 2026-08-23

本轮由一个上游因驱动：**MCP 规范 2026-07-28 修订**在三周内同时落地到 MCP TS SDK、OpenAI Agents JS 与 LangChain4j，连带把本仓库拖进一次比往常更宽的刷新。共 3 个新来源、5 篇分析版本推进、10 个 skill 更新，并第一次给本仓库自身的约定装上机械闸。

### 新增

- **DeepSeek Harness 源码分析** `analysis/18-deepseek-harness.md`，仓库快照固定到 commit `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`（`dsh` 0.1.1-rc.2，developer preview）。本仓库目前唯一把 agent harness 完整做成 **micro-kernel + 插件树**、并逐子系统写出可核验契约的生产级来源：capability seam 三角色、event-sourced session log 与 `deriveMessages()` 投影、`model-visible ⟺ logged` 不变量、turn/step/round 三级循环、agent scope 与 tool restriction、单调 `ToolGuard`（返回类型里没有 allow 结果）、闭合的 `ApprovalOutcome` 四元组、工具管线与 `deferContext()`/`concludeTurn()`、Code Mode 与正交失败分类、spill seam、compaction 锁与 `surfaceOp`、goal domain（持久 phase + revisioned CAS，激活态故意不持久化）、Ralph 循环、workflow engine、Agent Teams、**被机械 gate 强制的 Model Experience README 契约**、runtime invariants 与 Agent Notes 三态目录。
- **Anthropic《Harness design for long-running application development》分析**（发布 2026-03-24）`analysis/19-anthropic-harness-design-long-running-apps.md` 与结构化摘要 `raw/docs/anthropic-harness-design-long-running-apps.md`：GAN 式 generator/evaluator 分离（自评不可信）、planner/generator/evaluator 三角色、协商式 sprint contract、可评分的主观 rubric 与 few-shot 分数拆解校准、context anxiety 与 context reset vs compaction 按模型代际选择、evaluator 性价比取决于任务难度相对模型能力，以及核心元规则 **"harness 里每个组件都编码了一条关于模型做不到什么的假设，而假设会过期"**。
- **MCP 2026-07-28 规范修订分析** `analysis/20-mcp-2026-07-28-revision.md` 与结构化摘要 `raw/docs/mcp-2026-07-28-specification.md`：stateless core（移除 `initialize` / `notifications/initialized` / `Mcp-Session-Id`）、必须实现的 `server/discover`、MRTR（`InputRequiredResult` / `inputRequests` / `inputResponses`）取代服务端反向请求、必填 `resultType`、`subscriptions/listen`、Tasks 转为 `io.modelcontextprotocol/tasks` 扩展并改轮询、Extensions 框架、`CacheableResult`（`ttlMs` / `cacheScope`）与 `tools/list` 确定性排序（规范直接点名 prompt cache 命中率）、`Mcp-Method`/`Mcp-Name` 头与 `x-mcp-header`、错误码分区政策、OAuth 收紧，以及 Roots / Sampling / Logging 弃用与三态特性生命周期 + 12 个月弃用窗口。
- **本仓库设计重思** `analysis/21-lab-design-rethink-2026-08.md`（元层文件，非来源分析）：把本仓库六条从未写下的根基前提显式化并逐条压力测试，得到一条新的组织轴——**易腐类**内容补模型能力缺口、随模型变强而贬值；**耐久类**内容治理授权/证据/副作用/成本、随模型变强而增值。同时记录本仓库违反自己规则的三处（教了 gate 却没有验证集、教了机械约束却零检查、教了非目标清单却没写），并给出五条可证伪条件与偏见声明。
- **机械闸** `scripts/check-lab-invariants.sh`：检查分析元数据 blockquote 格式、四处版本一致（`SKILL.md` / `README.md` / `docs/index.html` / `CHANGELOG.md`）、lab 自有引用路径存在、`docs/index.html` 三 `<td>` 规则、`SOURCE_INDEX.md` 更新时间不倒挂；对 `raw/repos` 路径只能告警（多数是无本地检出的 gitlink）。已并入 `iterate-skill-lab` 的 Definition of Done。
- **来源新鲜度审查** `.planning/freshness-reviews/2026-08-23-source-freshness-review.md`（SEED-001 第二次执行）：14 仓库 + 6 文章/规范 + 1 综述，**5 个实质性变更**（上次仅 1 个），并首次抓到硬错误——**10 条失效引用路径**。

### 变更（skill）

- `skills/build-ai-agents/SKILL.md` 2.1.0 → **2.2.0**：Core Rules 新增七条（可见面与授权是两个问题、轮次结束 ≠ 目标达成、授权不从序列化状态继承、副作用需要"知道/不重复/能撤销"三件、前缀稳定性是成本项、组件是带日期的假设需按代际消融、发布非目标清单）；新增 `## Contract Stability` 给契约配三态弃用政策与最短两个 MINOR 的窗口；路由表增加"模型升级后组件是否还该存在"的入口。
- `skills/design-ai-agent/SKILL.md` 2.1.0 → **2.2.0**：新增 `## Model-Visible Surface and Authority`（含 capability seam 三角色）、`## Perishable vs Durable Design`、`## Completion Judgment`（会话级 stop hook + 无工具独立判定器 + 闭合三元组 + 对主模型的证据写入义务）、`## Durable Execution and Side Effects`（三存储、两种恢复模型、effect sandwich、按工具重放策略、授权不继承、用可轮询句柄而非可恢复流）、`## Orchestration Above the Loop`（模型只给名称与参数、barrier vs per-item pipeline、内容哈希缓存键）、`## Contract Deprecation`；并把 compaction vs context reset 改写为按模型代际选择。
- `skills/design-agent-tools/SKILL.md` 2.0.0 → **2.1.0**：新增 `## Prompt Prefix Economics`（确定性工具排序、进入前缀的清单化）；工具设计新增显式句柄、返回结构化输入缺口而非阻塞反问、重试语义下副作用后置、spill 到不透明 locator（best-effort，失败不得把成功变成错误）、schema 约束式采样并按模型能力提前失败，以及何时让模型写程序调工具（与原生 tool loop 互斥、`isolation` 不是安全承诺）。
- `skills/build-mcp-capabilities/SKILL.md` 2.0.0 → **2.1.0**：按 2026-07-28 重建协议基线（新增 `## Protocol Baseline`），含服务端必做项清单、两条设计后果（重试一等公民 ⇒ 幂等是正确性前提；`cacheScope` 是租户边界）、弃用清单与迁移路径、错误码分区，以及"TS SDK v2 是换包名不是升版本号"的说明；client checklist 与 security checklist 相应扩充。
- `skills/secure-ai-agents/SKILL.md` 2.0.0 → **2.1.0**：新增 `## Authority Boundary Design` 三条规则——拒绝必须单调（guard 类型不能表达 allow，故监听器顺序无法重开）、审批结果是闭合集且 unavailable ≠ allowed（且只有前台交互轮次可弹确认，异步轮次直接拒绝）、授权不从序列化状态继承；记录两个常被误认成安全边界的标签（沙箱 `isolation` 标签、per-task worktree）；MCP 清单新增"工具自述不是授权依据"、OAuth `iss` 校验与 issuer 绑定、`cacheScope: private`、`x-mcp-header` 注入面。
- `skills/test-ai-agents/SKILL.md` 2.1.0 → **2.2.0**：新增 `## Judging Subjective Quality`（评分者与产出者分离、命名维度、带分数拆解的 few-shot 校准、评运行中的东西、读分歧改 prompt、rubric 措辞会塑造产出、保留可回退的中间迭代、性价比按任务难度判定）与 `## Testing Completion Gates and Durable Execution`；fake model 一节指向框架自带的 scripted 测试设施；消融一节改为对着一份**带日期的假设登记表**做，而不是在整个 harness 上猜。
- `skills/review-ai-agents/SKILL.md` 2.1.0 → **2.2.0**：评审顺序新增两步（完成判定归属、组件是否还有存在理由）；grep 种子词新增 MCP 2026-07-28 弃用/移除构件与恢复路径中反序列化授权的迹象；反模式新增 13 条。
- `skills/implement-ts-agents/SKILL.md` 2.0.0 → **2.1.0**：新增 `## Version Reality Check`（Vercel AI SDK v7 已转正且破坏、MCP TS SDK v2 是包名重组、不要依赖框架默认模型）；Pi 风格 runtime 新增持久化执行层；OpenAI Agents JS 新增 Programmatic Tool Calling、确定性测试入口、fail-closed resume、敏感数据日志默认关闭；测试清单新增崩溃恢复与 resume 授权测试。
- `skills/implement-java-agents/SKILL.md` 2.0.0 → **2.1.0**：新增 `## Version Reality Check`（Spring AI 2.0 对齐、LangChain4j 1.19 的 2026-07-28 MCP 客户端）与 `## Compensating Side Effects`（补偿动作是副作用治理的第三条腿，Saga/TCC 语义直接可迁移，是 JVM 侧相对 TS 侧的真实优势）。
- `skills/optimize-agent-skills/SKILL.md` 2.0.0 → **2.1.0**：新增 `## Shelf Life`——改措辞前先问这条规则是否还该存在；把规则分成易腐/耐久两列并区别对待；"新一代模型发布"成为启动优化循环的触发之一；并明确 evaluator 本身也是被优化对象，其证据是与人类判断的分歧样例。
- `skills/iterate-skill-lab/SKILL.md` 1.0.2 → **1.1.0**：Definition of Done 要求 `scripts/check-lab-invariants.sh` 干净退出，且失败时修问题而非放宽检查；契约移除必须先经弃用登记并保留至少两个 MINOR；新增四条新鲜度审查反模式（只查仓库漂移不查引用路径、用 git tag 判断 monorepo 发布线、依赖没有版本行的规范、把未核验的漂移记为干净）。
- `skills/build-ai-agents/references/source-map.md`：登记 DeepSeek Harness、Anthropic 2026-03 文章与 MCP 规范；开头新增**已知版本漂移**块；修正 Pi 的 `agent-harness.md` → `harness.md` 与 learn-claude-code 的课程重编号。

### 变更（分析）

- `analysis/01-pi-source-analysis.md` 1.0 → **1.1**：re-snapshot 至 `a69bef78`（v0.84.x）；新增持久化执行 harness（三存储、持久化程序计数器、effect sandwich、按工具重放策略与合成 interrupted 结果、lanes、显式非目标清单）与 v0.78 → v0.84 的四条命中变更。
- `analysis/02-agent-framework-patterns.md` 1.0 → **1.1**：新增 2026 年中版本基线表与三个新抽象（Programmatic Tool Calling 作为 Code Mode 的第二次独立出现、重放歧义下 fail-closed、确定性测试设施），并记录 Vercel v7 的破坏面与 MCP SDK v2 的包名重组。
- `analysis/03-java-agent-patterns.md` 1.0 → **1.1**：Spring AI 示例仓整体对齐 Spring AI 2.0；LangChain4j 1.19.0 的 2026-07-28 MCP 客户端与 agentic 级 tool action compensation，后者补齐副作用治理三元组的第三条。
- `analysis/07-overall-agent-analysis.md` 2.1 → **2.2**：新增八条 2026-08 收敛结论；共识矩阵增加一列（2026-08 刷新）与四行（KV cache 前缀经济学、持久化执行与副作用治理、完成判定归属、契约演进政策）；形态光谱新增五档；分歧与取舍新增四条；更新后续可分析方向。
- `analysis/10-learn-claude-code.md` 1.0 → **1.1**：上游由 20 课重构为 17 课并整体重编号；新增重构后编目与三课新增内容（s15 组件在循环里的位置表、s16 workflow runtime 的内容哈希调用键、s17 goal loop）。

### 弃用登记

无。本版本未弃用任何 mode、deliverable 或 reference path。此小节自 2.2.0 起常设：契约内的任何移除都必须先在此登记，写明替代物与最早可移除的版本，并保留至少两个 MINOR 版本。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 DeepSeek Harness 仓库行、Anthropic 2026-03 文章行，以及**新的 `## Specifications` 小节**（规范类来源此前只有一条链接、没有版本行，导致 2025-11-25 → 2026-07-28 对漂移检测完全不可见）；刷新 Pi / OpenAI Agents JS / Vercel AI / MCP TS SDK / Spring AI / LangChain4j / learn-claude-code / mini-swe-agent 的核验事实；追加 2026-08-23 新鲜度审查小节；**修正全部 10 条失效引用路径**。
- `.planning/seeds/SEED-001-source-freshness-review.md`：`last_reviewed` 推进至 2026-08-23，追加第二次审查的 Review Log（含"实际范围为 medium 而非预估的 small"这一估计失效记录）。
- `docs/index.html`：来源表新增三行，footer 更新到 v2.2.0；`<style>` 与 `<script>` 零改动，标签配平已核验。
- `README.md`：新增三个来源与目录条目；新增 **`## 这个项目不做什么`**（六条非目标，含"没有验证集"这一已记录在案的自我违反）与 **`## 设计重思`**；版本更新到 2.2.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| DeepSeek Harness | repo | `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`（`dsh` 0.1.1-rc.2）| 1.0 | 2026-08-23 |
| Anthropic, Harness Design for Long-Running Application Development | article | 发布 2026-03-24 / 抓取 2026-08-23 | 1.0 | 2026-08-23 |
| MCP Specification | spec | 修订 2026-07-28 / 抓取 2026-08-23 | 1.0 | 2026-08-23 |
| Pi | repo | `a69bef789bc95abf0acee16f7b4660b70b650bb9`（v0.84.x）| 1.1 | 2026-08-23 |
| Learn Claude Code | repo | `f9e8b280f715f9ba107d4517fd39bc5f8ddda618`（17 课重构后）| 1.1 | 2026-08-23 |
| OpenAI Agents JS | repo | 快照未刷新；按 release 正文分析至 v0.17.0 | 1.1 | 2026-08-23 |
| Vercel AI SDK | repo | 快照未刷新；核验至 `ai@7.0.77` stable | 1.1 | 2026-08-23 |
| MCP TypeScript SDK | repo | 快照未刷新；核验至 `sdk@1.30.0` + 新包 `{core,client,server}@2.0.0` | 1.1 | 2026-08-23 |
| Spring AI Examples | repo | 快照未刷新；核验为 Spring AI 2.0 对齐 | 1.1 | 2026-08-23 |
| LangChain4j | repo | 快照未刷新；按 release 正文分析至 1.19.0 | 1.1 | 2026-08-23 |

### 待办（未在本版本落地）

- **OpenAI Codex 深度核验**：+858 commits 且 release 正文为空，本轮判为"待核验"，下轮以 `update-source` 模式重新快照后判定。
- **建立 skill 变更的最小验证集**，消除"教了 gate 自己没有 gate"这一自我违反（见 `analysis/21-lab-design-rethink-2026-08.md` 第四节）。
- **例行 re-snapshot**：LangGraphJS、Hello-Agents、SkillOpt、mini-swe-agent，以及 Vercel AI / OpenAI Agents JS 的本地树。

## [2.1.0] - 2026-08-04

### 新增

- 新增 OpenAI《Harness engineering: leveraging Codex in an agent-first world》分析 `analysis/14-openai-harness-engineering.md` 与结构化摘要 `raw/docs/openai-harness-engineering.md`，研究 repository-as-system-of-record、agent legibility、反馈闭环、架构约束和高吞吐下的维护策略。
- 新增 Anthropic《Effective harnesses for long-running agents》与配套 `cwc-long-running-agents` 仓库联合分析 `analysis/15-anthropic-long-running-agent-harness.md`；文章摘要保存在 `raw/docs/anthropic-effective-harnesses-long-running-agents.md`，仓库以 shallow clone 固定到 commit `ad107a974bced5244f74dd283dbf2bfd3baee3a1`。
- 新增 OpenAI Codex 生产级 coding-agent harness 分析 `analysis/16-openai-codex-harness.md`，仓库快照固定到 commit `9873cba8ce6d14e650e12cdc0dddd159ae6613d7`，覆盖 core loop、context/instruction loading、sandbox/approval、exec/runtime 与 rollout/eval 边界。
- 新增 mini-swe-agent v2 极简 harness 分析 `analysis/17-mini-swe-agent.md`，仓库快照固定到 commit `a83fcae82d2a08f0ee0c688f9d137b3566c097f8`，研究 bash-only action interface、线性 trajectory、无状态命令执行和 benchmark-first baseline。

### 变更

- `skills/design-ai-agent/SKILL.md`：把 harness 从“五类组件清单”扩展为三层工程模型——单次运行时、跨 session continuity、仓库/组织反馈系统；增加 repository legibility、外部化进度、fresh-session 验证和 harness-vs-model 归因规则。
- `skills/test-ai-agents/SKILL.md`：补充 fresh-session / clean-environment 长任务测试、trajectory 可重放性、harness ablation，以及模型与 harness 联合报告要求。
- `skills/review-ai-agents/SKILL.md`：把 repository knowledge、可执行约束、环境自描述和垃圾回收纳入 coding-agent harness 审查面。
- `skills/build-ai-agents/references/source-map.md`：登记新增文章、仓库、固定 commit 和高价值阅读文件。
- `analysis/07-overall-agent-analysis.md`：把 harness 从“loop 外围机制”提升为覆盖运行时、连续性与组织反馈闭环的工程层，并纳入跨来源共识矩阵和形态选择光谱。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 3 个仓库、2 篇文章、4 个重点阅读块并更新 canonical metadata。
- `docs/index.html`：来源表新增 OpenAI harness 文章、Anthropic 长任务 harness、OpenAI Codex、mini-swe-agent 四行，footer 更新到 skill suite v2.1.0；`<style>` 与 `<script>` 未改动。
- `README.md`：当前资料集新增 harness 专题来源，并把版本说明更新到 2.1.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| OpenAI, Harness Engineering | article | 发布 2026-02-11 / 抓取 2026-08-04 | 1.0 | 2026-08-04 |
| Anthropic, Effective Harnesses for Long-Running Agents | article | 发布 2025-11-26 / 抓取 2026-08-04 | 1.0 | 2026-08-04 |
| Anthropic cwc-long-running-agents | repo | `ad107a974bced5244f74dd283dbf2bfd3baee3a1` | 1.0 | 2026-08-04 |
| OpenAI Codex | repo | `9873cba8ce6d14e650e12cdc0dddd159ae6613d7` | 1.0 | 2026-08-04 |
| mini-swe-agent | repo | `a83fcae82d2a08f0ee0c688f9d137b3566c097f8` | 1.0 | 2026-08-04 |

## [2.0.0] - 2026-06-14

### 新增

- 新增 Microsoft SkillOpt 来源分析 `analysis/13-skillopt.md`，并以 shallow clone 记录 `raw/repos/skillopt/`（commit `c1ac570d944ee7f83fc7c4273abfcb4bfdfea392`）。该来源把 skill 文档视为 frozen agent 的可训练外部状态，核心循环为 rollout → reflect → aggregate → select → update → gate，并强调 textual learning rate、held-out validation、slow/meta update、strong optimizer vs frozen target、SkillOpt-Sleep 的离线 replay / staged adoption。
- 新增 9 个 focused child skills：`design-ai-agent`、`design-agent-tools`、`build-mcp-capabilities`、`implement-ts-agents`、`implement-java-agents`、`review-ai-agents`、`secure-ai-agents`、`test-ai-agents`、`optimize-agent-skills`。
- 为 `build-ai-agents` suite 入口和所有 child skills 新增 `agents/openai.yaml` UI metadata。

### 变更

- `skills/build-ai-agents/SKILL.md` 从单体执行 skill 重构为 suite router，保留旧入口名并按任务路由到 focused child skills；`build / extend / review` 外新增 `optimize-skill` 模式。
- 原 `skills/build-ai-agents/references/*.md` 的主体内容迁入对应 child skills；`references/` 下仅保留 `source-map.md` 作为共享来源索引，避免重复维护。
- skill 版本字段从顶层 `version` 迁移到 `metadata.version`，使通用 `quick_validate.py` 能通过。`build-ai-agents` suite 当前版本为 2.0.0；`iterate-skill-lab` 更新到 1.0.2，并同步其版本字段说明。
- `analysis/07-overall-agent-analysis.md` 更新到分析版本 2.0，把 SkillOpt 纳入“skill / prompt 文本空间优化”维度，并把 `build-ai-agents` 的沉淀形态更新为复合 skill suite。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 SkillOpt 仓库行、Official Links 与重点阅读文件块，顶部更新时间改为 2026-06-14。
- `skills/build-ai-agents/references/source-map.md`：补充 SkillOpt 本地路径、commit、官方链接和高价值文件；本地 source root 改为仓库相对路径。
- `README.md`：说明 `build-ai-agents` 2.0.0 suite 结构、安装所有 child skills、SkillOpt 来源和 `metadata.version` 版本约定。
- `docs/index.html`：分析来源表新增 SkillOpt，安装说明改为复制整个 `skills/` suite，footer 更新到 skill suite v2.0.0；`<style>` 与 `<script>` 不应改动。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| SkillOpt (Microsoft) | repo | `c1ac570d944ee7f83fc7c4273abfcb4bfdfea392` | 1.0 | 2026-06-14 |

## iterate-skill-lab [1.0.2] - 2026-06-14

### 修复

- 将 `skills/iterate-skill-lab/SKILL.md` 的顶层 `version` 迁移为 `metadata.version`，并把自身流程中对 `build-ai-agents` 版本字段的说明同步为 `metadata.version`。

## [1.5.1] - 2026-06-05

### 文档（来源新鲜度审计 SEED-001）

- 执行 SEED-001 源新鲜度审计：13 个来源（9 仓库 + 3 文章 + 1 研究综述）全部可达，所有快照均在一个季度内（最早 2026-05-18，阈值 2026-03-05），无 stale-by-time。11 个来源相对快照有 upstream 漂移，但经对抗式核验仅 Vercel AI SDK 为实质性变更（v7 canary 的 `onFinish`→`onEnd` 重命名 + finalStep 聚合语义，PR 15245，命中已分析的 Agent/ToolLoopAgent/streamText 表面），已在 `analysis/SOURCE_INDEX.md` 标记待再分析；其余为补丁级/纯增量改动，不影响已分析模式。原先疑似的 Pi tool-allowlist 破坏性迁移经核验为误归（该变更在 v0.68.0，早于 v0.75.3 快照），v0.75.4–v0.78.1 漂移窗口仅增量。完整审计报告见 `.planning/freshness-reviews/2026-06-05-source-freshness-review.md`。
- `analysis/SOURCE_INDEX.md`：`更新时间` 改 2026-06-05，新增 `## 新鲜度审查` 小节记录本次 SEED-001 运行与逐来源结论；逐来源 `最后更新` 与 `来源版本` 维持各自分析快照不变（本次仅核验新鲜度，未再分析单个来源）。

### 变更（skill 优化 / SEED-001 措辞收口）

- `skills/design-agent-tools/SKILL.md`：reactive compaction 触发条件由厂商字符串 `prompt_too_long` 改为按行为命名（“provider 仍报上下文超长 / 长度超限错误”），`prompt_too_long` 降为括注示例，并提示按 provider 当前错误分类核对。
- `skills/test-ai-agents/SKILL.md`：模型层两类失败由 `max_tokens reached` / `prompt_too_long` 字面名改为按行为命名（“输出在 token 预算处被截断” / “输入超出上下文窗口”），注明字段/错误名按 provider 而异（如 `finish_reason`/`stop_reason` 值 vs 专用错误），字面名保留为示例。
- `skills/build-mcp-capabilities/SKILL.md`：MCP/A2A/ANP 的成熟度排名由“当前最高采纳/生态更弱”改为带日期的观测（“截至源快照…，实现前请复核”），保留“默认 MCP、按跨运行时/跨组织需要升级”的决策规则不变。

### 变更（分析层措辞收口）

- `analysis/07-overall-agent-analysis.md`：`综合结论` 与 `跨来源共识矩阵` 中 MCP/A2A/ANP 成熟度排名降级为带日期观测，保留“按谱系而非单点选”的决策规则；`分析版本` 1.4→1.5，`最后更新` 2026-06-05。
- `analysis/11-hello-agents.md`、`analysis/02-agent-framework-patterns.md`、`analysis/12-retrieval-strategy-vector-vs-agentic.md`：将随时间漂移的“现状”表述（A2A/ANP 早期、MCP SDK 主分支 v2 pre-alpha、ripgrep “事实标准”、查询扩展“约 10 倍”实测值）锚定到快照日期或降为带保留的观测；durable 决策规则与能力事实不变（这些文件的 `分析版本`/`最后更新` 维持其分析快照不变，仅措辞收口、行内自带日期）。

### 待办（不在本次落地）

- 对 Vercel AI SDK 执行再分析并 re-snapshot 到当前 v7 canary commit（`onFinish`→`onEnd`、`allowSystemInMessages`、streaming-UI helpers 弃用 `fullStream`/`toUIMessageStream`/`toTextStreamResponse`）。
- 例行刷新（均为纯增量，无需再分析）：Pi v0.78.1、OpenAI Agents JS v0.11.6、LangGraphJS 1.3.5、LangChain4j 1.15.1、Learn Claude Code / Hello-Agents 最新 commit，可在下次常规同步时 re-snapshot。
- SEED-001 维持 dormant（递归触发型看护），已记录 `last_reviewed: 2026-06-05`，下个季度或下次 provider-API 集成里程碑重新触发。

## [1.5.0] - 2026-06-02

### 新增

- 新增专题研究综述分析 `analysis/12-retrieval-strategy-vector-vs-agentic.md`：向量 RAG vs Agentic 工具检索 vs 长上下文的检索选型，基于 2024–2026 多来源 web 研究（约 55 个源 + 对抗式核验）综合。覆盖"RAG 已死是伪命题 / 向量库被商品化为既有数据库内置功能"、agentic 检索的力量（模型坚持性）与代价（input token 近二次增长）、检索失败的静默性、混合（BM25+向量）+重排为何是生产标准、Anthropic Contextual Retrieval / DeepMind LIMIT / NoLiMa 等分层可信度证据，以及"按语料规模分层 + 按查询类型路由"的决策框架；并含 grep 类工具（ripgrep / ugrep / ast-grep / ripgrep-all）的具体工具层盘点。这是本仓库首篇"多来源研究综述"型来源（区别于单仓库 / 单文章）。
- 新增研究快照 `raw/docs/retrieval-strategy-research.md`（多来源 paraphrased digest，含源 URL 与"实测 / 厂商自报 / 营销"的可靠度分层标注）。

### 变更（skill 优化）

- `SKILL.md`：`Architecture Rules` 新增一条检索默认——文档检索默认 agentic 工具检索 / 小语料全量上下文，仅当语料规模、语义 / 跨文档查询、延迟或多租户隔离逼迫时才升级到 hybrid 向量+重排（且先用现有数据库如 pgvector），不默认自建向量库。
- `skills/design-agent-tools/SKILL.md`：在 `Long Document Handling` 之后新增 `Retrieval Strategy` 小节——按语料规模分层 + 按查询类型路由的选型闸、升级信号（先 pgvector 后专用库）、agentic 检索两条标配（查询扩展治同义漏检 / 精确匹配通道治编号·条款·型号·否定词的静默漏检）、检索失败的静默性提示，以及 grep 工具层背景。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 `Research Syntheses` 小节与检索策略综述行、对应 `重点阅读文件` 块与 Official Links 条目；`更新时间` 改 2026-06-02。
- `analysis/07-overall-agent-analysis.md`：`跨来源共识矩阵` 新增 `文档检索策略` 行；`综合结论` 增"检索按规模与查询类型分层"一条；`后续可分析方向` 补 Anthropic Contextual Retrieval、DeepMind LIMIT / NoLiMa 等候选；元数据与"对 skill 的总体指导"更新到 1.5.0。
- `docs/index.html`：分析来源表新增"检索策略研究综述"行，section-note 与 footer 更新到 skill 1.5.0；`<style>` 与 `<script>` 未触碰。
- `README.md`：当前资料集新增研究综述说明，版本说明更新到 1.5.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| 检索策略研究综述（向量 vs Agentic） | research-synthesis | 综合 2024–2026 多源 / 抓取 2026-06-02 | 1.0 | 2026-06-02 |

## [1.4.0] - 2026-05-22

### 新增

- 新增教学型仓库分析 `analysis/11-hello-agents.md`：Datawhale《Hello-Agents》16 章 / 5 部分系统化中文教程，覆盖智能体基础理论、经典范式（ReAct / Plan-and-Solve / Reflection）、低代码平台对比、主流框架编目（AutoGen / AgentScope / CAMEL / LangGraph）、HelloAgents 自建框架、记忆与 RAG、上下文工程 GSSC 流水线、智能体通信协议（MCP / A2A / ANP）、Agentic-RL（SFT + GRPO 全流程）、智能体性能评估（BFCL / GAIA）以及三个综合案例（旅行助手 / TODO 驱动深度研究 / 赛博小镇）。
- 新增源仓库快照 `raw/repos/hello-agents/`（commit `66401d9f54d989f3d35b32ae411faf0fb472164f`）作为 gitlink。

### 变更（skill 优化）

- `SKILL.md`：`Build Workflow` 第 5 条把 eval baseline 的来源从两篇文章扩展为"权威指南 + Hello-Agents 第 12 章给出的 BFCL / GAIA 基准"；新增可选的 training-time agency 提示——当任务在 inference-time 推理 / 工具 / 上下文工程穷尽后仍有缺口时再考虑 SFT/RL 微调，避免本末倒置（见 `analysis/11-hello-agents.md`）。
- `skills/design-ai-agent/SKILL.md`：`Workflow vs Agent` 小节强化"流程驱动平台（Coze/Dify/n8n）与 AI Native Agent 的差异"，并把"自建最小框架以理解原理"作为团队建立共同语言的一条可选路径。
- `skills/design-agent-tools/SKILL.md`：`Compaction Strategy` 与 `Memory Pipeline` 末尾并列引用 Hello-Agents 的 GSSC（Gathering → Structuring → Scoring → Compression）四步与四级记忆划分（工作 / 短期 / 长期 / 永久），作为对 cheap-first 与 selection/extraction/consolidation 的互补视角。
- `skills/build-mcp-capabilities/SKILL.md`：协议选择部分补充"MCP 之外还有 A2A（agent 直连）与 ANP（去中心化服务发现），按互操作性 / 灵活性 / 性能取舍"，并引用 Hello-Agents 第 10 章作为协议谱系的参考来源。
- `skills/test-ai-agents/SKILL.md`：`Eval Strategy` 把 BFCL（工具调用准确率）与 GAIA（端到端通用任务）写成默认可参考的基准命名，提示"自建评测前先看是否已有可对齐的公开基准"。
- `skills/build-ai-agents/references/source-map.md`：补记 hello-agents 仓库与本地路径，并说明它在教学型来源中扮演"广覆盖、含训练侧（Agentic-RL）"的角色，与 learn-claude-code 的"窄而深、harness 机制穷举"形成互补。

### 文档

- `analysis/SOURCE_INDEX.md`：新增 hello-agents 行（repos 表）、重点阅读文件块与 Official Links 条目。
- `analysis/07-overall-agent-analysis.md`：把 hello-agents 纳入跨来源共识矩阵；`形态选择光谱` 末行补充"训练侧 agency（SFT + RL）"作为推理侧穷尽后的兜底；`后续可分析方向` 移除已落地候选并新增 ReAct 原论文、Reflexion、Toolformer、Anthropic Agent SDK 等候选。
- `docs/index.html`：分析来源表新增 hello-agents 行，footer 更新到 skill 1.4.0；`<style>` 与 `<script>` 未触碰。
- `README.md`：当前资料集新增 hello-agents 条目，版本说明更新到 1.4.0。

### 来源版本与最后更新

| 来源 | 类型 | 来源版本 | 分析版本 | 最后更新 |
| --- | --- | --- | --- | --- |
| Hello-Agents (Datawhale) | repo | `66401d9` | 1.0 | 2026-05-22 |

## [1.3.0] - 2026-05-21

### 新增

- 新增教学型仓库分析 `analysis/10-learn-claude-code.md`：shareAI-lab《Learn Claude Code》20 课渐进式 harness 教程。覆盖 harness vs agent 的本体论框架、agent loop 一以贯之的演进、四层 context compaction 管线、memory 三段流程（selection/extraction/consolidation）、permission/hooks/skill loading/system prompt assembly/error recovery、task graph、background tasks、cron、worktree-isolated agent teams、autonomous claim-from-board 与 MCP 接入。
- 新增源仓库快照 `raw/repos/learn-claude-code/`（commit `1baf1aca5af439694cb3a1772c0b1ab44b482a01`）作为 gitlink。

### 变更（skill 优化）

- `SKILL.md`：Architecture Rules 首条改写为"区分 agent 与 harness"——agent 的能力来自模型训练，工程师的工作是把 harness 建好；并把 harness 内含的工具/知识/上下文/权限/观测显式列出。
- `skills/design-ai-agent/SKILL.md`：新增 `Agent vs Harness Boundary` 小节，把 harness engineering 的工程职责（tools / knowledge / context / permissions / trajectory）作为 skill 的工程心智模型；`Loop Design` 增补 hook 扩展点（pre/post tool）作为不改主循环的扩展机制。
- `skills/design-agent-tools/SKILL.md`：`Compaction Strategy` 扩写为"cheap-first → expensive-last 多层管线"：snip → micro-replace → tool-result budget → 显式 LLM 摘要 → reactive 应急；`Long Document Handling` 加入 tool-result 持久化与句柄引用思路；新增 memory 三段流程（selection / extraction / consolidation）作为 memory 写入与回读的设计骨架。
- `skills/secure-ai-agents/SKILL.md`：补充"按任务隔离工作目录（worktree / sandbox dir）"作为多 agent 并行执行与不可逆动作的隔离手段；补充"trajectory 是 PII/secrets 的扩散面，输出与日志按相同准则脱敏"。
- `skills/test-ai-agents/SKILL.md`：补充长任务 / 后台执行 / cron 触发的观测要点（运行 id、注入回执、超时与重试上下限），并把"失败分级 + 退避 + fallback 模型"加入错误恢复模式。
- `skills/build-ai-agents/references/source-map.md`：补记 learn-claude-code 仓库与本地路径，并把"教学型来源（教学化简实现，可直读 200–1000 行）"与生产框架来源区分清楚。

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
- `skills/design-agent-tools/SKILL.md`：把 tool 设计从“schema/description”扩展为“面向 agent 的工具产品设计”：高价值工具选择、命名空间、响应格式、token 预算、错误响应与真实任务评测。
- `skills/design-ai-agent/SKILL.md`：补充用例筛选、单 agent 优先、何时拆分 multi-agent、manager vs handoff 的适用边界。
- `skills/secure-ai-agents/SKILL.md`：补充 layered guardrails、tool risk rating、失败阈值与高风险动作的人类介入策略。

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
- `skills/design-ai-agent/SKILL.md`：新增 `Workflow vs Agent` 小节；决策表新增“开放式任务 / 步骤不可预测 / 工具可信 → 自治循环”行；`Loop Design` 增加 environment feedback 与显式停止条件。
- `skills/review-ai-agents/SKILL.md`：强化 `Over-Engineered Agent`，明确“在固定 workflow 更可靠 / 更透明时却做自治 agent”。
- `skills/design-agent-tools/SKILL.md`：Tool Description Rubric 增加 ACI 准则（把 agent-computer interface 当公共 API 一样设计）。
- `skills/build-ai-agents/references/source-map.md`：补充文章快照与抓取日期说明。

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
