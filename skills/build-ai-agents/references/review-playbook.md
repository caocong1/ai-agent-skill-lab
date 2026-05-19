# Review Playbook

Use this reference when reviewing or optimizing an existing AI-agent codebase.

## Locate Agent Constructs

Find the implementation before judging it.

TypeScript and Node:

- Search for `new Agent`, `run(`, `tool(`, `ToolLoopAgent`, `WorkflowAgent`, `StateGraph`, `ToolNode`, `createAgent`, `createReactAgent`, `stopWhen`, `prepareStep`, `runtimeContext`, `toolsContext`, `toolApproval`, `tool_calls`, `function_call`, `system`, `instructions`.
- Locate route handlers or server actions that convert UI messages to model messages.
- Locate prompt builders, context loaders, memory stores, approval handlers, and tool registries.

Java and Spring:

- Search for `ChatClient`, `AiServices`, `AgenticServices`, `@Tool`, `@McpTool`, `FunctionToolCallback`, `ToolProvider`, `ToolExecutor`, `ChatMemory`, `MessageWindowChatMemory`, `AgenticScope`.
- Locate service interfaces, tool beans, MCP providers, workflow services, and controller boundaries.
- Check whether tools are registered globally or scoped per user/request.

Raw SDK or other languages:

- Search for loops around model calls, `tool_calls`, `function_call`, message arrays, tool dispatch maps, prompt assembly, and manual retry logic.
- Map project-specific names to the common constructs: model adapter, tool registry, loop/graph, state, memory, approval, events, tests.

## Assessment Order

1. Goal and agent shape: is an agent needed, or would deterministic code or a structured workflow be better?
2. Tool boundary: schema, description, permissions, error classification, idempotency.
3. Context boundary: prompt assembly, long-document slicing, retrieval, source anchors, compaction, message separation, secret handling.
4. State and memory: persistence, tenant isolation, replay/resume, stale or poisoned memory risk.
5. Loop control: stop condition, timeout, cost budget, retry policy.
6. Safety: approval, prompt injection, data exfiltration, SSRF, audit and redaction.
7. Tests and observability: fake model tests, eval snapshots, traces, metrics.

## Severity Rubric

- `critical`: exploitable data leak, unauthorized mutation, unbounded cost loop, cross-tenant access, command/code execution without enforcement.
- `high`: missing approval for sensitive tools, no loop bound on production path, secrets in prompt, no persistence for required durable workflow.
- `medium`: weak tool schemas, vague tool errors, no fake-model tests, prompt bloat, no eval snapshot for risky behavior.
- `low`: naming, documentation, minor observability gaps, maintainability improvements.

Impact categories:

- `correctness`
- `safety`
- `cost`
- `reliability`
- `maintainability`

Effort categories:

- `S`: localized edit and focused test.
- `M`: several files or new harness.
- `L`: architecture or workflow redesign.

## Review Report Template

```markdown
| id | construct | severity | impact | evidence | recommended change | effort | regression risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | tool permission | high | safety | path/to/file.ts:42 | Move permission check into tool handler and return denial as tool result. | S | medium |
```

## Remediation Plan Template

```markdown
## Safe Now
- [ ] A1: Add execution-time permission check in `...`; validate with unit test `...`.

## Needs Eval Snapshot
- [ ] A2: Rewrite system prompt/tool descriptions; first capture current golden-task outputs, then compare before/after.

## Needs Design Change
- [ ] A3: Replace in-memory loop with durable workflow; design checkpoint schema and resume flow before implementation.
```

## Optimization Patterns

- In-memory loop to durable graph/workflow when resume, approval, retries, or long-running tasks are required.
- God-agent to supervisor/subagents when context or tool permissions are too broad.
- Private duplicated tools to MCP server when multiple agents or clients need the capability.
- No tests to fake-model harness before behavior refactor.
- Prompt bloat to context compaction/retrieval with source attribution.
- Vague tool errors to structured model-correctable errors.
