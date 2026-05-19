# TypeScript Agent Patterns

## Pi-Inspired Runtime Pattern

Use this shape when implementing a custom runtime:

- internal `AgentMessage[]`
- provider conversion at the model boundary
- `transformContext()` before each model call
- event stream for message/tool lifecycle
- `beforeToolCall` and `afterToolCall` hooks
- deterministic ordering of tool results
- session/harness layer above the loop

Keep structural operations such as prompt switch, skill load, compaction, and history navigation outside the active loop or guarded by an idle lock.

## OpenAI Agents JS Pattern

Use when the project already uses or can adopt OpenAI Agents JS.

Recommended shape:

```ts
const searchTool = tool({
  name: 'search_docs',
  description: 'Search project documentation for relevant snippets.',
  parameters: z.object({ query: z.string() }),
  execute: async ({ query }) => searchDocs(query),
});

const agent = new Agent({
  name: 'Support agent',
  instructions: 'Answer using tools when project facts are needed.',
  tools: [searchTool],
});

const result = await run(agent, userInput);
```

Use handoffs when control transfers to another specialized agent. Use agent-as-tool when the parent keeps control and delegates a bounded subtask.

For human approval, persist the run state, collect approve/reject externally, then resume from the stored state.

## Vercel AI SDK Pattern

Use `ToolLoopAgent` for in-memory TS/Next agents and `WorkflowAgent` for durable agents.

Important practices:

- Put shared request state in `runtimeContext`.
- Put per-tool secrets and permissions in `toolsContext`.
- Set explicit `stopWhen` conditions for long-running loops.
- Use `prepareStep` for message compaction, active tool selection, or model switching.
- Use `toolApproval` for mutating or sensitive tools.
- Use async generator tools when the UI should receive intermediate tool states.

Small agent shape:

```ts
const agent = new ToolLoopAgent({
  model,
  instructions: 'Use tools only when needed.',
  tools: {
    lookup: tool({
      description: 'Look up a record by id.',
      inputSchema: z.object({ id: z.string() }),
      execute: async ({ id }, { context }) => context.repo.find(id),
    }),
  },
  stopWhen: isStepCount(10),
});
```

Use `WorkflowAgent` when tool calls must survive restarts, retries, workflow step boundaries, or delayed approval.

## LangGraphJS Pattern

Use LangGraphJS when the process is better modeled as a graph than a simple loop.

Typical graph:

- state annotation for messages and domain state
- agent node that calls the model
- tool node that executes calls
- conditional edge from agent to tool node or end
- checkpointer for persistence

Use graph persistence when you need thread state, checkpoint history, replay, fork, or resume.

For multi-agent systems:

- supervisor pattern: central node routes to specialist agents
- swarm pattern: agents hand off dynamically
- handoff tool returns a command/goto rather than only text

## Subagent Pattern

Subagents are useful when:

- context-heavy research would pollute the parent context
- tools must be isolated by capability
- independent tasks can run in parallel
- the parent only needs a compressed result

Avoid subagents for simple single-tool tasks. They add latency, cost, and failure modes.

