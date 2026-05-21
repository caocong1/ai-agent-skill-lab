# Source Map

Local source root: `/Users/dongli/work/ai-agent-skill-lab/raw/repos`

When this skill is installed outside the lab, for example under `~/.codex/skills/`, `raw/repos/` may be unavailable. Use the upstream links below in that case. Treat local paths as lab-only evidence. Commits were pinned on 2026-05-18 (production frameworks) and 2026-05-21 (teaching repo `learn-claude-code`); article snapshots were captured in `raw/docs/` on the dates listed in `analysis/SOURCE_INDEX.md`. Verify APIs against the host project's installed framework version before applying version-specific code.

Distinguish two source kinds when citing:

- **Production frameworks** (Pi, OpenAI Agents JS, LangGraphJS, MCP TS SDK, Vercel AI SDK, Spring AI Examples, LangChain4j) ship runtime behavior and are the authority for API shapes and trade-offs.
- **Teaching repositories** (Learn Claude Code) ship 200–2000-line standalone Python lessons per mechanism. Cite them for the minimal skeleton of a mechanism, not as canonical production defaults — see `analysis/10-learn-claude-code.md` for which defaults are intentionally simplified.

## Local Repositories

| Source | Local path | Commit |
| --- | --- | --- |
| Pi | `pi` | `4943c1d62c8e6f3437446f480bb3e8422869535d` |
| OpenAI Agents JS | `openai-agents-js` | `629d35af99e1ba80fc968b0d062c070caed0683d` |
| LangGraphJS | `langgraphjs` | `bd72a897e15d0a29a06b8b8b4c589851b6c7b4a6` |
| MCP TypeScript SDK | `modelcontextprotocol-typescript-sdk` | `22595b96855b34f00adcc6c1e7932ad68ea5139d` |
| Vercel AI SDK | `vercel-ai` | `aa5a1e539643c2a7162a141502eee63c665a9544` |
| Spring AI Examples | `spring-ai-examples` | `2a6088db3d18d5fa6fc208b12adf1172d22f77fd` |
| LangChain4j | `langchain4j` | `6185599e370388b3c54489051c57469ef9094d5b` |
| Learn Claude Code (shareAI-lab, teaching) | `learn-claude-code` | `1baf1aca5af439694cb3a1772c0b1ab44b482a01` |

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
- Google Agent Development Kit docs: https://google.github.io/adk-docs/

## High-Value Source Files

Pi:

- `pi/packages/agent/src/agent-loop.ts`
- `pi/packages/agent/src/harness/agent-harness.ts`
- `pi/packages/agent/src/harness/skills.ts`
- `pi/packages/agent/docs/agent-harness.md`
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

Learn Claude Code (cite when looking for the minimal skeleton of one harness mechanism):

- `learn-claude-code/README.md`
- `learn-claude-code/s01_agent_loop/code.py`
- `learn-claude-code/s04_hooks/code.py`
- `learn-claude-code/s07_skill_loading/code.py`
- `learn-claude-code/s08_context_compact/code.py`
- `learn-claude-code/s09_memory/code.py`
- `learn-claude-code/s10_system_prompt/code.py`
- `learn-claude-code/s11_error_recovery/code.py`
- `learn-claude-code/s12_task_system/code.py`
- `learn-claude-code/s13_background_tasks/code.py`
- `learn-claude-code/s14_cron_scheduler/code.py`
- `learn-claude-code/s15_agent_teams/code.py`
- `learn-claude-code/s17_autonomous_agents/code.py`
- `learn-claude-code/s18_worktree_isolation/code.py`
- `learn-claude-code/s20_comprehensive/code.py`
- `analysis/10-learn-claude-code.md`

Java:

- `spring-ai-examples/agentic-patterns/README.md`
- `spring-ai-examples/agentic-patterns/chain-workflow/src/main/java/com/example/agentic/ChainWorkflow.java`
- `spring-ai-examples/agentic-patterns/orchestrator-workers/src/main/java/com/example/agentic/OrchestratorWorkers.java`
- `spring-ai-examples/agentic-patterns/evaluator-optimizer/src/main/java/com/example/agentic/EvaluatorOptimizer.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/DefaultToolExecutor.java`
- `langchain4j/langchain4j/src/main/java/dev/langchain4j/service/tool/ToolProvider.java`
- `langchain4j/langchain4j-agentic/src/test/java/dev/langchain4j/agentic/carrentalassistant/AssistantMain.java`
- `langchain4j/langchain4j-skills/src/main/java/dev/langchain4j/skills/Skills.java`
