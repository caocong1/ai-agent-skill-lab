---
name: design-ai-agent
description: Choose and specify AI agent architecture before implementation. Use for deciding whether an agent is needed, selecting deterministic code vs single model call vs structured workflow vs ReAct/tool loop vs durable graph vs subagents vs an embedded open harness, and designing loop, state, memory, approval, completion, durable-execution, and harness boundaries.
metadata:
  version: 2.3.0
  short-description: Choose the right agent architecture
---

# Design AI Agent

Use this skill before implementing an agent or when reviewing whether an
existing design is too simple, too broad, or too autonomous.

## Core Model

Treat an agent as an application subsystem, not a prompt: do not let one
controller, route handler, or prompt own the model adapter, instructions, tools,
loop, state and memory, approvals, traces, and evals.

## Model-Visible Surface and Authority

Shape selection is the first question, not the only one. Two designs with the
same shape can differ completely on the two axes that decide whether the system
is safe and affordable:

- **What does the model see?** Every capability should have a written answer for
  what the model sees, what it costs in tokens, and what it does to prompt-cache
  reuse. Make "everything the model saw is in the log" hold by construction —
  build each request from the log — or replay and audit become fiction. The
  converse need not hold: much of what is logged never reaches the model.
- **Who decides what happens?** Visibility is not authority. A model that can
  see a tool must still pass an authority boundary to use it, and that boundary
  must be enforced in code, not in prompt wording.

Write both answers down per capability before implementing it. Design a
capability as three roles together — its **definition** (the contract), its
**provider**, its **consumer**. A plugin that is both the definition and the only
provider makes the contract untestable and unreplaceable. See
`analysis/18-deepseek-harness.md`.

## Perishable vs Durable Design

Every harness component encodes a dated assumption about what the model cannot
do on its own. Classify each component before writing it:

- **Perishable** — compensates for a current model weakness: context resets,
  sprint decomposition, planning and todo tools, anti-drift prompt patches,
  step-by-step scaffolding. Record it as "we added X because the model at
  version M could not do Y." That record is the ablation list for the next
  model generation.
- **Durable** — governs authority, evidence, side effects, or cost. These get
  *more* valuable as models improve: a more capable model can do more, so
  boundaries matter more; a more convincing self-assessor makes independent
  judgment more necessary; capability never makes external systems
  transactional or tokens free.

Treat a model upgrade as a review trigger for the perishable list only. Vendors
now delete their own compensations on new generations, so the register is not
hypothetical — and a component's value is often **non-monotonic** in model tier:
it can rescue a weak model, help a mid-tier one most, and only cost a strong one.
Ablate per tier you deploy, above the measurement noise floor. Gate perishable
components by model and set the fallback by kind: a weak-model workaround stays
off for an unrecognized model, while a relaxed-permission feature falls back to
the stricter mode. See `analysis/25-harness-shelf-life-research.md` and
`analysis/28-claude-agent-sdk.md`.

Publish a **non-goals list** next to the capability list, with equal prominence.

## Agent vs Harness

Agency is produced by model training, not by code orchestration; the engineering
work is harness engineering. A harness has three nested layers — design only the
layers the task needs:

1. **Turn/runtime**: the loop, tools, context, observations, permissions,
   sandbox, approvals, events, and budgets for one active run.
2. **Session continuity**: history, checkpoints, progress and decision records,
   completion contracts, resume/fork, and clean handoff across context windows
   or processes.
3. **Repository/organization feedback**: discoverable specifications,
   architecture maps, reproducible environments, observability, executable
   invariants, review feedback, and recurring maintenance.

The runtime layer's jobs are tools, knowledge loaded on demand, context
management, observation/action interfaces, and permissions enforced in code. If a
feature seems to require rewriting the loop, first check whether it belongs in
one of those.

For coding agents, optimize for **agent legibility**: the agent must be able to
discover authoritative knowledge, start the application, observe user-visible
behavior and telemetry, and get actionable failures from mechanical checks. Keep
`AGENTS.md` short and spend it on what the agent would otherwise get wrong —
commands, conventions, constraints. Repository overviews in context files have
been measured to add cost without raising success; measure yours. See
`analysis/14-openai-harness-engineering.md` and
`analysis/25-harness-shelf-life-research.md`.

## Workflow vs Agent

Use a workflow when the LLM and tools follow predefined code paths; use an agent
when the model directs its own process from environment feedback until a stop
condition. Default to the least powerful shape: deterministic code < single
model call < structured workflow < autonomous tool loop < durable graph/workflow
< multi-agent. Choose an autonomous agent only when steps are genuinely
unpredictable, the path cannot be hard-coded, and the tool environment is
trustworthy.

Before writing a loop, check whether a maintained open harness can be **embedded
locally** — an exec / SDK / app-server layering, an adapter that puts several
local runtimes behind one stream interface, or a harness shipped as a library.
Embedding buys production-grade approvals, sandboxing, recovery, and streaming;
it does not remove your duties for the interface, the context and tools, and the
operational boundaries. Confirm each layer's default approval semantics — some
default to model-reviewed approval rather than asking a person. See
`analysis/24-openai-codex-as-a-platform.md` and `analysis/28-claude-agent-sdk.md`.

Establish a minimal harness baseline before adding planners, memory, specialist
tools, or multiple agents: one loop, the smallest action surface, linear
trajectory, explicit limits, a replaceable execution environment. Add each
mechanism only when a realistic eval shows improvement. See
`analysis/17-mini-swe-agent.md`.

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
| Separate expertise or tool access | Subagent or agent-as-tool | One agent with all tools |
| Shared external capability | MCP server | Duplicated project tools |
| Multi-tenant data | Scoped tool context + isolation tests | Global context |
| Reversible side effects required | Idempotent tools + compensation | Fire-and-forget mutation |
| Context exceeds window | Retrieval/compaction before call | Unbounded messages |
| Production-grade loop needed, not a differentiator | Embed a maintained local open harness | Rebuilding loop, approvals, and recovery |
| A crash must not lose the session | Session log + stateless loop + sandbox called as a tool | One process holding session, loop state, and sandbox |

## Single vs Multi-Agent

Prefer one capable agent with progressive disclosure (skills, deferred tools)
until evidence says splitting helps; router, planner, and per-domain subagent
designs often lose to one loop that loads what it needs. Keep a subagent when
context-heavy reading would flood the parent, when you need throwaway parallel
exploration, when tool sets still confuse the model after naming and description
fixes, or when expertise, context, or permissions must be isolated. Migrate one
subagent at a time under task-completion evals and check which tasks flip.
Coordination pays on decomposable work and costs on sequential work, and its
returns fall as the single agent gets stronger. See
`analysis/25-harness-shelf-life-research.md`.

Choose coordination deliberately: a **manager / agent-as-tool** keeps the parent
in control of bounded subtasks; a **handoff** transfers ownership of the next
part of the conversation.

## Loop Design

A robust tool loop builds a stable turn snapshot, transforms or compacts context
before the model call, converts internal messages to provider messages at the
boundary, calls the model with active tools, validates tool calls against
schemas, applies approval and permission hooks before execution, executes tools
in deterministic result order even when parallel, returns results or finishes,
and emits events and persists state at safe checkpoints.

Name the loop levels and give each its own budget and stop reason: **turn** (one
user-visible exchange), **step** (one model call plus its tool batch), **round**
(one outer-driver iteration such as a retry or re-plan). Keep one budget per
level; a hidden second budget masks the visible one. A spend cap covers the whole
subagent tree, carries across resume, and states how far it can overshoot; the
host owns the wall-clock limit. Give the tool layer a way to end the turn without
another model call and to defer context into the next turn.

Capture one step-consistent snapshot so the context and tool specs the model
sees match the permissions, working directory, model settings, and registry used
for execution, and bind approvals to the step that issued them. Persist
provenance for every context part, so you can reconstruct what the model
actually saw. See `analysis/16-openai-codex-harness.md`.

Every iteration must consume real environment feedback, and every loop must stop
on completion, step/cost/token budget, timeout, or human checkpoint. Add
extension points (pre/post tool call, pre/post turn, on stop) for permissions,
redaction, audit, cost accounting, and experiments without editing the loop.

## State, Approval, Memory

Keep separate contracts for domain state, agent runtime state, memory, model
messages, UI messages, and traces.

Approval belongs at the tool execution boundary — for mutations, commands,
notifications, private or regulated data, money, and large spend — and its
decision returns to the model as a structured tool result.

Use memory only when the agent needs information across turns or sessions.
Memory needs scoped permissions, provenance, tenant/user isolation, and a
forgetting policy.

Compaction and context reset are chosen by model generation, not ranked: a model
that wraps up early as it nears its perceived context limit needs a **reset**
plus a structured handoff; a model without that tendency loses useful context to
a reset for nothing. Re-check on every upgrade. Either way, constraints and
approvals must not travel through a lossy summary — see
`../design-agent-tools/SKILL.md`.

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
separate gate that decides whether to continue. Shape it as a stop hook on the
existing loop, not a second exit path: no active goal → pass through; goal active
and not met → append the reason and continue the same loop; met or provably
impossible → return.

Constrain the judge deliberately:

- It is a **separate model call** from the worker. An agent asked to grade its
  own output will confidently praise mediocre work.
- It does **not see the worker's own success claim or reasoning** — give it the
  record of what was done and the evidence. A judge that reads "done" is anchored
  by it; stripping the claim measurably raises false-success detection.
- Give it **no tools**. It judges whether evidence appeared in the record, not
  whether the claim is true; real verification still runs in tools.
- Have it return a **closed** result: met / not met with a reason / impossible.
  Without "impossible", an unreachable goal disguises itself as "not yet" and
  loops forever.
- The worker's instructions must require writing verification commands and their
  results into the record; evidence that is not written down does not exist to
  the judge.
- Keep the turn budget in the main loop, and cap automatic continuations that
  make no progress — one local harness blocks a goal after three empty
  continuation turns.

A good completion condition names the end state, how it is verified, and what
must not be broken along the way. For large deliverables, write the executable
completion standard **before** implementation, in a role the implementer cannot
see into or weaken; validators may add cases, never remove them. See
`analysis/26-durable-rules-production-evidence.md`.

Persist the goal's phase (active / paused / blocked / complete) with a revision so
concurrent updates compare-and-swap; a durable phase separates "turn ended" from
"goal met" but is not itself an independent judge. Deliberately **do not**
persist the goal's *armed* state: a resumed or forked session should require a
human to re-authorize autonomous continuation, and only a human may resume a goal
a human paused. See `analysis/10-learn-claude-code.md` and
`analysis/18-deepseek-harness.md`.

For subjective quality goals, separate generator and evaluator agents and
negotiate success criteria before the work starts; keep any planner at product
level, since implementation detail in a spec makes one mistake cascade. An
evaluator pays for itself only near the edge of model capability — measure the
generator's solo pass rate first. See
`analysis/19-anthropic-harness-design-long-running-apps.md`.

## Durable Execution and Side Effects

If the process can crash and the task touches external systems, three separate
problems must each be solved. Solving two is a common and silent failure:

1. **Know whether it happened.** Commit the intent — carrying an idempotency
   key, or one derived from a durable task id — before the effect, then commit
   the outcome; count it done only on a positive acknowledgement. Recovery that
   finds an intent without an outcome must assume the effect may have happened:
   tell the model the outcome is **unknown**, retry only read-only or idempotent
   tools, and otherwise check external state or ask.
2. **Do not repeat it.** Where retry is first-class, idempotency is a correctness
   requirement. Side effects come after all required input is gathered, or are
   deduplicated by a server-minted key.
3. **Be able to undo it.** Register compensating actions for completed tool
   actions so an upper-level failure can roll back rather than leave
   half-finished state. Retry and approval do not cover this case.

Persist two things separately rather than one mutable message array: **what
happened and what the model saw** (append-only, projected on read) and **where
execution is** (a whole-task checkpoint replaced at each step, so recovery reads
it and switches with no half-replayed state). A step that returns without
advancing its checkpoint is a fault, not a reason to rerun. Durable execution is
an optional runtime beside the loop, worth its cost only when the process lives
shorter than the work; a persistent append-only session covers most local CLIs.

Declare a replay policy per tool, defaulting to *not* safe. On resume the
effective policy is the stricter of what was declared when the call was recorded
and what the code declares now — a later change can veto replay, never grant it
— and current deterministic policy checks run again first. For a tool that must
not re-run, synthesize an "interrupted" result so the call/result pairing stays
well-formed. Never wait inside a step (a restart repeats it; make the sleep its
own durable boundary), cap automatic restarts so a task that keeps crashing on
resume is parked, and remember that a timeout does not prove an attempt stopped —
hold a lease with a single writer so it cannot keep acting beside its retry.

**Authorization is never inherited from serialized state.** State can be
restored; permission, approval, and credentials must be re-obtained. When
recovery cannot prove which response owns a pending output, fail closed. See
`analysis/01-pi-source-analysis.md` and `analysis/02-agent-framework-patterns.md`.

Keep session, loop, and sandbox as separate failure domains, even on one machine:
an append-only session log is the only thing that must survive a crash; the loop
is stateless and recoverable from that log alone; the sandbox is called like a
tool, so a dead container returns to the model as a tool error it can answer by
re-provisioning. If a loop bug, a dropped connection, and a sandbox crash look the
same in your logs, the separation is not real. Keep credentials structurally
unreachable from the sandbox (`../secure-ai-agents/SKILL.md`). See
`analysis/22-anthropic-managed-agents.md`.

Treat a framework's "resumable" flag as at-least-once replay until you have read
its recovery path. For work that must survive a disconnect, use a **pollable task
handle**, not a resumable stream.

## Orchestration Above the Loop

When the path is known before execution, a script beats letting the model
rediscover it each turn. Run a host-registered script that journals each call,
exposed to the model as one tool:

- the model supplies a **name, arguments, and an optional resume id** — never
  code or metadata, which is validated as plain data before any script runs;
- name the **barrier** (wait for all) and the **per-item pipeline** separately;
- key resume caches on a **stable hash of the call's content**, never on
  completion order;
- validate subagent output against a schema, retry once, then fail;
- keep intermediate results in variables, out of the conversation — that is the
  whole cost advantage.

See `analysis/10-learn-claude-code.md` and `analysis/18-deepseek-harness.md`.

## Contract Deprecation

If other people or systems consume your agent's contract — mode names, tool
names, result shapes, skill entry points, persisted session formats — SemVer
alone is not enough: it says whether *this* release breaks, not where the *next*
one will. Adopt three states (active / deprecated / removed), a minimum
deprecation window, and a single registry of everything deprecated with its
migration. Ship each breaking change with a short migration note, and once data
has been published, migrate stored formats one version at a time rather than
rejecting them. See `analysis/20-mcp-2026-07-28-revision.md` and
`analysis/18-deepseek-harness.md`.

## Handoff

- For TypeScript implementation, read `../implement-ts-agents/SKILL.md`.
- For Java implementation, read `../implement-java-agents/SKILL.md`.
- For tools/context/retrieval/memory details, read `../design-agent-tools/SKILL.md`.
- For MCP capability boundaries, read `../build-mcp-capabilities/SKILL.md`.
- For security boundaries, read `../secure-ai-agents/SKILL.md`.
- For tests/evals/observability, read `../test-ai-agents/SKILL.md`.
- For iterating the skill/prompt text itself under a gate, read
  `../optimize-agent-skills/SKILL.md`.
