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

## Agent vs Harness Boundary

Agency — the capacity to perceive, reason, and act — is produced by model training, not by code orchestration. The engineering work in this codebase is harness engineering: shaping the environment in which a capable model operates (see `analysis/10-learn-claude-code.md`).

A harness has five jobs. Use them as the mental model when scoping an agent feature:

- **Tools**: the actions the model can take (file I/O, shell, HTTP, database, browser, MCP). Atomic, composable, clearly described.
- **Knowledge**: domain references, style guides, SOPs, skills. Loaded on demand, not dumped into the system prompt up front.
- **Context management**: prompt assembly, compaction, subagent isolation, memory writes. Keeps the working window relevant and bounded.
- **Observation and action interfaces**: how the model sees the world (diffs, logs, search results, sensor data) and how its decisions become side effects (tool handlers, approvals, message bus).
- **Permissions**: code-level enforcement of what is allowed, what requires approval, and what is denied — independent of prompt wording.

The loop itself does not change as the harness grows; new capability is added by composing the five jobs above. If a feature appears to demand rewriting the loop, the loop is probably being asked to absorb work that belongs in the harness.

Two consequences for design:

- A "smarter agent" is usually a better harness, not a more elaborate prompt chain. Before adding orchestration logic, check whether better tools, sharper knowledge selection, tighter context, cleaner observations, or stricter permissions would solve the same problem with less moving code.
- A "richer interaction" is usually trajectory exhaust: the action sequences the model produces are simultaneously the user-visible behavior and raw material for future fine-tuning. Treat trajectories as a product output — same redaction and consistency standards as logs (see `references/security-and-safety.md`).

## Workflow vs Agent

Separate two shapes before choosing a framework (see `analysis/06-anthropic-building-effective-agents.md`):

- Workflow: the LLM and tools are orchestrated through predefined code paths. Steps are knowable, so the control flow is written by engineers and the model fills slots.
- Agent: the LLM dynamically directs its own process and tool usage based on environment feedback, looping until a stop condition.

Default to the least powerful shape: deterministic code, then a single call, then a fixed workflow. Choose an autonomous agent only when steps are genuinely unpredictable, the path cannot be hard-coded, and the tool environment is trustworthy. Frameworks are a starting point, not a substitute for understanding this choice.

Before calling something an agent, qualify the use case (see `analysis/09-openai-practical-guide-building-agents.md`). Agent complexity is most justified when a workflow has nuanced decisions, brittle rule systems, or heavy unstructured data that simpler automation cannot handle. If the requirement is a single classification, extraction, summary, or fixed sequence, keep it out of the agent loop.

Workflow-driven platforms (Coze, Dify, n8n, similar low-code automation hubs) and AI-native agents are two methodologies, not two tool preferences (see `analysis/11-hello-agents.md`). The platforms treat the LLM as a data-processing backend inside engineer-authored flow; the AI-native shape puts the model's judgment at the center and arranges tools and context around it. Choose the platform shape when the flow is broadly enumerable and predictability matters; choose the AI-native shape when the path is unknown ahead of time. Calling a platform flow an "agent" because it embeds an LLM call obscures this judgment.

If a team lacks shared vocabulary for what an agent must do, building a minimal Message/Config/Agent triplet against a raw provider API once — before adopting any framework — clarifies which abstractions are essential versus framework-specific (see `analysis/11-hello-agents.md` chapter 7). The exercise is a teaching tool, not a production substitute for LangGraph, OpenAI Agents JS, Vercel AI SDK, or Pi.

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
| Open-ended task, steps not predictable, trusted tools | Autonomous tool loop with stop conditions | Hard-coded chain or over-built graph |
| Human approval or long-running work | Durable graph/workflow | In-memory message array only |
| Streaming tool or UI state to a client | Streaming loop with separate UI/model messages | Returning only final text |
| Separate expertise or tool access | Subagent / agent-as-tool | Giving all tools to one agent |
| Shared external capability | MCP server | Duplicated project-specific tools |
| Multi-tenant data access | Per-request scoped tool context plus isolation tests | Shared/global tool context |
| Side effects must be reversible | Idempotent tools plus compensation plan | Fire-and-forget mutations |
| Context exceeds window | Compaction/retrieval before model call | Unbounded message array |

## Single vs Multi-Agent

Prefer one capable agent with well-shaped tools until there is concrete evidence that splitting helps. Add a second agent only when one of these pressures is visible:

- instructions have grown into many conditional branches that are hard to test;
- similar or overlapping tools cause repeated selection errors even after naming and descriptions are improved;
- separate expertise, context, or permissions must be isolated;
- a specialist result can be treated as a tool output without giving the specialist control of the user conversation.

Choose the coordination shape deliberately:

- **Manager / agent-as-tool**: one primary agent remains in control, calls specialist agents as tools, and synthesizes the result for the user. Use when continuity and a single final answer matter.
- **Handoff**: one agent transfers control to another specialist. Use when the specialist should own the next part of the conversation or workflow.

Do not use multi-agent decomposition as a substitute for clearer prompts, better tools, or a smaller workflow.

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

Every iteration must consume real environment/tool feedback (ground truth such as tool results or execution output), and the loop must have explicit stop conditions: task complete, step/cost/token budget exhausted, or a human checkpoint. A loop without environment feedback is not an agent; a loop without an explicit stop is an incident.

Add extension points around the loop, not inside it. A small set of named hooks — for example pre/post tool call, pre/post turn, on stop — lets you attach permission checks, redaction, audit logging, cost accounting, and experiment instrumentation without modifying the loop body (see `analysis/10-learn-claude-code.md`). If a feature can only be implemented by editing the main loop, treat that as a smell: either the hook surface is too small or the feature belongs in a tool or in state, not in the loop.

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
