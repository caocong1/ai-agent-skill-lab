---
name: test-ai-agents
description: Add or plan tests, evals, observability, replay, and production guardrails for AI agents. Use for fake model orchestration tests, tool unit tests, persistence and resume tests, public or internal eval baselines, golden task snapshots, approval tests, traces, cost metrics, background work, scheduled triggers, and production monitoring.
metadata:
  version: 2.2.0
  short-description: Plan tests, evals, traces, guardrails
---

# Test AI Agents

Prefer many deterministic tests and a small number of real-model tests.

## Test Pyramid

1. Tool unit tests:
   - valid input;
   - validation failure;
   - permission denial;
   - external dependency failure;
   - structured output shape.
2. Orchestration tests:
   - fake model requests a tool;
   - fake model finishes;
   - stop condition triggers;
   - tool error returns to model;
   - approval pauses and resumes.
3. Persistence tests:
   - session saved after safe checkpoints;
   - resume continues from expected state;
   - tenant/user memory isolation;
   - replay or fork behavior if graph-based.
4. Eval/integration tests:
   - small golden task set;
   - model behavior rubric;
   - cost and latency thresholds;
   - tool safety cases.
5. Harness and continuity tests:
   - fresh session can orient from repository artifacts alone;
   - inherited workspace passes a smoke test before new work starts;
   - completion status cannot change without criterion-linked evidence;
   - compaction preserves initial constraints and pending tool continuation;
   - model-visible context/tools match the execution snapshot;
   - sandbox denial cannot silently broaden permissions;
   - rollout can reconstruct the messages, injected instructions, tools and
     environment visible to the model.

## Public Eval Baselines

Before building a custom eval from scratch, check whether a public benchmark
covers part of the capability:

- **BFCL**: tool-selection and function-calling accuracy, including simple,
  multiple, parallel, multi-turn, and missing-parameter cases.
- **GAIA**: end-to-end assistant tasks with web search, file reasoning, and
  multi-step planning.

Most production agents need both: a public comparable number plus an internal
golden set matching user task distribution. Run them together before merging
tool, prompt, model, or memory changes.

Report model and harness together: model/version, instructions, tool surface,
execution environment, sandbox/approval policy, context/compaction settings,
and evaluator version. A score without this harness configuration is not a
reproducible agent result.

Training-side work such as SFT/RL is a last resort after instructions, tools,
context, retrieval, memory, and evals stop improving a quantified gap.

## Legacy Retrofit

When an existing agent has little coverage, do not start by refactoring prompts,
tools, or orchestration.

Minimum safe sequence:

1. Capture current behavior with a small golden task set.
2. Add a fake-model orchestration test for one normal path, one tool error, and
   one stop condition.
3. Add unit tests for high-risk tool handlers.
4. Add approval/denial tests before changing dangerous tools.
5. Make the smallest remediation, then compare before/after behavior.

Prompt and tool-description edits are behavior changes. Capture a before
snapshot, edit, then compare quality, tool selection, cost, and safety behavior.

## Fake Model Strategy

Use a fake model that can return:

- final text;
- one or more tool calls;
- malformed tool input;
- repeated tool calls;
- no content;
- approval-triggering tool calls.

This makes loop behavior testable without live model randomness.

Check whether the framework already ships one. Some agent SDKs now provide
first-party deterministic testing entry points — a scripted model, a scripted
sandbox session, a scripted realtime transport — that let you drive the runner,
sandbox, and streaming paths with no live model, container, or socket. Prefer
those over a hand-rolled fake, and treat "does it ship a scripted model?" as a
real selection criterion when choosing a framework. See
`analysis/02-agent-framework-patterns.md`.

## Composition and Invariant Tests

Two gaps that unit tests and fake-model loop tests both miss:

**Test the real composition, not a hand-assembled one.** Build the system
through its actual configuration and entry point, then assert on behavior. A
test that wires the pieces together by hand proves the pieces work and says
nothing about whether the shipped composition wires them the same way — which is
exactly where plugin ordering, registration, and default-profile bugs live.

**Assert runtime invariants against authoritative state.** A runtime invariant
should check an authoritative event stream or mutable data — "everything the
model saw is in the log", "no two active handles share an id", "the lock is
released last". It should *not* assert that a service or method exists; that is
a type-system job, and an invariant that only checks presence passes forever
while the real property rots. If a component genuinely has no invariant to
assert, say so explicitly and explain why, rather than leaving an empty hook
that reads as untested.

Two more worth adding where they apply:

- **Snapshot the assembled transcript**, keyed on nothing volatile. Render what
  the model would actually receive and diff it. This catches prompt-prefix
  churn, duplicated policy blocks, and ordering changes that no individual unit
  test sees. Strip or normalize timestamps, ids, and paths so the snapshot fails
  only on real changes.
- **Test disposal and hot reload.** If components can be unloaded or replaced at
  runtime, assert that disposal reaches quiescence: listeners removed, timers
  cleared, in-flight work settled, no writes after teardown. A component that
  unloads but keeps a timer alive fails only under load, much later.

## Error Strategy

Classify tool errors:

- user/model-correctable: invalid id, missing field, no match;
- permission/policy: denied by role, tenant, approval, safety rule;
- transient dependency: timeout, rate limit, 5xx;
- system bug: null pointer, invariant, serialization bug.

The first two usually become visible tool results. The latter two should be
logged, retried only when safe, and surfaced through application error handling.

Plan model-layer recovery paths:

- output truncated at token budget: increase max tokens once, then use bounded
  continuation turns;
- input exceeds context window: invoke reactive compaction and retry once;
- rate limit or model unavailable: bounded exponential backoff with jitter and
  fallback model after repeated availability failures.

Record which recovery path fired; repeated hits mean budget, compaction, or
model choice needs adjustment.

## Long-Running and Triggered Work

Background tools and scheduled runs need:

- stable run id;
- start/heartbeat/finish events;
- result injection back as a normal tool result or notification;
- submission and completion timestamps;
- heartbeat alerts;
- concurrency and queue-depth caps;
- durable scheduler state;
- fake clock and fake runner tests.

Also test session rollover with a genuinely fresh context:

- initializer creates a default-FAIL contract, startup path, progress record,
  and first versioned checkpoint;
- successor reads progress and history, runs a smoke test, selects one bounded
  unfinished item, and does not trust an unverified completion claim;
- builder leaves a clean working state plus evidence and a usable next step;
- a separate evaluator sees only the specification, diff, runtime evidence and
  narrow read-only tools;
- kill switch, steering, no-progress detection and budget termination work
  while the agent is active.

Compaction tests and continuity tests are distinct. Compaction protects a token
window; continuity proves another session can safely take over. See
`analysis/15-anthropic-long-running-agent-harness.md`.

## Judging Subjective Quality

When the deliverable's quality is subjective — visual design, prose, report
structure, interaction feel — it can still be graded, but only if you build the
grader deliberately.

- **Separate the grader from the producer.** An agent asked to evaluate its own
  output will confidently praise mediocre work. This is the single most reliable
  finding in this area.
- **Name the criteria.** Decompose "good" into a small set of named dimensions
  and score each separately. A single overall score cannot be argued with or
  improved against.
- **Calibrate with few-shot examples that include the score breakdown**, not
  just the score. Without calibration, the same grader drifts across iterations
  of a long pipeline and the scores stop being comparable to each other.
- **Grade the running thing, not the diff.** Drive the real application, take
  screenshots, exercise the user-visible path. Findings should be granular and
  actionable ("the fill tool only placed tiles at the drag start and end — FAIL")
  rather than a paragraph of impressions.
- **Tune the grader by reading divergences.** Read the grader's logs, find the
  cases where its judgment differs from a human's, and update its prompt to
  resolve those cases. The divergences are its training set — the grader is
  itself a skill under optimization, so gate its changes the same way.
- **Know that the rubric steers the output.** Wording like "the best designs are
  museum quality" pushes the generator toward a particular convergence. A rubric
  is simultaneously a measurement instrument and a prompt; write it knowing it
  does both.
- **Keep every iteration and be able to revert.** Scores generally improve
  across iterations but not monotonically, and a middle version is often the
  best one. Do not assume the last run wins.
- **Decide whether the grader pays for itself.** Its value depends on task
  difficulty relative to model capability: inside the model's comfortable range
  it is pure cost; at the edge of capability it catches the last-mile missing
  features and edge cases. Measure the producer's solo pass rate first, then
  decide. Budget explicitly — a full multi-role harness run costs orders of
  magnitude more than a single-agent run.

See `analysis/19-anthropic-harness-design-long-running-apps.md`.

## Testing Completion Gates and Durable Execution

If the system has a completion gate, test the gate and not only the loop:

- a goal that is met is accepted, with the evidence present in the record;
- a goal that is not met is rejected with a reason that names what is missing;
- a goal that is impossible returns the impossible outcome rather than looping;
- a completion claim with no supporting evidence in the record is rejected;
- the main loop's turn budget still terminates the run when the gate keeps
  saying "not yet".

If the system claims crash recovery, test the recovery path directly:

- kill the process between committing an effect's intent and its settlement,
  then verify recovery can determine whether the effect happened;
- verify a non-replayable tool produces a synthesized interrupted result on
  resume, so the call/result pairing the model sees stays well-formed;
- verify approvals and credentials are re-obtained rather than restored;
- verify a resume with an ambiguous pending output fails closed;
- for a journaled orchestration script, verify the resume cache keys are stable
  across runs with different concurrent completion orders.

## Harness Ablation and Attribution

Keep a minimal baseline such as one loop, a narrow or bash-only action surface,
linear trajectory and replaceable environment. When adding a planner, memory,
specialized tool, evaluator or multi-agent split, compare against that baseline
on the same task set.

Keep a register of dated assumptions to ablate against. Each harness component
should have a one-line entry: "we added X because the model at version M could
not do Y." On a model upgrade that register *is* the ablation list — without it,
ablation is a guessing game over the whole harness. Components that govern
authority, evidence, side effects, or cost do not belong on that list; they are
not compensating for a model limitation and should not be ablated on a model
schedule.

On model upgrades, remove one harness mechanism at a time and re-run the eval.
Classify regressions by model, prompt/context, tool interface, execution
environment, permissions/sandbox, persistence/continuity, or evaluator. Do not
credit the model for a harness improvement or preserve obsolete scaffold by
default. See `analysis/14-openai-harness-engineering.md`,
`analysis/16-openai-codex-harness.md`, and `analysis/17-mini-swe-agent.md`.

## Observability Events

Emit or record:

- agent start/end;
- turn start/end;
- model request id and provider;
- active tools;
- tool call start/end;
- redacted tool input summary;
- approval request/decision;
- stop condition;
- token/cost usage;
- error class;
- checkpoint id or session version;
- background run id;
- scheduled trigger id.

Never log raw secrets, credentials, full private documents, or unredacted PII.

## Production Guardrails

- Step limit.
- Wall-clock timeout.
- Token/cost budget.
- Active tool allowlist.
- Permission check in every mutating tool.
- Approval for irreversible actions.
- Memory isolation by user and tenant.
- Trace sampling and redaction.
- Rollback or compensation plan for side effects.
