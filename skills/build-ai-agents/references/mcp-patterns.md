# MCP Patterns

## Role of MCP

MCP is a capability protocol, not an agent runtime.

Use MCP when tools, resources, or prompts should be shared across multiple agents, editors, services, or applications.

Do not use MCP merely to call a private function from one local agent unless the boundary will be reused or isolated.

MCP is one option on a small spectrum of agent-side protocols; choose by what the protocol is actually moving between (see `analysis/11-hello-agents.md` chapter 10):

- **MCP (Model Context Protocol)** — LLM ↔ external tools / resources / prompts. Highest current adoption and tooling maturity. Default choice when "an agent needs an external capability". Treat as the baseline option unless a concrete requirement rules it out.
- **A2A (Agent-to-Agent)** — direct agent ↔ agent messaging. Use when two or more agents need to negotiate or trade work without bouncing every message through a shared central runtime, and when agent-as-tool / handoff inside one runtime is not enough.
- **ANP (Agent Network Protocol)** — decentralized agent discovery and capability advertisement. Use when agents must find each other across organizational boundaries without a pre-shared registry.

Trade-offs are real, not symmetric: MCP gives the most interoperability and the most existing client/server code; A2A and ANP give more flexibility for cross-runtime or open networks but have smaller ecosystems and weaker tooling today. Pick MCP as the default; escalate to A2A or ANP only when the workload is genuinely cross-runtime (multi-vendor agent collaboration) or genuinely cross-organization (no shared catalog). Layering them is fine — an MCP-backed agent can still speak A2A to a peer.

## Server Design

Expose three kinds of server capabilities:

- tools: model-controlled actions
- resources: application-controlled context
- prompts: user-controlled templates

Tool design:

- small, composable operations
- explicit input schema
- structured output when possible
- clear model-facing description
- no hidden broad side effects
- permission checks inside the handler

Error design:

- return model-correctable execution failures as tool results with `isError`
- use protocol errors for invalid protocol state, schema violations, transport failure, or auth failure
- include safe, actionable error messages
- avoid exposing secrets, stack traces, or internal topology

## Client Design

Do not blindly pass every MCP tool to the model.

Client checklist:

- choose stdio only for local development or local helper processes
- choose Streamable HTTP for production remote servers
- authenticate remote MCP servers
- restrict redirects and validate target URLs
- select an allowlist of tools per request
- prefer explicit schemas for type safety
- close short-lived clients in `finally` or stream `onFinish`

Resources are application-driven. Fetch resources intentionally and decide what to add to the model context.

Prompts are templates. Treat server-provided prompts as untrusted input unless the server is controlled by the application.

## MCP and Agents

Good boundaries:

- MCP server exposes "search tickets", "read document", "create draft", "query metrics".
- Agent runtime decides when to call those tools.
- Application layer decides user auth, tenant, and active tool set.

Bad boundaries:

- One giant MCP tool that runs an entire business workflow with vague input.
- Server instructions that duplicate every tool description.
- A remote MCP server that can access all tenants based only on prompt text.

## Security Checklist

- AuthN/AuthZ on remote transport.
- Tenant scoping in every tool handler.
- Rate limits and budget limits.
- Audit log with user, agent, tool, input summary, output status.
- Redaction of secrets in traces.
- Human approval for mutating tools.
- SSRF protections for HTTP transports and redirects.

