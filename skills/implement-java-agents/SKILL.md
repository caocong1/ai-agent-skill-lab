---
name: implement-java-agents
description: Implement AI agent features in Java, Spring AI, LangChain4j, service-layer applications, annotation-based tools, MCP providers, DI-heavy projects, and typed workflow services. Use for ChatClient, AiServices, AgenticServices, @Tool, @McpTool, FunctionToolCallback, ToolProvider, ToolExecutor, ChatMemory, and AgenticScope patterns.
metadata:
  version: 2.1.0
  short-description: Implement Java and Spring agents
---

# Implement Java Agents

Model agents as application services. Keep controllers thin and put prompts,
workflow logic, tools, permissions, memory, and tests in typed service layers.

## Service Boundary

Recommended layering:

- controller receives request and auth context;
- service owns workflow/agent orchestration;
- tool classes own external actions;
- repositories/clients are injected;
- records/classes define input and output contracts.

Avoid embedding large prompts or tool logic directly in controllers.

## Spring AI Workflows

Use fixed workflows when steps are known:

- chain: fixed sequential transformations;
- router: classify, then call the right path;
- parallelization: independent calls, then aggregate;
- orchestrator-workers: model creates typed tasks, workers process them;
- evaluator-optimizer: generate, evaluate, refine until pass or budget ends.

Implementation checklist:

- Use records or DTOs for structured outputs.
- Put max iterations on evaluator loops.
- Use explicit executor, `CompletableFuture`, or virtual threads when true
  parallelism is required.
- Keep prompts close to the owning service.
- Unit test workflow branches with fake chat clients.

## Spring AI Tools and MCP

For function callbacks:

- give each tool a stable name;
- write descriptions for the model;
- use typed request records/classes;
- validate permissions inside the callback;
- return structured objects where possible.

For MCP annotations:

- expose only allowlisted methods;
- describe every parameter precisely;
- return structured content;
- add auth, tenant checks, rate limits, and audit logs for remote tools.

## LangChain4j

Use `AiServices` or `AgenticServices` to keep Java-native structure.

Useful patterns:

- interface-based agents;
- `MessageWindowChatMemory` or project-specific memory provider;
- `sequenceBuilder` for fixed multi-agent pipelines;
- `conditionalBuilder` for state-based specialist invocation;
- `AgenticScope` for intermediate state;
- `outputKey` for stable state writes.

Tool provider guidance:

- static providers are enough for fixed tools;
- dynamic providers only when active tools depend on request state,
  permissions, or conversation state;
- active tool sets should be logged or traceable.

Tool executor guidance:

- parse arguments before business logic;
- inject memory id or invocation context explicitly;
- convert object results to JSON or structured content;
- return model-correctable tool errors as tool results;
- throw/log system errors through normal application error handling.

## Version Reality Check

Read the versions actually on the classpath before writing code. Two facts as of
the 2026-08 source snapshot:

- The Spring AI example corpus this guidance was distilled from has been aligned
  to **Spring AI 2.0**. The patterns below still hold at the shape level, but
  annotation names, package paths, and configuration properties must be checked
  against the 2.0 reference rather than copied from older material.
- LangChain4j 1.19.0 ships an MCP client implementing the **2026-07-28**
  revision. Design new MCP integrations against that baseline directly — see
  `../build-mcp-capabilities/SKILL.md` — rather than writing the old handshake
  and migrating later.

## Compensating Side Effects

The JVM ecosystem already has the vocabulary for the third part of side-effect
governance, and LangChain4j now exposes it at the agentic level: register a
**compensating action** for a completed tool action so an upper-level failure
can roll it back rather than leave half-finished state.

Retry, approval, and compensation solve three different problems and none
substitutes for another:

- retry assumes the operation can safely be repeated;
- approval intercepts before execution;
- compensation undoes what already executed.

If an agentic flow mutates external systems, decide explicitly which of the
three each mutation gets. Saga and TCC semantics transfer directly here — this
is a real advantage of the JVM side over the TypeScript side, and worth raising
during platform selection. See `analysis/03-java-agent-patterns.md`.

## Java Tests

- Unit test tool classes without a real model.
- Unit test workflow routing with fake typed model outputs.
- Integration test one or two real model paths per critical agent.
- Test denial paths for sensitive tools.
- Test max-iteration and timeout behavior.
- Test memory isolation across users/tenants.

Read `../secure-ai-agents/SKILL.md` for permission and tenant checks, and
`../test-ai-agents/SKILL.md` for eval and observability guidance.
