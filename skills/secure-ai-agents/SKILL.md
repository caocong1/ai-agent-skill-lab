---
name: secure-ai-agents
description: Threat-model, harden, or review AI agent safety boundaries. Use for prompt injection, excessive agency, mutating tools, data exfiltration, secrets, multi-tenant isolation, MCP or HTTP SSRF, tool-result poisoning, replay bugs, approvals, audit logs, redaction, guardrails, and human intervention triggers.
metadata:
  version: 2.0.0
  short-description: Harden agent safety boundaries
---

# Secure AI Agents

Agent security is primarily about controlling tool authority, context exposure,
and cross-boundary data flow.

## Threat Model

Review these threats for any production agent:

- prompt injection in user input, retrieved documents, tool results, MCP
  resources, or memory;
- excessive agency from overly broad tools;
- unauthorized side effects through mutating tools;
- data exfiltration through search, HTTP, email, ticket, file, database, or MCP
  tools;
- secrets in prompts, logs, traces, or model-visible tool output;
- multi-tenant bleed from shared context, memory, caches, or clients;
- SSRF and redirect abuse in remote MCP or HTTP tools;
- tool-result poisoning that tricks later model steps;
- replay/resume bugs that duplicate side effects;
- trajectory leakage: action sequences are user-visible behavior, audit log
  material, and possible training data.

## Tool Execution Checklist

- Each mutating tool checks user, tenant, role, and policy in code.
- Sensitive tools require approval or explicit scoped permission.
- Every tool has a risk rating: read/write scope, reversibility, permissions,
  user/financial impact, and blast radius.
- Tool results redact secrets and private fields.
- Side-effect tools are idempotent or have a compensation plan.
- Parallel tasks use isolated working directories, worktrees, sandboxes, or
  containers bound to task id.

## Context and Memory Checklist

- Prompt builders exclude credentials and broad private data.
- Retrieved context is source-labeled and scoped to user/tenant.
- Memory writes are intentional, auditable, and tenant-isolated.
- Tool results and retrieved documents are treated as untrusted text.
- Model-visible output never includes raw secrets, full private records, or
  unredacted PII.

## MCP and Remote Tool Checklist

- Remote transports are authenticated.
- Redirect behavior is restricted.
- Tool allowlists are per request or role.
- Server handlers enforce tenant isolation.
- Audit logs include tool name, user, tenant, status, and redacted input
  summary.
- HTTP tools enforce SSRF protections and destination allowlists where possible.

## Guardrails and Human Fallback

Layer guardrails:

- relevance/scope checks;
- prompt-injection or jailbreak detection;
- PII/data filters;
- moderation when applicable;
- deterministic input limits;
- tool safeguards;
- output validation.

Guardrails supplement code-level auth, tenant isolation, and handler checks; they
do not replace them. High-risk or irreversible actions pause for approval or
human handling until reliability is proven. Repeated failures, policy ambiguity,
or tool errors beyond a threshold trigger human intervention instead of
continued autonomous retries.

## Remediation Patterns

- Move policy from prompt text into tool handlers.
- Replace global clients with per-request scoped clients.
- Redact before logs, traces, and model-visible outputs.
- Add active tool allowlists.
- Return approval denial as a structured tool result.
- Sandbox shell/code tools and validate commands before execution.
- Add tenant-isolation tests with two users and conflicting data.
- Add failure thresholds and human handoff paths for workflows where repeated
  attempts can harm users or external systems.

## Severity Hints

- `critical`: cross-tenant access, command execution without enforcement,
  secrets sent to model/logs.
- `high`: mutating tool without permission check, unapproved irreversible
  action, remote MCP without auth.
- `medium`: weak redaction, missing audit trail, broad allowlist.
- `low`: unclear safety documentation or naming.

For review output formatting, read `../review-ai-agents/SKILL.md`. For tests,
read `../test-ai-agents/SKILL.md`.
