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
