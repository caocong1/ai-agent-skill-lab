# Source Map

Local source root: `raw/repos`

When this skill is installed outside the lab, for example under `~/.codex/skills/`, `raw/repos/` may be unavailable. Use the upstream links below in that case. Treat local paths as lab-only evidence. Commits were last pinned on 2026-10-25 for every repository that changed materially since the previous review (Pi, OpenAI Agents JS, Vercel AI, LangGraphJS, MCP TS SDK, Spring AI Examples, LangChain4j, learn-claude-code, SkillOpt, OpenAI Codex, DeepSeek Harness) and for the two new local harness libraries; Hello-Agents, mini-swe-agent and cwc-long-running-agents keep earlier pins; article and specification snapshots were captured in `raw/docs/` on the dates listed in `analysis/SOURCE_INDEX.md`. Verify APIs against the host project's installed framework version before applying version-specific code.

**Version facts as of the 2026-10-25 freshness review** — the pins below match these, but upstream keeps moving; check the host project's installed versions:

- **Pi 1.x** moved durable execution out of `pi-agent-core` into the experimental `pi-durable` package with new vocabulary; 0.8x harness exports are gone.
- **Vercel AI SDK** is at `ai@7.0.153`; 7.0.x patches add behavior (an `interrupted` finish reason, entry-point-specific step defaults). `@ai-sdk/workflow` is versioned separately; the `beta`/`canary` npm tags are stale pre-GA builds.
- **OpenAI Agents JS** is at **0.21.0**: keep run state server-side; HITL model calls count toward `maxTurns`.
- **MCP TypeScript SDK** scoped packages are at **2.4.0**; the monolithic `@modelcontextprotocol/sdk` 1.x line is maintenance-only and will not implement 2026-07-28; `server-legacy` is a frozen v1 shim slated for removal in v3.
- **MCP specification** is still at revision **2026-07-28**; the Skills (SEP-2640) and Apps extensions are Final.
- **Spring AI 2.1** is at RC: the `ChatMemory` family is deprecated for an event-sourced session, and its pinned MCP Java SDK does not implement 2026-07-28. **LangChain4j** is at **1.22.0**; 1.19.1 was mis-published.
- **DeepSeek Harness** `dsh` 0.2.1-rc.3 renamed Code Mode to PTC and removed its runtime-invariant layer.
- **Current Claude models** (Fable 5.1, Opus 5.5, Sonnet 5.5, Haiku 5.5) reject forced `tool_choice` and non-default sampling parameters, and accounts created on or after 2026-08-31 get a 400 when replayed reasoning follows an edited system prompt, tools array, or earlier message — context assembly must be append-only. Verify against the provider's current docs.

Details in `analysis/SOURCE_INDEX.md` and `.planning/freshness-reviews/2026-10-25-source-freshness-review.md`.

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
- **Local harness libraries** (Claude Agent SDK, Google ADK) are harnesses you
  host and embed. Cite them for the contract a vendor gives its host —
  permission order, resume semantics, what survives compaction, evaluation
  simulation — and only for their local, self-hosted parts; this suite does not
  cover cloud-hosted agent services.
- **Evidence compilations** (`analysis/25-harness-shelf-life-research.md`,
  `analysis/26-durable-rules-production-evidence.md`) gather papers and vendor
  reports around one question each; cite them for measured effects and their
  reliability tier, not as framework documentation.

## Local Repositories

| Source | Local path | Commit |
| --- | --- | --- |
| Pi | `pi` | `d5b3de22d0e24a3e9c38a9410d3329b099717283` |
| OpenAI Agents JS | `openai-agents-js` | `be4f1f9aa4ad4f03cc5db5fdd57d0d0136923570` |
| LangGraphJS | `langgraphjs` | `c6675bf03f353ff32fb2ee0a82adb3541c0aee40` |
| MCP TypeScript SDK | `modelcontextprotocol-typescript-sdk` | `951fe5603a7ec0b2dcb6a0b95d92cd86f93ad9e5` |
| Vercel AI SDK | `vercel-ai` | `6147ecd94b16c0cd14580e9725517fabff4cbdf4` |
| Spring AI Examples | `spring-ai-examples` | `e499007e2b4074561c015b057b31c026d1f02f14` |
| LangChain4j | `langchain4j` | `7948fba82672cdff5ec4219b0600693221ad855d` |
| Learn Claude Code (shareAI-lab, teaching) | `learn-claude-code` | `ce8f9f186058939da54c9d6fead78dfb5d0fd6c3` |
| Hello-Agents (Datawhale, teaching) | `hello-agents` | `66401d9f54d989f3d35b32ae411faf0fb472164f` |
| SkillOpt (Microsoft) | `skillopt` | `84b36cd5564e8893569e50e37f02a81d10b55e27` |
| Anthropic cwc-long-running-agents | `cwc-long-running-agents` | `ad107a974bced5244f74dd283dbf2bfd3baee3a1` |
| OpenAI Codex | `openai-codex` | `970111f6cb62cc02fe36a82ea7d71b37a2889c97` |
| mini-swe-agent | `mini-swe-agent` | `a83fcae82d2a08f0ee0c688f9d137b3566c097f8` |
| DeepSeek Harness | `deepseek-harness` | `1f81c047fc48fa190a683e469daa699857e9afe8` |
| Google ADK (Python) | `google-adk-python` | `d68ca857d5e3bab8e968d4e5f98ef028eb37dc87` |
| Claude Agent SDK (Python wrapper) | `claude-agent-sdk-python` | `0e89b298e771259378a6cd3734e00d323dff5703` |

## Upstream Links

- Pi: https://github.com/earendil-works/pi
- OpenAI, A Practical Guide to Building Agents: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI, A Practical Guide to Building Agents PDF: https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- Anthropic, Building Effective Agents: https://www.anthropic.com/research/building-effective-agents
- Anthropic, Writing Effective Tools for AI Agents: https://www.anthropic.com/research/writing-tools-for-agents
- OpenAI Agents JS: https://github.com/openai/openai-agents-js
- OpenAI Agents JS docs: https://openai.github.io/openai-agents-js/
- LangGraphJS: https://github.com/langchain-ai/langgraphjs
- LangGraphJS docs: https://docs.langchain.com/oss/javascript/langgraph/persistence
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
- Google Agent Development Kit docs: https://adk.dev/
- SkillOpt (Microsoft): https://github.com/microsoft/SkillOpt
- SkillOpt project page: https://microsoft.github.io/SkillOpt/
- SkillOpt arXiv paper: https://arxiv.org/abs/2605.23904
- OpenAI, Harness Engineering: https://openai.com/index/harness-engineering/
- Anthropic, Effective Harnesses for Long-Running Agents: https://www.anthropic.com/research/effective-harnesses-for-long-running-agents
- Anthropic cwc-long-running-agents: https://github.com/anthropics/cwc-long-running-agents
- OpenAI Codex: https://github.com/openai/codex
- mini-swe-agent: https://github.com/SWE-agent/mini-swe-agent
- DeepSeek Harness: https://github.com/deepseek-ai/deepseek-harness
- Anthropic, Harness Design for Long-Running Application Development: https://www.anthropic.com/research/harness-design-long-running-apps
- MCP specification 2026-07-28 changelog: https://modelcontextprotocol.io/specification/2026-07-28/changelog
- MCP deprecated features registry: https://modelcontextprotocol.io/specification/2026-07-28/deprecated
- MCP extensions overview (Skills, Apps): https://modelcontextprotocol.io/extensions/overview
- Anthropic, Scaling Managed Agents: https://www.anthropic.com/research/managed-agents
- Anthropic, How We Built Claude Code Auto Mode: https://www.anthropic.com/research/claude-code-auto-mode
- OpenAI, Codex as a Platform: https://developers.openai.com/blog/codex-as-a-platform
- Claude Agent SDK docs: https://code.claude.com/docs/en/agent-sdk/overview
- Claude Agent SDK (Python): https://github.com/anthropics/claude-agent-sdk-python
- Google ADK (Python): https://github.com/google/adk-python
- Agent Skills specification: https://agentskills.io

## High-Value Source Files

Pi:

- `pi/packages/agent/src/agent-loop.ts`
- `pi/packages/durable/docs/spec.md` (1.x durable execution spec; replaces the deleted `packages/agent/docs/harness.md`)
- `pi/packages/durable/src/harness/harness.ts` (successor of the deleted `packages/agent/src/harness/agent-harness.ts`)
- `pi/packages/durable/src/harness/tool.ts` (replay: the current declaration can veto, never upgrade)
- `pi/packages/coding-agent/src/core/skills.ts` (moved from `packages/agent/src/harness/skills.ts`)
- `pi/packages/coding-agent/docs/skills.md`
- `pi/packages/coding-agent/src/core/resource-loader.ts`
- `pi/packages/coding-agent/src/core/system-prompt.ts`
- `pi/packages/coding-agent/examples/extensions/permission-gate.ts`
- `pi/packages/coding-agent/examples/extensions/dynamic-tools.ts`

TypeScript frameworks:

- `openai-agents-js/packages/agents-core/src/run.ts`
- `openai-agents-js/packages/agents-core/src/runner/runLoop.ts`
- `openai-agents-js/packages/agents-core/src/tool.ts`
- `openai-agents-js/packages/agents-core/src/runner/toolCaller.ts` (per-tool caller restriction)
- `openai-agents-js/docs/src/content/docs/guides/human-in-the-loop.mdx` (keep approval state on the server)
- `langgraphjs/docs/docs/concepts/persistence.md` (legacy source; current docs live at docs.langchain.com)
- `langgraphjs/docs/docs/agents/human-in-the-loop.md` (legacy source)
- `langgraphjs/docs/docs/agents/multi-agent.md` (legacy source)
- `vercel-ai/content/docs/03-agents/02-building-agents.mdx`
- `vercel-ai/content/docs/03-agents/04-loop-control.mdx`
- `vercel-ai/content/docs/03-agents/07-workflow-agent.mdx`
- `vercel-ai/content/docs/03-ai-sdk-core/18-code-mode.mdx`
- `vercel-ai/content/docs/03-agents/06-policy-tool-approvals.mdx`
- `vercel-ai/content/docs/03-ai-sdk-harnesses/05-harness-adapters.mdx`

MCP:

- `modelcontextprotocol-typescript-sdk/packages/server/src/server/mcp.ts`
- `modelcontextprotocol-typescript-sdk/packages/client/src/client/client.ts`
- `modelcontextprotocol-typescript-sdk/docs/get-started/first-server.md` and `docs/serving/http.md` (replace the deleted `docs/server.md`)
- `modelcontextprotocol-typescript-sdk/docs/clients/connect.md` and `docs/clients/calling.md` (replace the deleted `docs/client.md`)
- `modelcontextprotocol-typescript-sdk/docs/clients/skills.md` (Skills over MCP)
- `modelcontextprotocol-typescript-sdk/examples/stateless-legacy/server.ts`
- `vercel-ai/content/docs/03-ai-sdk-core/16-mcp-tools.mdx`

Articles and guides:

- `raw/docs/anthropic-building-effective-agents.md` -> `analysis/06-anthropic-building-effective-agents.md`
- `raw/docs/anthropic-writing-effective-tools.md` -> `analysis/08-anthropic-writing-effective-tools.md`
- `raw/docs/openai-practical-guide-building-agents.md` -> `analysis/09-openai-practical-guide-building-agents.md`
- `raw/docs/openai-harness-engineering.md` -> `analysis/14-openai-harness-engineering.md`
- `raw/docs/anthropic-effective-harnesses-long-running-agents.md` -> `analysis/15-anthropic-long-running-agent-harness.md`
- `raw/docs/anthropic-harness-design-long-running-apps.md` -> `analysis/19-anthropic-harness-design-long-running-apps.md`
- `raw/docs/anthropic-managed-agents.md` -> `analysis/22-anthropic-managed-agents.md`
- `raw/docs/anthropic-claude-code-auto-mode.md` -> `analysis/23-claude-code-auto-mode.md`
- `raw/docs/openai-codex-as-a-platform.md` -> `analysis/24-openai-codex-as-a-platform.md`

Evidence compilations:

- `raw/docs/harness-shelf-life-research.md` -> `analysis/25-harness-shelf-life-research.md`
- `raw/docs/durable-rules-production-evidence.md` -> `analysis/26-durable-rules-production-evidence.md`

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
- `skillopt/docs/sleep/README.md` (replaces the deleted `CONTROLLABLE_DREAMING.md`)
- `skillopt/docs/sleep/evalkit.md` (paired A/B with McNemar and task-clustered bootstrap)
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
- `openai-codex/codex-rs/rollout/src/recorder.rs` (`core/src/rollout.rs` is now a re-export shim)
- `openai-codex/codex-rs/core/src/session/step_settings.rs`
- `openai-codex/codex-rs/core/src/guardian/` and `openai-codex/codex-rs/prompts/templates/guardian/policy.md`
- `openai-codex/codex-rs/core/src/responses_retry.rs`
- `openai-codex/codex-rs/features/src/lib.rs` (each flag's stage and default)
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
- `deepseek-harness/docs/defensive-patterns/README.md` (was a single file before 0.2)
- `deepseek-harness/docs/subsystems/` (`code-runtime.md` is now `ptc-runtime.md`; `invariants.md` was removed)
- `deepseek-harness/packages/experimental/tool-ralph/` (demoted to experimental in 0.2)
- `deepseek-harness/packages/experimental/auto-review/`
- `deepseek-harness/docs/upgrade-guide/`
- any package `README.md`, `## Model Experience` section
- `analysis/18-deepseek-harness.md`

Google ADK (cite for an event-log-only durable model, at-least-once resume, call integrity, and simulation-based evals; local and self-hosted parts only):

- `google-adk-python/src/google/adk/flows/llm_flows/compaction.py`
- `google-adk-python/src/google/adk/runners.py`
- `google-adk-python/src/google/adk/evaluation/`
- `google-adk-python/.agents/skills/adk-architecture/`
- `analysis/27-google-adk.md`

Claude Agent SDK (cite for the host-facing contract of a closed local harness; self-hosted use only):

- `claude-agent-sdk-python/src/claude_agent_sdk/types.py`
- `claude-agent-sdk-python/src/claude_agent_sdk/_internal/session_resume.py`
- `claude-agent-sdk-python/src/claude_agent_sdk/testing/session_store_conformance.py`
- `claude-agent-sdk-python/CHANGELOG.md`
- TypeScript changelog: `anthropics/claude-agent-sdk-typescript` at `019515d3` (no source in that repository)
- `raw/docs/claude-agent-sdk.md` -> `analysis/28-claude-agent-sdk.md`

Java:

- `spring-ai-examples/agentic-patterns/README.md`
- `spring-ai-examples/agentic-patterns/chain-workflow/src/main/java/com/example/agentic/ChainWorkflow.java`
- `spring-ai-examples/agentic-patterns/orchestrator-workers/src/main/java/com/example/agentic/OrchestratorWorkers.java`
- `spring-ai-examples/agentic-patterns/evaluator-optimizer/src/main/java/com/example/agentic/EvaluatorOptimizer.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/DefaultToolExecutor.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/ToolProvider.java`
- `langchain4j/langchain4j-agentic/src/test/java/dev/langchain4j/agentic/carrentalassistant/AssistantMain.java`
- `langchain4j/langchain4j-skills/src/main/java/dev/langchain4j/skills/Skills.java`
