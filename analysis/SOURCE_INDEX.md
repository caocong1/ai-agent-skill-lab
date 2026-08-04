# Source Index

更新时间：2026-08-04（新增 harness engineering 专题：OpenAI 工程文章、Anthropic 长任务文章与配套仓库、OpenAI Codex、mini-swe-agent；2026-06-05 执行 SEED-001 来源新鲜度审查，详见下方 `## 新鲜度审查`）。所有仓库均以 shallow clone 方式保存在 `raw/repos/`。

逐来源的 `来源版本 / 分析版本 / 最后更新` 在下方表格维护；再分析某来源新版本时，更新该来源所在行 + 对应分析文件头部元数据块 + `CHANGELOG.md`。`来源版本` 对仓库是 commit，对文章是发布/抓取日期。`分析版本` 是本仓库对该来源的分析报告版本，与 skill 版本独立。

## Repositories

| 项目 | 本地路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Pi | `raw/repos/pi` | `4943c1d62c8e6f3437446f480bb3e8422869535d` | 1.0 | 2026-05-18 | agent loop、harness、skills、resource loader、extensions、subagents |
| OpenAI Agents JS | `raw/repos/openai-agents-js` | `629d35af99e1ba80fc968b0d062c070caed0683d` | 1.0 | 2026-05-18 | Agent、tools、handoffs、guardrails、interruptions、RunState |
| LangGraphJS | `raw/repos/langgraphjs` | `bd72a897e15d0a29a06b8b8b4c589851b6c7b4a6` | 1.0 | 2026-05-18 | graph orchestration、checkpoint、thread、HITL、multi-agent handoff |
| MCP TypeScript SDK | `raw/repos/modelcontextprotocol-typescript-sdk` | `22595b96855b34f00adcc6c1e7932ad68ea5139d` | 1.0 | 2026-05-18 | MCP server/client、tool/resource/prompt、stdio/http transport |
| Vercel AI SDK | `raw/repos/vercel-ai` | `aa5a1e539643c2a7162a141502eee63c665a9544` | 1.0 | 2026-05-18 | ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP adapter ｜ ⚠ 待再分析：v7 canary `onFinish`→`onEnd`（PR 15245，2026-06-05 审查） |
| Spring AI Examples | `raw/repos/spring-ai-examples` | `2a6088db3d18d5fa6fc208b12adf1172d22f77fd` | 1.0 | 2026-05-18 | Java agentic patterns、function callback、MCP annotations |
| LangChain4j | `raw/repos/langchain4j` | `6185599e370388b3c54489051c57469ef9094d5b` | 1.0 | 2026-05-18 | Java AI service、tool executor/provider、agentic sequence、skills |
| Learn Claude Code | `raw/repos/learn-claude-code` | `1baf1aca5af439694cb3a1772c0b1ab44b482a01` | 1.0 | 2026-05-21 | harness vs agent 区分、20 课渐进式编目、cheap-first 多层 compaction、memory 三段流程、错误恢复三路径、worktree 隔离、mailbox + claim-from-board 多 agent |
| Hello-Agents (Datawhale) | `raw/repos/hello-agents` | `66401d9f54d989f3d35b32ae411faf0fb472164f` | 1.0 | 2026-05-22 | 流程驱动 vs AI Native Agent、16 章全栈编目、自建 HelloAgents 框架（Message/Config/Agent）、四级记忆 + RAG、GSSC 上下文工程、协议谱系（MCP/A2A/ANP）、Agentic-RL（SFT + GRPO）、BFCL/GAIA 评估、TODO 驱动深度研究、赛博小镇 |
| SkillOpt (Microsoft) | `raw/repos/skillopt` | `c1ac570d944ee7f83fc7c4273abfcb4bfdfea392` | 1.0 | 2026-06-14 | skill 文档作为可训练外部状态、rollout/reflect/aggregate/select/update/gate、textual learning rate、held-out validation、slow/meta update、SkillOpt-Sleep 离线巩固、staged adoption |
| Anthropic cwc-long-running-agents | `raw/repos/cwc-long-running-agents` | `ad107a974bced5244f74dd283dbf2bfd3baee3a1` | 1.0 | 2026-08-04 | default-FAIL contract、fresh-context evaluator、evidence gate、agent-maintained handoff、kill switch、operator steering |
| OpenAI Codex | `raw/repos/openai-codex` | `9873cba8ce6d14e650e12cdc0dddd159ae6613d7` | 1.0 | 2026-08-04 | turn/step/tool-call 生命周期、step snapshot、dynamic tools、AGENTS.md provenance、compaction、approval/sandbox/retry、rollout |
| mini-swe-agent | `raw/repos/mini-swe-agent` | `a83fcae82d2a08f0ee0c688f9d137b3566c097f8` | 1.0 | 2026-08-04 | bash-only action、linear trajectory、stateless execution、environment adapter、benchmark-first minimal harness |

## Articles and Papers

非代码来源的权威文章/论文。快照保存在 `raw/docs/`，分析报告在 `analysis/`。

| 来源 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Anthropic, Building Effective Agents | `raw/docs/anthropic-building-effective-agents.md` | 发布 2024-12-19 / 抓取 2026-05-19 | 1.0 | 2026-05-19 | workflow 与 agent 判定、五种 workflow 模式、自治 agent 循环、simplicity/transparency/ACI |
| Anthropic, Writing Effective Tools for Agents | `raw/docs/anthropic-writing-effective-tools.md` | 发布 2025-09-11 / 抓取 2026-05-20 | 1.0 | 2026-05-20 | tool 选择、命名空间、返回上下文、token 效率、tool description/spec、工具评测 |
| OpenAI, A Practical Guide to Building Agents | `raw/docs/openai-practical-guide-building-agents.md` | 发布未标注 / 抓取 2026-05-20 | 1.0 | 2026-05-20 | agent 适用性、model/tools/instructions、单 agent 优先、多 agent 编排、guardrails、人类介入 |
| OpenAI, Harness Engineering | `raw/docs/openai-harness-engineering.md` | 发布 2026-02-11 / 抓取 2026-08-04 | 1.0 | 2026-08-04 | repository-as-system-of-record、agent legibility、可观测环境、机械架构约束、反馈编译、持续垃圾回收 |
| Anthropic, Effective Harnesses for Long-Running Agents | `raw/docs/anthropic-effective-harnesses-long-running-agents.md` | 发布 2025-11-26 / 抓取 2026-08-04 | 1.0 | 2026-08-04 | initializer/coding session、外部化连续性、default-FAIL feature contract、progress + git、fresh-session E2E 验证 |

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
- `packages/agent/docs/agent-harness.md`
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

- `raw/repos/learn-claude-code/README.md`
- `raw/repos/learn-claude-code/s01_agent_loop/code.py`
- `raw/repos/learn-claude-code/s04_hooks/code.py`
- `raw/repos/learn-claude-code/s05_todo_write/code.py`
- `raw/repos/learn-claude-code/s07_skill_loading/code.py`
- `raw/repos/learn-claude-code/s08_context_compact/code.py`
- `raw/repos/learn-claude-code/s09_memory/code.py`
- `raw/repos/learn-claude-code/s10_system_prompt/code.py`
- `raw/repos/learn-claude-code/s11_error_recovery/code.py`
- `raw/repos/learn-claude-code/s12_task_system/code.py`
- `raw/repos/learn-claude-code/s13_background_tasks/code.py`
- `raw/repos/learn-claude-code/s14_cron_scheduler/code.py`
- `raw/repos/learn-claude-code/s15_agent_teams/code.py`
- `raw/repos/learn-claude-code/s17_autonomous_agents/code.py`
- `raw/repos/learn-claude-code/s18_worktree_isolation/code.py`
- `raw/repos/learn-claude-code/s19_mcp_plugin/code.py`
- `raw/repos/learn-claude-code/s20_comprehensive/code.py`
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
