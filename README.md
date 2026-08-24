# AI Agent Skill Lab

这个项目用于沉淀 AI agent 开发学习资料、源码分析和可复用的 Codex skill。目标不是只收集链接，而是把典型项目中的设计模式压缩成后续 Java、TypeScript 或其他语言项目能直接参考的工程方法。

本 skill 同时支持两种用途：(1) 在新项目里设计和实现 agent 功能；(2) 审查并优化已有 agent 代码，产出带 `file:line` 证据、按优先级排序、可执行的整改方案。

## 目录

- `raw/repos/`: 拉取的原始开源项目，只作为学习资料和证据来源。
- `raw/docs/`: 白皮书、官方文档快照、文章摘要或研究综述。
- `analysis/`: 分主题的源码分析、模式总结和结论。
- `skills/build-ai-agents/`: 最终可复用的 Codex skill suite 入口。
- `skills/design-*` / `skills/implement-*` / `skills/review-*` / `skills/secure-*` / `skills/test-*` / `skills/optimize-*`: `build-ai-agents` 拆出的 focused child skills。
- `skills/iterate-skill-lab/`: 维护本仓库自身迭代流程的 Codex skill。
- `docs/index.html`: 面向阅读的资料索引和可视化入口。
- `scripts/check-lab-invariants.sh`: 本仓库自身约定的机械闸（分析元数据格式、四处版本一致、引用路径存在、`index.html` 三 `<td>`、`SOURCE_INDEX` 日期不倒挂）。
- `.planning/`: 来源新鲜度审查报告与递归触发型 seed。

## 当前资料集

当前已经拉取并记录了这些项目：

- `pi`: 重点学习 agent loop、tool execution、harness/session、skills、extensions、subagent。
- `openai-agents-js`: 学习标准 TS agent SDK 的 Agent、tool、handoff、guardrail、approval、run state。
- `langgraphjs`: 学习 durable graph、checkpoint、human-in-the-loop、多 agent handoff。
- `modelcontextprotocol-typescript-sdk`: 学习 MCP server/client、tools/resources/prompts、transport、错误语义。
- `vercel-ai`: 学习 TS/Next 应用层 ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP client。
- `spring-ai-examples`: 学习 Java/Spring agentic patterns、function callback、MCP annotation。
- `langchain4j`: 学习 Java-native AI service、tool executor/provider、agentic service、skills 集成。
- `learn-claude-code`（教学型仓库，shareAI-lab）：17 课渐进式 harness 编目（2026 年由 20 课重构并整体重编号），把 agent loop、hooks、permission、skill 加载、cheap-first 多层 context compaction、selection/extraction/consolidation 三段 memory、模型层错误恢复三路径、task graph、background/cron、mailbox-based agent team、worktree 隔离、MCP 接入各自做成独立的最小可运行 `code.py`，强调 agency 来自模型训练、harness 来自工程的本体论区分；重构后新增 s15 集成 harness（组件在循环里的位置表）、s16 workflow runtime（journal 续跑 + 内容哈希调用键）、s17 goal loop（会话级 Stop hook + 无工具独立判定器）。
- `hello-agents`（教学型仓库，Datawhale）：16 章 / 5 部分系统化中文教程，覆盖智能体基础理论、经典范式（ReAct / Plan-and-Solve / Reflection）、低代码平台（Coze / Dify / n8n）、主流框架（AutoGen / AgentScope / CAMEL / LangGraph）、自建 HelloAgents 框架（Message / Config / Agent 三件套）、记忆与 RAG、上下文工程 GSSC 流水线、智能体通信协议谱系（MCP / A2A / ANP）、Agentic-RL（SFT + GRPO 训练通路）、智能体性能评估（BFCL / GAIA）以及三个综合案例（旅行助手 / TODO 驱动深度研究 / 赛博小镇）。与 `learn-claude-code` 形成互补："窄而深 + harness 机制穷举" vs "广覆盖 + 含训练侧"。
- `skillopt`（Microsoft）：把 skill/prompt 文档当作 frozen agent 的可训练外部状态，通过 rollout → reflect → aggregate → select → update → gate 的文本空间优化循环产出 compact `best_skill.md`，并提供 SkillOpt-Sleep 的离线 session replay / held-out gate / staged adoption 形态。本仓库吸收其思想用于 `optimize-agent-skills`，不把它作为其他项目 agent runtime 的默认依赖。
- `cwc-long-running-agents`（Anthropic）：长任务 harness 的可读 hooks/evaluator 配套仓库，把 default-FAIL contract、fresh-context evaluator、evidence gate、progress + git 交接、kill switch 与 operator steering 做成最小原语；与 Anthropic 长任务文章联合分析。
- `openai-codex`：生产级 coding-agent harness，重点研究 turn/step/tool-call 生命周期、step-consistent context/tool snapshot、层级 AGENTS.md provenance、compaction、动态工具、approval/sandbox/retry 集中编排与 rollout。
- `mini-swe-agent` v2（SWE-agent）：bash-only action、linear trajectory、stateless command execution 与可替换 environment 组成的极简 benchmark baseline，用于验证复杂 agent scaffold 是否真的带来增益。
- `deepseek-harness`（DeepSeek）：以 Cordis 插件树 micro-kernel 组织的编码 agent harness，按 profile/bundle 把同一套能力组装成不同产品形态。重点学习 capability seam（定义/提供/消费三角色）、事件溯源 session log 与 `deriveMessages()` 投影、turn/step/round 三级循环、单调 `ToolGuard`（返回类型里没有 allow）与闭合的 `ApprovalOutcome` 四元组、Code Mode、spill seam、compaction 锁、goal domain（持久 phase + revisioned CAS，激活态故意不持久化）、workflow engine，以及被机械 gate 强制的 **Model Experience README 契约**（What the model sees / Token effect / KV Cache effect）。

除代码项目外，还分析了权威文章：

- Anthropic, Building Effective Agents：workflow 与 agent 的判定框架、五种 workflow 模式、自治 agent 循环和工具接口（ACI）设计。分析见 `analysis/06-anthropic-building-effective-agents.md`，原文快照见 `raw/docs/anthropic-building-effective-agents.md`，跨来源综合见 `analysis/07-overall-agent-analysis.md`。
- Anthropic, Writing Effective Tools for Agents：agent tool 选择、命名空间、返回上下文、token 效率、tool description/spec 和真实任务评测。分析见 `analysis/08-anthropic-writing-effective-tools.md`，摘要快照见 `raw/docs/anthropic-writing-effective-tools.md`。
- OpenAI, A Practical Guide to Building Agents：agent 适用性、model/tools/instructions、单 agent 优先、多 agent 编排、guardrails 和人类介入。分析见 `analysis/09-openai-practical-guide-building-agents.md`，摘要快照见 `raw/docs/openai-practical-guide-building-agents.md`。
- OpenAI, Harness Engineering：把 harness 从单次 tool loop 扩展到 repository-as-system-of-record、agent legibility、可启动/可观测环境、机械架构约束、反馈编译和持续垃圾回收。分析见 `analysis/14-openai-harness-engineering.md`，摘要快照见 `raw/docs/openai-harness-engineering.md`。
- Anthropic, Effective Harnesses for Long-Running Agents：说明 compaction 不能替代跨 session 连续性，以 initializer/coding 阶段、default-FAIL feature contract、progress + git 与 fresh-session E2E 验证稳定推进长任务。与配套仓库的联合分析见 `analysis/15-anthropic-long-running-agent-harness.md`，摘要快照见 `raw/docs/anthropic-effective-harnesses-long-running-agents.md`。
- Anthropic, Harness Design for Long-Running Application Development（2026-03-24，上文续作）：把视角从"一个 agent 如何跨 session 推进"换到"多角色如何分工产出高质量成果"，并正面回答完成度不能由做事的 agent 自己认定。给出 GAN 式 generator/evaluator 分离、planner/generator/evaluator 三角色、协商式 sprint contract、context reset vs compaction 按模型代际选择、可评分的主观 rubric 与 few-shot 分数校准，以及一条元规则——**harness 里每个组件都编码了一条关于模型做不到什么的假设，而假设会过期**。分析见 `analysis/19-anthropic-harness-design-long-running-apps.md`，摘要快照见 `raw/docs/anthropic-harness-design-long-running-apps.md`。

此外还纳入了一份**协议规范修订**（新的来源类型；规范类来源必须有独立版本行才能被漂移检测覆盖）：

- MCP Specification 2026-07-28：一次改变协议形状的修订——从有会话、服务端可反向发起请求的双工协议，改为无状态、单向请求-响应协议。覆盖移除 `initialize` 与 `Mcp-Session-Id`、必须实现 `server/discover`、MRTR 取代反向请求、必填 `resultType`、`subscriptions/listen`、tasks 转为扩展、`CacheableResult` 与 `tools/list` 确定性排序（理由直接写成提高 prompt cache 命中率）、错误码分区政策、OAuth 收紧，以及 Roots / Sampling / Logging 的弃用与 12 个月弃用窗口。分析见 `analysis/20-mcp-2026-07-28-revision.md`，摘要快照见 `raw/docs/mcp-2026-07-28-specification.md`。

这组 harness 专题把当前工程概念收敛成三层：**turn/runtime**（loop、tools、context、sandbox、approval）、**session continuity**（contract、rollout、checkpoint、handoff）与 **repository/organization feedback**（规格、架构地图、可观测性、机械约束、review 和持续维护）。任何新增 scaffold 都应先对照 mini-swe-agent 式最小 baseline，用真实 eval 或消融证明收益。

此外还纳入了一篇**多来源研究综述**（区别于单一仓库 / 文章）：

- 检索策略研究综述（向量 RAG vs Agentic 工具检索 vs 长上下文）：基于 2024–2026 约 55 个 web 源 + 对抗式核验，给出"按语料规模分层 + 按查询类型路由"的检索选型（小语料 agentic grep/read、必要时再 hybrid 向量+重排），并含 grep 工具层（ripgrep / ast-grep / ripgrep-all）盘点。分析见 `analysis/12-retrieval-strategy-vector-vs-agentic.md`，快照见 `raw/docs/retrieval-strategy-research.md`。

## 这个项目不做什么

能力清单需要一份同等醒目的非目标清单，否则读者要读完全部内容才发现缺了关键东西。本仓库**明确不做**：

- **不承诺 skill 内容与任何框架的当前版本 API 一致。** 上游移动得比任何成文指导都快。skill 给的是形态判断与核对纪律；具体 API 请按宿主项目已安装的版本核对官方文档。已知的版本漂移记在 `skills/build-ai-agents/references/source-map.md` 开头。
- **不做自动化来源摄取。** 判断哪些东西值得写下来、哪些是会过期的现状，是这个仓库全部的价值所在；把它自动化掉等于自毁。
- **不发布为可安装包**（npm / pip 等）。安装方式就是软链到 skills 目录。
- **不维护多语言平行译本。** 分析用中文（维护者的思考空间），skill 用英文（下游 agent 的执行契约）。
- **不做上游文档的镜像。** `raw/docs/` 里的是**转述式结构化摘要**，带来源 URL、发布/抓取日期与"非原文镜像"声明；需要原文请去官方链接。
- **不给 skill 的每一条建议做实验验证。** 本仓库目前没有验证集，这是一处**已知的、被记录在案的自我违反**（见 `analysis/21-lab-design-rethink-2026-08.md` 第四节），不是可以忽略的省略。

## 设计重思

`analysis/21-lab-design-rethink-2026-08.md` 对本仓库自身的六条根基前提做了压力测试。主要结论是一条新的组织轴：

- **易腐类**内容补的是模型当前做不到的事（上下文压缩策略、防漂移的提示词补丁、为弱模型准备的分步引导）。模型变强时它们**贬值**，应该带日期与缺口说明登记，并在每次模型代际更新时按清单消融。
- **耐久类**内容治理的是授权、证据、副作用与成本。模型变强时它们**增值**——能做的事越多，边界越重要；自评越有说服力，独立判定越必要；能力再强也不会让外部系统变成事务性的，或让 token 变免费。

那篇文件同时记录了本仓库违反自己规则的三处，以及五条可证伪条件——它是一份自评，处在"agent 会自信地夸奖自己产出"这条失败模式的正中央，应当被当作待复核的材料看待。

## 版本与变更

skill 版本记录在各 `SKILL.md` frontmatter 的 `metadata.version` 字段（`build-ai-agents` suite 当前 2.2.0），遵循语义化版本。契约（modes / deliverables / reference paths）的移除必须先经过弃用登记，见 `skills/build-ai-agents/SKILL.md` 的 `## Contract Stability`。每次迭代的更新内容、新增或更新的分析报告记录在 `CHANGELOG.md`；每个来源（代码项目或文章/论文）的 `来源版本 / 分析版本 / 最后更新` 维护在 `analysis/SOURCE_INDEX.md`，便于后续按来源新版本做增量更新。

本仓库自身的迭代方式沉淀在 `skills/iterate-skill-lab/`（v1.1.0）。今后遇到新的 AI agent 论文、文章、框架或某个已分析来源的重大更新，调用该 skill 按既定流程执行（新增/更新来源 → 元数据 → 综合 → build-ai-agents 优化 → docs/README → 分步 commit → 草稿 PR），避免每次重新摸索。

## 使用方式

### 快速阅读路径

如果只是想快速吸收结论，建议按下面顺序读：

1. `analysis/07-overall-agent-analysis.md`: 跨来源总综合，先建立 agent / workflow / harness / tool / memory 的整体判断框架。
2. `skills/build-ai-agents/SKILL.md`: 查看最终沉淀成 Codex skill 的执行契约。
3. `skills/design-ai-agent/SKILL.md`: 决定是否真的需要 agent，以及应该选哪种形态。
4. `skills/design-agent-tools/SKILL.md`: 处理 prompt、context、retrieval、tool description 和 token 预算。
5. `skills/test-ai-agents/SKILL.md`: 落地测试、回放、审批、trace 和 eval。

### 安装 skill

如果要让 Codex 自动发现本仓库里的 skill，可以把 skill 目录复制或软链到 Codex skills 目录：

```bash
mkdir -p "$HOME/.codex/skills"
ln -sfn "<repo-path>/skills/build-ai-agents" "$HOME/.codex/skills/build-ai-agents"
ln -sfn "<repo-path>/skills/design-ai-agent" "$HOME/.codex/skills/design-ai-agent"
ln -sfn "<repo-path>/skills/design-agent-tools" "$HOME/.codex/skills/design-agent-tools"
ln -sfn "<repo-path>/skills/build-mcp-capabilities" "$HOME/.codex/skills/build-mcp-capabilities"
ln -sfn "<repo-path>/skills/implement-ts-agents" "$HOME/.codex/skills/implement-ts-agents"
ln -sfn "<repo-path>/skills/implement-java-agents" "$HOME/.codex/skills/implement-java-agents"
ln -sfn "<repo-path>/skills/review-ai-agents" "$HOME/.codex/skills/review-ai-agents"
ln -sfn "<repo-path>/skills/secure-ai-agents" "$HOME/.codex/skills/secure-ai-agents"
ln -sfn "<repo-path>/skills/test-ai-agents" "$HOME/.codex/skills/test-ai-agents"
ln -sfn "<repo-path>/skills/optimize-agent-skills" "$HOME/.codex/skills/optimize-agent-skills"
ln -sfn "<repo-path>/skills/iterate-skill-lab" "$HOME/.codex/skills/iterate-skill-lab"
```

其中 `<repo-path>` 替换为本仓库路径，例如 `/home/cao/workspace/ai-agent-skill-lab`。如果更喜欢复制而不是软链，也可以复制对应目录；软链的好处是仓库更新后 Codex 看到的 skill 会同步更新。

### 使用 `build-ai-agents`

`build-ai-agents` 用于在其他项目里设计、实现、扩展或审查 AI agent 能力。2.0.0 起它是 suite 入口；2.1.0 增加三层 harness、跨 session continuity、repository legibility 与 harness ablation 指导。它会按任务路由到 focused child skills，支持四种模式：

- `build`: 从零设计并实现一个新的 agent 功能。
- `extend`: 在已有 agent 上增加工具、记忆、审批、MCP、检索或其他能力。
- `review`: 审查已有 agent 代码，按风险优先级输出中文整改计划，并给出 `file:line` 证据。
- `optimize-skill`: 用真实轨迹、held-out gate 和 staged adoption 优化 agent skill / prompt / tool 描述。

可以显式点名 skill，也可以描述任务让 Codex 自动匹配。典型提示：

```text
请使用 build-ai-agents，帮我为这个项目设计一个带工具调用和人工审批的客服工单 agent。
```

```text
请使用 build-ai-agents 的 review 模式审查 src/agents，重点看 tool schema、权限边界、循环上限和测试缺口。
```

```text
请用 build-ai-agents 扩展现有 agent，让它通过 MCP 调用内部知识库，并补上回放测试。
```

使用时优先参考这些文件：

1. `skills/build-ai-agents/SKILL.md`: suite 入口和路由规则。
2. `skills/design-ai-agent/SKILL.md`: 选择 agent 架构。
3. `skills/design-agent-tools/SKILL.md`: prompt/context、retrieval、memory、tool schema/description。
4. `skills/build-mcp-capabilities/SKILL.md`: MCP server/client 设计。
5. `skills/implement-ts-agents/SKILL.md`: TS/OpenAI/Vercel/LangGraph/Pi 模式。
6. `skills/implement-java-agents/SKILL.md`: Spring AI 和 LangChain4j 模式。
7. `skills/review-ai-agents/SKILL.md`: 审查已有 agent 代码的定位、分级和整改模板。
8. `skills/secure-ai-agents/SKILL.md`: agent 安全威胁模型和审查清单。
9. `skills/test-ai-agents/SKILL.md`: 测试、回放、审批和可观测性。
10. `skills/optimize-agent-skills/SKILL.md`: SkillOpt 风格的 skill/prompt 优化流程。

`build-ai-agents` 的一个核心原则是先判断任务是否真的需要 agent：能用确定性代码解决的就不要引入模型；能用单次模型调用或固定 workflow 解决的就不要上自治 tool loop；只有当路径无法硬编码、需要模型动态选择工具并处理不确定状态时，才逐步升级到 tool loop、durable graph 或 multi-agent。

### 使用 `iterate-skill-lab`

`iterate-skill-lab` 只用于维护本仓库。当你想把新的 AI agent 论文、工程文章、开源框架或检索策略吸收到这个 lab 里时，用它来保持版本、元数据、分析报告、综合结论、skill 更新和文档更新一致。

典型提示：

```text
请使用 iterate-skill-lab，找一个新的 agent 论文或权威工程文章纳入这个仓库。
```

```text
请使用 iterate-skill-lab，更新已分析来源 openai-agents-js 到最新版本，并同步 SOURCE_INDEX、综合分析和 build-ai-agents。
```

它支持三种模式：

- `add-source`: 新增一个来源，生成快照、分析报告，并更新综合结论和 skill。
- `update-source`: 刷新已有来源的新版本，更新对应分析版本和索引。
- `skill-only`: 不新增来源，只对 `build-ai-agents` 做小范围优化。

### 维护检查清单

每次扩展资料集或改动 skill 后，至少检查这些内容：

- `skills/build-ai-agents/SKILL.md` 的 `metadata.version` 是否与 `README.md` 和 `CHANGELOG.md` 一致。
- `analysis/SOURCE_INDEX.md` 是否记录了来源版本、分析版本和最后更新日期。
- 新增分析文件是否包含元数据块，并说明“对最终 skill 的影响”。
- `docs/index.html` 是否把新来源展示出来。
- README 是否说明了新增来源、版本变化和实际使用方式。
