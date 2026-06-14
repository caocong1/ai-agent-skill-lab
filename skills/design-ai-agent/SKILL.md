---
name: design-ai-agent
description: Choose and specify AI agent architecture before implementation. Use for deciding whether an agent is needed, selecting deterministic code vs single model call vs structured workflow vs ReAct/tool loop vs durable graph vs subagents, and designing loop, state, memory, approval, and harness boundaries.
metadata:
  version: 2.0.0
  short-description: Choose the right agent architecture
---

# Design AI Agent

Use this skill before implementing an agent or when reviewing whether an
existing design is too simple, too broad, or too autonomous.

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

## Agent vs Harness

Agency is produced by model training, not by code orchestration. The engineering
work is harness engineering: shaping the environment where a capable model
operates.

A harness has five jobs:

- **Tools**: actions the model can take. Keep them atomic, composable, and
  clearly described.
- **Knowledge**: domain references, style guides, SOPs, and skills loaded on
  demand.
- **Context management**: prompt assembly, compaction, subagent isolation,
  memory writes, and retrieval.
- **Observation/action interfaces**: how the model sees the world and how its
  decisions become side effects.
- **Permissions**: code-level enforcement independent of prompt wording.

If a feature appears to require rewriting the loop, first check whether it
belongs in tools, knowledge selection, context management, observations,
permissions, or state.

## Workflow vs Agent

Use a workflow when the LLM and tools follow predefined code paths. Use an
agent when the model dynamically directs its process and tool usage from
environment feedback until a stop condition.

Default to the least powerful shape:

1. deterministic code
2. single model call
3. structured workflow
4. autonomous tool loop
5. durable graph/workflow
6. multi-agent or subagents

Choose an autonomous agent only when steps are genuinely unpredictable, the path
cannot be hard-coded, and the tool environment is trustworthy.

Workflow-driven platforms such as Coze, Dify, and n8n treat the LLM as a
component inside engineer-authored flow. AI-native agents put model judgment at
the center and arrange tools/context around it. Name the method honestly.

## Decision Table

| Requirement | Recommended shape | Avoid |
| --- | --- | --- |
| Pure deterministic task, no model judgment | Plain code | Any agent loop |
| Extract/classify/summarize once | Single model call with structured output | Tool loop |
| Known steps in fixed order | Chain workflow | Autonomous agent |
| Branching on typed classification | Router workflow | Free-form prompt branching |
| Independent specialist analysis | Parallel workers then synthesis | Sequential slow loop |
| Quality must be gated | Evaluator-optimizer plus eval set | One-shot generation |
| Model decides which action to take | ReAct/tool loop | Hard-coded chain |
| Open-ended task with trusted tools | Tool loop with stop conditions | Over-built graph |
| Approval, long-running work, resume | Durable graph/workflow | In-memory array only |
| Streaming UI/tool state | Streaming loop with UI/model split | Final text only |
| Separate expertise or tool access | Subagent or agent-as-tool | One agent with all tools |
| Shared external capability | MCP server | Duplicated project tools |
| Multi-tenant data | Scoped tool context + isolation tests | Global context |
| Reversible side effects required | Idempotent tools + compensation | Fire-and-forget mutation |
| Context exceeds window | Retrieval/compaction before call | Unbounded messages |

## Single vs Multi-Agent

Prefer one capable agent with well-shaped tools until there is evidence that
splitting helps. Add another agent only when:

- instructions have grown into many hard-to-test conditional branches;
- overlapping tools cause repeated selection errors after naming/description
  improvements;
- expertise, context, or permissions must be isolated;
- a specialist result can be treated as a tool output without giving the
  specialist control of the user conversation.

Choose coordination deliberately:

- **Manager / agent-as-tool**: parent remains in control and calls specialists
  for bounded subtasks.
- **Handoff**: control transfers to a specialist that should own the next part
  of the conversation or workflow.

## Loop Design

A robust tool loop:

1. Builds a stable turn snapshot from session state.
2. Transforms or compacts context before the model call.
3. Converts internal messages to provider messages at the boundary.
4. Calls the model with active tools.
5. Validates tool calls against schemas.
6. Applies approval and permission hooks before execution.
7. Executes tools in deterministic result order, even when parallelized.
8. Returns tool results to the model or finishes.
9. Emits events and persists state after safe checkpoints.

Every iteration must consume real environment/tool feedback, and every loop must
stop on task completion, step/cost/token budget, timeout, or human checkpoint.

Add extension points around the loop: pre/post tool call, pre/post turn, on stop.
Use hooks for permissions, redaction, audit logging, cost accounting, and
experiments without editing the loop body.

## State, Approval, Memory

Keep separate contracts for:

- domain state
- agent runtime state
- memory
- model messages
- UI messages
- traces

Approval belongs at the tool execution boundary. Require explicit approval for
file/database/ticket/payment mutations, commands, notifications, private data,
regulated data, money, or large resource spend. Make the approval result visible
to the model as a structured tool result.

Use memory only when the agent needs information across turns or sessions.
Memory needs scoped permissions, provenance, tenant/user isolation, and a
forgetting policy.

## Handoff

- For TypeScript implementation, read `../implement-ts-agents/SKILL.md`.
- For Java implementation, read `../implement-java-agents/SKILL.md`.
- For tools/context/retrieval/memory details, read `../design-agent-tools/SKILL.md`.
- For MCP capability boundaries, read `../build-mcp-capabilities/SKILL.md`.
- For security boundaries, read `../secure-ai-agents/SKILL.md`.
- For tests/evals/observability, read `../test-ai-agents/SKILL.md`.
