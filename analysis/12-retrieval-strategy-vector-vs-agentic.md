# 检索策略分析：向量 RAG vs Agentic 工具检索 vs 长上下文

> 分析版本：1.0 ｜ 最后更新：2026-06-02 ｜ 覆盖来源：检索策略多来源研究综述（2024–2026 web，约 55 个源含对抗式核验，快照见 `raw/docs/retrieval-strategy-research.md`，版本见 `analysis/SOURCE_INDEX.md`）

这是本仓库第一篇**专题研究综述型**分析（区别于"单仓库/单文章"来源）：它不分析某个框架，而是回答一个贯穿所有 agent 的横切问题——**当 agent 要在文档上回答问题，应该用向量数据库/RAG、让模型自己用 grep/read 迭代检索（agentic retrieval），还是直接长上下文塞进去？** 它与已有分析直接咬合：`analysis/10-learn-claude-code.md` 记录了 Claude Code"grep/read 优先、弃用向量索引"的 harness 立场；`analysis/11-hello-agents.md` 第 8 章给的是另一端"四级记忆 + 向量 RAG + 高级检索（重排/多跳/语义路由）"；`analysis/08-anthropic-writing-effective-tools.md` 主张"用 targeted search/filter 工具而非 list-all"；`references/context-and-tools.md` 的 `Long Document Handling` 已写了"search → read 顶块 → 带 anchor 作答"的雏形。本篇把这些散点收敛成一条**可按场景分层的检索选型**判断，并补上它们都没讲清的两件事：检索失败的**静默性**，以及"何时该从 agentic 升级到向量/混合"。

把它吸收进 `build-ai-agents` 的价值在于：本仓库此前对"检索"的态度是分裂的——harness 派（learn-claude-code）默认 grep、框架派（hello-agents / spring-ai / langchain4j）默认 RAG，skill 里只在 `Long Document Handling` 给了通用 pipeline，却没给"先选哪条路"的决策闸。这篇把决策闸补上：**默认按语料规模与查询类型路由，而不是默认上向量库**。

## 核心抽象

- **"RAG 已死"是伪命题，真问题是"无脑塞 vs 智能检索谁更经济可靠"**。2024–2026 的共识不是"向量没用了"，而是两层位移：① 向量数据库从"必须自建的品类"降级为"既有数据库（Postgres/Elastic/Mongo/Redis）的内置功能"；② 检索从"上线前固定的向量管道"升级为"运行时由 agent 决定 if/what/where/how 的智能检索"。这正是 `analysis/06` "能 workflow 就别 agent" 在检索维度的镜像：能让 agent 现搜就别预建一套静态管道。
- **检索失败是静默的——这是选型里最被低估的风险**。纯向量会把 `RTX-4090` 和 `RTX-4070` 当成几乎相同的向量，把错误码、单据号、规范条款号、否定词（"不得/严禁"）悄悄拉回相近但错误的片段，然后模型照样生成一段"流畅但错"的答案，没有任何报错。纯关键词 grep 则在同义改写上静默漏（招标方写"工期"、投标方写"建设周期"）。**两种失败都不抛异常**，所以选型必须按"这个查询的失败模式是什么"来定，而不是按"哪个更先进"。
- **agentic 检索的力量来自模型的"坚持性"，代价是 token 近二次增长**。让模型自己搜，靠的是它失败后会换关键词再搜、顺线索追下去（与 `analysis/10` 的 agent loop 同源）；但每一步都把前文重算一遍，input token 随步数近似二次增长——这把"检索预算"和 `analysis/10` 的"循环停止/预算"绑成了同一个工程问题。
- **规模是第一分水岭，查询类型是第二分水岭**。单语料能塞进上下文（约 < 20 万 token / 几百文件）时，agentic grep/read 或直接全量上下文明确优于自建 RAG；越过这条线、或需要"按意思找/跨全库推理/高频低延迟/多租户隔离"时，才轮到（混合）向量 RAG。

## 重要模式

- **按语料规模分层（第一闸）**：`< ~20 万 token / 单项目几十文件` → 全量上下文或 agentic grep/read，不建 RAG；`100–1000+ 文档、单文档大到填满窗口` → 拐点，上（混合）向量 RAG；`海量/高频/实时更新` → 必须 RAG，十亿级才考虑专用向量库（否则 pgvector 同库同事务最省）。
- **查询扩展（agentic 检索的标配前置）**：纯关键词只在问法与原文用词一致时命中；在 grep 前加一层 LLM 把问题展开成多个同义说法再搜，实测命中可提升约 10 倍，且不需要任何向量基础设施。这是"用一次便宜的 LLM 调用换掉一整套 embedding 管道"的高性价比模式。
- **精确匹配通道（防静默漏检）**：凡涉及编号、条款号、型号、否定词、金额这类"必须逐字对"的检索，强制走精确字面匹配（grep/BM25 一路），不要交给纯语义检索。生产级 RAG 的"BM25 + 向量混合 + 重排"本质就是用 BM25 给向量兜底这一类精确匹配。
- **检索即工具，套用 ACI 准则**：把 `search`/`read` 当作面向模型的产品界面设计（`analysis/08`）——targeted search 优于 list-all、返回带 file/offset/anchor 的高信号片段、read 支持 offset/length/截断提示。`references/context-and-tools.md` 的 `Long Document Handling` 已是这条的落地骨架。
- **可溯源 trace**：agentic 检索也能给出处（读了哪个文件哪段），但要显式记录"读了哪些片段 → 得出哪条结论"的链路，否则合规/审计场景说不清——这与 `analysis/10` 的 memory provenance、`security-and-safety` 的 trajectory 脱敏是同一类要求。
- **具体工具层（grep 家族）**：CLI 检索的事实标准是 **ripgrep**（默认尊重 `.gitignore`、跳二进制、Unicode 常开、零配置、被主流 AI 编码工具内置）；ugrep 在压缩包内搜/复杂正则上能反超但默认不过滤需手配；按代码结构改写用 **ast-grep**、找漏洞用 **semgrep**、搜 PDF/docx 原件用 **ripgrep-all**。"谁更快"的厂商基准互相打架、无绝对定论，胜负随场景翻转。

## 工程启发

- **不要默认上向量库**。这是本篇对 skill 最实质的修正：以往"做文档问答 = 切块 + embedding + 向量库"的条件反射，在中小语料下是过度工程，白白背上索引 drift、重建重计费、敏感数据上传、切块调优的包袱（`analysis/06` 的"复杂度被需求拉动，不被框架推动"在检索维度的体现）。
- **先建最便宜的可用检索，再按信号升级**。默认 agentic grep/read（+ 查询扩展 + 精确匹配通道）；出现明确升级信号才上向量/混合：① 语料稳定超 ~20 万 token / 几百文档；② 形态从"单库内找"变成"跨历史全库按意思找"；③ 高频亚秒级检索；④ 上线后语义/概念查询反复漏检且查询扩展补不上。升级时**先用 pgvector**（复用现有关系库、同库同事务），不要一上来引专用向量库。
- **检索质量的证据要分层信**：DeepMind LIMIT（单向量有维度天花板）、NoLiMa（长上下文有效长度远小于标称）这类同行评审/多模型横评最可信；Anthropic Contextual Retrieval ↓67%、Amazon agentic 91%+ 这类厂商自报方向对但有立场、未必可复现、且常是跨域平均。把这条接到 `testing-observability` 的"建 eval 前先看公开基准"。
- **把检索预算并入循环预算**：agentic 检索的步数上限、已读片段缓存、子 agent 压缩中间结果，与 `analysis/10` 的循环停止/cheap-first compaction 是同一套工程，不应分开设计。

## 适用场景

- **agentic grep/read（首选）**：单项目/单文档级语料（< ~20 万 token / 几十文件）、查询能落到明确关键词或可被查询扩展覆盖、要可迭代细化、要省去索引维护、有敏感数据不宜外传向量库。典型即"在一份/一个项目的文档里问答"。
- **混合向量 RAG（+重排）**：大语料、语义/同义/概念性查询为主、跨全库按意思检索、高频低延迟、多租户隔离、需稳定的来源引用与检索日志。
- **GraphRAG**：跨多文档的"全局意义建构"（主题归纳、共性/差异分析、多跳实体关联）——纯 grep/向量局部检索都吃力。
- **长上下文直塞**：单语料 < ~10 万 token、绝大部分内容都相关、可接受 30–60s 延迟的批处理/异步、语料静态、查询稀疏。

## 注意

- **别把这篇当"agentic 全面优于 RAG"**。证据明确：agentic 在大语料、纯语义查询、跨文档多跳、成本/延迟上是弱项；"agentic 碾压 RAG"多源于厂商内测或单一实验，严谨论文（《Is Agentic RAG worth it?》）反而判"尚不清楚谁在何条件下更优"。结论是**分层路由**，不是站队。
- **静默漏检比报错更危险**：选型时优先问"这个查询若漏了会不会无声地给出流畅错答"，对编号/条款/型号/否定词一律精确匹配兜底。
- **grep 工具层与 bidops 实现是两件事**：bidops 标书问答 agent 在 JVM 内存里搜抽取出的纯文本、不 shell 调 CLI，故"哪个 grep CLI 最快"只是背景知识；真要从命令行搜文件用 ripgrep，真要搜 PDF/docx 原件用 ripgrep-all。
- **本篇是多来源综述**，不绑定单一上游版本；其"最后更新"按再综述时间推进，不随某个来源的小改动走。

## 对最终 skill 的影响

本分析驱动以下 `build-ai-agents` 改动（与实际提交一致）：

- `references/context-and-tools.md`：在 `Long Document Handling` 之后新增 **`Retrieval Strategy`** 小节——给出"按语料规模分层 + 按查询类型路由"的检索选型闸（默认不上向量库；小语料 agentic grep/read；升级信号；先 pgvector 后专用库），并补两条 agentic 检索的标配——**查询扩展**（治同义漏检）与**精确匹配通道**（治编号/条款/型号/否定词的静默漏检），以及检索失败的静默性提示。引用本文件。
- `SKILL.md`：`Architecture Rules` 的"最简优先"链补一句检索维度的默认——"文档检索默认 agentic 工具检索 / 必要时再 hybrid 向量+重排，不要默认自建向量库"，把检索纳入"复杂度被需求拉动"的同一判断。
- `analysis/07-overall-agent-analysis.md`：`跨来源共识矩阵` 新增 `文档检索策略` 行；`综合结论` 增"检索按规模与查询类型分层"一条；`后续可分析方向` 补 Anthropic Contextual Retrieval、DeepMind LIMIT 等单源深挖候选。
- 均为 additive 强化，不改 skill 契约（MINOR，1.5.0）。
