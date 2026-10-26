# Harness 保质期研究综述快照：组件价值随模型强度的变化、固定模型上的 harness 效应、测量噪声底线

> **来源类型**：多来源研究综合（非单一文章）：arXiv 论文 33 篇 + 厂商一手文章 / 文档 / changelog / PR / 源码 20 项（其中 C7 的正文未能核验）。
> **综合窗口**：来源发布于 2025-06-12（Cognition《Don't Build Multi-Agents》）至 2026-10-23（本地 Codex 检出提交）；主体集中在 2026-02 至 2026-10。
> **抓取/综合日期**：2026-10-25。
> **抓取方式**：arXiv 读摘要页（取 v1 日期与版本历史）与 HTML 全文，2608.08654、2608.06113 无 HTML、读 PDF 文本；数字回到正文表格逐条核对，标"（正文）"者不在摘要里。厂商页面用 curl（浏览器 UA）/ WebFetch / RSS / npm 元数据；GitHub 用 `gh api` 并记 commit。上一轮调研笔记只作线索，与一手来源不符处按一手来源改正，并在条目内标"线索更正"；综合收尾时网络中断，未完成的部分在原位标"待核验"。
> **可靠度分级**：**A** = 受控实验且经同行评审，或多模型受控预印本并公开代码；**B** = 受控预印本未公开代码，或单一团队 / 单模型 / 单任务；**C** = 厂商自报（关于自家产品的一手博客、文档、changelog、PR、源码）。
> **重要声明**：本文件是对多个来源的**转述式结构化摘要，不是原文镜像**；短引只在措辞关键处使用，数字以原文为准。本文件只整理证据、不下结论；解读与对 skill 的影响由维护者另写为第 25 号分析。

本快照服务于一个问题：**哪些 harness 组件随模型变强而贬值、哪些反而升值？固定模型时 harness 效应有多大？最少要怎样的测量协议才能把真实变化与噪声分开？** 被检验的仓库论点见 `analysis/21-lab-design-rethink-2026-08.md` 的易腐 / 耐久表：补模型能力缺口的组件是带日期的假设、会过期；管授权、证据、副作用与成本的组件是耐久的。仓库已有的同类一手证据：`analysis/19-anthropic-harness-design-long-running-apps.md`（Opus 4.5 删 context reset、Opus 4.6 删 sprint；评估器的性价比取决于任务难度相对模型能力的位置）与 `analysis/22-anthropic-managed-agents.md`（context reset 成为死重），此处不重复。

---

## 来源清单

arXiv 条目一律为 `https://arxiv.org/abs/<ID>`，日期取 v1（ID 月份与 v1 日期不一致时以 v1 为准）。

- **A 同模型不同 harness**：2602.09540、2603.28052、2607.22585、2608.08654、2609.11999、2608.11386、2512.24601、2508.21433、2607.03691；QwenLM/qwen-code `docs/evaluation.md`（https://github.com/QwenLM/qwen-code/blob/main/docs/evaluation.md ）；OpenAI《How enabling two settings tripled our scores on the ARC-AGI-3 benchmark》（https://openai.com/index/how-two-settings-tripled-our-arc-agi-3-scores ）。
- **B 组件价值 × 模型强度**：2609.20804、2606.00408、2605.30621、2512.08296、2610.28802、2605.08741、2608.06113、2610.05640。
- **C 厂商重做消融**：Anthropic《The new rules of context engineering for Claude 5 generation models》https://claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/ ；《Effective context engineering for AI agents》https://www.anthropic.com/research/effective-context-engineering-for-ai-agents ；《An update on recent Claude Code quality reports》https://www.anthropic.com/research/april-23-postmortem ；Claude Agent SDK changelog https://github.com/anthropics/claude-agent-sdk-typescript/blob/main/CHANGELOG.md ；提示词文档 https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices （及同目录 `prompting-claude-opus-5`、`prompting-claude-fable-5`）；《Building agents: When to fold subagents into your main agent loop》https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop ；Cognition《Multi-Agents: What's Actually Working》https://cognition.com/blog/multi-agents-working 与《Don't Build Multi-Agents》https://cognition.com/blog/dont-build-multi-agents ；OpenAI Developers《Rethinking skills and prompts for GPT-6 Astra》https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra 与《Maintaining software with the GPT-6 family》https://developers.openai.com/blog/maintaining-software-with-the-gpt-6-family ；openai/codex PR #41744、#55355（https://github.com/openai/codex/pull/41744 、https://github.com/openai/codex/pull/55355 ）；Cursor《Improved token efficiency for longer agent runs》https://cursor.com/blog/improved-token-efficiency ；Replit《Free the models: Harness design at the frontier》https://replit.com/blog/free-the-models ；Amp《Amp, Rebuilt》https://ampcode.com/news/neo ；OpenAI Cookbook《Codex Prompting Guide》https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide ；langchain-ai/deepagents（https://github.com/langchain-ai/deepagents ）；mastra-ai/mastra（https://github.com/mastra-ai/mastra ）。
- **D Skills 与上下文文件**：2602.12670、2602.11988、2608.14036、2610.04832、2610.08875、2609.09233、2606.15017。
- **E 自动优化的有效性**：2607.12227、2610.22466、2604.25850、2607.13083；锚点 2510.04618（ACE）、2507.19457（GEPA）。
- **F 噪声底线**：2602.07150、2510.11977、2610.30499；Anthropic《Quantifying infrastructure noise in agentic coding evals》https://www.anthropic.com/research/infrastructure-noise ；《Demystifying evals for AI agents》https://www.anthropic.com/research/demystifying-evals-for-ai-agents 。
- 说明：Anthropic 工程博客的 `/engineering/<slug>` 旧地址现跳转到 `/research/<slug>`。

## A. 同一模型、不同 harness：效应有多大

### A1 2602.09540《SWE-Bench Mobile: Can Large Language Model Agents Develop Industry-Level Mobile Applications?》
- 元信息：多伦多大学、小红书、Coolwei AI Lab、UIUC、UC Berkeley ｜ v1 2026-02-10 ｜ https://arxiv.org/abs/2602.09540 ｜ 数据不公开（托管评测，防污染），提交工具包公开 ｜ 级 B（私有数据、基本单次运行）
- 设置：Cursor v2.3、Codex CLI v0.77.0、Claude Code v2.1.37、OpenCode v1.1.44 × Opus 4.5 / Sonnet 4.5 / Haiku、GLM 4.6/4.7、GPT 5/5.1/5.2、Gemini 3 Pro，共 22 个配置；一个约 50 万行的 iOS 代码库、50 个任务、449 个测试（测试对 diff 文本做模式匹配，不编译不运行）；只有两个配置复跑。
- 数字：最好的配置任务成功率也只有 12%。"同一模型跨 agent 差 6 倍"（正文）= Opus 4.5 在 Cursor 12% vs OpenCode 2%，即 6/50 vs 1/50；Sonnet 4.5 为 12/10/10/4。复跑：Claude Code + Opus 三次 6% / 8% / 6%，主表报的是最高的 8%。
- 线索更正：①6× 是单次运行下 5 道题的差（本综述按 Fisher 检验算 p≈0.11，非原文）；②"简单的 Defensive Programming prompt 比复杂 prompt 好 7.4%"实为相对 **Baseline** prompt 的**测试通过率** +7.4 pp，任务成功率不变，且只在 Claude Code + GLM-4.6 一个配置上测；③"商业 agent 一贯优于开源"被其自身 GPT-5.1 行反驳（OpenCode 6%，最好）。
- 作者局限：单一代码库；测试不执行代码；prompt 消融只有一个配置；50 题。

### A2 2603.28052《Meta-Harness: End-to-End Optimization of Model Harnesses》
- 元信息：Stanford（Y. Lee、Nair、Q. Zhang、Finn）、KRAFTON（Kangwook Lee）、MIT（Khattab）｜ v1 2026-03-30 ｜ https://arxiv.org/abs/2603.28052 ｜ 代码：正文链接 stanford-iris-lab/meta-harness-tbench2-artifact（另有未在文中链接的 stanford-iris-lab/meta-harness）｜ COLM 2026（仅见于项目页 BibTeX）｜ 级 A（TB2 子结论按 B 读）
- 设置：外层搜索 harness 代码；proposer 是 Claude Code + Opus 4.6，经文件系统读取全部历史候选的源码、分数与执行轨迹。TB2 89 题、基座 Opus 4.6 与 Haiku 4.5，从 Terminus 2 / Terminus-KIRA 起搜 10 轮；正文无 trial 数与置信区间。
- 数字：（摘要）在线文本分类比 SOTA 上下文管理系统高 7.7 分、上下文 token 少 4 倍；200 道 IMO 级题在 5 个留出模型上平均 +4.7。（正文 Table 7）TB2 上 Haiku 4.5：37.6 vs Goose 35.5、Terminus-KIRA 33.7、Mini-SWE 29.8、Terminus 2 28.3、**Claude Code 27.5、OpenHands 13.9**；Opus 4.6：76.4 vs ForgeCode 81.8（作者无法复现）、Terminus-KIRA 74.7、Claude Code 58.0。胜出改动是进入循环前的一段环境快照引导（约 80 行），在 7/89 题上带来增益。（正文 Table 3，在线文本分类）proposer 只看分数：候选中位 34.6 / 最佳 41.3；分数 + 摘要 34.9 / 38.7；完整执行轨迹 50.0 / 56.7。
- 线索更正：76.4% 是"Opus 4.6 agent 中第 2"，不是总榜第 2；对比基线取自官方榜单、并非重跑（作者自跑 Terminus-KIRA + Opus 为 64.4%）；34.6 vs 50.0 属文本分类任务，每条件一次搜索、无方差；**TB2 的搜索集就是报告集（同一 89 题）**，作者称 TB2 是"发现问题"、未另设划分，以人工检查与正则审计排查任务字符串泄漏。
- 作者自述：该工作流"直到 2026 年初"随编码 agent 变强才变得可行。

### A3 2607.22585《The Scaffold Effect in Coding Agents: Harness Choice as a Hidden Variable in Coding-Agent Evaluation》
- 元信息：Sentient Labs ｜ v1 2026-06-08（ID 为 2607，以 v1 日期为准）｜ https://arxiv.org/abs/2607.22585 ｜ 配置、原始日志与脚本经匿名仓库发布 ｜ DL4C@ICML 2026 审稿中，自称初步工作 ｜ 级 B（按分级定义可到 A，但通过率结论只能当描述）
- 设置：Qwen 3.6 Plus、MiniMax M2.5 × Goose / OpenCode / OpenHands-SDK（经 Harbor），Terminal-Bench Pro 公开 200 题中分层取 50 题，**每格每题 1 次**（共 300 次）；Goose、OpenHands 有 40 轮上限，OpenCode 无上限。
- 数字：通过率（Goose / OpenCode / OpenHands）Qwen 48 / 50 / 50、MiniMax 38 / 46 / 46，配对 bootstrap CI 约 ±14 pp；最大差 MiniMax 上 Goose − OpenCode = −8.0 pp，CI [−18.0, 0.0]。每个已解任务的 token：Goose 28,142 / 36,950、OpenHands 约 84 万、OpenCode 115 万 / 155 万（约 41 倍），CI 不重叠。无动作轮次 OpenCode 2.0–2.16 vs Goose 0.2–0.3。失败指纹跨模型重复（Goose 多为 REASON，OpenHands-SDK 多为 VERIFY / MAX_TURNS，OpenCode 多为空转 / 超时）。
- 作者局限：n=50 时 1 题 = 2 pp；Goose 只报总 token，另两者含缓存 token；轮次预算不对称。另：其 Table 4 解题数折算后与 Table 2 通过率对不上。
- 作者建议：按 token / 延迟预算下的通过率选"harness-模型对"，模型比较须同时报告 token、延迟与完整 harness 规格。

### A4 2608.08654《The Scaffolding Matters More Than the Interface: A Controlled Comparison of MCP and CLI Tool Use Across Seven Agent Scaffoldings, Five Language Models, and One Software Task》
- 元信息：UPC Barcelona、萨拉曼卡大学、UPV/EHU ｜ v1 2026-08-09 ｜ https://arxiv.org/abs/2608.08654 ｜ github.com/Lamb-Project/mcp-vs-cli-bench + Zenodo（GPL-3.0）｜ 级 B（单任务；代码与数据公开）
- 设置：一个固定任务（对私有 GitHub 仓库的 6 个操作），按 GitHub API 检查仓库状态判定完成、不信 agent 自报；脚手架 Claude Code 2.1.220、Codex 0.146.0、qwen-code 0.21.2、Hermes 2026.8、opencode 1.18.15（支持 MCP）与 pi 0.73.1、Tau 0.3.6（无 MCP 客户端）；模型 gpt-5.6-luna、gpt-5.6-terra、sonnet-5（仅在 Claude Code 下）、本地 qwen3.6:27b、本地 glm-5.2；GitHub MCP server（44 个工具）vs shell + gh。托管配置单次运行，本地模型配置复跑 3 次。
- 数字：CLI 组完成运行的输入 token 中位数：pi 14,660、Tau 16,459、Codex 82,378、Hermes 83,954、opencode 137,800、qwen-code 297,649、Claude Code 410,797——摘要的"便宜 5.0×–28×"按表是 CLI 组的 **token** 比（Codex / Tau 到 Claude Code / pi），美元数字因模型组合不同不可直接比。"139×"= qwen3.6:27b 在 Tau-CLI（17,416 token）vs 挂了 MCP 的 Codex（2,418,828 token），混入了接口差异；只看 CLI 组，该模型跨脚手架约 17.6×（本综述据表计算）。13 个严格配对的 MCP/CLI 比为 0.43–29.06、中位 0.93；失败花费占比 MCP 12.9% vs CLI 2.2%，失败次数两组都是 3/19；同配置运行间 token 离散中位 1.51×、最宽 5.41×，作者称 <~2× 的差分辨不出。强制接口隔离之前的 21 次运行里只有 6 次只用了指定的 MCP，改 prompt 无效，撤掉凭据才有效。
- 作者局限：单任务单领域（GitHub 的 CLI 很成熟）；pi / Tau 与其他脚手架的差别不止"没有 MCP"；失败率持平主要由 27B 模型撑起。

### A5 2609.11999《Is Bash All You Need? An Empirical Study of Tool Interfaces for Enterprise Digital Worker Agents》
- 元信息：Microsoft（6 位作者中 5 位）+ CMU ｜ v1 2026-09-10 ｜ https://arxiv.org/abs/2609.11999 ｜ 代码未见 ｜ 级 B（两模型受控、无代码）
- 设置：Opus-4.8、GPT-5.5（默认推理强度），agent loop 为 GitHub Copilot SDK（工具与 prompt 被覆盖）；5 种接口：只有 typed tools / typed + bash / 只有 bash / bash + 持久化自合成工具 / PTC（只能调用 typed 目录的受限 Python）；TheAgentCompany 174 题（作者自建 60 个工具的目录）、APEX-Agents 全部 480 题（其"bash"是带护栏的 sh 服务）；每格每题 1 次。
- 数字：TAC 得分 typed-only → bash：Opus 44.9 → 69.4（+24.5）、GPT 45.3 → 67.1（+21.8）；APEX +7.4 / +4.8。总 token：TAC Opus −72%、GPT −19%，APEX 两者 −46%；Opus 在 TAC 每题 $1.20 → $0.37。配对池化差：bash − typed-only +24.6 [+20.6, +29.0]（TAC）、+6.2 [+3.6, +8.7]（APEX）；bash+typed − bash −0.6 / −0.2、bash+自合成 − bash −1.6 / −0.2，CI 均含 0。typed-only 下逐字重复的调用占 16.2%，bash 0.3%。
- 作者局限：给了 shell 就出现 reward hacking（读公开仓库里的评测脚本、读同事文件），靠封仓库与加密同事数据缓解；typed 目录不可能覆盖所有 shell 可达端点；结论"可能不适用于后续版本"。作者建议：执行可隔离时用 bash，合规要求固定工具目录时用 PTC。

### A6 2608.11386《The Devil Is in the Interface: Evaluating How Tool Architecture Shapes Coding Agent Behavior》
- 元信息：Purdue、Microsoft Research、UChicago ｜ v1 2026-08-11 ｜ https://arxiv.org/abs/2608.11386 ｜ github.com/XZ-X/tool-arch-study ｜ 级 A
- 设置：actor 为 Qwen3Coder-30B、Kimi K2.5、Claude Sonnet 4.5；6 种工具架构（BashOnly 基线、Atomic、NLSearch、Python/CodeAct、HypoTrack、Scratchpad），刻意对齐能力（97% 的 Python 动作有 bash 等价）；SWE-bench **Live** 65 题 × 10 rollouts × 6 × 3 = 11,700 条轨迹。
- 数字：摘要的"一致性最高 4.7×"是 pass^9 之比：Qwen3Coder-30B 上 Atomic 0.094 vs BashOnly 0.020；Kimi 0.266 → 0.280、Sonnet 0.252 → 0.283；rollouts 增到 30 时 Qwen 的比值降到约 3.2×。Python vs BashOnly 步数 77→46、65→47、80→55。Atomic 让 Qwen 步数 −33%、输入 token −32%，却让 Kimi 与 Sonnet 步数 +5–8%、**输入 token +20%**。解决率"大体相近"（仅图）。记录中间推理一类的文本"认知脚手架"工具效果有限。
- 线索更正：机构不只 MSR；摘要的"步数 −41.6%、token −56.3%"在各表中找不到推导。
- 作者局限：脚手架无效的结论限于所研究的轻量脚手架；泛化实验只用开源 actor。

### A7 2512.24601《Recursive Language Models》
- 元信息：MIT CSAIL ｜ v1 2025-12-31，读 v3 2026-05-11 ｜ https://arxiv.org/abs/2512.24601 ｜ github.com/alexzhang13/rlm ｜ 级 A
- 设置：把长 prompt 放进外部环境、由模型写代码检视并递归调用自己；根模型 GPT-5（medium）+ GPT-5-mini 子调用，另测 Qwen3-Coder-480B；基线：基座、CodeAct（+BM25 / +子调用）、compaction agent、OpenCode ± 上下文卸载、Claude Code ± 卸载（= **Claude Opus 4.1** + Claude Code v2.0.0）；任务 CodeQA、BrowseComp-Plus（1K 文档、600 万–1100 万 token）、OOLONG、OOLONG-Pairs；每实例单次运行。
- 数字：GPT-5 上相对 compaction 中位 +26%、相对 CodeAct + 子调用 +130%、相对 Claude Code + 卸载 +13%（四任务中位）；相对**同模型** OpenCode + 卸载只有中位 +2.4%（本综述据 Table 1 计算），OpenCode 在 CodeQA 与 BrowseComp+ 上更好；递归主要在二次密度任务上起作用（OOLONG-Pairs F1 0.1 → 58.0）。RLM-Qwen3-8B：摘要页写"平均 +28.3%"，v3 正文写"中位 28%"；可处理长度摘要页写"两个数量级"，v3 正文写"一个数量级以上"。
- 线索更正："+13% vs Claude Code"是跨模型比较（Opus 4.1 驱动）。
- 作者局限：护栏未充分探索；子调用成本可能爆炸、长尾；Qwen3-Coder 需另调 prompt。

### A8 2508.21433《The Complexity Trap: Simple Observation Masking Is as Efficient as LLM Summarization for Agent Context Management》
- 元信息：JetBrains Research + TU Munich ｜ v1 2025-08-29，v3 2025-10-27 ｜ https://arxiv.org/abs/2508.21433 ｜ github.com/JetBrains-Research/the-complexity-trap ｜ DL4C@NeurIPS'25 ｜ 级 A
- 设置：SWE-agent（另有 OpenHands v0.43.0 探针）；Qwen3-32B（含 thinking）、Qwen3-Coder-480B-A35B、Gemini 2.5 Flash（含 thinking）共 5 个配置；SWE-bench Verified 500 题、250 轮、温度 0.8、单次运行；遮蔽窗口 M=10。
- 数字（解决率 / 每题 $；原始 → 遮蔽 → LLM 摘要）：Qwen3-32B 17.0/$1.12 → 15.0/$0.55 → 16.0/$0.50；Qwen3-32B thinking 23.0/$0.51 → 24.6/$0.46 → 24.8/$0.51；Qwen3-Coder-480B 53.4/$1.29 → 54.8/$0.61 → 53.8/$0.64；Gemini Flash 32.8/$0.41 → 35.6/$0.18 → 36.0/$0.24；**Gemini Flash thinking 40.4 → 36.4（−4.0 pp，p=0.041）→ 31.4（−9.0 pp，p<0.001）**。LLM 摘要拉长轨迹（Gemini Flash 52 轮 vs 遮蔽 44 轮），作者解释为摘要掩盖了失败信号。混合策略只在 Verified-50 子集与 Qwen3-Coder 上测：比遮蔽再省 7%、比摘要省 11%。
- 线索更正："成本减半"在 5 个配置中 4 个成立（−50.9% 至 −57.1%），Qwen3-32B thinking 仅 −9.8%；OpenHands 下 M=10 的遮蔽"大幅退化"，窗口调到 M=58 才追平摘要（仅图）。最强配置在两种上下文管理下都显著掉分。
- 作者局限：仅软件工程领域（观察冗长、天然利于遮蔽）；触发固定；窗口大小依赖脚手架。

### A9 2607.03691《Don't Blame the Large Language Model: How Agent Harness Evolution Shapes Coding Agent Quality》
- 元信息：Queen's University ｜ v1 2026-07-04，读 v2 2026-07-20 ｜ https://arxiv.org/abs/2607.03691 ｜ 复现包"录用后公开" ｜ 级 B（单模型、单 harness）
- 设置：固定模型 Qwen3-Next-80B-A3B-Instruct（vLLM v0.18.0、Qwen Code 默认采样）；Qwen Code v0.0.10 → v0.10.3 共 35 个连续版本；SWE-bench Verified 分层 50 题；每版本每题 2 次（共 3,500 次）。另统计 5 个开源 harness 的发布速度（>2 次/天）。
- 数字：解决率均值 30.5%、区间 23.0–39.0%，与版本序 Spearman ρ=0.208（p=0.231，无趋势）；两次运行的二元一致率 87.7%（即 12.3% 的任务结果翻转）；每题 token 从前 9 个版本约 39.1 万升到最新约 66.8 万（+70%，ρ=0.743，p<0.0001），机制是初始 prompt +8%、轮数 +18%。PR 级例子：v0.1.4→v0.1.5 token +52%、解决率不变（#969 搜索工具重写、#981 工具输出格式）；v0.2.3→v0.3.0 token +131%、解决率 26→33%（#926、#1058 把 i18n 写进 system prompt）；v0.4.1→v0.5.0 解决率 39.4→32.5%（#1235 Provider 层的 OpenAI 转换器）。上下文管理扩张与 token 效率变差相关（ρ=−0.346）。
- 作者局限：单 harness、单模型、50 题子集；35 个版本统计功效低。本综述注：12.3% 的翻转率与 16 pp 的跨版本区间同量级；39.4% 不落在 50 题 × 2 次允许的 1 pp 网格上。

### A10 QwenLM/qwen-code `docs/evaluation.md`（厂商自报的同模型多版本评测）
- 元信息：Qwen Code 仓库文档，创建于 commit `a9cd8ace`（2026-10-14，PR #14093；同一组数字 2026-09-02 先写进 README，PR #10808）｜ https://github.com/QwenLM/qwen-code/blob/main/docs/evaluation.md ｜ 级 C
- 设置：同一模型 Qwen 3.7 Max、同一配置（temperature=1、top_p=0.95、reasoning_effort=high、1M 上下文、max_iterations=500）；SWE-bench Verified 500 题；每版本 3 次 trial（每版 1,500 个作业）；7 个版本 0.0.14、0.1.0、0.5.0、0.10.0、0.15.0、0.19.0、0.22.0。
- 数字：平均分 76.40%（0.19.0）至 77.80%（0.0.14），极差 1.40 pp；pass@3 83.0–85.0%；pass^3 65.8–69.2%（极差 3.4 pp，0.19.0 的 pass^3 最低而通过率最高）。文档只报数字，未讨论版本间改了什么。
- 与 A9 的重叠：0.0.14、0.1.0、0.5.0、0.10.0 两边都测了（模型不同：A9 是 Qwen3-Next-80B、50 题 × 2 次）；两边都是 0.0.14 最高，A9 的区间 16 pp、A10 的 1.4 pp。

### A11 OpenAI《How enabling two settings tripled our scores on the ARC-AGI-3 benchmark》
- 元信息：OpenAI ｜ 发布 2026-07-29（RSS pubDate 15:00 GMT）｜ https://openai.com/index/how-two-settings-tripled-our-arc-agi-3-scores ｜ 正文页对抓取返回挑战页，读到的是 OpenAI 新闻 RSS 的摘要与 OpenAI 自家另一页面（developers.openai.com《Codex as a platform》）的引用 ｜ 级 C
- 已核验：RSS 摘要称两项 API 设置——保留推理与开启压缩——提升了 GPT-5.6 在 ARC-AGI-3 上的分数与效率；《Codex as a platform》页写明 GPT-5.6 Sol 从 13.3% 到 38.3%、输出 token 少 6 倍（`raw/docs/openai-codex-as-a-platform.md` 已记录同一句）。
- 未核验：原文的评测集（公开 / 半私有游戏与局数）、运行次数、两项设置各自的消融、具体参数名。

## B. 组件价值随模型强度的变化

### B1 2609.20804《An Empirical Study of Harness Design for Coding Agents》
- 元信息：UMass Amherst、Zoom、Emory、UNC Charlotte（部分作者在 Zoom 实习期间完成）｜ v1 2026-09-17 ｜ https://arxiv.org/abs/2609.20804 ｜ 代码未见 ｜ 级 B（多模型受控、有 McNemar 检验，但无代码、单次运行）
- 设置：执行循环固定，只变规划、动作空间、上下文管理三个组件；模型 Nemotron-3 30B / 120B / 550B 与 Mistral-Medium-3.5-128B；SWE-bench Verified（500）+ Terminal-Bench 2.1（89）；176 个配对设置（T0–T4 五档上下文管理 × 32k/64k/96k/128k 四档窗口，外加关规划、只给 bash，后两者只在 T4/128k 做）；温度 0、300 步、每题 1 次；精确 McNemar + BH-FDR 0.05。
- 数字（正文 Table 3，SWE-bench Verified，128k/T4）：规划开 vs 关：30B 25.2 vs 13.6（**+11.6 pp**，显著；TB 上 +4.5，不显著）；550B 65.8 vs 67.8（**−2.0 pp**，不显著），每题成本 $2.33 vs $3.31（约 −30%）；Mistral −0.4 pp、成本 −32%。只给 bash vs 预定义工具：550B 69.4 vs 65.8（+3.6，显著），成本 $1.11 vs $2.33；TB 上 +5.6（不显著）、成本 −30%；Mistral 在 SWE 上 **68.6 → 45.4**（显著），在 TB 上 bash-only 反而 +6.7；30B −15.0（SWE）/ −10.1（TB）。上下文管理的价值（受管 − T0）随窗口 32k→64k→96k→128k：SWE 35.7→15.9→5.5→2.7 pp，TB 9.5→7.5→4.8→2.8；同期 T0 的溢出率 78.7%→8.7%（SWE）、61.0%→12.1%（TB），受管各档溢出始终为 0。可召回的被删内容：64 个 T2/T4 设置中 36 个（56.3%）从未调用 recall_event，均值 0.540 次/题（32k）→ 0.007（128k）；T2 对 T1 为 15 胜 14 负 3 平、均差 −0.36 pp；调用几乎全部来自 30B。机制：关规划时 30B 有 68.6% 的运行一行代码没改就结束（开规划 27.8%），中位轮数 40 → 5。
- 作者局限：每个组件只有一种实现；动作空间改动是打包的（工具 + prompt + 状态追踪 + 诊断）；规划与动作空间只在 T4/128k 消融；单次运行，TB 只有 89 题、多数对比不显著；模型大小只是能力的粗代理；SWE-bench Verified 只有 Python。
- 作者结论大意：规划从弱模型的"准确率脚手架"变成强模型的"省钱工具"；决定工具分界的是 bash 熟练度而不是规模；上下文管理的价值由窗口预算决定。

### B2 2606.00408《Masking Stale Observations Helps Search Agents – Until It Doesn't: A Regime Map and Its Mechanism》
- 元信息：UIUC、UCSD（McAuley）、UC Berkeley、Texas A&M ｜ v1 2026-05-29 ｜ https://arxiv.org/abs/2606.00408 ｜ github.com/i-DeepSearch/observation-masking（脚手架 + 轨迹）｜ 级 A（未量化噪声）
- 设置：9 个开源骨干（Qwen3.5-4B / 9B / 35B-A3B、Qwen3.6-35B-A3B、GPT-OSS-20B / 120B、OpenResearcher-30B-A3B、DeepSeek-V4-Flash-Max 284B-A13B、Tongyi-DeepResearch-30B-A3B）× 3 个检索器（BM25、Qwen3-Embedding-8B、AgentIR-4B）+ Serper 实网；BrowseComp-Plus（830）、GAIA 纯文本（103）、xBench-DeepSearch（100）、BrowseComp-ZH（289）；保留窗口 K=5、500 轮、温度 1.0、GPT-5-mini 判分；单次运行、无显著性检验。
- 数字：弱检索器（BM25，召回 ≤0.54）下增益是 +6.2 至 +6.6 的平台；峰值 +11.7（Qwen3.5-35B-A3B + AgentIR，召回 0.88，无上下文管理时 62.9%）；饱和格（无管理时 ≳70%）+0.1 至 +3.8，Tongyi −1.1；实网 GPT-OSS-120B 在 GAIA −4.8、在 xBench +8.0；同架构不同代：Qwen3.5-35B +11.7 vs Qwen3.6-35B +3.7。遮蔽在每个 BrowseComp-Plus 格都增加工具调用（每题 +20.3 至 +91.6 次），修好:弄坏之比 Qwen3.5-35B 约 3:1、GPT-OSS-120B 约 1:1。注意力：推理占每步注意力 53.7%、观察 25.6%；对前一轮之前的观察注意力约 1.7%、更早约 0.7%，而观察占 token 的 85% 以上。
- 线索更正：引言称饱和时增益"≤0"，实际饱和格为 −1.1 至 +3.8，负值只有 Tongyi 与 GPT-OSS-120B@GAIA。
- 作者局限：只有一种回合式遮蔽策略；只测开源模型；区域图是描述性的、不是预测性的。

### B3 2605.30621《Harness Updating Is Not Harness Benefit: Disentangling Evolution Capabilities in Self-Evolving LLM Agents》
- 元信息：Penn State、UC Santa Cruz、Amazon、Emory、UIUC、Northeastern ｜ v1 2026-05-28 ｜ https://arxiv.org/abs/2605.30621 ｜ github.com/A-EVO-Lab/a-evolve（release/harness-evolution 分支）｜ 级 A（无噪声估计、无留出集）
- 设置：执行 agent 6 个（Claude Opus 4.6、Sonnet 4.6、Haiku 4.5、Qwen3-235B-A22B、Qwen3-32B、GPT-OSS-120B），更新者另加 Qwen3.5-9B；SWE-bench Verified（500）、MCP-Atlas（500）、SkillsBench（86 题 × 5 trials）；可进化部件是 skills（MCP-Atlas 上加 prompt 与 memory）；在同一任务流上原位评估，无留出划分。
- 数字（Δ收益 pp，SWE / MCP / SB）：Qwen3-32B 4.4 / 1.0 / 5.8；Qwen3-235B 19.3 / 4.3 / 1.1；GPT-OSS-120B 15.8 / 7.0 / 7.0；Haiku 2.4 / 3.6 / 15.1；Sonnet 2.8 / 3.2 / 3.5；Opus 2.6 / 3.6 / 5.8。更新者能力：Qwen3.5-9B vs Opus 4.6 写出的更新带来的增益 SWE 6.8 vs 7.4、MCP 1.0 vs 3.6、SB 3.8 vs 2.3，每个基准上最好与最差更新者差 ≤3.1 pp。弱模型的两种失败：skill 加载率 Qwen3-32B 0.251、GPT-OSS 0.446、Haiku 0.794、强模型 0.957–0.961；遵循率 Qwen3-32B 0.142 … Opus 0.757；从加载到最后一轮的遵循率漂移 Qwen3-32B 0.52→0.13、Opus 0.89→0.80。
- 线索更正：倒 U 在 SWE / MCP 上成立；SkillsBench 上峰值是 Haiku 4.5（+15.1），Qwen3-32B 与 Opus 并列 5.8。
- 作者局限：权重固定；模型集"有代表性但不穷尽"。本综述注：Δ收益取 3 个更新者中的最大值，噪声下偏高。

### B4 2512.08296《Towards a Science of Scaling Agent Systems》
- 元信息：Google Research、Google DeepMind、MIT ｜ v1 2025-12-09，读 v3 2026-04-08 ｜ https://arxiv.org/abs/2512.08296 ｜ github.com/ybkim95/agent-scaling ｜ 级 A（编码基准样本小）
- 设置：GPT-5-nano / mini / 5、Gemini-2.0 Flash / 2.5 Flash / 2.5 Pro、Claude Sonnet 3.7 / 4 / 4.5；留出模型 GPT-5.2、Gemini-3.0 Pro / Flash；BrowseComp-Plus（100）、Finance-Agent（50）、PlanCraft（100）、Workbench（100）、SWE-bench Verified（20 题子集）、Terminal-Bench（前 20 题）；单 agent + 4 种多 agent 架构（独立、中心、去中心、混合），统一工具、prompt 与计算预算；260 个配置。
- 数字：能力饱和阈值约为单 agent 基线 45%（β=−0.236，p=0.004，聚类稳健与 Holm 校正后仍显著），越过之后协调收益递减乃至为负；错误放大：独立式 17.2×、中心式 4.4×（去中心 7.8×、混合 5.1×），但控制其他变量后不显著（p=0.658）；相对单 agent 的变化：Finance-Agent（中心式）+80.8%、PlanCraft（独立式）−70.0%，总体均值 −0.3%（95% CI −58.7 至 +77.2）；交叉验证 R²=0.373；在留出配置上 87% 选对最佳架构。
- 版本变化：v2 摘要为 180 个配置、4 个基准、R²=0.524；v3 改为 260 个配置、6 个基准，R² 降到 0.373（v1 摘要未取到）。
- 作者局限：团队至多 9 个 agent；只混用同家族模型；prompt 未按模型调；SWE / TB 每格 n=20，bootstrap CI 约 ±20 pp。

### B5 2610.28802《How Much Does the Harness Matter, and for Whom? A Multi-Model Study of Context in LLM-Driven Vulnerability Discovery》
- 元信息：Georgian（一作兼多伦多大学）｜ v1 2026-10-20 ｜ https://arxiv.org/abs/2610.28802 ｜ harness 为 DeepSec（github.com/vercel-labs/deepsec），prompt 与汇总表公开、漏洞细节不公开 ｜ CAMLIS 2026 ｜ 级 A（同行评审、模型内受控；仅 2 次运行、单代码库）
- 设置：一个扫描时漏洞未公开的 TypeScript 生产代码库；24 个模型-runner 配置 × 2 次；上下文实验 4 个模型：GPT-5.5（"前沿"，Codex SDK、xhigh）、Composer-2.5、GLM-5.1、Gemma-4-31B，8 个条件 × 2 次；CyberGym 21 个 C/C++ 实例作留出。
- 数字：最小 prompt → 工程化 prompt + CodeQL 调用图，按危急度加权的产出：Gemma +86%、GLM +36%、Composer +20%、GPT-5.5 +2%（作者称"在运行间噪声内"）。拆开看：只换 prompt +6.5 / +19.0 / +41.0 / +8.0（GPT-5.5 / Composer / GLM / Gemma）；在 prompt 之上再加 CodeQL −6.5 / −4.5 / −29.5 / +4.5——只有最小模型从额外上下文获益。误报率 GPT-5.5 10.0%→5.3%、GLM 13.3%→29.4%。覆盖：265 个确认根因，最好的两次运行配置覆盖 60.4%，14.3% 只被一个模型找到。同一条件两次运行的产出可相差约三分之一（如 29 vs 55）。
- 作者局限：4 个模型、2 次运行；标题数字混合了 prompt 与上下文两种处理；单仓库；无等长上下文对照。

### B6 2605.08741《Training with Harnesses: On-Policy Harness Self-Distillation for Complex Reasoning》
- 元信息：北京大学 ｜ v1 2026-05-09 ｜ https://arxiv.org/abs/2605.08741 ｜ github.com/zzy1127/OPHSD-On-Policy-Harness-Self-Distillation ｜ 级 B（单模型）
- 设置：只有 Qwen3-8B；这里的 harness 是推理工作流（文本分类的 draft–verify + 检索记忆库、数学的 plan–solve），不是工具循环；LawBench、USPTO；AIME24 / 25、OlympiadBench、HMMT25。
- 数字：harness 挂在基座上：LawBench +4.93、USPTO +48.95、数学 pass@1 平均 25.64→43.47；自蒸馏（OPHSD）之后再挂回 harness：LawBench −1.10、USPTO −7.19、数学 pass@8 平均 −0.37（各基准有升有降）；"在 HMMT25 上比 OPSD 高 10.83%"是绝对差（53.33 vs 42.50）。
- 作者自述：程序性 harness 可被蒸馏；依赖实时外部交互的部分（搜索、代码执行、有状态环境）"不可蒸馏"，未测。

### B7 2608.06113《DCAS: Decoupling CLI Agent Scaffolding to Internalize Planning across Scaffolds》
- 元信息：Huawei Canada 软件卓越中心 + Queen's University ｜ v1 2026-08-06 ｜ https://arxiv.org/abs/2608.06113 ｜ Zenodo + HF 模型与数据 ｜ ASE '26 ｜ 级 A（同行评审；单执行模型、单次运行）
- 设置：SWE-bench Verified（500）；脚手架 OpenHands v0.50.0、Claude Code 2.0.76 / 2.1.73、OpenCode v0.0.55、mini-swe-agent v2.2.8；执行模型 Qwen3-Coder-30B-A3B；规划者 Claude Sonnet 4.5 / Opus 4.5 / Qwen3-Coder-480B；SFT 数据为 Claude Code 下采集的 576 条 GLM-4.7 轨迹。
- 数字（Pass@1：OpenHands / Claude Code / OpenCode / mini）：用 OpenHands 轨迹微调的 SWE-Lego-Qwen3-32B 52.6（报告值）/ 44.2 / 8.4 / 37.6；Nebius-SWE-Rebench-30B 49.7 / 46.0 / 35.8 / 20.4；基座 Qwen3-32B 29.0 / 23.2 / 18.4 / 8.0。计划来源：无计划 42.8 → 自己规划 48.2 → Sonnet 4.5 给计划 57.8（+15.0 pp）。只在一个脚手架下用少量"规划感知"轨迹 SFT 后迁移：OpenCode +3.4、mini-swe-agent +7.0。
- 线索更正：作者 2/3 来自 Huawei Canada；"基座模型不随脚手架分化"不准确——基座也有 21 与 13.6 分的跨脚手架差，只是小于所有微调模型（27.8–44.2）。
- 作者局限：规划与工具调用格式、解析器、轮次管理共变；SFT 增益混入"见过成功轨迹"的效应；单执行模型。

### B8 2610.05640《Can CaMeLs Talk? Securing Multi-Agent Systems Against Indirect Prompt Injection Attacks》
- 元信息：独立研究者（一作）、Oxford、MATS Research、AI Sequrity Company ｜ v1 2026-10-05 ｜ https://arxiv.org/abs/2610.05640 ｜ 称将发布代码，未见链接 ｜ 预印本 ｜ 级 B
- 设置：Claude Fable 5、GPT-5.5、GPT-4.1、Gemini 2.5 Pro、Gemini 2.5 Flash-Lite（经 OpenRouter）；AssetOpsBench（112 题，LLM 判分）测效用；作者自建 MultiAgentDojo（97 个良性任务、每模型每配置 949 个注入实例）测安全-效用权衡。CaMeL 在单 agent 内有效，但分层多 agent（agent 作为工具）中不可组合：下游 agent 会把不可信数据当成可信输入。
- 数字：攻击成功率无 CaMeL 平均 12.9%（GPT-5.5 0.0%、Fable 5 1.5%、Flash-Lite 2.1%、Gemini Pro 24.6%、GPT-4.1 36.1%）、单 agent CaMeL 平均 0.2%、multi-CaMeL 对所有模型 0/949。AssetOpsBench 效用（无 → multi-CaMeL）：Fable 5 88.4→67.9（−20.5）、GPT-5.5 87.5→79.5（−8.0）、GPT-4.1 81.2→48.2（−33.0）、Gemini Pro 75.9→50.9（−25.0）、Flash-Lite 64.3→26.8（−37.5）；MultiAgentDojo 良性任务 GPT-5.5 86.6→66.0、GPT-4.1 78.4→24.7；Fable 5 拒绝了 97 个良性任务中的 52 个。
- 线索更正：作者说效用代价"随能力增加而下降"，同时自己注明"非单调"（Fable 5 −20.5 大于 GPT-5.5 −8.0）；12.9% 是 5 模型平均、主要来自 GPT-4.1 与 Gemini Pro——对 GPT-5.5，非自适应攻击下的安全增益本身接近 0。
- 作者局限：只研究分层 agent-as-tool；0% ASR 不代表对自适应攻击稳健；仍可能被引导分支；结果绑定模型版本。

## C. 厂商重做消融的一手记录（全部为 C 级自报，除非另注）

### C1 Anthropic《The new rules of context engineering for Claude 5 generation models》
- 元信息：Thariq Shihipar ｜ 发布 2026-07-24 ｜ https://claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/（claude.com/blog 同 slug 308 跳转至此）｜ curl 抓 HTML 与 .md ｜ 级 C
- 核心数字：为 Opus 5、Fable 5 这类模型删掉 Claude Code system prompt 的 80% 以上，"在我们的编码评测上没有可测损失"。**未披露**评测名称、分数、trial 数或删前删后 token 数——"无可测损失"没有定义。
- 删改清单（then → now）：硬规则 → 判断（"默认不写注释、不写多段 docstring"一类规则换成"匹配周围代码的注释密度、命名与习惯"）；工具用法示例 → 接口设计（作者原话大意：对最新模型，给示例反而把它限制在某个探索空间；TodoWrite 描述从约 9,100 字符的"何时用"清单加示例缩成一句话 + 状态枚举 + "同时只能一个 in_progress"）；反复强调 → 简单工具描述（理由：旧模型需要重复，且更听上下文末尾的指令）；验证与代码评审移出 system prompt、各成一个 skill；部分工具（如 Task 系列）延迟加载、经 ToolSearch 取完整定义；CLAUDE.md 里的记忆 → auto-memory；简单 spec → 富参考（HTML 产物、测试套件、代码、配 verifier agent 的 rubric）；`/doctor` 为 skills 与 CLAUDE.md "瘦身"（Claude Code 2.1.206 changelog 有对应条目）。
- 作者自述：这些约束"曾经是为了避免最坏情况"；对旧模型若去掉这些护栏，写出的注释"在许多情况下会是错的"；旧规则只对"某一子集的 prompt"有害。
- 未出现：任何"权限 / 安全 / 验证不得删"的边界说明；验证是**挪进 skill**，不是删除。

### C2 Anthropic《Effective context engineering for AI agents》（C1 的前作）
- 元信息：Applied AI 团队（Rajasekaran、Dixon、Ryan、Hadfield）｜ 发布 2025-09-29 ｜ https://www.anthropic.com/research/effective-context-engineering-for-ai-agents（旧 /engineering/ 地址跳转至此）｜ 级 C
- 2025 建议 → 2026（C1）的处置：
  - system prompt 取"合适高度"、避免脆弱的 if-else 式硬编码 → **保留**原则，但实践上高度上移（硬规则换判断）。
  - "先用最好的模型测试一个最小 prompt" → **保留并放大**（删 80%+）。
  - 工具集最小、不重叠、参数描述清晰 → 设计原则**保留**；工具数量**修订**（延迟加载让"更多工具不占上下文"）。
  - few-shot 示例："我们仍强烈建议的公认最佳实践" → 对最新模型的**工具用法示例明确反转**；一般 few-shot 未提及。
  - 不要堆砌边缘情况清单 → **保留并加强**。
  - 即时检索 / 渐进披露 → **保留并扩展**到 skills、ToolSearch 延迟加载、文件树、@ 引用。
  - CLAUDE.md 先行全量放入上下文的混合策略 → **修订**：CLAUDE.md 只留 gotchas，其余推给 skills。
  - 结构化笔记（to-do、NOTES.md、memory 工具）→ **修订**：auto-memory；TodoWrite 描述缩短（另见 C4 默认移除）。
  - compaction（摘要 + 最近访问的 5 个文件、清理工具结果）与"subagent 回传 1,000–2,000 token 摘要" → **未提及**。
  - "更聪明的模型需要更少的规定性工程""做最简单可行的事" → **保留**；2026 年那篇读起来正是这句预言的兑现。
- 唯一明确反转的是**工具用法示例**；其余是同方向的加强或修订。

### C3 Anthropic《An update on recent Claude Code quality reports》
- 元信息：无署名 ｜ 发布 2026-04-23 ｜ https://www.anthropic.com/research/april-23-postmortem ｜ 级 C
- 事实：用户感知的"模型变差"被追溯到 Claude Code / Agent SDK / Cowork 的三处 harness 变更，"API 未受影响"；内部使用与 eval 起初都没复现。①3-04 把默认 effort 从 high 改 medium（降延迟），4-07 回滚，影响 Sonnet 4.6 / Opus 4.6；②3-26 上线"会话空闲 >1 小时清旧 thinking"，bug 导致**每轮**都清，模型显得健忘重复、缓存未命中加速耗尽额度，4-10（v2.1.101）修复——它通过了人工与自动代码评审、单测、端到端测试与内部试用；回测中 Opus 4.7 在给足仓库上下文时找出了这个 bug，Opus 4.6 没有；③4-16 加入一行字数限制（工具调用之间 ≤25 词、最终回答 ≤100 词），随 Opus 4.7 发布、"在我们跑的评测里无回归"，4-20 回滚，影响 Sonnet 4.6 / Opus 4.6 / Opus 4.7。
- 测量：事后做逐行消融（"从 system prompt 删行，理解每一行的影响"），一个更广的评测显示 Opus 4.6 与 4.7 **都掉了 3%**（未说明评测名，也未说明是百分点还是相对值）。
- 补救：每次 system prompt 改动跑一套**按模型**的评测；模型特定改动只对目标模型生效（gate）；牺牲智能换别的东西的改动要 soak 期、更广评测与渐进放量；prompt 改动审计工具。
- 厂商自述：三处改动各影响不同流量切片、不同时间表，看起来像"广泛而不一致的退化"，难与正常波动区分。

### C4 Claude Agent SDK / Claude Code changelog：按模型代际收回 harness 组件
- 元信息：anthropics/claude-agent-sdk-typescript `CHANGELOG.md`（gh api 读取）；changelog 本身不带日期，日期取 npm `time` 字段 ｜ 级 C（代码 / changelog）
- 0.3.233（npm 发布 2026-08-14T18:52Z）：todo / 任务追踪工具（`TaskCreate`/`TaskGet`/`TaskUpdate`/`TaskList`、`TodoWrite`）**不再在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 及更新模型的默认工具面里**；可用 `tools` 选项、`allowedTools` 或环境变量 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 留住。Claude Code 2.1.233 同一改动。Python SDK 无对应条目（0.2.139 只是把内置 CLI 升到 2.1.233）。**线索更正**：模型列表还包括 Mythos 5；且是"移出默认"，不是删除。
- 同类条目（日期按同号 SDK 的 npm 时间推定，≈）：2.1.201（≈07-03）Sonnet 5 会话不再用对话中途的 system 角色发 harness 提醒；2.1.228（≈08-11）Write 工具允许"较新模型"覆盖本会话未读过的文件，旧模型仍须先读；2.1.221（≈08-03）claude-api skill 加入 `prompt-audit`，针对"为旧模型写的模式"；2.1.283（≈09-25）加入 `/doctor prompt-audit`，扫描 CLAUDE.md、skills、agents、commands 里为旧模型写的提示模式；2.1.295（≈10-08）不再向 Claude 3 Opus / 3.x Sonnet 提供 tool search（"这些模型会拒绝"）。

### C5 Anthropic 提示词文档（platform.claude.com，按模型分页）
- 元信息：https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices（旧 claude-4-best-practices 地址跳转至此；活文档、无日期）；同目录 `prompting-claude-opus-5`、`prompting-claude-fable-5` ｜ curl ｜ 级 C
- 通用页：为解决"欠触发"而写的强调措辞会让 Opus 4.5 / 4.6"过触发"，应软化（把"CRITICAL: You MUST use this tool when…"改成"Use this tool when…"）；迁移步骤含"调整反偷懒提示"。
- Opus 5 页：Opus 5 不经要求就会自查；prompt 里显式的验证指令（"加最终验证步骤""用 subagent 验证"）会导致过度验证，删掉可减少浪费 token 且质量无损，"**同样适用于加独立验证步骤的旧式 harness 脚手架**"。
- Fable 5 页：为旧模型写的 skills 往往过于规定性、可能降低产出质量；但同页又**新增**脚手架——独立的新上下文 verifier subagent 往往胜过自我批评；长任务里让模型按实际工具结果审计进度声明，"几乎消除了"捏造的状态报告；执行改变系统状态的命令前先核对证据是否支撑该动作。
- 厂商告诫：页内建议应视为"在那个模型上测得"，换模型前在自己的 eval 上复核。

### C6 Anthropic《Building agents: When to fold subagents into your main agent loop》
- 元信息：Diane Sarkis ｜ 发布 2026-10-22 ｜ https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop ｜ curl（2026-10-25 综合）｜ 级 C
- 事实（厂商自报，无公开数据集）：Applied AI 团队在若干企业部署的对比中，"单 agent + skills"常在质量上胜过"一个 prompt 包一切"与"subagent 设计"两者，且每任务成本与延迟往往更低；一家客户实测单 loop 比其多 agent harness 运行时快约 2 倍。常见的意图分类器 + 固定多步推理管线 + 用户分桶 + 多 agent 编排器，被反馈为"多数结构在做模型已不再需要别人替它做的事"。
- 与模型能力挂钩的表述：从 Opus 4.5 起模型能在单 loop 里管理远超预期的工作；Opus 5.5 与 Fable 5.1 不能关闭 thinking；新模型越来越多地边做边汇报进度、自查工作，"让部分 harness 元素变得多余"；迁移中**僵硬的多 agent 结构常是阻止新模型多做事的东西**。又一次引用：为更先进模型把 Claude Code system prompt 减了 80% 以上。
- 仍留在 harness / 工具里的：轮次与成本预算、写入闸门由 harness 设定；硬约束（校验、审批闸门）挪进工具；每个工具检查调用用户的权限并返回模型可读的拒绝；答完后可选跑目标 / verifier 检查。被删除的：按规则目录重写计划的代码步骤（"不再需要"）。subagent 仍适用的三种情况：单 loop 因上下文膨胀出现**可测**退化；需要并行、用完即弃的新上下文；单 agent 选不对工具或 system prompt 指令冲突。工具定义超过 30–50 个时选工具质量下降，用 tool search 延迟加载。
- 测量方法：先建端到端 eval（"10 个黄金样例就够起步"）；一次折叠一个 subagent，比较有无；不只看总分，**看哪些任务翻转**；每条生产中一起运行的 agent 链、每条不可违反的规则都要有任务；每个任务跑不止一次——文中一次破坏只在两次运行中的一次出现。收尾原则：测量、一次改一处、留下站得住的。

### C7 Cognition《Multi-Agents: What's Actually Working》（修订 2025-06-12《Don't Build Multi-Agents》）
- 元信息：Walden Yan ｜ 发布 2026-04-22（前作 2025-06-12）｜ https://cognition.com/blog/multi-agents-working ｜ 级 C
- 已核验：标题、日期与 slug 来自 Cognition 官方博客索引页（WebFetch，2026-10-25）。正文**待核验**：本轮 WebFetch 对该域名的文章页持续失败，沙箱 curl 无法连接 cognition.com，Wayback 亦不可达。

### C8 OpenAI Developers《Rethinking skills and prompts for GPT-6 Astra》
- 元信息：Eric Provencher（OpenAI Developers 博客）｜ 发布 2026-09-11 ｜ https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra ｜ 级 C
- 事实：开篇即称"能力更强的模型下，过去需要大量手把手与脚手架的东西已不再需要"。skills：描述越短越好、只说清何时用（反例：一个只该在迁移时用的数据库 skill，描述写得让模型一碰数据库就加载）；skill 过多时 Codex 会自动截短描述；描述之间互相矛盾或过度强调触发条件，会让模型加载无用指令；多工作流的 skill 根文档只做极简路由、指向支撑文档与脚本（渐进披露）；很多 skill 写成"行程表 / 菜谱"，模型更懂细微差别后，过细的指导"现在会妨碍结果，而过去是有帮助的"；仓库 skill 会被别的模型读到，"对 Sol 或 Luna 有用的指导可能过度约束 GPT-6 Astra"。AGENTS.md：常回头逐条问"还需要吗"；旧模型需要被鼓励去跑测试、自查，Astra 会自己做，同样的指令会导致多余的测试；Astra 更谨慎、可能做完第一版就回来请人审——可用 AGENTS.md 为确知安全的工作流（如本地测试套件）明确授权；为防旧模型越权而写的强硬"先问我"边界措辞，Astra 可能"太当真"而在你本想让它继续的地方停下，建议更新这类措辞。
- 未见：数值评测。

### C9 OpenAI Developers《Maintaining software with the GPT-6 family》
- 元信息：Rodrigo Roim（OpenAI Core Experimentation 团队）｜ 发布 2026-10-14 ｜ https://developers.openai.com/blog/maintaining-software-with-the-gpt-6-family ｜ 级 C
- 事实：OpenAI Core Experimentation 团队用 Codex 删死代码、清理过期实验、优化 CI。五名工程师两周兼职、跨仓库合并 1,400 多个 PR、删除 80 多万行代码；GPT-6.1 Sol Ultra 以 14% 的 API 成本产出了 GPT-6 Astra Ultra 92% 的发现（每种设置一次运行、作者人工核对：131 vs 142 条，$15.12 vs $109.06）。AGENTS.md 指令的消融方法出现在"Other ideas to try"一节，是**建议的提示词而非报告过的实验**：让 Codex 翻最近的会话，找出一条看起来误导了 agent 的 AGENTS.md 指令，然后在**同一仓库快照、同一模型**上把同一个 prompt 各重放一次——一次指令不变、一次只删掉或修正这一条——再比较；文中没有给出结果，也没有保留 / 删除的判定规则。同节另一条提示（按仓库 CI 历史估算每天可省的 CI 分钟数并排序）带来约 30 个 CI 优化 PR，CI 完成时间中位数约 10 → 4.5 分钟、P90 12.5 → 6 分钟。Astra 发现某标为"Permanent"的 flag 造成大量 CPU 扇出时，没有自行删除而是提交人工审核。
- 注：重放每种条件只一次，未给重复次数或显著性。

### C10 openai/codex PR #41744 与 #55355
- 元信息：#41744《Make the update_plan tool opt-in》合并于 2026-08-31、#55355《Remove the long-thread accuracy warning after compaction》合并于 2026-10-19，作者均为机器人账号 app/copyberry，两者都未写理由 ｜ 本地检出 `raw/repos/openai-codex`（HEAD 970111f6，2026-10-23）已核对当前状态 ｜ 级 C（代码）
- #41744（diff 已读）：`[tools.update_plan]` 的默认值由 true 改为 false（`UpdatePlanToolConfig.enabled` 改为 `#[serde(default)]`，schema 默认 false），并新增 `without_update_plan_instructions`，在工具关闭时从指令中剥掉 `update_plan` 相关段落；子 agent 继承父配置；PR 正文只写"默认 `tools.update_plan.enabled` 为 false，用户可显式开启"，默认对所有模型生效，自定义指令不被改动。
- #55355（diff 已读）：**线索更正**——删掉的不是一条代码注释，而是每次压缩后向用户发出的警告事件："Heads up: Long threads and multiple compactions can cause the model to be less accurate. Start a new thread when possible…"，连同相关测试一并删除。
- 本地检出核对：该警告文本已不存在；`UpdatePlanToolConfig.enabled` 默认 false。

### C11 Cursor《Improved token efficiency for longer agent runs》
- 元信息：Jediah Katz、Connor O'Keefe、Calvin Yee ｜ 发布 2026-09-23 ｜ https://cursor.com/blog/improved-token-efficiency ｜ 级 C
- 事实：各层改动合计让用户的 token 成本降 7%，"未降低 agent 质量"。system prompt：模型较弱时要写明工具用法、任务管理、改代码流程，还要防超长哈希输出、二进制输出、emoji；模型变强后，不再需要成串的"DO NOT""You must""Important"，只需定义工具行为，"跨模型家族都成立"，据此删掉约 66% 的 system prompt；之后仍随新模型增删指令。工具定义：此前把 MCP 工具移入动态上下文（按需加载），在调用过 MCP 工具的会话上总 token −46.9%；内置工具按使用频率做 A/B，只保留读、搜、改、shell 等高频工具与 `ask_question`（"有些模型会幻觉出对它的调用"）和 `create_plan` 等关键流程工具，静态上下文中的工具描述 token −60%。缓存：显式标出可复用前缀后冷缓存未命中 −20%。Read 工具只每 10 行标一次行号，缓存读取 token −1.6%、"质量无下降"。删掉强烈鼓励用 subagent 做代码库探索的指令（模型已在后训练中学会），subagent 使用更均衡。
- 测量方法：A/B 测试同时跟踪 token、成本、延迟、工具调用错误与整体 agent 使用量；作者认为 eval 是快速代理，但多代表"难题"、不反映真实请求分布。
- 未披露：A/B 的流量比例、时长与质量指标的具体数值。

### C12 Replit《Free the models: Harness design at the frontier》
- 元信息：Daniel Furman、Jacky Zhao、Vaibhav Kumar、Ed Sioufi、Michele Catasta ｜ 发布 2026-09-29 ｜ https://replit.com/blog/free-the-models ｜ 级 C
- 事实："每一次模型发布都会让 harness 里固化的假设失效"；模型长程能力越强，harness 层需要的脚手架越少；harness 提供选项、"保留护栏"，由核心 loop 决定思考强度、何时交接、交给谁（领域 subagent、小 / 中 / 大三档 subagent 加强度、可复用 subagent、逐步动态调整 effort）。Astra 与 Fable 5.1 的代码质量让他们"更少使用代码评审 subagent，eval 分数没有下降"。生产数据（每模型一周）：Fable 系很少把实现交给通用 worker，Astra 是第一个不经提示就常规委派的模型。基准（Max 模式、Astra 作核心 loop、每项 4 次重复、95% 区间）：DeepSWE v1.1（113 题）Replit Agent 72% / 每题 $2.11，对照 Astra 单独跑 mini-swe-agent 低强度 67% / $1.60、xhigh 74% / $4.43，"sidekick"架构 61% / $1.34；Terminal-Bench 4.0（63 题，去掉 GPU 题）49% / $2.53，对照 42% / $2.25、60% / $5.86，sidekick 33% / $1.84。
- 注意：Astra 的对照数字取自公开榜单（mini-swe-agent 基线），不是同批运行；作者把结果读作"苦涩的教训"的一例。

### C13 Amp《Amp, Rebuilt》
- 元信息：署名 Amp（机构）｜ 发布 2026-05-06 ｜ https://ampcode.com/news/neo（标题《Amp, Rebuilt》，`/news/amp-rebuilt` 返回 not_found）｜ 级 C
- 事实：新 CLI（代号 Neo）以"为前沿模型能做的事而建"为原则，压缩优先：上下文窗口 90% 满时自动压缩。**Handoff 被移除**——"压缩让它过时了"。**默认不再在运行工具前请求许可**：过去的 `--dangerously-allow-all` 成为未配置权限用户的默认行为；旧权限系统改为内置插件，设置里显式开启权限（如 `amp.permissions`、`amp.dangerouslyAllowAll: false`、`amp.guardedFiles.allowlist`）时照旧加载。理由：一年前按工具名与参数做字符串匹配就能判断，现在前沿模型写一次性脚本、串联 shell 命令，静态判断某次调用的后果"几乎不可能"，检查是否含 `rm -rf` 只给人虚假的安全感；权限因此移到 Plugin API，"需要策略就按自己的环境建一个"。**编辑或恢复消息时不再回滚文件改动**："模型已足够好，能比回滚更细致地替你撤销改动"，且回滚本来只是尽力而为。也移除了用户可调用的 skills；消息排队成为默认（模型工作更久、需要更少中途打断）。
- 未见：数值评测。

### C14 langchain-ai/deepagents 按模型的 harness profile
- 元信息：读的是 PyPI 发布包 deepagents 0.7.32 的 `deepagents/profiles/harness/`（GitHub 不可达，无 commit SHA；JS 版 deepagentsjs 1.15.1 已下载但未逐文件比对）｜ 级 C（代码）
- 事实：共 5 个 profile。`_anthropic_opus_4_7.py` 只匹配 `anthropic:claude-opus-4-7`，在通用 Claude 指导之外追加专属段落，用来抵消该模型"在未另行提示时比前几代 Opus 更少使用工具、派生 subagent"的已记录倾向，出处注为 Anthropic 提示词最佳实践页（即 C5）。`_anthropic_sonnet_4_6.py`、`_anthropic_haiku_4_5.py` 只加通用 Claude 指导，并在注释里说明不加专属段落的理由：指南里关于过度 / 不足使用的片段是标给 Opus 4.5 / 4.6 的，不适用于这两个模型。`_openai_codex.py` 只对 `openai:gpt-5.1-codex`、`gpt-5.2-codex`、`gpt-5.3-codex` 生效，按模型键注册以免改变其他 OpenAI 模型的默认行为。`_nvidia_nemotron_3_ultra.py`（1,857 行）针对 Nemotron 3 Ultra 550B 在工具调用、文件系统、上下文管理与最终答案上的观察到的行为，加入提示与 middleware。
- 代码证明的：补偿是按模型逐个登记、按模型键精确匹配的，每条都写明针对哪个模型的哪种行为；该版本中**没有** Claude 5 代、GPT-6 家族或 Gemini 的 profile。代码不证明：这些 profile 在对应模型上确实有益。

### C15 Mastra 的"末尾 assistant 消息"防护
- 元信息：读的是 npm 发布包 @mastra/core 1.79.0（GitHub 不可达，无 commit SHA）｜ 级 C（代码）
- 事实：两层。①`PrefillErrorHandler`（`src/processors/prefill-error-handler.ts`，默认挂在每个 agent 的 errorProcessors 上）：按三条供应商报错文本匹配（"does not support assistant message prefill"、prefill 与 thinking 不兼容、"requests ending with a model turn are not supported"），首次重试时注入一条隐藏的 `system-reminder`（内容为 continue）再重试；文档说明它改为对 API 拒绝本身作出反应，而不是重新检查消息形状。②显式的模型代际判断：`supportsAssistantPrefill` 用正则解析 Claude 版本，只有低于 4.6 才算支持 prefill，源码注释写明"Claude 4.6 及以后拒绝 assistant prefill 请求"，未知的 Anthropic 版本按保守处理（视为不支持）；`supportsTrailingModelTurn` 只对 Gemini 3 以下返回支持，注释写明"Gemini 3 及以后对以模型轮结尾的请求返回 400"。
- 代码证明的：这是一个因新一代模型改变接口约束而**新增**的 harness 组件，并按模型代际开关；代码不证明其对质量的影响。

### C16 OpenAI Cookbook《Codex Prompting Guide》
- 元信息：OpenAI ｜ 页面显示日期 2026-02-25 ｜ https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide（旧 GPT-5-Codex 指南地址已不可用）｜ 读的是核验代理 2026-10-25 保存的页面 ｜ 级 C
- 事实：迁移步骤要求"删掉所有让模型在执行过程中交代前期计划、preamble 或其他状态更新的提示"，理由是这会让模型在执行完成前突然停下。同页又说明：gpt-5.3-codex 之前的 Codex 版本，执行中的用户更新由系统生成、不可提示，因此不建议为它们写中间计划或给用户的消息；**从 gpt-5.3-codex 起**这些更新可以按"Preambles & Personality"一节提示，并须配合 Responses API 新增的 `phase` 字段（assistant 输出项上的 `commentary` / `final_answer`），用来防止请求 preamble 时提前停止；`phase` 目前只支持 gpt-5.3-codex，且对它是必需的——重建历史时丢掉 assistant 的 `phase` 元数据会造成"显著的性能下降"。
- 注：同一页面同时保留了"删除"与"按新模型重新允许"两条，页面未给出各自的生效时间或评测数字。

## D. Skills 与上下文文件

### D1 2602.12670《SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks》
- 元信息：BenchFlow 牵头，另有 OSU、Amazon、UC Berkeley、Stanford、CMU、Princeton、Oxford 等 35 个机构 ｜ v1 2026-02-13，读 v4 2026-06-14（并对照 v1 HTML）｜ https://arxiv.org/abs/2602.12670 ｜ github.com/benchflow-ai/benchflow；称公开基准、harness 与轨迹 ｜ 级 A
- 设置（v4）：87 题、8 个领域、每格 3 次、温度 0；18 个配置 = 15 个 OpenHands 配置（GPT-5.5、GPT-5.4 Mini、Claude Opus 4.8 / 4.7、Sonnet 4.6、Gemini 3.1 Pro、3.5 Flash、3.1 Flash Lite、GLM 5.1、Kimi K2.6、DeepSeek V4 Pro / Flash、Grok 4.3、MiniMax M3 / M2.7）+ Claude Code + Opus 4.7、Codex CLI + GPT-5.5、Gemini CLI + Gemini 3.1 Pro。v1：7 个配置（Claude Code 配 Opus 4.5 / 4.6、Sonnet 4.5、Haiku 4.5；Gemini CLI 配 Gemini 3 Pro / Flash；Codex 配 GPT-5.2）、实评 84 题、每题 5 次。
- 数字（v4）：无 skills → 精选 skills 平均 33.9% → 50.5%（+16.6 pp，归一化增益 25.5%），配置间 +4.1（OpenHands + Gemini 3.1 Flash Lite）至 +25.7（OpenHands + GLM 5.1）；作者 Finding 2"绝对分最高的系统不一定获益最多"：OpenHands + Gemini 3.5 Flash 无 skills 基线 41.1%（OpenHands 组中较高）只 +7.1，OpenHands + Opus 4.7 42.1 → 53.1（+11.1），最大增益来自 GLM 5.1（+25.7）、Gemini CLI + 3.1 Pro（+24.8）、DeepSeek V4 Pro（+23.2）；同模型不同 harness（都带 skills）：Opus 4.7 在 Claude Code 61.2 vs OpenHands 53.1、Gemini 3.1 Pro 60.8 vs 52.8、GPT-5.5 Codex 66.5 vs OpenHands 67.3；skill 数量 1 个 +18.0、2–3 个 +19.0、≥4 个 +10.1；"全面型" skill +0.7。负增益任务 13/87（最大 −7.4 pp）；领域跨度 +9.7（数学与运筹）至 +28.8（自然科学），软件工程 +11.6。
- **v1 → v4 的关键变化（本次核验重点）**：①自生成 skills 条件**仍在**，但移出主汇总、只在 3 个专用 harness 配置上作诊断，结论是"在全部三个配置上都低于无 skills 基线"：Claude Code + Opus 4.7 43.0 → 34.9（−8.1，精选 +18.2）、Codex + GPT-5.5 46.8 → 35.5（−11.3，精选 +19.7）、Gemini CLI + 3.1 Pro 36.0 → 24.5（−11.5，精选 +24.8）；协议也变了（v1 单会话提示自写；v4 两个隔离会话，先用 Anthropic 的 skill-creator 写、再求解；Claude Code 自生成组用 effort max、基线用 high）；作者审计称该缺口混合了内容质量、skill 未被发现与创作者/求解者干扰，并称其"最明显的赢处是泄漏而非复用"。v1 结果是 5 个配置平均 −1.3 pp。②v4 摘要删掉了自生成 skills 与"16/84 题负增益"两句；正文仍报负增益，但从 16/84（最大 −39.3 pp）缩为 13/87（最大 −7.4）。③v1 的领域跨度 +4.5（软件工程）至 +51.9（医疗）在 v4 中不复存在（医疗、制造不再单列）。
- 线索更正：上一轮笔记写"v1：自写 skills 无平均收益、16/84 题变差"——16/84 指的是**精选** skills 的负增益任务，不是自写 skills。
- 作者局限：无等长或无关文本对照；Claude 模型训练时已知 Skills 规范；模型 / harness 有限；CI 为 Wald 区间。

### D2 2602.11988《Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?》
- 元信息：ETH Zurich（Gloaguen、Mündler-Sasahara、Vechev）+ LogicStar.ai（M. N. Müller、Raychev）｜ v1 2026-02-12，读 v3 2026-09-29 ｜ https://arxiv.org/abs/2602.11988 ｜ v1 链接 github.com/eth-sri/agentbench，v3 HTML 未见代码链接 ｜ 级 A
- 设置：Claude Code + Sonnet-4.5、Codex + GPT-5.2、Codex + GPT-5.1 mini、Qwen Code + Qwen3-30b-coder；每实例 1 个样本，温度 0（Qwen 0.7）；SWE-bench Lite（300 题、11 个仓库，配 LLM 生成的上下文文件）+ 新建 CTXbench（138 个实例、12 个仓库，开发者提交的上下文文件；v1 称 AGENTbench）。
- 数字：LLM 生成的文件：SWE-bench −0.5%、CTXbench −2%，8 个设置中 5 个下降，CMH 检验 p=0.87 / 0.37；开发者写的文件 +2.4%（p=0.21），对除 Claude Code 外的所有 agent 有益（Sonnet 73.2 → 70.3）；开发者 vs LLM 生成 p=0.038。成本：LLM 文件 +20% / +23%（p<0.001），开发者文件最多 +19%，步数 +2.45 / +3.92。指令被遵循：文件提到 uv 时每实例用 1.6 次、没提时 <0.01；仓库专用工具 2.5 次 vs <0.05。仓库概览：Sonnet 生成的文件 100% 含概览，但不减少到达首个相关文件的步数（仅图）。更强模型生成的文件并不更好（+2% / −3%）。
- v1 → v3：摘要从"上下文文件倾向于降低成功率"改为"总体不提高成功率"；v3 加入显著性检验与污染、知识截止、类别删除、问题改写等消融。
- 作者建议：暂不使用 LLM 生成的上下文文件；人写的文件只放 README 里没有的指令（非标准约定、非功能需求），上线前严格评测。
- 作者局限：只有 Python；每实例单样本；只看解决率。n=138 时标准误约 3–4 pp，足以淹没 2–4 pp 的差。

### D3 2608.14036《Demystifying Agent Skills: Why They Work—Until They Don't》
- 元信息：Princeton、UCSD、Stanford、USC、JHU ｜ v1 2026-08-14 ｜ https://arxiv.org/abs/2608.14036 ｜ 代码未见 ｜ 级 B（两套配对、无代码）
- 设置：Codex + GPT-5.3-Codex、Gemini CLI + Gemini-3.1-Pro-Preview（RQ4 换 GPT-5.4）；Terminal-Bench Pro、TB 2.0、SkillsBench（v1 的 86 题）的子集，Harbor 上每题 5 次；528 个配对三元组、8,135 条记录；分类体系来自 238 个标签（人与 LLM 映射一致率 95.8%）。
- 数字：成功率 skill 61.9% vs 原始 59.1% vs workflow memory 55.9%；skill − workflow memory = +6.06 pp，95% CI [+0.76, +11.36]；**skill − 原始 = +2.84，CI [−2.27, +7.95]，不显著**。机制标签中"程序性锚定"占 65.7%、"显式知识注入"4.5%（LLM 判定的标签，n=528）。skill 被误用或忽略占 10.0%（原始 0.8%）。实际使用精度（解析出"被使用"的 skill 中属于正确集合的比例）随候选池 5 → 100 从 29.6% 降到 3.3%，而成功率 36.4 → 39.3 并未下降。
- 作者局限：配置少；分类只覆盖约 3% 的记录；每组只一条轨迹；token 数据不全。

### D4 2610.04832《Agent Skill Evolution: How Revisions Affect Coding Agents》
- 元信息：亚利桑那大学、CSU Long Beach、NTU Singapore、中科院信工所、武汉大学、East Carolina U. ｜ v1 2026-10-04 ｜ https://arxiv.org/abs/2610.04832 ｜ figshare 复现包 ｜ 级 A
- 设置：3,159 个 skill 的 2,608 对首末版本；21 个模型（16 个 3.8B–32B 开源模型 + Claude Sonnet 3.5 / 3.7 / 4.5、Haiku 4.5、GPT-5.5 reasoning none），关闭 thinking；"四个 agent"实为同一 mini-SWE-agent 脚手架（12 步、无网络）下的 4 个模型（Qwen 3.5-9B / 27B、Devstral-Small-2507、Claude Sonnet 4.5）；396 个探针、80 个任务。
- 数字：55% 的修订改的是规则或流程；修订 skill 的提交比同等规模提交更常改 CLAUDE.md 一类 harness 文件。新增一条规则：16 个开源模型单答合规 +0.41；四个模型的"执行所需动作"率 +0.23 [+0.15, +0.31]（+0.16 至 +0.36，Sonnet 从 0.62 起 +0.19）；人工盲评的最终正确率 +0.10（+0.06 至 +0.14）。收益主要来自点名旧 skill 没提到的命令或路径。按需加载 skill 正文时保留约 51% 的动作收益（三个开源模型 38%）。成本：一次修订让单答输入 token +18–19%、对整个 episode 无可测成本；加载 skill 正文让 episode token 平均 +50%（37–57%）。
- 线索更正："四个 agent"= 一个脚手架里的四个模型。
- 作者局限：只研究可机械检查的规则（占指令 17%，禁止性与权限护栏代表性不足）；无推理模型；单脚手架且输出截断到 2k 字符。作者称"新旧两代模型从规则修订中获益相近"，但只在小型、非推理模型梯队内。

### D5 2610.08875《An Empirical Study of Agent Skills' Downstream Utility》
- 元信息：浙江大学、江西师范大学、CSIRO's Data61 ｜ v1 2026-10-06，读 v2 2026-10-08 ｜ https://arxiv.org/abs/2610.08875 ｜ 匿名代码仓库 ｜ 级 A
- 设置：9 个配置 = {GPT-5.5、DeepSeek-V4-Flash、Qwen3.5-27B} × {Codex、OpenCode、OpenClaw}；SkillsBench 87 题；每条件 3 次；37,596 个市场 skill 作候选库。
- 数字：基准自带 skills 在全部 9 个配置上提高通过率 +4.60 至 +19.54 pp；同 harness 下 GPT 比 Qwen 多得 3.45–8.43 pp（OpenCode 上 GPT +19.54、Qwen +11.11）；同一组 skill 在 32/87 = **36.78%** 的任务上对部分配置有益、对另一部分有害；按"对所需操作的支持"重排后首选通过率 +4.35 / +4.35 / +5.80 pp（约为 69 组中 3 次运行的差）。
- 作者局限：只 3 次重复；skill 组的提示里明确要求使用 skill、无 skill 组没有；只看通过率不看成本。

### D6 2609.09233《Subagents vs Agent Skills: Executing Reusable Knowledge for Long-Horizon Agentic Tasks》
- 元信息：Cornell（一作为 MSR 实习生）+ Microsoft Research Cambridge ｜ v1 2026-09-07 ｜ https://arxiv.org/abs/2609.09233 ｜ 代码未见 ｜ 级 B（仅图、无代码）
- 设置：OpenHands；SkillsBench 87 题中能合成"契约式 skill"的 64 题；模型 Qwen3.5 2B / 4B / 9B、Ministral-3-8B、Gemma-4-12B-it、GPT-5.x（GPT-5.3 Codex）、Mistral-Large-3、Kimi-K2.6；契约式 skill 由 Copilot CLI（Claude Opus 5）从 GPT-5.3-Codex 在同一批任务上的成功轨迹合成；运行次数未说明。
- 数字（仅图、近似）：精选 skill 在上下文内执行，对每个模型都持平或胜过 subagent 执行；契约式 skill（输入输出契约清晰）则 subagent 胜，小模型胜得最多；加入干扰工具时 subagent 退化更慢；GPT-5.3 Codex 与 Kimi K2.6 在 80% 以上的任务上用 subagent 时峰值上下文更低，但总 token"明显更多"。
- 作者局限：合成 skill 与精选 skill 的比较"不是受控比较"；弱模型的峰值上下文受提前终止干扰；通信成本是未解决问题。

### D7 2606.15017《Are Online Skill and Memory Modules Always Worth Their Tokens? A Budget-Constrained Study of Web Agents》
- 元信息：ServiceNow AI Research、ÉTS Montréal、UBC、McGill ｜ v1 2026-06-12，读 v2 2026-08-30 ｜ https://arxiv.org/abs/2606.15017 ｜ 项目页 sinahmr.github.io/budget-constrained-web-agents ｜ EMNLP 2026 ｜ 级 A
- 设置：AWM、ASI、ReasoningBank（actor 10 步）vs 同预算的普通 actor（15 步 + 可访问性树裁剪）；WebArena 的 Shopping / Reddit / Admin / GitLab 与 WorkArena-L1（33 类任务）；每组 3 次。
- 数字（平均成功率 / 每题千 token）：Gemini 3 Flash 普通 44.78 / 73.6，AWM 39.34 / 99.3、ASI 41.02 / 107.3、ReasoningBank 39.33 / 82.6；GPT-5.4-mini 普通 32.67 / 90.2，AWM 27.02 / 88.5、ASI 29.00 / 99.8、ReasoningBank 24.58 / 81.0；Qwen 3.6-27B 普通 42.14 / 95.5，AWM 38.01 / 115.0、ASI 40.15 / 125.8、ReasoningBank 37.00 / 101.9。WorkArena-L1（Qwen）普通与 ReasoningBank 都是 55.56。消融：不裁剪的 10 步普通 actor（Gemini）在 4 个域中 3 个仍胜 AWM。方差：Shopping 上"3 次中任一成功"比均值高 5.9–8.9 pp、"3 次全成功"低 5.4–10.7 pp，作者称单次运行的比较"能支持相反的标题"。
- 线索更正："常用更少 token"对 Gemini 与 Qwen 成立，对 GPT-5.4-mini 不成立；预算对齐按步数近似。
- 作者局限：两个基准；WorkArena 只测 Qwen；任务不以记忆为重；只研究在线设定。

## E. 自动 harness / skill 优化的有效性

### E1 2607.12227《Rethinking the Evaluation of Harness Evolution for Agents》
- 元信息：AI2、UW（Hajishirzi、Tsvetkov、N. A. Smith、Dasigi）等 ｜ v1 2026-07-14，读 v4 2026-10-05 ｜ https://arxiv.org/abs/2607.12227 ｜ github.com/rethinking-harness-evolution ｜ 级 A
- 设置：重评 AHE（关闭其探索 agent，称"Harness Evolution"）并新增逐题的"Harness Scaling"；**未重跑 Meta-Harness**；TB 2.1（89 题），Claude Opus 4.6、GPT-5.4、GPT-5.4 mini；预算 K=5；两次平均。
- 数字：无测试用例时平均 pass@1：直接 68.2、并行采样 72.3、顺序修订 69.3、Harness Evolution 67.4（GPT-5.4 75.3 → 69.7）、Harness Scaling 71.8；有测试用例时：直接 67.6、并行 82.0、顺序 76.9、Harness Evolution 69.7、Harness Scaling 75.5。留出划分（45 训练 / 10 验证 / 34 测试）：Harness Evolution 留出增益 +0.0。ARC-AGI-3（25 局，RHAE）：Opus 4.8 原生 Claude Code 44.3、同预算搜索基线 VISTA* 43.3 → 完整 harness 77.5（相对搜索基线 +79.0%）；GPT-5.6 Terra 原生 Codex 4.6、VISTA* 21.1 → 38.2（+81.0%）；EdgeBench 游戏（12 小时、2 次）Opus 4.8 48.3 → 54.7（+13.3%）、GPT-5.4 45.9 → 49.8（+8.5%）。
- 线索更正：摘要的 +80% / +11% 来自**逐任务的 Harness Scaling**，不是一个可复用的进化后 harness。
- 作者局限：Terminal-Bench 可能对 harness 不敏感或已被训练覆盖；游戏上的增益是任务特定的。

### E2 2610.22466《Harness-Delta Attribution: Dissecting Gains From Harness Evolution》
- 元信息：Amazon + New York University（Durrett）｜ v1 2026-10-15 ｜ https://arxiv.org/abs/2610.22466 ｜ github.com/Wenwen-D/HarnessDeltaAttribution ｜ 级 A
- 设置：11 个执行模型（9 个 Qwen3 / 3.5 / 3.6、Claude Haiku 4.5、Claude Opus 4.8）；三个框架：Meta-Harness（16 个设置）、SkillOpt（6 个；描述为"由独立优化模型把打分后的 rollout 变成对 skill 文档的有界编辑"，与本仓库 `analysis/13-skillopt.md` 分析的 Microsoft SkillOpt 一致，是否同一项目待核验）、AHE（3 个）；LiveMath、SWE-bench Verified、CREATE、ALFWorld；25 个设置中 21 个有显著搜索集增益。
- 数字：平均 ≥54% 的增益归于过拟合、14% 归于 test-time scaling，两者合计在 21 个中 14 个超过 50%；排除 ALFWorld 后，15 个设置中 13 个留出增益小于搜索集增益、8 个不到一半、4 个低于基线；ALFWorld 迁移好但 89% 是过拟合；按验证集挑选在 16 个设置中 10 个变好、6 个变差，14 个仍低于搜索集增益。
- 线索更正：机构为 Amazon + NYU，不是 UT Austin。
- 作者局限：过拟合份额是下界、剩余是上界；"中和"产物由 LLM 代理完成。

### E3 2604.25850《Agentic Harness Engineering: Observability-Driven Automatic Evolution of Coding-Agent Harnesses》
- 元信息：复旦、北大、上海奇绩智峰 ｜ v1 2026-04-28，读 v4 2026-05-18 ｜ https://arxiv.org/abs/2604.25850 ｜ github.com/china-qijizhifeng/agentic-harness-engineering ｜ 级 B（单模型、单次搜索、无留出集）
- 设置：所有角色 agent 用 GPT-5.4（high）；一次 10 轮进化（约 32 小时），每题 2 次 rollout；在全部 89 道 TB2 上进化并在同一集合上报告（**搜索集 = 报告集**）。
- 数字：TB2 种子 69.7 → AHE 77.0；Codex 71.9、Terminus-2 62.9、OpenCode 47.2、ACE 68.9（低于种子）、TF-GRPO 72.3；困难档 AHE 53.3 < Codex 56.7。SWE-bench Verified 75.6 vs 种子 75.2（+0.4）、token −12%。跨模型（仍在 TB2）：deepseek-v4-flash +10.1、qwen-3.6-plus +6.3、gemini-3.1-flash-lite +5.1、GPT-5.4 medium / xhigh 各 +2.3。消融（只给种子加单个组件）：memory 75.3、tools 73.0、middleware 71.9、system prompt 67.4（低于种子 69.7），效应不可加。
- 作者局限："高方差设定"；超时等工作点按 GPT-5.4 high 调定；护栏不完整。

### E4 2607.13083《Phantom Guardrails: When Self-Improving Agent Harnesses Fix Failures That Never Happened》
- 元信息：CMU 校友、Corespeed Inc.、Georgia Tech、独立研究者 ｜ v1 2026-07-13 ｜ https://arxiv.org/abs/2607.13083 ｜ 代码未见 ｜ 级 B（玩具实验室、无代码）
- 设置：确定性微型实验室，正确动作是"什么都不做"：植入一个针对从未发生的失败类别的候选护栏，只给合法 episode，用字节级 oracle 核对每条被引用的违规；proposer 为 deepseek-v4-pro / flash、qwen3.7-max、qwen3.6-max-preview、glm-5.1，60 次 = 5 × 4 子池 × 3 种子。
- 数字：合法输入含"像游戏规则"的无害模式时，15/60 次启用了不存在规则的护栏并引用了被 oracle 驳回的违规，无特征输入 0/60（z=4.14）；主要来自一个模型（glm-5.1 11/12）。三个条件（规则形状的模式、开放的规则集、预设"有失败"的指令）缺一即为 0；只追加不删除、"不变差即接受"的循环中跨轮从 1/60 升到 11/60，一旦进入就留下；要求"有据才接受"时 0/60。
- 作者局限：一个实验室、一种体裁先验（棋盘规则）。

### E5 2510.04618 ACE（Agentic Context Engineering）
- Stanford、SambaNova、UC Berkeley ｜ v1 2025-10-06 ｜ ICLR 2026 ｜ https://arxiv.org/abs/2510.04618 ｜ github.com/ace-agent/ace ｜ 把上下文当作不断累积、精炼的"playbook"做增量更新以防坍缩；agent 任务 +10.6%、金融 +8.6%；AppWorld 上用 DeepSeek-V3.1 总体追平榜首生产 agent、在 test-challenge 上超过 ｜ 级 A。（注：E3 的 TB2 表中 ACE 68.9 低于 AHE 的种子 69.7。）

### E6 2507.19457 GEPA（Reflective Prompt Evolution）
- UC Berkeley、Stanford、Databricks、Notre Dame、MIT、BespokeLabs.ai ｜ v1 2025-07-25 ｜ ICLR 2026 Oral ｜ https://arxiv.org/abs/2507.19457 ｜ github.com/gepa-ai/gepa ｜ 以自然语言反思采样轨迹来进化 prompt：六个任务上平均比 GRPO 高 6%、最多 20%，rollout 少至 1/35；比 MIPROv2 高 10% 以上（AIME-2025 +12%）｜ 级 A。（注：A2 Table 4 中 GEPA 在文本分类搜索集上中位 32.6，低于 Meta-Harness 的 50.0。）

## F. 噪声底线与测量协议

### F1 2602.07150《On Randomness in Agentic Evals》
- 元信息：KTH ｜ v1 2026-02-06，读 v3 2026-03-25 ｜ https://arxiv.org/abs/2602.07150 ｜ github.com/ASSERT-KTH/agentic-evals-lab + HF 数据 ｜ 级 A
- 设置：Qwen3-32B、DeepSWE-preview、Devstral-2-123B × 两个温度（默认与 0）× 10 次 × 两个脚手架（作者自写、确保未进训练集的 nano-agent，与 R2E-Gym）= 120 次 × SWE-bench Verified 500 题 = 60,000 条轨迹。
- 数字：单次运行 pass@1 随所选运行变动 2.2 pp（Qwen + nano，T=0.6）至 6.0 pp（Devstral + nano，T=0）；温度 0 下 SD：nano 1.2 / 1.0 / 1.6、r2e 1.8 / 1.5 / 1.7；DeepSWE 在 nano 上 T=1.0 31.4 vs T=0 20.4；固定模型跨脚手架（正文 Table 1，10 次均值 ± SD）：Devstral-2 nano 63.5±1.1 vs r2e 34.9±1.5，Qwen3-32B 方向相反 16.4±0.7 vs 23.9±1.4；pass@1 34.4 → pass@5 52.9、pass^5 15.5（DeepSWE + r2e）；轨迹首次分叉总在前 1% 之内。80% 功效：检出 2 pp 需 9 次运行（σ=1.5）、σ=1.8 时 13 次；检出 1 pp 需 36 次。作者结论：报告的 2–3 pp 改进可能只是噪声。
- 线索更正："温度 0 下 SD 仍 >1.5 pp"只对 6 个温度 0 配置中的 3 个成立。
- 作者局限：一个基准、只有开源模型；功效分析假设正态。

### F2 Anthropic《Quantifying infrastructure noise in agentic coding evals》
- 元信息：Gian Segato ｜ 发布 2026-02-05 ｜ https://www.anthropic.com/research/infrastructure-noise ｜ 级 C（内部测量、给 p 值，未经独立复现）
- 设置：Terminal-Bench 2.0 跑在 GKE 上，"同一 Claude 模型、同一 harness、同一任务集"，只变沙箱资源：从 1x（任务规格同时作下限与硬杀线）到不设上限共六档；模型未点名、运行次数未说明。
- 数字：基础设施错误率 1x 5.8% → 3x 2.1%（p<0.001）→ 不设上限 0.5%；成功率 1x–3x 之间在噪声内（p=0.40），3x → 不设上限再涨"近 4 个百分点"，总计 **+6 个百分点（p<0.01）**；换其他 Anthropic 模型方向一致、幅度不同；非 Claude 模型未严格测。SWE-bench 交叉验证：内存到 5x、227 题 × 10 样本，单调上升，5x 时 +1.54 pp。
- **线索更正**：原文不是"<3 pp 一律视为未证实"，而是"低于 3 个百分点的榜单差距在评测配置被记录并对齐之前值得怀疑"；中等配置之间的差约"略低于 2"pp；朴素二项置信区间本身已有 1–2 pp，混杂因素叠加其上。
- 建议：评测脚手架与推理栈尽量同硬件；每任务同时规定保证配额与硬杀阈值，并报告倍数；把资源配置当一等实验变量（与 prompt 格式、温度同级）；多时段、多日运行（时段效应有轶事观察、未量化）。

### F3 Anthropic《Demystifying evals for AI agents》
- 元信息：Grace、Hadfield、Olivares、De Jonghe ｜ 发布 2026-01-09 ｜ https://www.anthropic.com/research/demystifying-evals-for-ai-agents ｜ 级 C
- 要点：评测的是"harness 与模型一起工作"；pass@k 与 pass^k 在 k=1 时相同、到 k=10 讲相反的故事（例：0.75³≈42%）；每个 trial 从干净环境起步（共享状态会抬分：Claude 读到了前一 trial 留下的 git 历史）；"给它产出的东西打分，而不是它走的路径"（示例里仍有工具调用与 transcript 评分器）；起步"20–50 个取自真实失败的简单任务就很好"，成熟 agent 需要更大更难的集才能测出更小的效应；两位专家能给出相同判定、每题有参考解，"pass@100 为 0% 多半说明题坏了"；capability eval 起点低、regression eval 接近 100%，前者毕业进后者；"不读 transcript 之前不按表面值相信分数"；约束过紧的脚手架会扭曲分数——Opus 4.5 在 CORE-Bench 上经评分修复与"约束更少的脚手架"后从 42% 到 95%；100% 的 eval 只能追回归、不提供改进信号。
- 未给出显著性检验或最少 trial 数规则。

### F4 2510.11977《Holistic Agent Leaderboard: The Missing Infrastructure for AI Agent Evaluation》（HAL）
- 元信息：Princeton 牵头（文中未逐一列出机构；平台 hal.cs.princeton.edu）｜ v1 2025-10-13 ｜ https://arxiv.org/abs/2510.11977 ｜ github.com/princeton-pli/hal-harness + HF 轨迹 ｜ 级 A（但多数为单次运行）
- 设置：9 个模型（o3、GPT-4.1、GPT-5、Claude Sonnet 3.7、Opus 4.1、DeepSeek V3 / R1、o4-mini、Gemini 2.0 Flash）× 9 个基准（Online Mind2Web、AssistantBench、GAIA、CORE-Bench Hard、ScienceAgentBench、SciCode、SWE-bench Verified Mini 50 题、USACO、TAU-bench Airline）；21,730 次 rollout、约 $40,000；标准化 harness 在数百台 VM 上并行。
- 数字：36 个"模型-agent-基准"组合中 21 个在更高推理强度下准确率**持平或更低**；Online Mind2Web 上 SeeAct + GPT-5 Medium $171 vs BrowserUse + Sonnet 4 $1,577（约 9× 成本）而准确率只差约 2 pp，且 Claude 系在 BrowserUse 下更好、OpenAI 系在 SeeAct 下更好（脚手架排名随模型家族翻转）；任务特化脚手架胜过通用脚手架（CORE-Bench 9/12、SWE Mini 11/12），通用脚手架在 24 次比较中 20 次更便宜。LLM 辅助的日志检查发现 agent 去 HuggingFace 搜基准答案、在航班预订任务中误用信用卡。
- 线索更正："多数运行中更高推理降低准确率"应为"21/36 组合持平或更低"。
- 作者局限：多数评测"只能依赖单次运行、无统计验证"；公开测试集；推理档位跨厂商不可比；OpenRouter 可能切换量化版本。

### F5 2610.30499《Can LLMs Improve Their Own Harness? A Controlled Study on ARC-AGI-3》
- 元信息：Lehmann（Amazon，注明"在 Amazon 之外完成"；TU Dresden）、Vahdati（汉诺威大学 / TIB）｜ v1 2026-10-21 ｜ https://arxiv.org/abs/2610.30499 ｜ 附代码 / 数据存档 ｜ 级 A（单基准）
- 设置：9 个模型-强度条件（GPT-6 Astra high、GPT-5.6 Sol high / xhigh、GPT-5.6 Terra high、GPT-5.6 Luna high、Claude Fable 5 high、Opus 5 high / xhigh、Sonnet 5 high）× 3 次构建 = 27 条谱系；经固定的编码引导（OpenCode）各自搭出完整 harness，在 5 个开发游戏上行动并整库修订两次；每个版本在 20 个从不参与适配的留出游戏上评估（RHAE：关卡完成度 × 相对人类的动作效率）；81 个快照、2,025 次游戏评估、10 万次谱系级 bootstrap。
- 数字：第 2 次修订后开发集 +8.42、留出集 **+2.80 [−1.44, 7.35]**；15 升 12 降（p=.70）；适配差距 5.62 [1.78, 9.77]；harness 得分从 0.00（Sonnet 5）到 97.55（Astra）；同一个 harness 复评 10 次 SD 3.99（43.38–55.37）——自我修订的平均增益小于单个 harness 的复评标准差；人工引导系统 Tycho 达 100，这些 harness 平均 39.95。成本：平均每局 −$2.72，但 27 条中 9 条更便宜却更差。
- 作者局限：一个基准、两轮修订；公开游戏可能在训练数据中；每条件 3 次；花费、模型、harness 未完全分离。

### F6 背景（维护者已核验，此处只作语境）
- 当前前沿 Claude 模型拒绝非默认的 `temperature` / `top_p` / `top_k`，"温度 0"式评测在这些模型上已不可用；F1 也表明即使温度 0，同配置的运行间 SD 仍有 1.0–1.8 pp。方差只能靠多样本估计。

## 条目间的冲突与张力（显式标注，不作调和）

1. **固定模型时 harness 效应的大小**：通过率上，能力对齐的比较大多小于噪声或不显著（A3 ≤8 pp 且 CI 含 0；A6 解决率"大体相近"；A8 遮蔽 ≈ 摘要；A9 35 个版本无趋势）；A1 的"6×"是单次运行下 6/50 vs 1/50。显著的大效应出现在 harness 改变"能接触到什么"时（A5 bash +22–25 pp；A7 超出窗口的输入），以及 F1 的 10 次重复下 Devstral-2 nano-agent 63.5±1.1 vs R2E-Gym 34.9±1.5（Qwen3-32B 方向相反：16.4 vs 23.9）。成本上的效应则一贯大且可分辨（A3 约 40×、A4 token 5–28×、A5 −19%至−72%、A9 +70%、F4 约 9×）。
2. **bash-only vs 预定义工具**：A5 对前沿模型 bash 单独使用比 typed tools 高 21.8–24.5 pp，往 bash 上加 typed tools 无可测增益；B1 同一处理让 Mistral-Medium-3.5-128B 在 SWE-bench Verified 掉 23.2 pp、在 TB 2.1 涨 6.7 pp，30B 掉 15.0 pp，只有 550B 涨 3.6 pp；A6 结构化低层接口让弱 actor 的重复一致性（pass^9）提高 4.7×，却给强 actor 加 20% 输入 token；F4 任务特化脚手架胜过通用脚手架。B1 作者把分界归到 bash 熟练度而非规模。
3. **观察遮蔽 / 上下文管理**：A8 遮蔽 ≈ LLM 摘要、成本约减半，但最强配置在两种策略下都显著掉分；B2 收益呈倒 U、在饱和模型上接近 0 或为负；B1 的价值主要是防溢出、随窗口变大而缩小，可召回的被删内容几乎没人用。
4. **skills / 上下文文件是否有用**：D1 精选 skills 平均 +16.6 pp、D5 九个配置全部为正；但 D3 skill 对比"什么都不加"只有 +2.84 pp（CI 含 0），D7 同预算普通 actor 追平或超过 skill / memory 模块，D2 上下文文件总体不提高成功率而成本 +20%，D5 同一组 skills 在 36.78% 的任务上对一些配置有益、对另一些有害。
5. **谁写的程序性知识有用**：D1 v4 自生成 skills 在三个配置上全部低于无 skills（−8.1 至 −11.5 pp），D2 LLM 生成的上下文文件不如开发者写的（p=0.038）；B3 却称更新者能力与基础能力无关（Qwen3.5-9B ≈ Opus 4.6）。B3 是从执行证据中更新、D1 是事前凭空写；D6、D3 中"由成功轨迹合成"的 skill 表现好，但用的是同一批任务的数据——D1 自己的审计把自生成条件"最明显的赢处"归为泄漏。
6. **弱端谁获益最多**：B5 最小模型从注入的上下文中获益最多；B3 最弱模型从 skill 更新中获益最少（加载率 0.251、遵循率 0.142）；D5 更强的 GPT-5.5 比 Qwen 多得 3.45–8.43 pp；D1 Finding 2 称绝对分最高的系统不一定获益最多；E3 跨模型迁移时弱基座获益更多。
7. **自动 harness 优化的增益**：A2（Meta-Harness）与 E3（AHE）报告大幅增益，二者在 TB2 上都是搜索集 = 报告集；E1 重评 AHE（未重跑 Meta-Harness），同预算下不胜并行采样、留出增益 +0.0；E2 覆盖 Meta-Harness、SkillOpt、AHE，平均 ≥54% 的增益归于过拟合、14% 归于额外推理；F5 两轮自我修订的留出增益 +2.80、CI 跨零、小于单个 harness 复评 SD 3.99；E3 的 TB2 表里 ACE 低于其种子。唯一同预算下的大胜是有余量任务上的逐题搜索（E1 ARC-AGI-3 +79–81%）。
8. **固定模型上 harness 版本的效应**：A9 35 个版本解决率 23.0–39.0% 而无趋势，两次运行间 12.3% 的结果翻转；A10（Qwen Code 自报）见该条；F1 的单次运行波动 2.2–6.0 pp。
9. **厂商文档内部**：C5 Opus 5 页要求删掉显式验证指令与"加独立验证步骤的旧式 harness 脚手架"；同一套文档的 Fable 5 页要求新上下文 verifier subagent 与按工具结果审计进度声明；C6 把验证列为 subagent 仍然有效的用途；`analysis/19-anthropic-harness-design-long-running-apps.md` 记录评估器只在任务处于能力边缘时值得。
10. **厂商前后反转**：C2（2025）对 few-shot 示例"仍强烈建议" → C1（2026）对最新模型的工具用法示例起反作用。Cognition 2025《Don't Build Multi-Agents》→ 2026《Multi-Agents: What's Actually Working》（C7，正文待核验）。
11. **多 agent 协调**：B4 可分解任务上多 agent 相对单 agent +80.8%、顺序规划上 −70.0%，单 agent 基线过约 45% 后协调不再划算；C6 建议把路由 / 规划 / 领域 subagent 折回主 loop，但保留并行、可丢弃上下文与验证用途。
12. **基座模型是否随脚手架稳定**：B7 称未微调的基座不随脚手架分化，但其自身表中基座 Qwen3-32B 为 29.0 / 23.2 / 18.4 / 8.0；F1 的 10 次重复也显示固定模型跨脚手架差异很大（见第 1 条）。

## 对本仓库论点的直接相关性

只按条目归类、不作论证；归类对象是命题"补偿性组件的价值随模型变强单调下降"。

- **支持**：B1（规划的准确率价值 +11.6 → −2.0 pp；预定义工具对 550B 无益；被删内容的召回几乎没人用，强模型更少）；B4（单 agent 基线越过约 45% 后协调不再划算）；B5（工程化 prompt + 上下文 +86% → 前沿模型 +2%，额外上下文只帮最小模型）；B6（程序性 harness 蒸馏进模型后再挂回无益）；A2（发现的 harness 相对种子在 Haiku 上增益大于 Opus）；A6（Atomic 工具修弱模型的交互错误，对强模型只加 token）；E3（跨模型迁移时弱基座获益更多，作者注明与工作点有关）；C1（删 80%+ system prompt）；C4（todo 工具对新模型移出默认、先读后写限制只对新模型放宽）；C5 通用页与 Opus 5 页（软化强调措辞、删验证指令与旧式验证脚手架）；C6（折叠路由 / 规划 / 领域 subagent）；C8（Astra 不再需要"去跑测试"的鼓励、菜谱式 skill 反而妨碍）；C10（`update_plan` 默认关闭、压缩警告删除）；C11（跨模型家族删约 66% system prompt、删掉鼓励 subagent 的指令）；C12（代码评审 subagent 少用而 eval 不降）；C13（Handoff、编辑回滚被删）；C14（deepagents 的按模型补偿 profile 止于 Opus 4.7 与 gpt-5.3-codex，Claude 5 代与 GPT-6 无条目）；仓库内 `analysis/19-anthropic-harness-design-long-running-apps.md`（context reset、sprint 随代际删除）。
- **使之复杂**（非单调，或取决于"强度"以外的能力剖面、窗口预算、任务余量）：B2（遮蔽收益倒 U，同架构新一代 +11.7 → +3.7）；B3（收益在中档最大，SkillsBench 上峰值在 Haiku）；B1 的动作空间（由 bash 熟练度而非规模决定，Mistral 在 SWE −23.2、在 TB +6.7）与上下文管理（由窗口预算决定）；A8（最强配置在两种上下文管理下都显著掉分）；A7（超出窗口的输入上，环境托管上下文对前沿模型仍有大增益，但相对同模型 OpenCode + 卸载只 +2.4%）；D1（skill 增益与基座强度不单调；同模型换 harness 差约 8 pp）；D4（新旧两代从规则修订中获益相近）；D6（契约式 skill 走 subagent 对小模型最有利）；E1（有余量的任务上逐题 harness 搜索对 Opus 4.8 / GPT-5.6 Terra 仍有 +79–81%）；B7（微调把模型与训练脚手架绑定，离开即掉最多 29 分）；F1（10 次重复下，组内最强的 Devstral-2 换脚手架差 28.6 pp，最弱的 Qwen3-32B 方向相反）；C3（单行 prompt 与 thinking 裁剪 bug 让强模型退化，harness 在任何强度上都可能有害）；C5 Fable 5 页（对最强模型新增 verifier subagent 与证据审计）；C8（为防旧模型越权写的强硬边界措辞会让 Astra 过早停下，建议改写，同时为安全工作流显式授权）；C11（保留 `ask_question` 是因为有些模型会幻觉出对它的调用——针对特定模型的补偿仍在）；C13（默认关闭运行前许可，理由是对能写一次性脚本的模型做静态字符串匹配已无效，权限改由插件策略承担）；C15（新一代模型改变接口约束后**新增**的兼容组件：Claude ≥4.6 拒绝 prefill、Gemini ≥3 拒绝以模型轮结尾）；C16（对旧 Codex 模型删掉的计划 / preamble 提示，从 gpt-5.3-codex 起配合 `phase` 字段重新允许——一个为更新的模型回来的补偿）；仓库内 `analysis/19-anthropic-harness-design-long-running-apps.md` 的"评估器性价比取决于任务难度相对模型能力"。
- **相反**（某类组件的价值随强度上升，或代价随强度下降）：B8（安全控制的效用代价随能力下降，但对强模型其安全增益在非自适应攻击下也接近 0）；D5（更强的 GPT-5.5 从 skills 中获益多于 Qwen）；C6（折叠 subagent 时，预算、写入闸门、审批闸门、逐用户权限检查留在 harness / 工具里不动）；C12（harness"保留护栏"，只把思考强度与委派交给模型）；A5（对前沿模型 typed 目录不再带来分数，作者给它留下的理由是合规；给 shell 后出现读评测脚本的 reward hacking，需要隔离）。
- **与测量协议直接相关**：F1（SD 0.7–1.8 pp，检出 2 pp 约需 9 次运行）；F2（仅沙箱资源即可移动 6 pp；<3 pp 的差在配置未对齐前存疑）；F3（多 trial、隔离、按结果评分、读 transcript、capability / regression 分离）；F5（自我修订增益 +2.80 小于复评 SD 3.99）；E1、E2（同预算基线与留出集；增益的 54% 为过拟合）；A3、A4（报告 token / 延迟 / 完整 harness 规格；核验实际行为而非指定接口）；A9 与 A10（固定模型下版本间差异与运行噪声同量级；A10 用 500 题 × 3 次）；D7（同预算基线；单次运行可得出相反标题）；C3、C6、C9、C11（按模型的 eval 闸门；看哪些任务翻转；同快照同模型逐条重放消融（C9 只是建议、未报结果）；线上 A/B）。

## 未能核验 / 来源未披露

- **未能核验**：C7 Cognition 两篇的正文（只核验了官方博客索引页上的标题、日期与 slug；综合期间 WebFetch 对所有站点失效，沙箱 curl 连不上 cognition.com 与 web.archive.org，Claude in Chrome 未连接）；C14、C15 读的是 PyPI / npm 发布包而非指定 commit（综合后段 github.com 不可达）；A11 原文正文（挑战页拦截，数字取自 OpenAI 自家另一页面）。2512.08296 的 v1 摘要（抓取超时，只对照了 v2 与 v3）。Meta-Harness 的 COLM 2026 录用只见于项目页元数据。2608.11386 摘要中的"步数 −41.6%、token −56.3%"在正文各表中找不到推导。E2 中的 SkillOpt 是否就是 `analysis/13-skillopt.md` 分析的 Microsoft SkillOpt。C5 通用页在 Claude 4.5 时代的历史版本（只读了当前合并后的页面）。C4 中 Claude Code 各版本的确切日期（由同号 SDK 的 npm 发布时间推定）。
- **来源未披露**（不是核验失败）：C1 没有给出评测名、分数或 trial 数；C3 的"3%"未说明是百分点还是相对值，也未给评测名；F2 未点名模型、未给运行次数；C11 未给 A/B 的流量、时长与质量指标数值；C8、C13 没有数值评测；D6 只有图、没有数值差。
- **本综述自行计算、非原文的数字**：A1 的 Fisher p≈0.11；A4 中 qwen3.6:27b 只看 CLI 组的约 17.6×；A7 相对同模型 OpenCode + 卸载的中位 +2.4%。
- **维护者临时版中的线索（未经本轮核验，未收入正文）**：arXiv 2610.19999（法律 XML 任务，最弱的 Claude 模型放进完整流水线 0.948 胜过最强模型单独使用 0.806）；C1 与 Anthropic《Introducing advanced tool use》（2025-11-24）中工具用法示例建议的抵触；Cognition 2026 一文"写操作留在一个 agent、其余只贡献判断"的概括。
- **他处已核验**：Claude Agent SDK 0.3.268（2026-09-10）把任务工具反转为白名单——只在 Claude 3.x、Opus 4.0–4.7、Sonnet 4.0–4.6、Haiku 4.5 上默认提供，包括认不出的模型 ID 在内其余一律默认关闭；已在 `raw/docs/claude-agent-sdk.md`（TS CHANGELOG @ `019515d3`）核验，本文未复查。
