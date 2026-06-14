---
name: implement-ts-agents
description: Implement AI agent features in TypeScript, Node, Next.js, OpenAI Agents JS, Vercel AI SDK, LangGraphJS, or Pi-inspired custom runtimes. Use for tool-calling loops, runtimeContext/toolsContext, prepareStep, stopWhen, toolApproval, streaming UI boundaries, graph persistence, handoffs, and subagent patterns.
metadata:
  version: 2.0.0
  short-description: Implement TypeScript agent patterns
---

# Implement TypeScript Agents

Inspect the host project first and match its framework, dependency injection,
test style, logging, and provider wrapper. Do not introduce a new framework when
the existing one can support the required shape.

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

Read `../test-ai-agents/SKILL.md` for the full test/eval strategy.
