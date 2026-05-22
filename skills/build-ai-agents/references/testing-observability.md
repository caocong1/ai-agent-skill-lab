# Testing and Observability

## Test Pyramid

Prefer many deterministic tests and a small number of real-model tests.

1. Tool unit tests
   - valid input
   - validation failure
   - permission denial
   - external dependency failure
   - structured output shape
2. Orchestration tests
   - fake model requests a tool
   - fake model finishes
   - stop condition triggers
   - tool error returns to model
   - approval pauses and resumes
3. Persistence tests
   - session saved after safe checkpoints
   - resume continues from expected state
   - tenant/user memory isolation
   - replay or fork behavior if graph-based
4. Eval/integration tests
   - small golden task set
   - model behavior rubric
   - cost and latency thresholds
   - tool safety cases

## Public Eval Baselines

Before building a custom eval set from scratch, check whether a public benchmark already covers the capability you need to measure (see `analysis/11-hello-agents.md` chapter 12). Aligning even a slice of an agent's evaluation to a published benchmark gives a comparable number across model/prompt/tool changes, and makes regressions easier to spot against a fixed yardstick rather than a moving internal set.

Two widely cited starting points:

- **BFCL (Berkeley Function-Calling Leaderboard)** — measures tool-selection and function-calling accuracy across categories (simple, multiple, parallel, multi-turn, missing-parameter). Use it when the agent's main risk is "calls the wrong tool" or "fills arguments incorrectly".
- **GAIA (General AI Assistant)** — end-to-end task completion across difficulty levels, including web search, file reasoning, and multi-step planning. Use it when the agent's main risk is "fails to finish realistic open-ended tasks".

These do not replace a domain-specific golden set — most production agents need both: a public benchmark as a fixed comparable number, plus an internal eval that captures the actual user task distribution. Run them on the same trigger (e.g., before merging tool/prompt/model changes) so regressions surface in one report.

When inference-time changes have stopped improving the public benchmark score and the gap is still meaningful, that is the point at which SFT/RL training of the underlying model becomes worth evaluating (see `analysis/11-hello-agents.md` chapter 11). Treat training-side work as the last resort after prompt, tool, context, and memory are tuned, not as a substitute for them.

## Legacy Retrofit Strategy

When reviewing an existing agent with little or no test coverage, do not start by refactoring prompts, tools, or orchestration.

Minimum safe sequence:

1. Capture current behavior with a small golden task set.
2. Add a fake-model orchestration test that covers one normal path, one tool error, and one stop condition.
3. Add direct unit tests for high-risk tool handlers.
4. Add approval/denial tests before changing dangerous tools.
5. Make the smallest remediation, then compare before/after behavior on the golden set.

Prompt and tool-description edits are behavior changes. Treat them like code changes: capture a before snapshot, make the edit, then compare output quality, tool selection, cost, and safety behavior.

## Fake Model Strategy

Use a fake model for orchestration tests. It should be able to return:

- a final text response
- one or more tool calls
- malformed tool input
- repeated tool calls
- no content
- approval-triggering tool calls

This makes loop behavior testable without relying on live model randomness.

## Tool Error Strategy

Classify errors:

- user/model-correctable: invalid id, missing field, no matching record
- permission/policy: denied by role, tenant, approval, safety rule
- transient dependency: timeout, rate limit, upstream 5xx
- system bug: null pointer, invariant violation, serialization bug

The first two usually become tool results the model can see. The latter two should be logged, retried only when safe, and surfaced through application error handling.

For model-layer failures, plan three independent recovery paths instead of one shared try/except (see `analysis/10-learn-claude-code.md`):

- **max_tokens reached** — escalate the max-tokens budget once (for example default → extended) and, if still truncated, issue a bounded number of "continuation" turns that pick up mid-thought. Track an explicit counter; cap retries.
- **prompt_too_long** — invoke the reactive layer of the compaction pipeline (see `references/context-and-tools.md`), then retry the same turn once. Do not loop.
- **rate-limit or model unavailable (429 / 5xx)** — exponential backoff with jitter, bounded total attempts, and a fallback model after N consecutive availability failures so the agent degrades gracefully instead of stalling.

Record which recovery path was taken on each retry — repeated falls into the same path are a signal to adjust budget, compaction layer, or model choice rather than to keep retrying.

## Long-Running and Triggered Work

Background tools (slow shell commands, large builds, multi-minute API calls) and time-triggered runs (cron, scheduled jobs) need distinct observability beyond a single turn:

- Assign every background or scheduled run a stable run id and emit `start / heartbeat / finish` events keyed by it.
- On completion, inject the result back as a normal tool result or notification so the model sees it on the next turn — never silently mutate state.
- Record both submission time and completion time; alert when heartbeats stop.
- Cap concurrent background runs and total queue depth; reject or defer beyond the cap rather than fan out unbounded threads.
- Persist scheduler state (last trigger time, next trigger time, missed runs) durably so restarts do not double-fire or silently skip.
- Treat cron and background paths as first-class triggers in the test pyramid: a fake clock and a fake background runner are as important as a fake model.

## Observability Events

Emit or record:

- agent start/end
- turn start/end
- model request id and provider
- active tools
- tool call start/end
- tool input summary after redaction
- approval request/decision
- stop condition
- token/cost usage
- error class
- checkpoint id or session version
- background run id, submit/finish timestamps, and the turn id where the result was injected
- scheduled-trigger id, planned vs actual fire time, and the run id it produced

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
