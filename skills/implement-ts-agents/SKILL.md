---
name: implement-ts-agents
description: Implement AI agent features in TypeScript, Node, Next.js, OpenAI Agents JS, Vercel AI SDK, LangGraphJS, or Pi-inspired custom runtimes. Use for tool-calling loops, runtimeContext/toolsContext, prepareStep, stopWhen, toolApproval, streaming UI boundaries, graph persistence, handoffs, and subagent patterns.
metadata:
  version: 2.1.0
  short-description: Implement TypeScript agent patterns
---

# Implement TypeScript Agents

Inspect the host project first and match its framework, dependency injection,
test style, logging, and provider wrapper. Do not introduce a new framework when
the existing one can support the required shape.

## Version Reality Check

The TypeScript agent ecosystem moves faster than any written guidance. Before
writing code, read the versions actually installed in the host project and check
their current docs. Two traps as of the 2026-08 source snapshot:

- **Vercel AI SDK v7 is stable and breaking.** `stepCountIs` became
  `isStepCount`; all packages are **ESM-only** with CommonJS exports removed;
  `ToolCallOptions` is gone in favor of `ToolExecutionOptions`;
  `experimental_customProvider` was removed; telemetry graduated out of
  `experimental_` and `*TelemetryIntegration` became `*Telemetry`; callback event
  data was reworked; `StepResult` response messages narrowed to messages created
  in that step.
- **MCP TypeScript SDK v2 is a package rename, not a version bump.** The v2 line
  ships as new scoped packages (`@modelcontextprotocol/core`, `/client`,
  `/server`, and friends); the old monolithic `@modelcontextprotocol/sdk` stays
  on its 1.x line and does not advance to 2.x. Migration changes import sources.

Never rely on a framework's default model. Defaults change between minor
versions; specify the model explicitly in production code.

## Pi-Inspired Runtime

Use this shape for a custom runtime:

- internal `AgentMessage[]`
- provider conversion at the model boundary
- `transformContext()` before each model call
- event stream for message/tool lifecycle
- `beforeToolCall` and `afterToolCall` hooks
- deterministic ordering of tool results
- session/harness layer above the loop

Keep structural operations such as prompt switch, skill load, compaction, and
history navigation outside the active loop or guarded by an idle lock.

If the runtime must survive a crash, add a durable layer rather than trying to
replay the message array:

- three stores with distinct roles — a write-once history, mutable named
  registers for current state, an append-only usage ledger;
- a durable program counter: after each step, overwrite one register with the
  *total* current state, so recovery reads one value and switches instead of
  replaying;
- an effect sandwich around uncertain side effects — commit the intent with
  pre-minted output ids, do the effect, commit the settlement;
- a per-tool replay policy, where a non-replayable tool yields a synthesized
  "interrupted" result on resume so the call/result pairing stays well-formed;
- named cursors ("lanes") into the shared history for threads, subagents, and
  parallel work, instead of a separate history per concurrent unit.

Write the non-goals down next to the capabilities. See
`analysis/01-pi-source-analysis.md`.

## Plugin-Tree Runtime

An alternative skeleton for a custom TypeScript runtime: a small kernel plus a
tree of plugins, where a product profile composes bundles of plugins into one
configuration. Worth considering when the same capabilities must ship as several
products (a CLI, a server, a headless worker) rather than one.

What it buys:

- capabilities become individually loadable, replaceable, and testable;
- the effective configuration for a profile is dumpable, so "what is actually
  enabled here" is answerable without reading code;
- ordering and lifecycle are the kernel's problem, not each feature's.

What it costs, and when to skip it:

- with two or three deployment shapes the indirection costs more than it saves;
- a plugin that is both the definition of a capability and its only provider
  produces an untestable, unreplaceable seam — keep contract, provider, and
  consumer distinct;
- disposal becomes a real obligation: unloading must reach quiescence, or hot
  reload leaks timers and listeners.

See `analysis/18-deepseek-harness.md`.

## OpenAI Agents JS

Use when the project already uses or can adopt OpenAI Agents JS.

Recommended shape:

```ts
const searchTool = tool({
  name: "search_docs",
  description: "Search project documentation for relevant snippets.",
  parameters: z.object({ query: z.string() }),
  execute: async ({ query }) => searchDocs(query),
});

const agent = new Agent({
  name: "Support agent",
  instructions: "Answer using tools when project facts are needed.",
  tools: [searchTool],
});

const result = await run(agent, userInput);
```

Use handoffs when control transfers to another specialist. Use agent-as-tool
when the parent keeps control and delegates a bounded subtask. For human
approval, persist run state, collect approve/reject externally, then resume.

Recent capabilities worth knowing before hand-rolling equivalents:

- **Programmatic tool calling** lets supported models emit hosted JavaScript
  that coordinates eligible tools and reduces their intermediate results,
  preserved across streaming, sessions, replay, and serialized run state. Use it
  when a task chains many tools whose intermediates are large and uninteresting.
- **Deterministic testing entry points** (`@openai/agents/testing` and the
  core/realtime equivalents) provide a scripted model, scripted sandbox session,
  and scripted realtime transport. Prefer them over a hand-written fake.
- **Resume is fail-closed by design.** Serialized output-bearing approval
  checkpoints error rather than guess when ownership of a pending terminal tool
  output cannot be proven; non-streaming replay needs an explicit unsafe-replay
  opt-in; serialized credentials and mount authority are not trusted on resume.
  Do not paper over these with a blanket catch — continue from live state or
  restart from safe input.
- **Sensitive model and tool data logging is off by default.** Enable it
  explicitly and only where the trace store is appropriately protected.
- Local MCP connections negotiate the current protocol with fallback for older
  servers, so applications need not bridge SDK generations themselves.

See `analysis/02-agent-framework-patterns.md`.

## Vercel AI SDK

Use `ToolLoopAgent` for in-memory TS/Next agents and `WorkflowAgent` for durable
agents.

Practices:

- Put shared request state in `runtimeContext`.
- Put per-tool secrets and permissions in `toolsContext`.
- Set explicit `stopWhen`.
- Use `prepareStep` for compaction, active tool selection, or model switching.
- Use `toolApproval` for mutating or sensitive tools.
- Use async generator tools when UI should receive intermediate states.

Small shape:

```ts
const agent = new ToolLoopAgent({
  model,
  instructions: "Use tools only when needed.",
  tools: {
    lookup: tool({
      description: "Look up a record by id.",
      inputSchema: z.object({ id: z.string() }),
      execute: async ({ id }, { context }) => context.repo.find(id),
    }),
  },
  stopWhen: isStepCount(10),
});
```

Use `WorkflowAgent` when tool calls must survive restarts, retries, workflow step
boundaries, or delayed approval.

## LangGraphJS

Use LangGraphJS when the process is better modeled as a graph than a simple
loop.

Typical graph:

- state annotation for messages and domain state
- agent node that calls the model
- tool node that executes calls
- conditional edge from agent to tool node or end
- checkpointer for persistence

Use graph persistence for thread state, checkpoint history, replay, fork, or
resume. For multi-agent systems, choose supervisor routing or dynamic swarm
handoff deliberately. A handoff tool should return a command/goto rather than
only text.

## Subagents

Subagents are useful when:

- context-heavy research would pollute parent context;
- tools must be isolated by capability;
- independent tasks can run in parallel;
- parent only needs a compressed result.

Avoid subagents for simple single-tool tasks. They add latency, cost, and
failure modes.

## Tests to Add

- Tool unit tests for validation, denial, dependency failure, and output shape.
- Fake-model loop tests for tool call, finish, malformed args, repeated calls,
  stop condition, and approval pause/resume.
- Streaming/UI boundary tests if model messages differ from UI messages.
- Persistence/resume tests for graphs or workflows.
- Recovery tests that kill the process between an effect's intent and its
  settlement, and assert recovery can tell whether the effect happened.
- Resume tests asserting approvals and credentials are re-obtained, not
  restored, and that an ambiguous pending output fails closed.

Read `../test-ai-agents/SKILL.md` for the full test/eval strategy.
