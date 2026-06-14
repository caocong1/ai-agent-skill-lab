---
name: test-ai-agents
description: Add or plan tests, evals, observability, replay, and production guardrails for AI agents. Use for fake model orchestration tests, tool unit tests, persistence and resume tests, public or internal eval baselines, golden task snapshots, approval tests, traces, cost metrics, background work, scheduled triggers, and production monitoring.
metadata:
  version: 2.0.0
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
