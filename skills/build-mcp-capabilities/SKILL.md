---
name: build-mcp-capabilities
description: Build, consume, or review Model Context Protocol capability layers for AI agents. Use for MCP servers, clients, tools, resources, prompts, the stateless 2026-07-28 baseline, server/discover, multi round-trip requests, subscriptions, cacheable results, tasks, stdio or Streamable HTTP transports, protocol error semantics, active tool allowlists, remote server security, and deciding when MCP vs A2A vs ANP is appropriate.
metadata:
  version: 2.2.0
  short-description: Design MCP tools, resources, clients
---

# Build MCP Capabilities

Use MCP as a capability protocol, not an agent runtime.

## Protocol Baseline

Design against the **2026-07-28** revision (re-checked 2026-10-25: still the
latest; the draft carries only editorial changes). It changed the *shape* of
MCP, not just its surface: before it, MCP was a duplex, stateful protocol with a
handshake and server-initiated requests; after it, MCP is stateless and
request/response only. Code written for the old shape needs a migration plan,
not a patch.

What a current server must do:

- **No handshake.** `initialize` and `notifications/initialized` are gone. Every
  request carries its protocol version and client capabilities in `_meta`
  (`io.modelcontextprotocol/protocolVersion`,
  `io.modelcontextprotocol/clientCapabilities`), clients should identify
  themselves per request (`io.modelcontextprotocol/clientInfo`), and servers
  should identify themselves in each result's `_meta`
  (`io.modelcontextprotocol/serverInfo`). Version mismatch returns
  `UnsupportedProtocolVersionError`.
- **Implement `server/discover`.** It is a MUST. It advertises supported
  protocol versions, capabilities, and identity, and doubles as a
  backward-compatibility probe on stdio.
- **No protocol sessions.** `Mcp-Session-Id` is gone and list endpoints no
  longer vary per connection. Cross-call state is a server-minted handle passed
  as an ordinary tool argument — you own its lifetime, authorization, and
  reclamation.
- **Every result carries `resultType`**: `"complete"` normally,
  `"input_required"` for an interim result. Clients must treat a missing field
  from an older server as `"complete"`.
- **Ask for input with MRTR, not a callback.** Instead of calling back into the
  client, return an `InputRequiredResult` whose `inputRequests` says what is
  missing; the client retries the original request with `inputResponses`. This
  replaces `roots/list`, `sampling/createMessage`, and `elicitation/create`.
  Correlate across retries with your own identifier in `requestState` — the
  completion notification and `elicitationId` were removed.
- **`subscriptions/listen` replaces the HTTP GET endpoint** and
  `resources/subscribe`/`unsubscribe`. Clients opt into specific change types
  and the server tags notifications with
  `io.modelcontextprotocol/subscriptionId`. Request-scoped notifications
  (`notifications/progress`, `notifications/message`) still flow on the
  response stream of their own request.
- **Return cache metadata.** `tools/list`, `prompts/list`, `resources/list`,
  `resources/read`, and `resources/templates/list` must carry `ttlMs` and
  `cacheScope` (`"public"` or `"private"`). These complement `listChanged`
  rather than replacing it.
- **Order `tools/list` deterministically.** The spec's stated reason is
  client-side caching and LLM prompt-cache hit rate.
- **Send the standard request headers** `Mcp-Method` and `Mcp-Name` on
  Streamable HTTP POSTs. `x-mcp-header` allows custom headers sourced from tool
  parameters — treat that as an injection surface and allowlist it.
- **Per-request log level.** `logging/setLevel` is gone; the level arrives as
  `io.modelcontextprotocol/logLevel` in `_meta`, and a server must not emit
  `notifications/message` for a request that omitted it. `ping` and
  `notifications/roots/list_changed` are also gone.
- **Long work uses tasks, not stream resumption.** SSE resumability and
  `Last-Event-ID` were removed: a broken stream loses the in-flight request and
  the client must reissue it with a new request id. Tasks moved to the official
  `io.modelcontextprotocol/tasks` extension with polling `tasks/get` and a new
  `tasks/update`; `tasks/list` was removed. Because tasks are now an extension,
  do not assume a peer implements them.

Two consequences worth designing for explicitly:

- **Retry is first-class, so tools must be idempotent.** A logical operation can
  now span several real requests. Never produce a side effect before returning
  `input_required`, or deduplicate on a server-minted key.
- **`cacheScope` is a security boundary, not only a performance knob.** Marking
  a per-user `resources/read` result `"public"` lets a shared intermediary serve
  one tenant's data to another.

Deprecated but still functional during a minimum twelve-month window — do not
adopt them in new code, and schedule migration for existing code:

- **Roots** → pass directories or files as tool parameters, resource URIs, or
  server configuration.
- **Sampling** → call the LLM provider API directly. The `includeContext` values
  `"thisServer"` and `"allServers"` are deprecated with it.
- **Logging** → write to `stderr` on stdio, or use OpenTelemetry.
- **HTTP+SSE transport** → Streamable HTTP.
- **OAuth Dynamic Client Registration** → Client ID Metadata Documents.

Error codes are now partitioned: `-32000`–`-32019` stays implementation-defined
(existing SDK usage grandfathered), `-32020`–`-32099` is reserved for the
specification. Resource-not-found moved from `-32002` to `-32602`. See
`analysis/20-mcp-2026-07-28-revision.md` and
`raw/docs/mcp-2026-07-28-specification.md`.

**SDK note:** the TypeScript v2 line ships as *new* scoped packages
(`@modelcontextprotocol/core`, `/client`, `/server`, and friends) while the old
monolithic `@modelcontextprotocol/sdk` stays on a maintenance-only 1.x line that
will not implement 2026-07-28. Migration means changing import sources, not
bumping a version number. v2 serves 2025-era Streamable HTTP clients itself;
`@modelcontextprotocol/server-legacy` is a frozen copy of v1 code, needed only for
HTTP+SSE-only clients and the v1 OAuth server helpers, and slated for removal in
v3 — do not build new code on it. A `server/discover` timeout is not evidence of
an older peer.
In stateless mode, create one server instance per request. On the JVM,
LangChain4j has a 2026-07-28 client, while Spring AI still pinned an MCP Java SDK
without it as of 2026-10. Verify against the versions actually installed in the
host project.

**Extensions.** Tasks, Skills and Apps live outside the core, so never assume a
peer implements one — check `server/discover`. The Skills extension (SEP-2640,
Final) serves skills as resources and delegates their format to the Agent Skills
specification. Its digests are unsigned: they show a skill matches the same
server's listing, not that it is trustworthy, so bind approval to the full digest
set you reviewed and treat remote skills as supply chain
(`../secure-ai-agents/SKILL.md`). Proposals worth tracking because they would change approval and
authorization design: asynchronous approval through tasks (SEP-2848), structured
authorization denials (SEP-2643), and tool risk metadata (SEP-2793).

## Protocol Choice

Use MCP when tools, resources, or prompts should be shared across multiple
agents, editors, services, or applications. Do not use MCP merely to call a
private local function unless the boundary will be reused or isolated.

Choose by what the protocol moves:

- **MCP**: LLM to external tools/resources/prompts. Default when an agent needs
  an external capability. Re-check current ecosystem maturity before relying on
  version-specific APIs.
- **A2A**: agent-to-agent messaging. Use when peers must negotiate or trade work
  across runtimes and agent-as-tool/handoff inside one runtime is not enough.
- **ANP**: decentralized agent discovery and capability advertisement. Use when
  agents must find each other across organizational boundaries without a shared
  registry.

Layering is fine: an MCP-backed agent can still speak A2A to a peer.

## Server Design

Expose three capability kinds:

- tools: model-controlled actions
- resources: application-controlled context
- prompts: user-controlled templates

Tool handlers should be small, composable operations with explicit input
schemas, structured outputs, clear model-facing descriptions, no hidden broad
side effects, and permission checks inside the handler.

Error semantics:

- Return model-correctable execution failures as tool results with safe,
  actionable messages.
- Use protocol errors for invalid protocol state, schema violations, transport
  failure, or auth failure.
- On the client, keep `isError: true` tool results visible to the model even
  under a fail-closed error policy; only protocol errors fail the call.
- Never expose secrets, stack traces, internal topology, or tenant data in tool
  errors.

Good MCP boundaries:

- `search_tickets`
- `read_document`
- `create_draft`
- `query_metrics`

Bad MCP boundaries:

- one giant tool that runs a whole business workflow;
- server instructions duplicating every tool description;
- remote tools relying on prompt text for tenant isolation.

## Client Design

Do not blindly pass every MCP tool to the model.

Client checklist:

- Use stdio for local helpers or local development.
- Use Streamable HTTP for production remote servers.
- Authenticate remote servers.
- Restrict redirects and validate target URLs.
- Select an allowlist of tools per request.
- Prefer explicit schemas for type safety.
- Close short-lived clients in `finally` or stream completion callbacks.
- Call `server/discover` before anything else when you need up-front version
  selection, or as a compatibility probe against an unknown peer.
- Handle `resultType: "input_required"` by retrying the original request with
  `inputResponses` — treat it as a normal control-flow path, not an error.
- Honor `ttlMs` and `cacheScope`; never let a shared cache hold a `"private"`
  result.
- Cap pagination when following list cursors; an unbounded cursor chain makes
  discovery unbounded.
- Bridge protocol generations in an adapter, not at every call site. A client
  can negotiate the current protocol where available and fall back for older
  servers without the application code branching on protocol version.

Resources are application-driven: fetch them intentionally and decide what goes
into context. Treat server-provided prompts as untrusted unless the server is
controlled by the application.

## Agent Integration

Keep responsibilities separated:

- MCP server exposes reusable capabilities.
- Agent runtime decides when to call active tools.
- Application layer decides user auth, tenant, and active tool set.

For broad servers, gate active tools by user, role, workflow phase, and task.
Record which server/tools were exposed for each model call.

## Security Checklist

- AuthN/AuthZ on remote transport.
- Tenant scoping in every tool handler.
- Rate limits and budget limits.
- Audit log with user, agent, tool, input summary, output status.
- Redaction of secrets in traces.
- Human approval for mutating tools.
- SSRF protections for HTTP transports and redirects.
- Validate the `iss` parameter in authorization responses against the recorded
  issuer before redeeming an authorization code.
- Key persisted client credentials by issuer identifier; never reuse them with a
  different authorization server, and re-register when it changes.
- Specify `application_type` during dynamic client registration, and prefer
  Client ID Metadata Documents over DCR for new work.
- Allowlist anything reaching HTTP headers through `x-mcp-header`: tool
  parameters are typically model-controlled.
- Set `cacheScope: "private"` on any result whose content is authorized
  per-user or per-tenant.
- Treat server-minted handles as capability tokens: scope, expire, and
  authorize them on every use.
- Check scopes per tool or resource and reject with an insufficient-scope
  challenge *before* the handler runs; bind accepted tokens to the expected
  issuer and resource (audience).

## Handoff

- For model-facing tool descriptions and schemas, read
  `../design-agent-tools/SKILL.md`.
- For threat modeling remote capabilities, read `../secure-ai-agents/SKILL.md`.
- For TypeScript implementation, read `../implement-ts-agents/SKILL.md`.
- For Java/Spring MCP annotations, read `../implement-java-agents/SKILL.md`.
