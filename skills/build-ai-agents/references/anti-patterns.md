# Agent Anti-Patterns

Use this catalog during reviews. For each smell, collect `file:line` evidence and recommend the smallest safe remediation.

## Permission Only in Prompt

- Symptom: instructions say "do not delete" or "ask before running" but the tool handler executes without checking.
- Detect: inspect tool handlers for auth/role/approval checks, not just system prompts.
- Impact: unauthorized mutation, policy bypass.
- Remediate: enforce permission in the handler; return approved/denied result to the model.
- Validate: unit test denied and approved paths.

## Unbounded Loop

- Symptom: `while true`, recursive agent calls, missing `stopWhen`, no timeout/cost budget.
- Detect: search loop code around model/tool calls.
- Impact: runaway cost, stuck requests, rate limits.
- Remediate: add step limit, wall-clock timeout, cost/token budget, and terminal condition.
- Validate: fake model that repeatedly calls a tool stops as expected.

## Secrets in Prompt

- Symptom: API keys, tenant ids, credentials, raw private records inserted into instructions/messages.
- Detect: inspect prompt builders and context injection.
- Impact: secret leak to provider, logs, traces, or downstream tools.
- Remediate: pass secrets through scoped runtime/tool context; redact logs.
- Validate: prompt snapshot contains no secrets.

## Full Long Document Dump

- Symptom: entire PDFs, docs, logs, transcripts, or large source files are pasted into model messages without chunking, retrieval, or source anchors.
- Detect: inspect file/document readers, prompt builders, and tool-result handling for unbounded full-content insertion.
- Impact: context overflow, higher cost, weaker factual grounding, lost citations, and brittle answers when the model misses details.
- Remediate: add inventory, bounded reads, chunk ids, source anchors, retrieval, per-chunk summaries, and synthesis over selected evidence.
- Validate: test with an oversized fixture and assert the model context contains bounded chunks plus source references, not the full document.

## God Agent With All Tools

- Symptom: one agent gets broad filesystem, database, network, admin, and user-data tools.
- Detect: inspect active tool set and tool registry.
- Impact: excessive agency, higher prompt-injection blast radius, poor debuggability.
- Remediate: scope tools per task/user, split specialist subagents, or add supervisor routing.
- Validate: tests show restricted users never receive restricted tools.

## MCP Tool Runs Whole Workflow

- Symptom: one vague MCP tool performs multi-step business process with broad input.
- Detect: MCP server exposes large "do everything" actions.
- Impact: poor composability, hard approval, weak audit.
- Remediate: split into small typed tools and let the agent/workflow orchestrate.
- Validate: each tool has schema, permission, audit entry, and focused tests.

## UI and Model Message Bleed

- Symptom: UI-only parts, transient rendering state, or approval widgets are sent directly to the model.
- Detect: inspect UI-to-model message conversion.
- Impact: model confusion, data leakage, malformed tool results.
- Remediate: separate UI messages from model messages and define conversion rules.
- Validate: conversion unit tests.

## In-Memory State for Durable Work

- Symptom: approvals, long tasks, or retries depend on process-local arrays.
- Detect: inspect session/run state and resume path.
- Impact: lost progress on restart, duplicate side effects.
- Remediate: add checkpointer/workflow/session persistence and idempotent tools.
- Validate: resume test from saved checkpoint.

## Over-Engineered Agent

- Symptom: graph, subagents, vector memory, or MCP used for a one-shot classification.
- Detect: compare complexity against user-visible requirement.
- Impact: latency, cost, maintenance burden.
- Remediate: replace with deterministic code or single structured model call.
- Validate: behavior remains equivalent on golden cases.

## Human API Descriptions for Tools

- Symptom: tool description mirrors internal API docs and omits when/how the model should use it.
- Detect: read tool names/descriptions and parameter descriptions.
- Impact: poor tool selection, invalid arguments.
- Remediate: rewrite descriptions for model decision-making; add examples only when useful.
- Validate: eval cases where the model should and should not call the tool.

## Swallowed or Vague Tool Errors

- Symptom: catch-all returns "failed" or hides model-correctable detail.
- Detect: inspect try/catch in tool execution.
- Impact: model cannot self-correct; users get opaque failures.
- Remediate: classify errors and return safe structured details for correctable failures.
- Validate: fake tool failures produce expected model-visible result.

## No Agent Tests

- Symptom: only live manual testing, no fake model or tool handler tests.
- Detect: test tree lacks orchestration tests around model/tool loop.
- Impact: refactors and prompt changes are risky.
- Remediate: add fake-model harness and small golden eval set before behavior changes.
- Validate: CI runs deterministic tests without live model credentials.

## Non-Deterministic Tool Result Ordering

- Symptom: parallel tool calls append results as they finish.
- Detect: inspect `Promise.all`, streams, or async worker joins.
- Impact: model receives tool results mismatched to calls.
- Remediate: execute in parallel if safe, but return results in original tool-call order.
- Validate: test delayed tools still produce stable ordering.
