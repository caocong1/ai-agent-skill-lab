---
name: implement-java-agents
description: Implement AI agent features in Java, Spring AI, LangChain4j, service-layer applications, annotation-based tools, MCP providers, DI-heavy projects, and typed workflow services. Use for ChatClient, AiServices, AgenticServices, @Tool, @McpTool, FunctionToolCallback, ToolProvider, ToolExecutor, ChatMemory, and AgenticScope patterns.
metadata:
  version: 2.2.0
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

For confirmation-gated tools (Spring AI 2.1), mark a tool as requiring
confirmation or supply a confirmation policy; the loop pauses before any call in
the reply runs, keeps no state while paused, and resumes with a decision per
awaiting call. Policies combine with OR, so configuration can only add
confirmations — keep it that way in your own policies, and list the escape
hatches (a global disable switch, a replaced tool-calling manager bean) as
review items. The paused reply is authority-bearing state: read it back from
server-side storage, never from the client. For batch or other non-interactive
runs, deny calls that need confirmation instead of disabling confirmation.

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
- return model-correctable tool errors as tool results, and mark explicitly which
  exception types may show their message to the model;
- throw/log system errors through normal application error handling.

For routing, gating and grading, LangChain4j's decision models return a typed
answer with probabilities — a better fit for a classifier step than parsing JSON
out of a chat reply. They are experimental.

## Version Reality Check

Read the versions actually on the classpath, and their release notes, before
writing code — version numbers alone mislead (one LangChain4j patch was
mis-published with newer code than the release after it). Facts as of the
2026-10 source snapshot:

- **Spring AI 2.1 (RC as of 2026-10)** deprecates the `ChatMemory` family
  (`MessageWindowChatMemory`, `ChatMemoryRepository`, `MessageChatMemoryAdvisor`,
  the stores) for removal in 3.0, in favor of an event-sourced session module:
  an append-only event log, a prompt built from a view of it, windows that keep
  turns whole, and compaction recorded as a boundary event. It also adds tool
  call confirmation (below). `defaultToolCallbacks()` is deprecated for
  `defaultTools()`. Re-check at GA.
- Spring AI's pinned MCP Java SDK does **not** yet implement the 2026-07-28
  revision; LangChain4j has had a 2026-07-28 client since 1.19.0. Design new MCP
  integrations against that baseline — see `../build-mcp-capabilities/SKILL.md`.
- LangChain4j 1.21+ lets an exception declare whether its message is visible to
  the model, warns when a tool has no explicit error handler, and plans to make
  "not visible" the default in 2.0; Spring AI's default still sends runtime
  exception messages to the model. Decide it per error type now.
- Changing a LangChain4j AI Service method to an asynchronous return type changes
  its defaults: tools run concurrently and execution errors fail the call. Treat
  the switch as a behavior change and test it.

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
