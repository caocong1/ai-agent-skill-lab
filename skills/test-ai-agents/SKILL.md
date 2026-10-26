---
name: test-ai-agents
description: Add or plan tests, evals, observability, replay, and production guardrails for AI agents. Use for fake model orchestration tests, tool unit tests, persistence and resume tests, public or internal eval baselines, golden task snapshots, approval tests, traces, cost metrics, background work, scheduled triggers, and production monitoring.
metadata:
  version: 2.3.0
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

When you simulate the environment instead — injected tool responses and errors,
a model-backed mock, then the real tool — make an unconfigured or unmatched call
fail rather than fall through to a real system, seed each injection separately,
and test approval paths on their own, since mocks can skip the confirmation
gate. Validate a simulated user before trusting multi-turn scores. See
`analysis/27-google-adk.md`.

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

**An invariant needs two observations that can fail separately.** Check
something another component produced — an authoritative event log against a
request rebuilt from it, external state against the record: "everything the
model saw is in the log", "no two active handles share an id", "the lock is
released last". A check that reads back what the same code just wrote is a test,
not an invariant, and a check that never runs in the shipped product is a test
with extra packaging. Properties that must hold in production belong in how the
code is built (build each request from the log) or in an always-on guard inside
the component that owns the data. Do not assert that a service exists, and do not
keep empty or "explained-empty" invariant hooks — one production harness pruned
hundreds of them and then removed its invariant layer, moving coverage into
tests. See `analysis/18-deepseek-harness.md`.

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
- **Make persistence adapters pass a conformance suite that covers delivery, not
  only storage**: duplicate redelivery, concurrent appends, and a crash between
  the local write and any mirror. Ordering and isolation alone are not enough.
- **Pin what an end-to-end test ran against**: SDK version, any bundled harness
  binary, and the model. A vendor harness changes its defaults per model.

## Error Strategy

Classify tool errors:

- user/model-correctable: invalid id, missing field, no match;
- permission/policy: denied by role, tenant, approval, safety rule;
- transient dependency: timeout, rate limit, 5xx;
- system bug: null pointer, invariant, serialization bug.

The first two usually become visible tool results. The latter two should be
logged, retried only when safe, and surfaced through application error handling.
Test the boundary: inject a tool exception carrying a secret or a SQL fragment
and assert it reaches neither the model request, memory, nor the final answer.

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
- the judge still accepts a genuinely met goal when the worker's own success
  claim is stripped from what it sees — and catches more false claims that way;
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
  across runs with different concurrent completion orders;
- a tool recorded as replay-safe but now declared unsafe yields "interrupted",
  not a rerun; a task that keeps crashing on resume is parked; a step that does
  not advance its checkpoint faults;
- a run-state snapshot submitted twice resumes once, a forged or altered
  approval is rejected, and parallel writes replay in the same order across runs;
- a direct call to a program-only tool is rejected, an escalated retry after a
  sandbox denial is re-reviewed, and a reviewer failure or timeout denies.

## Comparing Variants Under Noise

Agent evals are noisy enough that a single run decides nothing. Before claiming
that variant B beats variant A — a prompt edit, a harness component, a model, an
optimizer's output:

- **Run several trials per task** and report the spread. Current frontier models
  reject non-default sampling parameters, so "temperature 0" is not available as
  a noise control; even where it was, runs diverged.
- **Pair by task.** For pass/fail outcomes use McNemar's test; for the
  success-rate difference use a bootstrap interval that resamples *tasks*, not
  seeds — repeated seeds of one task are not independent samples.
- **Run an A/A check** on the same setup first. If A beats A, the harness is
  noisier than the effect you are measuring.
- **Match the budget.** Compare a harness change against simply spending the
  same extra compute (more samples, more turns). Several reported harness gains
  vanish against a same-budget baseline.
- **Keep held-out tasks** the change was never tuned on, and keep resource
  configuration fixed: infrastructure settings alone can move a coding-agent
  benchmark by several points. Treat small gaps as unproven.
- **Record the benchmark version** and the full harness configuration with the
  score; versioned benchmarks are not comparable across versions.
- Report pass@k when any success suffices and pass^k when every attempt must
  succeed; they answer different questions.

See `analysis/25-harness-shelf-life-research.md` and `analysis/13-skillopt.md`.

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

Ablate per model tier you deploy. A component's value is often non-monotonic in
model strength — it can rescue a weak model, help a mid-tier one most, only add
cost for a strong one, or turn from an accuracy aid into a cost saver — so a
result on one tier does not transfer.

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
