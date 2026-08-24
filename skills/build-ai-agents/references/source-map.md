# Source Map

Local source root: `raw/repos`

When this skill is installed outside the lab, for example under `~/.codex/skills/`, `raw/repos/` may be unavailable. Use the upstream links below in that case. Treat local paths as lab-only evidence. Commits were pinned on 2026-05-18 (initial production frameworks), 2026-05-21/22 (teaching repositories), 2026-06-10 (SkillOpt), 2026-08-04 (harness engineering repositories), and 2026-08-23 (Pi re-snapshot, learn-claude-code re-snapshot, DeepSeek Harness); article and specification snapshots were captured in `raw/docs/` on the dates listed in `analysis/SOURCE_INDEX.md`. Verify APIs against the host project's installed framework version before applying version-specific code.

**Known version drift as of the 2026-08-23 freshness review** — these were verified upstream but the local snapshots below were not all refreshed:

- Vercel AI SDK **v7 is stable** (`ai@7.0.77`), with breaking changes including `stepCountIs` → `isStepCount` and ESM-only packages.
- OpenAI Agents JS is at **v0.17.0**, adding programmatic tool calling, scripted testing entry points, and fail-closed resume.
- MCP TypeScript SDK **v2 is a package rename**: new scoped packages `@modelcontextprotocol/{core,client,server,…}@2.0.0`; the monolithic `@modelcontextprotocol/sdk` stays on 1.x.
- Spring AI examples are aligned to **Spring AI 2.0**; LangChain4j is at **1.19.0** with a 2026-07-28 MCP client.
- The **MCP specification** is at revision **2026-07-28**, which changed the protocol's shape.
- learn-claude-code was **restructured from 20 lessons to 17** with full renumbering.

Details in `analysis/SOURCE_INDEX.md` and `.planning/freshness-reviews/2026-08-23-source-freshness-review.md`.

Distinguish two source kinds when citing:

- **Production frameworks** (Pi, OpenAI Agents JS, LangGraphJS, MCP TS SDK, Vercel AI SDK, Spring AI Examples, LangChain4j) ship runtime behavior and are the authority for API shapes and trade-offs.
- **Teaching repositories** (Learn Claude Code, Hello-Agents) ship pedagogical implementations meant to be read end-to-end rather than imported into production. Cite them for the minimal skeleton of a mechanism, not as canonical production defaults — see `analysis/10-learn-claude-code.md` and `analysis/11-hello-agents.md` for which defaults are intentionally simplified. They play different roles:
  - `learn-claude-code`: narrow but deep, exhausts harness mechanisms (17 lessons after the 2026 restructure, one mechanism each, 200–2000-line Python per lesson).
  - `hello-agents`: broad and long, covers the full stack (theory → paradigms → frameworks → memory/RAG → context engineering → protocols → Agentic-RL → eval → case studies → capstone, 16 chapters).
- **Skill optimization source** (SkillOpt) treats skill text as an optimizable external state for a frozen agent. Cite it for validation-gated skill/prompt evolution, not as a default runtime dependency for application agents.
- **Harness engineering sources** serve three distinct levels: OpenAI Codex for
  production runtime boundaries; Anthropic `cwc-long-running-agents` for
  cross-session contract/evaluator/handoff primitives; OpenAI Harness
  Engineering for repository/organization feedback systems. mini-swe-agent is
  the minimal benchmark baseline used to challenge whether extra scaffold is
  still necessary. DeepSeek Harness adds a fourth level: a plugin-tree
  micro-kernel where capabilities are composed per profile, with a mechanically
  gated "Model Experience" contract on every package README.

## Local Repositories

| Source | Local path | Commit |
| --- | --- | --- |
| Pi | `pi` | `a69bef789bc95abf0acee16f7b4660b70b650bb9` |
| OpenAI Agents JS | `openai-agents-js` | `629d35af99e1ba80fc968b0d062c070caed0683d` |
| LangGraphJS | `langgraphjs` | `bd72a897e15d0a29a06b8b8b4c589851b6c7b4a6` |
| MCP TypeScript SDK | `modelcontextprotocol-typescript-sdk` | `22595b96855b34f00adcc6c1e7932ad68ea5139d` |
| Vercel AI SDK | `vercel-ai` | `aa5a1e539643c2a7162a141502eee63c665a9544` |
| Spring AI Examples | `spring-ai-examples` | `2a6088db3d18d5fa6fc208b12adf1172d22f77fd` |
| LangChain4j | `langchain4j` | `6185599e370388b3c54489051c57469ef9094d5b` |
| Learn Claude Code (shareAI-lab, teaching) | `learn-claude-code` | `1baf1aca5af439694cb3a1772c0b1ab44b482a01` |
| Hello-Agents (Datawhale, teaching) | `hello-agents` | `66401d9f54d989f3d35b32ae411faf0fb472164f` |
| SkillOpt (Microsoft) | `skillopt` | `c1ac570d944ee7f83fc7c4273abfcb4bfdfea392` |
| Anthropic cwc-long-running-agents | `cwc-long-running-agents` | `ad107a974bced5244f74dd283dbf2bfd3baee3a1` |
| OpenAI Codex | `openai-codex` | `9873cba8ce6d14e650e12cdc0dddd159ae6613d7` |
| mini-swe-agent | `mini-swe-agent` | `a83fcae82d2a08f0ee0c688f9d137b3566c097f8` |

## Upstream Links

- Pi: https://github.com/earendil-works/pi
- OpenAI, A Practical Guide to Building Agents: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI, A Practical Guide to Building Agents PDF: https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
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
- Spring AI Examples: https://github.com/spring-projects/spring-ai-examples
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

## High-Value Source Files

Pi:

- `pi/packages/agent/src/agent-loop.ts`
- `pi/packages/agent/src/harness/agent-harness.ts`
- `pi/packages/agent/src/harness/skills.ts`
- `pi/packages/agent/docs/harness.md` (renamed from `agent-harness.md`; durable execution model)
- `pi/packages/coding-agent/docs/skills.md`
- `pi/packages/coding-agent/src/core/resource-loader.ts`
- `pi/packages/coding-agent/src/core/system-prompt.ts`
- `pi/packages/coding-agent/examples/extensions/permission-gate.ts`
- `pi/packages/coding-agent/examples/extensions/dynamic-tools.ts`

TypeScript frameworks:

- `openai-agents-js/packages/agents-core/src/run.ts`
- `openai-agents-js/packages/agents-core/src/runner/runLoop.ts`
- `openai-agents-js/packages/agents-core/src/tool.ts`
- `langgraphjs/docs/docs/concepts/persistence.md`
- `langgraphjs/docs/docs/agents/human-in-the-loop.md`
- `langgraphjs/docs/docs/agents/multi-agent.md`
- `vercel-ai/content/docs/03-agents/02-building-agents.mdx`
- `vercel-ai/content/docs/03-agents/04-loop-control.mdx`
- `vercel-ai/content/docs/03-agents/07-workflow-agent.mdx`

MCP:

- `modelcontextprotocol-typescript-sdk/packages/server/src/server/mcp.ts`
- `modelcontextprotocol-typescript-sdk/packages/client/src/client/client.ts`
- `modelcontextprotocol-typescript-sdk/docs/server.md`
- `modelcontextprotocol-typescript-sdk/docs/client.md`
- `vercel-ai/content/docs/03-ai-sdk-core/16-mcp-tools.mdx`

Articles and guides:

- `raw/docs/anthropic-building-effective-agents.md` -> `analysis/06-anthropic-building-effective-agents.md`
- `raw/docs/anthropic-writing-effective-tools.md` -> `analysis/08-anthropic-writing-effective-tools.md`
- `raw/docs/openai-practical-guide-building-agents.md` -> `analysis/09-openai-practical-guide-building-agents.md`
- `raw/docs/openai-harness-engineering.md` -> `analysis/14-openai-harness-engineering.md`
- `raw/docs/anthropic-effective-harnesses-long-running-agents.md` -> `analysis/15-anthropic-long-running-agent-harness.md`
- `raw/docs/anthropic-harness-design-long-running-apps.md` -> `analysis/19-anthropic-harness-design-long-running-apps.md`

Specifications:

- `raw/docs/mcp-2026-07-28-specification.md` -> `analysis/20-mcp-2026-07-28-revision.md`

Learn Claude Code (cite when looking for the minimal skeleton of one harness mechanism):

- `learn-claude-code/README.md`
- `learn-claude-code/s01_agent_loop/code.py`
- `learn-claude-code/s04_hooks/code.py`
- `learn-claude-code/s07_skill_loading/code.py`
- `learn-claude-code/s08_context_compact/code.py`
- `learn-claude-code/s09_memory/code.py`
- `learn-claude-code/s10_task_system/code.py`
- `learn-claude-code/s11_background_tasks/code.py`
- `learn-claude-code/s12_cron_scheduler/code.py`
- `learn-claude-code/s13_agent_teams/code.py`
- `learn-claude-code/s14_mcp_plugin/code.py`
- `learn-claude-code/s15_integrated_harness/` (where every mechanism enters one loop)
- `learn-claude-code/s16_workflow_runtime/` (journaled orchestration, content-hash resume keys)
- `learn-claude-code/s17_goal_loop/` (completion gate as a session-level stop hook)
- `analysis/10-learn-claude-code.md`

Hello-Agents (cite when looking for full-stack pedagogical coverage, especially Agentic-RL and protocol spectrum):

- `hello-agents/README.md`
- `hello-agents/docs/chapter4/第四章 智能体经典范式构建.md`
- `hello-agents/docs/chapter7/第七章 构建你的Agent框架.md`
- `hello-agents/docs/chapter8/第八章 记忆与检索.md`
- `hello-agents/docs/chapter9/第九章 上下文工程.md`
- `hello-agents/docs/chapter10/第十章 智能体通信协议.md`
- `hello-agents/docs/chapter11/第十一章 Agentic-RL.md`
- `hello-agents/docs/chapter12/第十二章 智能体性能评估.md`
- `hello-agents/docs/chapter14/第十四章 自动化深度研究智能体.md`
- `hello-agents/docs/chapter15/第十五章 构建赛博小镇.md`
- `hello-agents/code/chapter11/` (Agentic-RL training pipeline, 8 Python scripts)
- `hello-agents/Extra-Chapter/Extra01-面试问题总结.md` (Chinese interview Q&A)
- `analysis/11-hello-agents.md`

SkillOpt (cite when improving skill/prompt artifacts from trajectory evidence):

- `skillopt/README.md`
- `skillopt/docs/guide/training-loop.md`
- `skillopt/docs/guide/skill-document.md`
- `skillopt/docs/guide/dl-analogy.md`
- `skillopt/docs/reference/config.md`
- `skillopt/skillopt/engine/trainer.py`
- `skillopt/skillopt/evaluation/gate.py`
- `skillopt/skillopt/optimizer/skill.py`
- `skillopt/skillopt/gradient/reflect.py`
- `skillopt/skillopt_sleep/cycle.py`
- `skillopt/docs/sleep/CONTROLLABLE_DREAMING.md`
- `skillopt/plugins/codex/skills/skillopt-sleep/SKILL.md`
- `analysis/13-skillopt.md`

Anthropic long-running harness (cite for cross-session continuity and independent completion gates):

- `cwc-long-running-agents/README.md`
- `cwc-long-running-agents/claude-code-config/.claude/CLAUDE.md`
- `cwc-long-running-agents/claude-code-config/.claude/agents/evaluator.md`
- `cwc-long-running-agents/claude-code-config/.claude/hooks/track-read.sh`
- `cwc-long-running-agents/claude-code-config/.claude/hooks/verify-gate.sh`
- `cwc-long-running-agents/claude-code-config/.claude/hooks/commit-on-stop.sh`
- `cwc-long-running-agents/claude-code-config/.claude/hooks/kill-switch.sh`
- `cwc-long-running-agents/claude-code-config/.claude/hooks/steer.sh`
- `analysis/15-anthropic-long-running-agent-harness.md`

OpenAI Codex (cite for production turn/step/tool-call lifecycle and policy enforcement):

- `openai-codex/codex-rs/core/src/session/turn.rs`
- `openai-codex/codex-rs/core/src/session/step_context.rs`
- `openai-codex/codex-rs/core/src/tools/orchestrator.rs`
- `openai-codex/codex-rs/core/src/tools/approvals.rs`
- `openai-codex/codex-rs/core/src/tools/sandboxing.rs`
- `openai-codex/codex-rs/core/src/agents_md.rs`
- `openai-codex/codex-rs/core/src/compact.rs`
- `openai-codex/codex-rs/core/src/rollout.rs`
- `analysis/16-openai-codex-harness.md`

mini-swe-agent v2 (cite for minimal harness baselines and scaffold ablation):

- `mini-swe-agent/README.md`
- `mini-swe-agent/src/minisweagent/agents/default.py`
- `mini-swe-agent/src/minisweagent/environments/local.py`
- `mini-swe-agent/src/minisweagent/config/default.yaml`
- `mini-swe-agent/docs/advanced/control_flow.md`
- `mini-swe-agent/tests/agents/test_default.py`
- `analysis/17-mini-swe-agent.md`

DeepSeek Harness (cite for capability seams, monotonic guards, event-sourced sessions, code mode, and the Model Experience README contract):

- `deepseek-harness/docs/architecture.md`
- `deepseek-harness/docs/defensive-patterns.md`
- `deepseek-harness/docs/subsystems/`
- `deepseek-harness/packages/workflow/tool-ralph/`
- any package `README.md`, `## Model Experience` section
- `analysis/18-deepseek-harness.md`

Java:

- `spring-ai-examples/agentic-patterns/README.md`
- `spring-ai-examples/agentic-patterns/chain-workflow/src/main/java/com/example/agentic/ChainWorkflow.java`
- `spring-ai-examples/agentic-patterns/orchestrator-workers/src/main/java/com/example/agentic/OrchestratorWorkers.java`
- `spring-ai-examples/agentic-patterns/evaluator-optimizer/src/main/java/com/example/agentic/EvaluatorOptimizer.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/DefaultToolExecutor.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/ToolProvider.java`
- `langchain4j/langchain4j-agentic/src/test/java/dev/langchain4j/agentic/carrentalassistant/AssistantMain.java`
- `langchain4j/langchain4j-skills/src/main/java/dev/langchain4j/skills/Skills.java`
