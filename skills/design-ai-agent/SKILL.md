---
name: design-ai-agent
description: Choose and specify AI agent architecture before implementation. Use for deciding whether an agent is needed, selecting deterministic code vs single model call vs structured workflow vs ReAct/tool loop vs durable graph vs subagents, and designing loop, state, memory, approval, and harness boundaries.
metadata:
  version: 2.2.0
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

## Model-Visible Surface and Authority

Shape selection is the first question, not the only one. Two designs with the
same shape can differ completely on the two axes that decide whether the system
is safe and affordable:

- **What does the model see?** Every capability should have a written answer for
  what the model sees, what it costs in tokens, and what it does to prompt-cache
  reuse. State the invariant explicitly: anything model-visible is logged, and
  anything logged is model-visible. If the two can diverge, replay and audit
  both become fiction.
- **Who decides what happens?** Visibility is not authority. A model that can
  see a tool must still pass an authority boundary to use it, and that boundary
  must be enforced in code, not in prompt wording.

Write both answers down per capability before implementing it. See
`analysis/18-deepseek-harness.md`.

Define a capability as three roles that are designed together, never as one:
its **definition** (the contract), its **provider** (who implements it), and
its **consumer** (who calls it). A seam missing any of the three is a leak: the
common failure is a plugin that is simultaneously the definition and the only
provider, which makes the contract untestable and unreplaceable.

## Perishable vs Durable Design

Every harness component encodes a dated assumption about what the model cannot
do on its own. Those assumptions expire as models improve. Classify each
component before writing it:

- **Perishable** — compensates for a current model weakness: context resets,
  sprint decomposition, anti-drift prompt patches, step-by-step scaffolding for
  a weaker model. Record it as "we added X because the model at version M could
  not do Y." That record is the ablation list for the next model generation.
- **Durable** — governs authority, evidence, side effects, or cost. These get
  *more* valuable as models improve: a more capable model can do more, so
  boundaries matter more; a more convincing self-assessor makes independent
  judgment more necessary; model capability never makes external systems
  transactional or tokens free.

Treat a model upgrade as an explicit review trigger: re-run the perishable list
and delete what the model no longer needs. Do not ablate the durable list on the
same schedule. See `analysis/19-anthropic-harness-design-long-running-apps.md`
and `analysis/21-lab-design-rethink-2026-08.md`.

Publish a **non-goals list** next to the capability list, with equal
prominence. Readers need to decide in minutes whether the design fits, and a
capability list alone cannot tell them what it deliberately refuses to do.

## Agent vs Harness

Agency is produced by model training, not by code orchestration. The engineering
work is harness engineering: shaping the environment where a capable model
operates.

A harness has three nested engineering layers. Design only the layers the task
needs:

1. **Turn/runtime**: the loop, tools, context, observations, permissions,
   sandbox, approvals, events, and budgets for one active run.
2. **Session continuity**: rollout/history, checkpoints, progress and decision
   records, completion contracts, resume/fork, and clean handoff across context
   windows or processes.
3. **Repository/organization feedback**: discoverable specifications,
   architecture maps, reproducible environments, observability, executable
   invariants, review feedback, and recurring maintenance that improve future
   runs.

The runtime layer has five core jobs:

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

For coding agents, optimize for **agent legibility**: the agent must be able to
discover authoritative knowledge, start the application, observe user-visible
behavior and telemetry, and receive actionable failures from mechanical checks.
Use a short `AGENTS.md` as a map into structured repository-local sources of
truth instead of a monolithic manual. Keep sensitive data outside git and expose
only the necessary scoped view. See `analysis/14-openai-harness-engineering.md`.

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

Before adding planners, memory, specialist tools, or multiple agents, establish
a minimal harness baseline: one loop, the smallest action surface, linear
trajectory, explicit limits, and a replaceable execution environment. Add each
mechanism only when a realistic eval shows improvement. On model upgrades,
ablate old prompt rules and scaffold one at a time; remove what is no longer
load-bearing. See `analysis/17-mini-swe-agent.md`.

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

Name the loop levels and give each its own budget and stop reason. A useful
three-level split is **turn** (one user-visible exchange), **step** (one model
call plus its tool batch), and **round** (one iteration of an outer driver such
as a retry or a re-plan). Keep budgets in one place per level; a hidden second
budget inside a subsystem will mask the visible one.

Give the tool layer a way to end the current turn without another model call,
and a way to defer additional context into the next one. Without those, every
"we already know we are done" case costs a full round trip.

Treat turn, sampling step, and tool call as separate lifecycles. Capture one
step-consistent snapshot so the context and tool specs advertised to the model
match the permissions, working directory, and registry used for execution.
Persist enough provenance to reconstruct what the model actually saw. See
`analysis/16-openai-codex-harness.md`.

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

Compaction and context reset are not ranked; they are chosen by model
generation. A model prone to wrapping up early as it nears its perceived context
limit needs a **reset** plus a structured handoff artifact, because a summary
preserves continuity without giving a clean slate. A model without that tendency
loses useful context to a reset for nothing. Re-check this choice on every model
upgrade rather than freezing the answer.

For work spanning multiple context windows, compaction is not continuity. Keep
an externalized default-FAIL completion contract, semantic progress/decision
notes, a versioned checkpoint such as git, a reproducible startup/smoke-test
path, and evidence for completed items. A fresh session must be able to orient,
verify the inherited state, choose one bounded next item, and leave a clean
handoff. Long unattended runs also need a kill switch, steering channel, budget,
and no-progress stop. See `analysis/15-anthropic-long-running-agent-harness.md`.

## Completion Judgment

A turn ending is not a goal being met. "The model stopped calling tools" only
says this turn is over; for any task whose goal is a verifiable end state, add a
separate gate that decides whether to continue.

Shape it as a stop hook on the existing loop, not as a second exit path:

- No active goal: the hook passes through and the loop behaves as before.
- Goal active and not met: append the reason as a message and continue the same
  loop.
- Goal met, or provably impossible: return.

Constrain the judge deliberately:

- It is a **separate model call** from the one doing the work. An agent asked to
  grade its own output will confidently praise mediocre work.
- Give it **no tools**. It judges whether evidence appeared in the record, not
  whether the claim is true. It is not a test framework — real verification
  still runs in tools.
- Have it return a **closed** result: met / not met with a reason / impossible.
  Without an explicit "impossible", an unreachable goal disguises itself as "not
  yet" and loops forever.
- Because it can only see the conversation, the working model's instructions
  must require writing verification commands and their results into the
  conversation. Evidence that is not written down does not exist to the judge.
- Keep the turn budget in the main loop. Do not give the gate a private one.

A good completion condition names three things: the end state, how it is
verified, and what must not be broken along the way. Persist the goal's phase
(active / paused / blocked / complete) with a revision so concurrent updates
compare-and-swap. Deliberately **do not** persist the goal's *armed* state: a
resumed or forked session should require a human to re-authorize autonomous
continuation. See `analysis/10-learn-claude-code.md` and
`analysis/18-deepseek-harness.md`.

For subjective quality goals, separate generation from evaluation into different
agents, and negotiate the deliverables and success criteria between them before
the work starts rather than handing down a spec one way. If a planning role
exists, scope it to product context and high-level technical direction only —
pushing implementation detail into the spec makes a single spec-level mistake
cascade through everything downstream. Whether an evaluator
pays for itself depends on task difficulty relative to model capability: inside
the model's comfortable range it is pure overhead; at the edge it catches the
last-mile gaps. Measure the generator's solo pass rate first, then decide. See
`analysis/19-anthropic-harness-design-long-running-apps.md`.

## Durable Execution and Side Effects

If the process can crash and the task touches external systems, three separate
problems must each be solved. Solving two is a common and silent failure:

1. **Know whether it happened.** Wrap uncertain effects: commit the intent with
   pre-minted output ids, do the effect, then commit the settlement. The
   pre-minted id is what lets recovery ask the external system "did this
   happen?" instead of guessing.
2. **Do not repeat it.** Any protocol where retry is first-class makes
   idempotency a correctness requirement, not a best practice. Side effects must
   come after all required input is gathered, or be deduplicated by a
   server-minted key.
3. **Be able to undo it.** Register compensating actions for completed tool
   actions so an upper-level failure can roll back rather than leave a
   half-finished state. Retry and approval do not cover this case.

Separate the stores by role: a write-once history of what happened, mutable
named cells for what is true now, and an append-only ledger for usage. One
mutable message array cannot serve all three — replay and current state
contaminate each other.

Two workable recovery models, chosen by who pays the derivation cost:

- **Event-sourced**: append events, project current state on read. Small writes,
  recovery replays a projection.
- **Durable program counter**: after each step, overwrite one register with the
  *total* current state. Larger writes, but recovery reads one value and
  switches — there is no replay semantics, so there is no half-replayed state.

Declare a replay policy per tool. For a tool that must not re-run, recovery
should synthesize an "interrupted" result rather than dropping the call, so the
call/result pairing the model sees stays well-formed.

**Authorization is never inherited from serialized state.** State can be
restored; permission, approval, and credentials must be re-obtained. When
recovery cannot prove which response owns a pending output, fail closed instead
of guessing. See `analysis/01-pi-source-analysis.md` and
`analysis/02-agent-framework-patterns.md`.

For work that must survive a disconnect, the right abstraction is a **pollable
task handle**, not a resumable stream. Two independent designs — a durable
harness and a wire protocol — both list stream resumption as an explicit
non-goal and make "reissue the request" the only path.

## Orchestration Above the Loop

When the path is known before execution, a script beats letting the model
rediscover it each turn. Add a runtime that runs a host-registered script and
journals each call, and expose it to the model as one tool.

- The model supplies a **name, arguments, and an optional resume id** — never
  executable code and never the metadata. Validate registered metadata as plain
  data before any script text is evaluated.
- Distinguish the two concurrency primitives and name them separately: a
  **barrier** (wait for all, because the next step needs every result) and a
  **per-item pipeline** (each item advances through stages independently, no
  waiting).
- Derive the resume cache key from a **stable hash of the call's content**
  (kind, label, prompt, schema) — never from completion order. Concurrent
  completion order is nondeterministic, and a counter-based key silently
  misaligns the cache on the second run.
- Validate subagent output against a schema, retry once, then fail. Untrusted
  input and untrusted output are the same problem seen from two sides.
- Keep intermediate results in variables, out of the conversation. That is the
  whole cost advantage over letting the model iterate.

See `analysis/10-learn-claude-code.md` and `analysis/18-deepseek-harness.md`.

## Contract Deprecation

If other people or systems consume your agent's contract — mode names, tool
names, result shapes, skill entry points — SemVer alone is not enough. SemVer
says whether *this* release breaks; consumers also need to know where the *next*
one will.

Adopt three states (active / deprecated / removed), a minimum deprecation
window, and a single registry of everything currently deprecated with its
suggested migration. A deprecation that only exists as a line in a changelog is
not queryable, and therefore not plannable. See
`analysis/20-mcp-2026-07-28-revision.md`.

## Handoff

- For TypeScript implementation, read `../implement-ts-agents/SKILL.md`.
- For Java implementation, read `../implement-java-agents/SKILL.md`.
- For tools/context/retrieval/memory details, read `../design-agent-tools/SKILL.md`.
- For MCP capability boundaries, read `../build-mcp-capabilities/SKILL.md`.
- For security boundaries, read `../secure-ai-agents/SKILL.md`.
- For tests/evals/observability, read `../test-ai-agents/SKILL.md`.
- For iterating the skill/prompt text itself under a gate, read
  `../optimize-agent-skills/SKILL.md`.
