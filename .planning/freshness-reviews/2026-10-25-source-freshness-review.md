# 来源新鲜度审查报告 — 2026-10-25（SEED-001 第三次审查）

> 审查日期：2026-10-25 ｜ 触发：SEED-001（快照超过一个季度 + 新模型代际发布；本季度无上游规范修订）｜ 范围：large（seed 预估 small，连续第二次失效）
> 方法：`git ls-remote` 漂移比对 + npm dist-tags + **仅读稳定版** release 正文（过滤 `prerelease`）+ 对**全部**来源（含判为非实质者）逐条核对引用路径 + 文章正文与 Wayback 存档逐段对比 ｜ 关联：`[[SEED-001-source-freshness-review]]`、`CHANGELOG.md` [2.3.0]、`analysis/SOURCE_INDEX.md` `## 新鲜度审查`

## 概述

本次审查覆盖 **14 个代码仓库 + 6 篇文章 + 1 份协议规范 + 1 份研究综述**，外加 2026-09-04 一次中断迭代留下的 **3 份未提交草稿**（`analysis/22..24` 及其快照）。

- **14 个仓库里 13 个漂移，11 个命中已分析表面**（2026-06：1/13；2026-08：5/14）。实质变更从"偶发"变成了"常态"，节奏在加快。
- 本季度**没有**上游规范修订（MCP 仍为 2026-07-28），驱动因素换成了两类：**大版本线**（Pi 跨入 1.x 并把持久化层拆出核心；DeepSeek Harness 从 0.1 到 0.2；MCP TS SDK 2.x 走到 2.4）与**新模型代际**（Claude 5.x、GPT-6 系列、Gemini 4 等在 9–10 月集中发布）。
- 本仓库**自身记录**的硬错误比上次更多，且有三类是新的：失效引用路径（其中 4 条在上一轮就已失效却被漏检）、三处 commit 记录互相矛盾、一条从第一次分析起就写错的结论（learn-claude-code s08 压缩顺序）。
- 9 月草稿核实后有三处事实错误需要更正（见下）。

## 方法

在 2026-08-23 的方法上新增五条，全部源于本次发现的漏检：

1. **只读稳定版 release 正文**。上一轮记录"Codex 的 release 正文为空、无法判定"，实际上只是 alpha 预发布版正文为空，稳定版（如 0.147.0）有 2.5 万字符以上的说明。判定时过滤 `prerelease==false`。
2. **对所有来源核对引用路径，包括判为"非实质"的来源**。上一轮漏掉的 4 条失效路径（MCP TS SDK 3 条、SkillOpt 1 条）都在 6 月就已失效。
3. **commit 三处记录机械一致**。gitlink、`SOURCE_INDEX.md` 的 `来源版本` 首个 hash、`source-map.md` 的 Local Repositories 表现由 `scripts/check-lab-invariants.sh` 的 C7 检查。
4. **文章逐段对比 Wayback 存档**，不信页面的修改时间。Anthropic 站点在 2026-10-18 批量重存了大多数文章（修改时间集中在那一天），正文并无变化；而真正的变化（Building Effective Agents 在 8 月新加的编者注）在上一轮的人工核对里被漏掉了。openai.com 对 curl 返回 403，改用 RSS + Wayback。
5. **版本号不是事实**。LangChain4j 1.19.1 是误发布（数值低于 1.19.2，却包含 1.20.0 之后的代码）；Vercel AI SDK 7.0.78–7.0.153 全部以 patch 发布，其中包含新 finish reason 等破坏 exhaustive switch 的变化；MCP TS SDK 的 `server-legacy@2.x` 实为冻结的 v1 代码。判断变更只读 release 正文与 CHANGELOG。

## 逐来源结论

### 代码仓库

| 来源 | 记录快照 | 现状 | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| **Pi** | `a69bef78` / v0.84.x | `d5b3de22` / v1.4.0（2026-10-21）| **实质（重大）** | re-snapshot；`analysis/01` → 2.0（1.0 把持久化层拆出核心，旧分析描述的 API 已不存在）|
| **OpenAI Agents JS** | `629d35af` / 按 release 分析至 v0.17.0 | `be4f1f9a` / 0.21.0 | **实质（增量）** | re-snapshot；`analysis/02` → 1.2 |
| **Vercel AI SDK** | `aa5a1e53`（v7 canary 期）/ 核验至 7.0.77 | `6147ecd9` / `ai@7.0.153` | **实质** | re-snapshot；`analysis/02` → 1.2（补记此前漏掉的 `@ai-sdk/harness` 等）|
| **LangGraphJS** | `bd72a897` / 1.x | `c6675bf0` / 1.5.2 | **实质（低）** | re-snapshot；`analysis/02` → 1.2；文档迁至 docs.langchain.com |
| **MCP TypeScript SDK** | `22595b96`（早于 2026-07-28 实现）| `951fe560` / scoped 2.4.0、单体 1.32.2 | **实质** | re-snapshot；`analysis/02` → 1.2；修 3 条失效路径 |
| **Spring AI Examples**（含框架）| `2a6088db` | `e499007e`；框架 2.0.2 GA / 2.1.0-RC1 | **实质（RC）** | re-snapshot；`analysis/03` → 1.2（2.1 GA 后复核）|
| **LangChain4j** | `6185599e` / 按 release 分析至 1.19.0 | 1.22.0 = `7948fba8` | **实质** | re-snapshot；`analysis/03` → 1.2 |
| **Learn Claude Code** | 记录 `f9e8b280`，**gitlink 实为 `1baf1aca`** | `ce8f9f18` | **实质（窄）** | re-snapshot；`analysis/10` → 1.2（s08 顺序更正）|
| Hello-Agents | `66401d9f` | `36f583c2` / V1.0.3 | 漂移-非实质 | 仅记录；16/16 路径有效 |
| **SkillOpt** | `c1ac570d` | `84b36cd5` / 仍为 v0.2.0 | **实质（Sleep）** | re-snapshot；`analysis/13` → 1.1；修 1 条失效路径 |
| Anthropic cwc-long-running-agents | `ad107a97` | `ad107a97` | 零漂移 | 无 |
| **OpenAI Codex** | `9873cba8`（≈0.147.0-alpha.7）| `970111f6` / 稳定版 rust-v0.164.0 | **实质**（上轮"待核验"已消费）| re-snapshot；`analysis/16` → 1.1；8/8 路径有效 |
| mini-swe-agent | `a83fcae8` | `04d809ce` / 仍为 v2.4.6 | 漂移-非实质 | 仅记录；观察未合并的 #1011（受控本地 resume）|
| **DeepSeek Harness** | `b150a551` / `dsh` 0.1.1-rc.2 | `dsh-v0.2.1-rc.3` = `1f81c047` | **实质（重大）** | re-snapshot；`analysis/18` → 1.1；修 3 条失效路径 |

### 文章 / 规范 / 综述

| 来源 | 现状 | 状态 | 处置 |
| --- | --- | --- | --- |
| **Anthropic, Building Effective Agents** | 正文未变，但 2026-08-05 至 08-11 之间加了一条**编者注**（工具生态自 2024-12 已大变，并把读者指向托管产品）| **更新（上轮漏检）** | 记录事实；刷新抓取日期；编者注所指的托管产品不在本仓库范围 |
| Anthropic, Writing Effective Tools / Effective Harnesses / Harness Design | 正文未变（Wayback 逐段对比）；URL 由 `/engineering/` 308 到 `/research/` | Fresh | 更新 canonical URL |
| OpenAI, Practical Guide / Harness Engineering | 正文未变（Wayback）| Fresh | — |
| MCP Specification | 2026-07-28 仍为最新；草案只有编辑性修改；SEP-2640（Skills 扩展）已 Final | Fresh（核心）| 规范行记"2026-10-25 复核"；Skills 扩展进 skill 指导 |
| 检索策略研究综述 | 结论未失效 | Fresh | — |
| 9 月草稿：Managed Agents | 逐条核实，3 处小出入 | 已更正 | 见下 |
| 9 月草稿：Claude Code auto mode | 1 处**理解反了**，缺作者与若干细节 | 已更正 | 见下 |
| 9 月草稿：Codex as a platform | 日期可核实（2026-08-19）；ARC-AGI-3 归因有误 | 已更正 | 见下 |

## 关键发现

### 1. Pi 1.0 把持久化执行拆出了核心——本仓库描述的是一个已删除的 API

`@earendil-works/pi-agent-core` 1.0.0 移除了实验性的 harness（会话与存储、持久化运行时、压缩、skills、提示词模板），核心只剩 `Agent`、循环与代理流；持久化执行移到新的实验性包 `pi-durable`，且编码 agent 本身**不依赖**它。`analysis/01` 1.1 的整节"持久化执行 harness"与 3 条引用路径因此失效。新模型里最值得记的一条：**重放授权只能被否决、不能被升级**——恢复时一个工具只有在"存储时的声明"与"当前声明"都说可安全重放时才会重跑。

### 2. 五个来源独立收敛到"上下文只追加"——并第一次变成某家 API 的正确性约束

- Codex 的增量工具目录：完整目录只发一次，之后只追加新增/变更定义，移除以开发者通知表达（2026-10-19 起默认）。
- DeepSeek Harness 0.2：system prompt 作为日志条目写入会话，prompt 与工具更新**追加在已缓存的历史之后**而不是重写前缀，并用 "request series" 事件显式标出缓存断点。
- Pi 0.86–0.87：system prompt 与工具声明进入 transcript；`ContextEditEntry` 以追加方式编辑模型上下文。
- Strands 设计文档 0021：一次会话内工具目录固定，只追加。
- Claude API：thinking block 的签名记录了产生它时的完整前缀（顶层 system、tools 集合、此前所有消息）；对 2026-08-31 及之后创建的账户，重放一个前缀被改过的 block 会**返回 400**。官方给出的替代全是追加形式（中途 `role: "system"` 消息、工具增删块、单轮提醒、服务端压缩）。

本仓库此前把"前缀稳定"定性为**成本项**。现在它至少在一家提供方那里是**正确性约束**，而且在不依赖任何提供方的本地 harness 里已经是共识设计。

### 3. 三个本地 harness 独立长出了"模型审批层"

Claude Code auto mode、Codex Guardian、DeepSeek Harness 0.2 的实验性 Auto review：都是在机械边界之上加一层由模型做的审批、带拒绝预算熔断、把人留给升级。DeepSeek 文档自陈的缺口——**程序化工具调用里的直接副作用绕过审查**——给出了这一层最容易漏的地方：模型审批必须覆盖每一条有副作用的路径。三家在判定上下文上并不一致：auto mode 只给判定者看用户消息与裸工具调用（并有自家消融支持），Guardian 给判定者看带来源标注的完整记录、可在只读子会话里调查（未公布误判率）；共同的硬约束是只有用户或开发者来源的内容能构成授权、审查失败一律按拒绝处理。

### 4. 本仓库的一条规则被更细的机制取代

`design-agent-tools` 写着"code mode 与原生工具调用在同一轮必须互斥"（来自 DeepSeek）。Vercel `experimental_toolCallers`、OpenAI Agents JS `allowedCallers`、Pi 的 `exposure`/callers、以及 Claude API 程序化工具调用的 `allowed_callers`，都改成了**按工具声明"谁可以调用我"**。模式级互斥是这条规则最粗的一种实现，而非唯一正确的实现。更要紧的是，skill 里给出的理由"否则模型会在两条路径间摇摆"是本仓库自己的推断：DeepSeek 原文没有这句话，它后来删掉混合模式的理由是接口重复。

### 5. 本仓库曾称赞的几个机制被上游删掉了

DeepSeek Harness 删除了整个运行时不变量包（先把 209 个"解释为何为空"的不变量占位删到 39 个，再整体移除，覆盖改由测试承担）、删除了自修改工具集、把 Teams 的持久化邮箱换成了直接投递、把"每个非平凡改动都要写 note"放宽为"只记代码与文档说明不了的长期理由"；Pi 删除了 lanes。`test-ai-agents` 推荐的"不变量 + 解释为空"形式正是被删掉的那一种。教训不是"上游变了所以我们跟着变"，而是：**一条检查若只是读回同一段代码刚写下的东西，它是测试，不是不变量**。

### 6. 本仓库自己的四处错误

- **s08 压缩顺序从第一次分析起就写错了**：上游调用顺序一直是先落盘，本仓库照代码注释的层号写成了"截断 → 占位 → 落盘"，并把错误顺序带进了 `design-agent-tools`。
- **learn-claude-code 的 commit 三处不一致**：2026-08-23 的 `SOURCE_INDEX.md` 写着已 re-snapshot 到 `f9e8b280`，gitlink 与 `source-map.md` 仍是最初的 `1baf1aca`——而在 `1baf1aca` 上，被引用的 s10–s17 路径根本不存在。DeepSeek Harness 则从未进入 `source-map.md` 的本地仓库表。
- **9 月草稿**：Codex 文章的日期其实可以在页面上核实（2026-08-19）；ARC-AGI-3 的三倍提升被归因于 harness 的工具与审批，实际来自两个上下文管理设置（保留推理与压缩）；auto mode 草稿把"分类器找到看似授权的证据就停下"这一**失败模式**写成了"不把一次既往审批当作模式"的设计规则。
- **来源分析里的误读**（各分析本轮已就地更正）：`analysis/18` 1.0 把 DeepSeek 工具管线里的 guard 画在审批之前，上游顺序是"审批 → guard 作为最终否决"；`analysis/07` 与 `analysis/21` 把 DeepSeek 的 goal domain 当作"完成判定离开执行方"的证据，而它自陈没有独立评估者；`analysis/01` 1.1 把 Pi 的"预铸 id"读成了可向外部系统查询的幂等键，它其实只是 Pi 自己记录的预留槽位；`analysis/22` 草稿的 Managed Agents 摘要有三处措辞超出原文。
- **上一轮审查本身**：Codex release 正文"为空"的判断、4 条漏检的失效路径、Building Effective Agents 的编者注。

### 7. 新模型代际：厂商在亲手删除补偿组件

8 月 23 日以来的主要发布（日期均以厂商公告或 API changelog 为准）：Claude Fable 5.1（09-01）、GPT-6 Astra（09-03）、Claude Opus 5.5 与 GPT-6 Sol/Luna（09-22）、Claude Sonnet 5.5（09-28）、GPT-6.1 Sol（09-29）、Gemini 4 Argon（09-30 预览，10-13 GA）、Claude Haiku 5.5（10-07），以及 DeepSeek-V4.1-Flash、Kimi K3.1 Pro 等开源权重模型。这触发了 SEED-001 的"新模型代际"条件。

同一时期，厂商自己的 harness 在删除"补偿模型弱点"的组件，且都给出了理由：Claude Code 为 Claude 5 代删掉了 80% 以上的系统提示词，编码评测无可测损失；Claude Agent SDK 在 Opus 4.8 / Sonnet 5 / Fable 5 及更新模型上从默认工具集里移除了 todo 工具；Codex 把 `update_plan` 改为默认关闭，并删掉了向用户提示"多次压缩会降低准确率"的警告；Cursor 报告删减约 66% 的提示词并做了 A/B；OpenAI 针对 GPT-6 建议按条消融 AGENTS.md。另一方面，研究给出的图景比"随模型变强单调贬值"复杂：好几类组件的价值随模型强度呈**倒 U 形**，对中档模型最有用。这一组证据由新的研究综述 `analysis/25-harness-shelf-life-research.md` 整理，并据此第一次检验了 `analysis/21-lab-design-rethink-2026-08.md` 的可证伪条件（见该文 1.1）。

本仓库没有自己的验证集，因此这次"复核"只能是**依据厂商与研究证据的案头复核**，不是本仓库自己跑出的消融。这一点在 `analysis/21` 里继续记为未消除的自我违反。

## 方法改进（并入下次审查）

1. 路径核对要对着**上游 HEAD 机械地跑**，不能靠人工逐条看——本次的 4 条漏检就是人工核对的产物。（本轮未落地；记为待办。）
2. release 正文只读稳定版。
3. 文章用 Wayback 逐段对比，不看修改时间。
4. 一次迭代若跨会话中断，下一次开始时先检查未提交的草稿，并把它们当作**未核实**材料重新核对（本次 9 月草稿有三处事实错误）。已写入 `iterate-skill-lab`。
5. 版本号不可信：读 release 正文与 CHANGELOG。

## 本次落地

见 `CHANGELOG.md` [2.3.0]。要点：11 个仓库 re-snapshot；7 篇分析推进（01→2.0、02→1.2、03→1.2、10→1.2、13→1.1、16→1.1、18→1.1）；9 月 3 份草稿更正后入库（22/23/24）；4 篇新分析（25 保质期研究综述、26 耐久规则的生产证据、27 Google ADK、28 Claude Agent SDK，后两者只研究本地运行部分）；`analysis/21` 第一次可证伪性复核；检查脚本新增 C7；全部失效路径修复；commit 三处记录统一。

## 待办（不在本次落地）

1. **上游路径的机械核对脚本**：对 `source-map.md` 的每条高价值文件路径，在记录的 commit 上调用 `gh api .../contents/<path>?ref=<commit>`。这是 `analysis/21` 可证伪条件四（"失效路径再次出现"）触发后所要求的结构性修复。
2. **建立 skill 变更的最小验证集**（`analysis/21` 第四节违反一，仍未消除）。本轮的研究证据（SkillsBench、AGENTS.md 评测等）显示 skill 与上下文文件的改动可能中性甚至有害，使这条待办更紧迫。
3. Spring AI 2.1 GA 后复核 `analysis/03`；MCP TS SDK v3 发布时复核 `server-legacy` 的移除。
4. 观察：mini-swe-agent #1011（受控本地 resume，若合并会改变其"无状态线性轨迹"基线）；MCP SEP-2848（经 Tasks 的异步审批）、SEP-2643（结构化授权拒绝）、SEP-2793（工具风险元数据）。

## SEED-001 状态

**维持 dormant**。本次消费的触发是"快照超过一个季度"与"新模型代际发布"。seed 的 `scope: small` 估计**连续第二次失效**（上次 medium，这次 large），原因不是偶然：上游的发布节奏与本仓库的来源数量都在增长。本次把 seed 的 `scope` 改为 medium，并在 Review Log 里记下"大版本季度或模型代际季度为 large"。
