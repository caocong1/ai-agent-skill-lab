---
name: build-mcp-capabilities
description: Build, consume, or review Model Context Protocol capability layers for AI agents. Use for MCP servers, clients, tools, resources, prompts, stdio or Streamable HTTP transports, protocol error semantics, active tool allowlists, remote server security, and deciding when MCP vs A2A vs ANP is appropriate.
metadata:
  version: 2.0.0
  short-description: Design MCP tools, resources, clients
---

# Build MCP Capabilities

Use MCP as a capability protocol, not an agent runtime.

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

## Handoff

- For model-facing tool descriptions and schemas, read
  `../design-agent-tools/SKILL.md`.
- For threat modeling remote capabilities, read `../secure-ai-agents/SKILL.md`.
- For TypeScript implementation, read `../implement-ts-agents/SKILL.md`.
- For Java/Spring MCP annotations, read `../implement-java-agents/SKILL.md`.
