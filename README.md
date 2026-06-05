# AI Agent Skill Lab

这个项目用于沉淀 AI agent 开发学习资料、源码分析和可复用的 Codex skill。目标不是只收集链接，而是把典型项目中的设计模式压缩成后续 Java、TypeScript 或其他语言项目能直接参考的工程方法。

本 skill 同时支持两种用途：(1) 在新项目里设计和实现 agent 功能；(2) 审查并优化已有 agent 代码，产出带 `file:line` 证据、按优先级排序、可执行的整改方案。

## 目录

- `raw/repos/`: 拉取的原始开源项目，只作为学习资料和证据来源。
- `raw/docs/`: 白皮书、官方文档快照、文章摘要或研究综述。
- `analysis/`: 分主题的源码分析、模式总结和结论。
- `skills/build-ai-agents/`: 最终可复用的 Codex skill。
- `skills/iterate-skill-lab/`: 维护本仓库自身迭代流程的 Codex skill。
- `docs/index.html`: 面向阅读的资料索引和可视化入口。

## 当前资料集

当前已经拉取并记录了这些项目：

- `pi`: 重点学习 agent loop、tool execution、harness/session、skills、extensions、subagent。
- `openai-agents-js`: 学习标准 TS agent SDK 的 Agent、tool、handoff、guardrail、approval、run state。
- `langgraphjs`: 学习 durable graph、checkpoint、human-in-the-loop、多 agent handoff。
- `modelcontextprotocol-typescript-sdk`: 学习 MCP server/client、tools/resources/prompts、transport、错误语义。
- `vercel-ai`: 学习 TS/Next 应用层 ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP client。
- `spring-ai-examples`: 学习 Java/Spring agentic patterns、function callback、MCP annotation。
- `langchain4j`: 学习 Java-native AI service、tool executor/provider、agentic service、skills 集成。
- `learn-claude-code`（教学型仓库，shareAI-lab）：20 课渐进式 harness 编目，把 agent loop、hooks、permission、skill 加载、cheap-first 多层 context compaction、selection/extraction/consolidation 三段 memory、模型层错误恢复三路径、task graph、background/cron、mailbox-based agent team、worktree 隔离、MCP 接入各自做成独立的最小可运行 `code.py`，强调 agency 来自模型训练、harness 来自工程的本体论区分。
- `hello-agents`（教学型仓库，Datawhale）：16 章 / 5 部分系统化中文教程，覆盖智能体基础理论、经典范式（ReAct / Plan-and-Solve / Reflection）、低代码平台（Coze / Dify / n8n）、主流框架（AutoGen / AgentScope / CAMEL / LangGraph）、自建 HelloAgents 框架（Message / Config / Agent 三件套）、记忆与 RAG、上下文工程 GSSC 流水线、智能体通信协议谱系（MCP / A2A / ANP）、Agentic-RL（SFT + GRPO 训练通路）、智能体性能评估（BFCL / GAIA）以及三个综合案例（旅行助手 / TODO 驱动深度研究 / 赛博小镇）。与 `learn-claude-code` 形成互补："窄而深 + harness 机制穷举" vs "广覆盖 + 含训练侧"。

除代码项目外，还分析了权威文章：

- Anthropic, Building Effective Agents：workflow 与 agent 的判定框架、五种 workflow 模式、自治 agent 循环和工具接口（ACI）设计。分析见 `analysis/06-anthropic-building-effective-agents.md`，原文快照见 `raw/docs/anthropic-building-effective-agents.md`，跨来源综合见 `analysis/07-overall-agent-analysis.md`。
- Anthropic, Writing Effective Tools for Agents：agent tool 选择、命名空间、返回上下文、token 效率、tool description/spec 和真实任务评测。分析见 `analysis/08-anthropic-writing-effective-tools.md`，摘要快照见 `raw/docs/anthropic-writing-effective-tools.md`。
- OpenAI, A Practical Guide to Building Agents：agent 适用性、model/tools/instructions、单 agent 优先、多 agent 编排、guardrails 和人类介入。分析见 `analysis/09-openai-practical-guide-building-agents.md`，摘要快照见 `raw/docs/openai-practical-guide-building-agents.md`。

此外还纳入了一篇**多来源研究综述**（区别于单一仓库 / 文章）：

- 检索策略研究综述（向量 RAG vs Agentic 工具检索 vs 长上下文）：基于 2024–2026 约 55 个 web 源 + 对抗式核验，给出"按语料规模分层 + 按查询类型路由"的检索选型（小语料 agentic grep/read、必要时再 hybrid 向量+重排），并含 grep 工具层（ripgrep / ast-grep / ripgrep-all）盘点。分析见 `analysis/12-retrieval-strategy-vector-vs-agentic.md`，快照见 `raw/docs/retrieval-strategy-research.md`。

## 版本与变更

skill 版本记录在 `skills/build-ai-agents/SKILL.md` frontmatter 的 `version` 字段（当前 1.5.1），遵循语义化版本。每次迭代的更新内容、新增或更新的分析报告记录在 `CHANGELOG.md`；每个来源（代码项目或文章/论文）的 `来源版本 / 分析版本 / 最后更新` 维护在 `analysis/SOURCE_INDEX.md`，便于后续按来源新版本做增量更新。

本仓库自身的迭代方式沉淀在 `skills/iterate-skill-lab/`（v1.0.1）。今后遇到新的 AI agent 论文、文章、框架或某个已分析来源的重大更新，调用该 skill 按既定流程执行（新增/更新来源 → 元数据 → 综合 → build-ai-agents 优化 → docs/README → 分步 commit → 草稿 PR），避免每次重新摸索。

## 使用方式

### 快速阅读路径

如果只是想快速吸收结论，建议按下面顺序读：

1. `analysis/07-overall-agent-analysis.md`: 跨来源总综合，先建立 agent / workflow / harness / tool / memory 的整体判断框架。
2. `skills/build-ai-agents/SKILL.md`: 查看最终沉淀成 Codex skill 的执行契约。
3. `skills/build-ai-agents/references/agent-architecture.md`: 决定是否真的需要 agent，以及应该选哪种形态。
4. `skills/build-ai-agents/references/context-and-tools.md`: 处理 prompt、context、retrieval、tool description 和 token 预算。
5. `skills/build-ai-agents/references/testing-observability.md`: 落地测试、回放、审批、trace 和 eval。

### 安装 skill

如果要让 Codex 自动发现本仓库里的 skill，可以把 skill 目录复制或软链到 Codex skills 目录：

```bash
mkdir -p "$HOME/.codex/skills"
ln -sfn "<repo-path>/skills/build-ai-agents" "$HOME/.codex/skills/build-ai-agents"
ln -sfn "<repo-path>/skills/iterate-skill-lab" "$HOME/.codex/skills/iterate-skill-lab"
```

其中 `<repo-path>` 替换为本仓库路径，例如 `/home/cao/workspace/ai-agent-skill-lab`。如果更喜欢复制而不是软链，也可以复制对应目录；软链的好处是仓库更新后 Codex 看到的 skill 会同步更新。

### 使用 `build-ai-agents`

`build-ai-agents` 用于在其他项目里设计、实现、扩展或审查 AI agent 能力。它有三种模式：

- `build`: 从零设计并实现一个新的 agent 功能。
- `extend`: 在已有 agent 上增加工具、记忆、审批、MCP、检索或其他能力。
- `review`: 审查已有 agent 代码，按风险优先级输出中文整改计划，并给出 `file:line` 证据。

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

1. `skills/build-ai-agents/SKILL.md`: 给 Codex 的触发和执行流程。
2. `skills/build-ai-agents/references/agent-architecture.md`: 选择 agent 架构。
3. `skills/build-ai-agents/references/typescript-patterns.md`: TS/OpenAI/Vercel/LangGraph/Pi 模式。
4. `skills/build-ai-agents/references/java-patterns.md`: Spring AI 和 LangChain4j 模式。
5. `skills/build-ai-agents/references/mcp-patterns.md`: MCP server/client 设计。
6. `skills/build-ai-agents/references/review-playbook.md`: 审查已有 agent 代码的定位、分级和整改模板。
7. `skills/build-ai-agents/references/anti-patterns.md`: 常见 agent 反模式、检测方式和修复方案。
8. `skills/build-ai-agents/references/security-and-safety.md`: agent 安全威胁模型和审查清单。
9. `skills/build-ai-agents/references/context-and-tools.md`: prompt/context 与 tool 描述优化。
10. `skills/build-ai-agents/references/testing-observability.md`: 测试、回放、审批和可观测性。

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

- `skills/build-ai-agents/SKILL.md` 的 `version` 是否与 `README.md` 和 `CHANGELOG.md` 一致。
- `analysis/SOURCE_INDEX.md` 是否记录了来源版本、分析版本和最后更新日期。
- 新增分析文件是否包含元数据块，并说明“对最终 skill 的影响”。
- `docs/index.html` 是否把新来源展示出来。
- README 是否说明了新增来源、版本变化和实际使用方式。
