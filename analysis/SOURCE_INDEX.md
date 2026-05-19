# Source Index

更新时间：2026-05-19。所有仓库均以 shallow clone 方式保存在 `raw/repos/`。

逐来源的 `来源版本 / 分析版本 / 最后更新` 在下方表格维护；再分析某来源新版本时，更新该来源所在行 + 对应分析文件头部元数据块 + `CHANGELOG.md`。`来源版本` 对仓库是 commit，对文章是发布/抓取日期。`分析版本` 是本仓库对该来源的分析报告版本，与 skill 版本独立。

## Repositories

| 项目 | 本地路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Pi | `raw/repos/pi` | `4943c1d62c8e6f3437446f480bb3e8422869535d` | 1.0 | 2026-05-18 | agent loop、harness、skills、resource loader、extensions、subagents |
| OpenAI Agents JS | `raw/repos/openai-agents-js` | `629d35af99e1ba80fc968b0d062c070caed0683d` | 1.0 | 2026-05-18 | Agent、tools、handoffs、guardrails、interruptions、RunState |
| LangGraphJS | `raw/repos/langgraphjs` | `bd72a897e15d0a29a06b8b8b4c589851b6c7b4a6` | 1.0 | 2026-05-18 | graph orchestration、checkpoint、thread、HITL、multi-agent handoff |
| MCP TypeScript SDK | `raw/repos/modelcontextprotocol-typescript-sdk` | `22595b96855b34f00adcc6c1e7932ad68ea5139d` | 1.0 | 2026-05-18 | MCP server/client、tool/resource/prompt、stdio/http transport |
| Vercel AI SDK | `raw/repos/vercel-ai` | `aa5a1e539643c2a7162a141502eee63c665a9544` | 1.0 | 2026-05-18 | ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP adapter |
| Spring AI Examples | `raw/repos/spring-ai-examples` | `2a6088db3d18d5fa6fc208b12adf1172d22f77fd` | 1.0 | 2026-05-18 | Java agentic patterns、function callback、MCP annotations |
| LangChain4j | `raw/repos/langchain4j` | `6185599e370388b3c54489051c57469ef9094d5b` | 1.0 | 2026-05-18 | Java AI service、tool executor/provider、agentic sequence、skills |

## Articles and Papers

非代码来源的权威文章/论文。快照保存在 `raw/docs/`，分析报告在 `analysis/`。

| 来源 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点 |
| --- | --- | --- | --- | --- | --- |
| Anthropic, Building Effective Agents | `raw/docs/anthropic-building-effective-agents.md` | 发布 2024-12-19 / 抓取 2026-05-19 | 1.0 | 2026-05-19 | workflow 与 agent 判定、五种 workflow 模式、自治 agent 循环、simplicity/transparency/ACI |

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
- Google Agent Development Kit docs: https://google.github.io/adk-docs/

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
