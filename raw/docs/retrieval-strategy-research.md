# 检索策略研究综述快照：向量 RAG vs Agentic 工具检索（+ grep 工具盘点）

> **来源类型**：多来源 web 研究综合（非单一文章）。
> **抓取/综合日期**：2026-06-02。
> **抓取方式**：两次多代理调研工作流（WebSearch + WebFetch 扇出，深读权威源，对关键论断做对抗式核验），共约 55 个唯一源、核验若干争议论断。
> **重要声明**：本文件是对多个第三方来源观点的**事实性转述与综合（paraphrased digest）**，不是任何来源的逐字拷贝；引用以 URL 标注。所有"实测 vs 厂商自报 vs 营销"的可靠度判断保留在文中。仓库内的解读、对 skill 的影响在 `analysis/12-retrieval-strategy-vector-vs-agentic.md`。

本快照服务于一个工程问题：**一个需要在文档上回答用户问题的 agent，应该用向量数据库 / RAG，还是让模型自己用 grep/read 这类工具迭代检索（agentic retrieval），还是直接长上下文塞进去？** 第二部分附一个具体子调查：grep 类命令行工具有哪些、哪个最高效。

---

## 第一部分：向量 RAG vs Agentic 检索 vs 长上下文

### 1. 核心结论

- **主流已不是"无脑上向量库"**。共识是**按场景分层**：小语料直接塞上下文或让 agent 自己 grep/read；大语料才上检索，且上的是"混合检索（BM25 关键词 + 向量）+ 重排"，纯向量裸跑被判定生产里会静默翻车（来源: https://venturebeat.com/data/the-retrieval-rebuild-why-hybrid-retrieval-intent-tripled-as-enterprise-rag-programs-hit-the-scale-wall）。
- **"RAG 已死 / 向量库已死"是标题党**。准确说法：向量库从"必备品类"被降级为"现成功能"（被 Postgres/Elastic/Mongo/Redis 等吸收为内置能力）；检索本身没死，而是**升级成运行时由 agent 决定"要不要搜 / 搜什么 / 从哪搜"的智能检索**（来源: https://ragflow.io/blog/rag-review-2025-from-rag-to-context）。

### 2. 向量 RAG 现状

- 企业里 RAG 仍是关键基础设施、投入在加深；但**独立向量数据库品类正被既有数据库平台吸收为一个功能**——SQL Server 2025、MongoDB Atlas、Redis、Elasticsearch、Postgres/pgvector 都已原生内置向量搜索（逐项核验全部坐实）。Elastic CEO 名言被反复引用："向量搜索是个功能，从来不是一门生意"（来源: https://venturebeat.com/ai/from-shiny-object-to-sober-reality-the-vector-database-story-two-years-later）。
- ⚠️ 核验：**"品类被商品化"≠"专用向量库已死"**。Qdrant 2026 初拿 5000 万美元 B 轮；十亿级、重过滤、超高写入场景 Pinecone/Qdrant/Milvus 仍结构性领先。
- **pgvector 已成"默认起点"**：托管 Postgres（RDS、Supabase、Neon）多已捆绑，中小规模可把向量与业务数据同库同事务（来源: https://encore.dev/blog/you-probably-dont-need-a-vector-database）。⚠️ "运维更省"只在"向量量级 < ~1000 万、本就在跑 Postgres"时成立。
- 痛点：切块/embedding/重建索引是隐性成本（改切块策略要按整库重计费、数据清洗占成本 30–50%）；纯向量召回有理论天花板；结构化资料被当语义段落会丢结构（来源: https://www.kalviumlabs.ai/blog/rag-in-production-what-it-actually-costs-after-sprint-3/）。

### 3. Agentic 工具检索现状（让 LLM 自己 grep/read）

- 不预建索引，把 `grep`/`glob`/`read_file` 交给模型，让它像资深工程师一样**迭代地**搜：搜一轮、看结果、换关键词再搜、顺引用链跨文件追。
- **Claude Code（最权威一手源头）**：早期用过 RAG + 本地向量库（Voyage embedding），很快全弃用改成纯 agentic search。负责人 Boris Cherny 原话：agentic 检索"碾压了一切，大幅领先"（来源: https://www.latent.space/p/claude-code）。⚠️ 核验：这句"碾压"确实是他说的，但他承认依据"主要凭感觉 + 少量内部基准"，非公开可复现严谨评测——应读成"Anthropic 内部代码搜索场景的体感+内测"，非客观定律。
- 弃用 RAG 四理由（一手）：① 索引复杂、代码一改即 drift；② 向量索引要上传、敏感代码有隐私风险；③ 索引会过时；④ 可靠性。代价被明确承认：**更慢、更费 token**。
- **Cursor 是混合派反例**：未弃向量，用 AST 切块 + 自训 embedding + 向量库 + Merkle 树增量重建，再与 grep 混合；上传前混淆文件路径护隐私（来源: https://towardsdatascience.com/how-cursor-actually-indexes-your-codebase/）。
- **代价（别只看好处）**：① 成本/延迟——agent 循环每步重算前文，input token 近**二次增长**；② **纯关键词在自然语言查询上很差**——只有问法与文档用词完全一致才命中；先用 LLM 做**查询扩展**（把问法换成文档里的说法）再 grep，命中能提升约 **10 倍**（来源: https://www.nuss-and-bolts.com/p/on-the-lost-nuance-of-grep-vs-semantic）。

### 4. 长上下文的冲击

- 反"RAG 已死"的硬证据：长上下文有"中间迷失"（信息在中段时性能掉 20+ 个点，来源: https://arxiv.org/abs/2407.16833）；长上下文又贵又慢（RAG 比长上下文便宜约 8–82 倍，延迟 RAG ~1s vs 长上下文 30–60s，交互场景直接出局，来源: https://tianpan.co/blog/2026-04-09-long-context-vs-rag-production-decision-framework）。
- ⚠️ 核验：网上一条流传论断把这些"成本/延迟/中间迷失"论据**错误归属**给 LlamaIndex《RAG is dead》一文——逐句核对该文压根没提这些；真正出处是 arXiv:2407.16833 等。
- DeepMind/UMich（EMNLP 2024）：最优解是**路由（SELF-ROUTE）**——简单事实题走 RAG、复杂全局题走长上下文。

### 5. 混合与进阶检索（向量仍明显胜出处）

- **生产标准管线 = 混合 + 重排**：召回阶段 BM25 + 向量并行（RRF 融合），精排阶段 cross-encoder 重排（来源: https://optyxstack.com/rag-reliability/hybrid-search-reranking-playbook）。
- **为什么必须 BM25 兜底**：纯向量**静默漏掉**精确字符串——错误码、单据号、型号（`RTX-4090` vs `RTX-4070` 向量几乎重合）、法律术语；失败无声、生成"流畅但错"的答案（来源: https://tianpan.co/blog/2026-04-12-hybrid-search-production-bm25-dense-embeddings）。**对投标文档的项目编号、规范条款号、型号尤其要命。**
- **Anthropic Contextual Retrieval**：入库前让模型给每块生成"定位上下文"再嵌入；官方实测 top-20 失败率 ↓35%（contextual embeddings）/↓49%（+BM25）/↓67%（+重排）（来源: https://www.anthropic.com/news/contextual-retrieval）。⚠️ 核验：数字逐条命中原文、真实，但①自评未被第三方复现；②跨域平均、方差极大（小说类 ↑84%、模糊代码查询仅 ↑41%）。
- **GraphRAG（微软）**：在"全局意义建构"（如"这批文档主要讲什么主题"）大幅胜出；但向量 RAG 恰擅长"局部查询"，GraphRAG 优势只在需跨全库推理时（来源: https://www.microsoft.com/en-us/research/blog/benchmarkqed-automated-benchmarking-of-rag-systems/）。
- 向量/混合仍明显胜出场景：语义/同义改写查询、跨语言、跨全库推理的全局问题、多跳实体关联、海量+实时更新。

### 6. 证据与基准（标注可信度）

- **有据/实测**：DeepMind **LIMIT**（ICLR'26）——极简任务 recall@100 BM25 85.7% vs SOTA 单向量 8.3%，证明单向量有由维度决定的固有天花板（核验 supported，来源: arXiv）；**NoLiMa**（ICML 2025）——去掉字面词重叠后号称 128K 的模型有效长度普遍只剩 2K；**Databricks** 2000+ 实验——实用上限常在 32K–64K；**Amazon "Keyword search is all you need"**（AAAI 2026）——纯 agentic 关键词检索达向量 RAG 的 91%+、结构化技术文档 99%+，**但作者多为 AWS、有立场**，且自陈在散文/跨学科文本退化（正是向量仍胜出处）；**LlamaIndex 2026 规模拐点基准**——小语料（5 篇论文）文件系统 agent 正确性 8.4/10 vs RAG 6.4/10，扩到 100–1000 文档后 RAG 反超（来源: https://www.llamaindex.ai/blog/did-filesystem-tools-kill-vector-search）。
- **营销/标题党（contested）**：各种"agentic +26%/token 少 90%"多为厂商自报或单一实验；严谨论文《Is Agentic RAG worth it?》（arXiv 2601.07711）反而结论"仍不清楚哪种方法在何条件下更优"，且实测 agentic 多花 2.7–3.6 倍 token、宽域反而崩。
- 规律：**越接近通用横评越可信，越是单点暴涨越可能营销。**

### 7. 选型决策框架

按"语料规模分层 + 查询类型路由"，不是二选一：
- 单语料 **< ~20 万 token（~500 页）**：直接全量塞上下文，或 agentic grep/read，**别上 RAG**（Anthropic 明确阈值，来源: https://www.anthropic.com/news/contextual-retrieval）。
- **几十文件 / 单项目级**：agentic 工具检索明显优于 RAG。
- **100–1000+ 文档、文件大到填满窗口**：出现拐点 → 上（混合）向量 RAG。
- **海量/高频/实时更新**：必须 RAG；十亿级才考虑专用向量库。
- 特殊硬约束：需精准引用/合规审计 → 偏 RAG（天然给来源+检索日志）；多租户隔离 → 偏向量 RAG；真上 RAG 默认"混合+重排+按查询类型路由"；最高级是动态路由（Self-Route，省成本 39–65%）。

---

## 第二部分：grep 类命令行工具盘点（哪个最高效）

> 这是 agentic 检索的"具体工具层"调查。注意：bidops 的标书问答 agent 是在 **JVM 内存里**对抽取出的纯文本做检索、**不 shell 调 CLI**，故以下主要是背景知识。

### 工具盘点

| 工具 | 定位 | 维护状态 | 最适合 |
|---|---|---|---|
| **ripgrep (rg)** | 高速递归检索，默认尊重 `.gitignore`，AI agent 事实标准 | 活跃 15.1.0(2025-10) | 真实代码库递归搜——当前首选 |
| GNU grep | POSIX 基线、无处不在 | 维护 3.12(2025) | 可移植脚本；不挑大代码树 |
| **ugrep (ug)** | grep 超集，带 TUI/布尔查询/搜归档压缩包 | 活跃 v7.8.2 | 压缩包/归档内搜、超大 pattern 集、复杂正则 |
| The Silver Searcher (ag) | 早年快速代码搜索 | **已停滞**(2020) | 不推荐新项目，迁 rg/ugrep |
| ack (ack3) | Perl、按文件类型过滤 | 维护 v3.9 | 已有 Perl 环境 |
| git grep | Git 内建、可搜历史 | 随 Git | Git 仓库内、搜历史提交 |
| **ast-grep (sg)** | 按语法树(AST)结构搜/改写 | 活跃 | 重构、批量改 API、按代码结构精确找 |
| semgrep | 语义级 SAST/找漏洞 | 活跃 | 安全审计 |
| comby | 语言无关结构化搜改 | **半停滞**(2021) | 新项目优先 ast-grep |
| **ripgrep-all (rga)** | 把 rg 包成能搜 PDF/docx/epub/zip | 活跃 v0.10.7 | 直接搜 PDF/Office 原件 |

### 效率（"大目录递归搜 + 尊重 .gitignore"场景）

- **结论：ripgrep 稳定领先**，这是它对 ugrep 的结构性优势（默认开 `.gitignore`/跳二进制/Unicode 常开）。Chromium 树上 rg 0.350s vs ugrep 1.844s（约 5×，来源: https://github.com/BurntSushi/ripgrep/discussions/2597）。作者基准里 rg vs ag 约 4.5×、Unicode 词边界 vs git grep 约 37×（来源: https://burntsushi.net/ripgrep/，作者自报自承有偏）。
- **"ugrep 与 ripgrep 谁更快"是两厂商公开互掐、无定论**：ugrep 在复杂正则 `x*y*z*`（rg 塌到 10s vs ugrep 0.21s）、超大 pattern 集、压缩包内搜上能反超甚至让 rg 出现性能悬崖；ripgrep 作者反驳 ugrep 基准只用单个 ~100MB 文件"测的是进程开销不是搜索"，并举 rg 0.107s vs ugrep 26s 的反例。双方都能在自己设计的场景里赢（contested，来源: https://github.com/Genivia/ugrep-benchmarks ; https://github.com/BurntSushi/ripgrep/discussions/2597）。
- "ripgrep 比 grep 快 5–13×"是多基准拼接、非单一实测、随语料大幅波动（contested，来源: https://www.codeant.ai/blogs/ripgrep-vs-grep-performance）。
- ripgrep 也有天花板：超大 monorepo 上 Cursor 观察到单次 rg 常 >15s 卡住 agent，故额外加倒排索引"先缩小要扫的文件子集"（对 rg 的补充而非替代，来源: https://cursor.com/blog/fast-regex-search）。
- ⚠️ contested：有报告称 Claude Code 2026-04 某版把 macOS/Linux 搜索后端从 ripgrep 换成内嵌 ugrep+bfs（换正则兼容性与压缩支持），随即引发 OOM 回归（来源: https://github.com/anthropics/claude-code/issues/54394）——"默认用谁"并非一锤定音。

### 结构化 grep 何时需要

- ast-grep 不是更快的文本 grep，而是其上的**精度层**：按 AST 结构匹配，忽略注释/字符串/空白/变量名噪音。该用它：批量重构/codemod、强制编码规范、找弃用 API（来源: https://ast-grep.github.io/）。找漏洞是 semgrep 的领域。官方建议：先 grep 探索、再 ast-grep 精修。对纯文本/文档/非代码格式完全不适用。
- 一句话：**搜文本用 ripgrep，改代码结构用 ast-grep，找漏洞用 semgrep**——分工不是竞争。

### 推荐 + 对 bidops 的关系

- **综合首选 ripgrep**：默认行为最贴合"在真实项目里搜东西"、零索引零配置、跨平台、AI 工具生态事实标准。需搜压缩包/归档或撞 rg 复杂正则悬崖时 ugrep 备一手；按代码结构改写上 ast-grep。
- **对 bidops**：标书问答 agent 在 JVM 内存里搜抽取出的纯文本、不 shell 调 grep CLI，故"哪个 CLI 最快"是背景知识、不影响线上性能。真正会用到的两种情形：(1) 若将来要从命令行搜文件系统，用 **ripgrep**；(2) 若要直接搜 PDF/docx **原件**（而非先抽纯文本），看 **ripgrep-all(rga)**（用 pdftotext/pandoc 抽文本再交 rg，并缓存加速重复搜，来源: https://github.com/phiresky/ripgrep-all）。
