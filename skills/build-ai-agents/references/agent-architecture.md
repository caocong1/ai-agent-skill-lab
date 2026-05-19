# Agent Architecture Reference

## Core Model

Treat an agent as an application subsystem:

- model adapter
- instructions
- tool registry
- orchestration loop or graph
- state and memory
- approval and permission boundary
- event/trace stream
- tests and evals

Do not let one controller, route handler, or prompt own all of these concerns.

## Decision Table

| Requirement | Recommended shape | Avoid |
| --- | --- | --- |
| Pure deterministic task, no model judgment | Plain code, no agent | Any agent loop |
| Extract or classify data once | Single model call with structured output | Tool loop |
| Known steps in fixed order | Chain workflow | Autonomous agent |
| Branching based on typed classification | Router workflow | Free-form prompt branching |
| Independent specialist analysis | Parallel workers then synthesis | Sequential slow loop |
| Output quality must be gated or measured | Evaluator-optimizer plus eval set | One-shot generation |
| Model decides which action to take | Tool loop | Hard-coded chain |
| Human approval or long-running work | Durable graph/workflow | In-memory message array only |
| Streaming tool or UI state to a client | Streaming loop with separate UI/model messages | Returning only final text |
| Separate expertise or tool access | Subagent / agent-as-tool | Giving all tools to one agent |
| Shared external capability | MCP server | Duplicated project-specific tools |
| Multi-tenant data access | Per-request scoped tool context plus isolation tests | Shared/global tool context |
| Side effects must be reversible | Idempotent tools plus compensation plan | Fire-and-forget mutations |
| Context exceeds window | Compaction/retrieval before model call | Unbounded message array |

## Loop Design

A robust tool loop has these phases:

1. Build a stable turn snapshot from session state.
2. Transform or compact context before the model call.
3. Convert internal messages to provider messages at the boundary.
4. Call the model with active tools.
5. Validate tool calls against schemas.
6. Apply approval and permission hooks before execution.
7. Execute tools in a deterministic result order, even if execution is parallel.
8. Return tool results to the model or finish.
9. Emit events and persist state after safe checkpoints.

## State Design

Keep these contracts separate:

- domain state: application records and business data
- agent runtime state: step count, active tools, pending approval, trace ids
- memory: persisted facts or conversation summaries used in future turns
- model messages: compact provider-facing context
- UI messages: display and interaction state

This separation prevents UI artifacts, secrets, or internal state from leaking into model prompts.

## Approval Design

Approval belongs at the tool execution boundary. Use prompts to explain policy, but enforce policy in code.

Require explicit approval for tools that:

- mutate files, databases, tickets, payments, or external systems
- run commands or code
- send messages or notifications
- access private or regulated data
- spend money or consume large resources

Approval results should become part of the model-visible tool result so the agent can stop, retry differently, or explain denial.

## Memory Design

Use memory only when the agent needs information across turns or sessions.

Common patterns:

- short-term chat memory: recent messages
- summarized session memory: compacted history
- structured long-term memory: facts with keys, timestamps, sources
- retrieval memory: documents or embeddings
- provider memory tool: low effort but provider-specific

Memory tools need scoped permissions and tenant/user isolation.
