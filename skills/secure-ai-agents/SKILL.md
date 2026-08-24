---
name: secure-ai-agents
description: Threat-model, harden, or review AI agent safety boundaries. Use for prompt injection, excessive agency, mutating tools, data exfiltration, secrets, multi-tenant isolation, MCP or HTTP SSRF, tool-result poisoning, replay and resume authority, approval outcomes, OAuth issuer binding, cache scope, audit logs, redaction, guardrails, and human intervention triggers.
metadata:
  version: 2.1.0
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

## Authority Boundary Design

Three design rules decide whether an authority boundary actually holds.

**Denial must be monotonic.** Give the guard type no way to express "allow". If
a guard can return an approval, then listener ordering, a later plugin, or a
misconfigured priority can reopen a denial that an earlier guard closed. When
the only expressible outcomes are "no opinion" and "deny", ordering stops
mattering and the boundary cannot be argued out of.

**Approval outcomes are a closed set, and the default is deny.** Enumerate them
explicitly — allowed-once, rejected, cancelled, unavailable — and make every one
distinguishable to the caller. "Unavailable" in particular must not collapse
into "allowed": an approval channel that is missing, timed out, or running in a
non-interactive context is a denial, not a pass. Only a foreground, interactive
turn may prompt a human; an asynchronous or background turn must deny anything
that needs confirmation rather than compete for the user's attention or block
forever on a prompt nobody can see.

**Authorization is never inherited from serialized state.** State can be
restored; permission cannot. On resume, fork, or replay:

- do not trust serialized credentials or mount authority;
- do not treat a previously granted approval as still granted;
- require re-authorization for autonomous continuation, which means the "armed"
  flag on a long-running goal should deliberately *not* be persisted;
- if you cannot prove which request owns a pending output, fail closed rather
  than guess;
- invalidate stale approvals when the thing they were granted against changes —
  version the assignment or resource and compare on use.

Two labels that are commonly mistaken for security boundaries and are not:

- a runtime "isolation" flag on a code sandbox is a diagnostic descriptor, not
  a containment claim;
- a per-task worktree or working directory changes where tools default to
  writing; it does not confine a process. Destructive removal stays a host-side
  operation the model cannot invoke.

Any mechanism that redacts, withholds, or sanitizes should state what it does
*not* cover — typically external side effects already performed and copies the
application owns. A guardrail whose coverage is unstated will be assumed total.

## Tool Execution Checklist

- Each mutating tool checks user, tenant, role, and policy in code.
- Sensitive tools require approval or explicit scoped permission.
- Every tool has a risk rating: read/write scope, reversibility, permissions,
  user/financial impact, and blast radius.
- Tool results redact secrets and private fields.
- Side-effect tools are idempotent or have a compensation plan.
- Parallel tasks use isolated working directories, worktrees, sandboxes, or
  containers bound to task id.
- Sensitive model and tool data is **off** by default in logs and traces, with
  an explicit opt-in to enable it.
- Cancellation reaches into function and remote tools, and stream completion
  waits for background work and cleanup to settle before resolving.
- A batch of checks all settle before a failure is surfaced, so one early
  tripwire does not discard the other diagnostics.

## Sandbox and Subprocess Hygiene

**Sandbox policy is per call, not per session.** Resolve the policy at the point
of execution from the tool, the arguments, and the current approval state.
A session-level "sandbox mode" cannot express "this one command needs more" and
invites a global relaxation to unblock a single case.

**A denied action and a broken runner are different outcomes.** Distinguish
"the sandbox refused this" from "the sandbox itself failed to run", and never
let either fall back to unsandboxed execution. A denial is a result the model
should see and adapt to; a runner failure is an operational error for the
operator. Collapsing them produces the worst pattern in this area: a sandbox
failure silently retried without the sandbox.

**Report orthogonal outcomes independently.** A command can time out *and* exit
zero. Wall-clock outcome, exit status, and completeness of captured output are
separate facts; encoding them as one enum loses information the caller needs.
Say explicitly whether captured output is complete or truncated rather than
letting the caller infer it from length.

**Scrub the environment for spawned commands.** Build the child environment from
an explicit allowlist rather than inheriting the parent's. Agent processes
routinely hold provider keys, cloud credentials, and tokens that no tool
subprocess needs.

**Own the files you create.** Put agent-written artifacts in a private directory
created with restrictive permissions, and create files with an exclusive-create
flag and restrictive mode so an existing file — including one an attacker
planted — is never silently written through.

**Unlink link-shaped paths; do not follow them.** When cleaning up a path the
agent believes it created, check whether it is a symlink or hard link and remove
the link itself. Following it deletes something else.

**Permission presets are named, and customization derives from a preset.** Offer
a small set of named levels and let a project derive a custom profile from one
of them, so the diff from a known baseline is reviewable. A free-form permission
blob has no baseline to review against.

**A toolset that can modify the running agent is bash-equivalent.** If tools can
define, run, or unload code inside the agent process, treat granting them as
granting shell access, regardless of any language-level sandbox in between. Say
so plainly in the tool description and gate them accordingly.

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
- **A tool's own description is not authorization evidence.** It comes from the
  server, which is the untrusted party. Maintain a host-side allowlist of
  exactly which external tools are known read-only; everything else asks.
- Validate the `iss` parameter against the recorded issuer before redeeming an
  authorization code, and key persisted credentials by issuer — never reuse
  them against a different authorization server.
- Prefer Client ID Metadata Documents over Dynamic Client Registration; when
  DCR is unavoidable, specify `application_type` to avoid redirect-URI
  conflicts.
- Mark per-user or per-tenant results `cacheScope: "private"`. A wrong cache
  scope hands one tenant's data to another through a shared intermediary.
- Allowlist any tool parameter that can reach an HTTP header; model-controlled
  values landing in headers is a classic injection shape.
- Treat server-minted state handles as capability tokens: scope, expire, and
  re-authorize them on every use.

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
  action, remote MCP without auth, approval or credentials inherited from
  serialized state on resume, an approval path where "unavailable" behaves as
  "allowed".
- `medium`: weak redaction, missing audit trail, broad allowlist.
- `low`: unclear safety documentation or naming.

For review output formatting, read `../review-ai-agents/SKILL.md`. For tests,
read `../test-ai-agents/SKILL.md`.
