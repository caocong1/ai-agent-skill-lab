---
name: secure-ai-agents
description: Threat-model, harden, or review AI agent safety boundaries. Use for prompt injection, excessive agency, mutating tools, data exfiltration, secrets, multi-tenant isolation, MCP or HTTP SSRF, tool-result poisoning, replay and resume authority, approval outcomes, OAuth issuer binding, cache scope, audit logs, redaction, guardrails, and human intervention triggers.
metadata:
  version: 2.2.0
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
mattering and the boundary cannot be argued out of. An "allow" that is always
outranked by every deny is an acceptable second form — but the guarantee must
hold against every principal that can approve, plugins and extensions included,
whatever credentials the deployment uses. Put must-run checks first in the
evaluation order: a check placed in a last-step approval callback is silently
skipped whenever an earlier rule auto-approves. The same rule governs
composition elsewhere: combine confirmation policies so configuration can only
add checks, and on resume let the current code veto a recorded "safe to replay"
declaration but never upgrade one.

**Approval outcomes are a closed set, and the default is deny.** Enumerate them
explicitly — allowed-once, rejected, cancelled, unavailable — and make every one
distinguishable to the caller. A policy engine's "no rule matched" must also
mean deny; check the default of any engine you adopt, because some treat it as
allow. Every extension point declares what its silence means, and a broken
control channel — a closed pipe, a timed-out hook — counts as unavailable. "Unavailable" in particular must not collapse
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
  version the assignment or resource and compare on use. Bind a grant to the turn
  and the artifact version it was issued for: an approval of one commit does not
  cover the next, and an approval bound to one input does not cover an edited
  one;
- before resuming, re-check that the plan or resource a grant covered is still
  live, and only then pick a credential; settle an approve-versus-stop race by
  compare-and-swap on that plan's status;
- treat serialized run state as executable authority: keep it server-side,
  never where the agent can write it, and check-and-consume each pending
  decision atomically before deserializing. A client-supplied snapshot is not
  authenticated by being parseable, and signing a client-held approval proves
  integrity, not freshness — it does not stop a replay. Consuming a decision
  does not make the side effect exactly-once;
- an escalation after a sandbox denial needs a fresh review, widens only what it
  must, and fails closed if it cannot preserve the other restrictions;
- a replay re-runs the current deterministic policy checks first; a human
  approval is single-use and is not re-asked, nor reused, for the replay — mark
  it used before the tool runs, in the same commit as the intent record, or a
  crash after the effect lets it authorize the call twice;
- stored calls that recovery will re-execute are integrity-stamped; unstamped or
  imported history is never executed, because whoever can edit the store can
  otherwise schedule tool calls;
- restore restrictions on resume, re-acquire escalations; keep persistent grants
  only as reviewable configuration, never as transcript state, and let new user
  input invalidate a pending deferred approval.

Safety guards live in a layer that conversations, plugins and subagents cannot
deselect. If a guard can be left out of a profile or a child session, it is
opt-out by construction. Owning a session or task is not authority to act.

See `analysis/01-pi-source-analysis.md`, `analysis/02-agent-framework-patterns.md`,
`analysis/16-openai-codex-harness.md`, and
`analysis/26-durable-rules-production-evidence.md`.

Two labels that are commonly mistaken for security boundaries and are not:

- a runtime "isolation" flag on a code sandbox is a diagnostic descriptor, not
  a containment claim;
- a per-task worktree or working directory changes where tools default to
  writing; it does not confine a process. Destructive removal stays a host-side
  operation the model cannot invoke.

Any mechanism that redacts, withholds, or sanitizes should state what it does
*not* cover — typically external side effects already performed and copies the
application owns. A guardrail whose coverage is unstated will be assumed total.

## Approval Automation Layering

When approval volume is high enough that people stop reading what they approve,
add a model-based review layer *on top of* the mechanical boundary — never as its
replacement. Three local harnesses converged on this shape independently. Three
layers, each with its own failure mode:

- **Mechanical boundary** (monotonic guard, closed approval set): decides what
  can never be reopened. It must not depend on the classifier; when the
  classifier fails, this layer still holds.
- **Classifier** (transcript-level, model-based): judges the semantic gray zone
  the mechanical rules cannot express — whether the user's consent covers this
  action's blast radius. Publish its false-positive and false-negative rates
  next to the mechanism, and re-measure on model upgrades: the judge model is
  itself a perishable component.
- **Human**: receives only escalated denials, not the routine flow.

Design rules for the review layer, from `analysis/23-claude-code-auto-mode.md`:

- **Choose the judging context deliberately; label provenance either way.** Two
  production designs differ here. One judge sees only user messages and bare
  tool calls, so the executing agent cannot rationalize its way past it and
  injected content has no way in — its authors measured judging get worse when
  agent text and tool results were added. Another sees a provenance-labelled
  full transcript and may investigate in a read-only, network-less sandbox; it
  publishes no error rates. In both, only user- or developer-authored content
  can count as authorization, and the reviewer's own past verdicts are not
  precedent.
- **A review that fails is a denial.** Timeouts, malformed verdicts and reviewer
  crashes fail closed and do not count toward the deny budget. A headless run
  offers only "review" or "deny all", never "allow".
- **Cover every path that has effects.** A program-mode or plugin path whose side
  effects skip the reviewer is a hole in the layer, not an edge case; effects
  that cannot be routed through review need OS-level confinement instead. A
  denial issued to a child agent is final for that child.
- **Deny-and-continue with a deny budget.** Return denials as structured tool
  results that ask for a safer path, and circuit-break to a human after N
  consecutive or M total denials. Without the budget, "deny then retry" is a
  loop recipe.
- **Default deny on intent, matched to blast radius.** Everything the agent
  chose autonomously is unauthorized unless the user said so; matching is
  per-action and against the action's blast radius, not its surface verb; a
  question is not a directive. Expect this to be the weak spot: the dominant
  miss is a judge that finds approval-shaped evidence and stops before checking
  that the consent covers this action. Prompting has not fixed it, so the
  mechanical layer must hold on its own.
- **Re-audit blanket rules when autonomy mode changes.** Entering a
  higher-autonomy mode must drop blanket grants for arbitrary execution so the
  reviewer actually sees the dangerous commands — permission aggregation
  silently blinds downstream judges.
- **Treat approval requests as an attack surface.** Planted text can steer an
  agent into asking for a broad but plausible standing rule. Fix the authority
  ceiling before the agent reads untrusted content, review a mid-task request
  for a standing grant against its blast radius, prefer one-off approvals, and
  never count an agent's approval as a human's.
- **An opt-in mechanism is not a boundary until you have verified it is on.**
  Many harness safety features ship disabled; auto-approval multiplies attack
  success. Audit the effective configuration, not the feature list.
- **Asymmetric gates for asymmetric risk.** Deny on subagent delegation (the
  downside is real); warn on subagent return (discarding completed, legitimate
  work is the larger waste).

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

**Keep credentials structurally unreachable from model-executed code.** Not
narrower scopes — unreachability. Two patterns, from
`analysis/22-anthropic-managed-agents.md`: bundle auth with the resource (clone
with the token wired into the local remote, so push/pull works and the token
stays invisible), or vault-and-proxy (tokens live in a vault; a dedicated proxy
injects credentials per call). The harness never sees the credential either.

**Contain at the environment layer first, steer the model second.** Project
configuration that only restricts may apply before the trust decision for that
project; configuration that grants capability — hooks, allow-rules, tools,
instruction files, memory — waits for it. Treat an egress allowlist as a
capability grant: an allow-listed API endpoint can carry an attacker's key, so
route it through a proxy that accepts only the sandbox's own session credential.
See `analysis/26-durable-rules-production-evidence.md`.

**Own the files you create.** Put agent-written artifacts in a private directory
created with restrictive permissions, and create files with an exclusive-create
flag and restrictive mode so an existing file — including one an attacker
planted — is never silently written through.

**Unlink link-shaped paths; do not follow them.** When cleaning up a path the
agent believes it created, check whether it is a symlink or hard link and remove
the link itself. Following it deletes something else. When validating a path
against a boundary, resolve links first, then check.

**Persistent state is an injection-persistence surface.** Memory files,
instruction files and agent state directories that survive sessions let one
injected turn steer every later one; scope who may write them and review changes
to them like code.

**Permission presets are named, and customization derives from a preset.** Offer
a small set of named levels and let a project derive a custom profile from one
of them, so the diff from a known baseline is reviewable. A free-form permission
blob has no baseline to review against.

**A toolset that can modify the running agent is bash-equivalent.** If tools can
define, run, or unload code inside the agent process, treat granting them as
granting shell access, regardless of any language-level sandbox in between. Say
so plainly in the tool description and gate them accordingly — or, as one
harness concluded after shipping such tools, remove them and route agent
self-extension through the normal plugin install lifecycle with an install-time
gate, leaving the agent read-only inspection.

## Context and Memory Checklist

- Prompt builders exclude credentials and broad private data.
- Retrieved context is source-labeled and scoped to user/tenant.
- Memory writes are intentional, auditable, and tenant-isolated.
- Tool results and retrieved documents are treated as untrusted text — and so
  are compaction summaries and handoff notes, which a model can use to pass
  instructions to its own future context.
- Content arriving from outside the user — subagent messages, external events,
  other agents — carries tool-level authority, not user authority.
- Tool error text is a leak channel to the provider, the transcript, memory and
  the user; whether an error's text is model-visible is decided per error type,
  default closed.
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
- Skills fetched from a server are supply chain, and a digest only shows the
  skill matches that server's own listing — it is not a trust boundary. Bind
  approval to the full set of digests you reviewed, ignore tool pre-approvals a
  remote skill declares, and never let a cached remote skill gain the trust of a
  local one.
- Cap list pagination. A server can make discovery unbounded by never ending its
  cursor chain.

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
