# Security and Safety

Agent security is primarily about controlling tool authority, context exposure, and cross-boundary data flow.

## Threat Model

Review these threats for any production agent:

- prompt injection in user input, retrieved documents, tool results, MCP resources, or memory
- excessive agency from overly broad tools
- unauthorized side effects through mutating tools
- data exfiltration through search, HTTP, email, ticket, file, database, or MCP tools
- secrets in prompts, logs, traces, or model-visible tool output
- multi-tenant bleed from shared context, memory, caches, or tool clients
- SSRF and redirect abuse in remote MCP or HTTP tools
- tool-result poisoning that tricks later model steps
- replay/resume bugs that duplicate side effects

## Review Checklist

Tool execution:

- Each mutating tool checks user, tenant, role, and policy in code.
- Sensitive tools require approval or explicit scoped permission.
- Each tool has a risk rating based on read/write scope, reversibility, required permissions, user/financial impact, and blast radius.
- Tool results redact secrets and private fields.
- Side-effect tools are idempotent or have a compensation plan.

Context and memory:

- Prompt builders do not include credentials or broad private data.
- Retrieved context is source-labeled and scoped to the user/tenant.
- Memory writes are intentional, auditable, and tenant-isolated.
- Tool results and retrieved documents are treated as untrusted text.

MCP and remote tools:

- Remote transports are authenticated.
- Redirect behavior is restricted.
- Tool allowlists are per request or per role.
- Server handlers enforce tenant isolation.
- Audit logs include tool name, user, tenant, status, and redacted input summary.

Observability:

- Logs and traces are redacted by default.
- Approval decisions are recorded.
- Cost, step count, tool count, and stop reason are tracked.

Guardrails and fallback:

- Guardrails are layered: relevance/scope, prompt-injection or jailbreak detection, PII/data filters, moderation when applicable, deterministic input limits, tool safeguards, and output validation.
- High-risk or irreversible actions pause for approval or human handling until reliability is proven.
- Repeated failures, policy ambiguity, or tool errors beyond a threshold trigger human intervention instead of continued autonomous retries.
- Guardrails supplement code-level authentication, authorization, tenant isolation, and handler checks; they do not replace them.

## Remediation Patterns

- Move policy from prompt text into tool handlers.
- Replace global clients with per-request scoped clients.
- Add redaction before logs/traces/model-visible outputs.
- Add allowlists for active tools.
- Add approval response messages so the model knows the action was denied.
- Use sandboxed execution for shell/code tools and validate commands before execution.
- Add tenant-isolation tests with two users and conflicting data.
- Add failure thresholds and human handoff paths for workflows where repeated attempts can harm users or external systems.

## Severity Hints

- `critical`: cross-tenant access, command execution without enforcement, secrets sent to model or logs.
- `high`: mutating tool without permission check, unapproved irreversible action, remote MCP without auth.
- `medium`: weak redaction, missing audit trail, broad tool allowlist.
- `low`: unclear safety documentation or naming.

