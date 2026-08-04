---
name: review-ai-agents
description: Review existing AI agent codebases for correctness, safety, cost, reliability, and maintainability. Use for locating agent constructs, auditing tool schemas, permissions, prompt/context assembly, memory, loop bounds, MCP exposure, tests, observability, anti-patterns, and producing a Chinese findings table plus prioritized remediation plan.
metadata:
  version: 2.1.0
  short-description: Audit agent correctness and risk
---

# Review AI Agents

Default to a code-review stance. Findings lead; summaries come after issues.
The final user-visible report is Chinese unless the user asks otherwise.

## Locate Agent Constructs

TypeScript and Node:

- Search for `new Agent`, `run(`, `tool(`, `ToolLoopAgent`, `WorkflowAgent`,
  `StateGraph`, `ToolNode`, `createAgent`, `createReactAgent`, `stopWhen`,
  `prepareStep`, `runtimeContext`, `toolsContext`, `toolApproval`,
  `tool_calls`, `function_call`, `system`, `instructions`.
- Locate route handlers or server actions converting UI messages to model
  messages.
- Locate prompt builders, context loaders, memory stores, approval handlers, and
  tool registries.

Java and Spring:

- Search for `ChatClient`, `AiServices`, `AgenticServices`, `@Tool`, `@McpTool`,
  `FunctionToolCallback`, `ToolProvider`, `ToolExecutor`, `ChatMemory`,
  `MessageWindowChatMemory`, `AgenticScope`.
- Locate service interfaces, tool beans, MCP providers, workflow services, and
  controller boundaries.
- Check whether tools are registered globally or scoped per user/request.

Raw SDK or other languages:

- Search for loops around model calls, `tool_calls`, `function_call`, message
  arrays, dispatch maps, prompt assembly, and manual retry logic.
- Map project names to model adapter, tool registry, loop/graph, state, memory,
  approval, events, and tests.

## Assessment Order

1. Goal and shape: is an agent needed, or would deterministic code or workflow
   be better?
2. Tool boundary: schema, description, permissions, error classification,
   idempotency.
3. Context boundary: prompt assembly, long-document slicing, retrieval, anchors,
   compaction, message separation, secret handling.
4. State and memory: persistence, tenant isolation, replay/resume, poisoning.
5. Loop control: stop condition, timeout, cost budget, retry policy.
6. Safety: approval, prompt injection, data exfiltration, SSRF, audit/redaction.
7. Harness lifecycle: turn/step/tool-call ownership, consistent tool/context
   snapshots, rollout compatibility, clean handoff, resume and fork.
8. Repository legibility: authoritative knowledge map, reproducible startup,
   user-visible and telemetry observations, executable architecture rules,
   feedback capture and recurring cleanup.
9. Tests and observability: fake model tests, eval snapshots, traces, metrics,
   fresh-session recovery and harness ablation.

## Anti-Patterns to Check

- Permission only in prompt.
- Unbounded loop.
- Secrets in prompt.
- Full long-document dump.
- God agent with all tools.
- MCP tool runs a whole workflow.
- UI/model message bleed.
- In-memory state for durable work.
- Over-engineered agent where a workflow is enough.
- Human-only tool descriptions.
- Swallowed or vague tool errors.
- No agent tests.
- Non-deterministic tool result ordering.
- Monolithic instruction file with no discoverable source-of-truth structure.
- Compaction treated as the only cross-session handoff.
- Completion state defaults to pass or can be changed without linked evidence.
- Builder grades its own long-running work with no fresh-context or
  deterministic evaluator.
- Model-visible tools/context come from a different snapshot than execution.
- Sandbox denial silently retries with broader permissions.
- Bash-only action surface described as "simple" without a real sandbox.
- Hidden context transformations cannot be reconstructed from the rollout.
- Agent feedback and repeated review findings never become docs, tests, lints,
  skills, or maintenance tasks.

## Severity Rubric

- `critical`: exploitable data leak, unauthorized mutation, unbounded cost loop,
  cross-tenant access, command/code execution without enforcement.
- `high`: missing approval for sensitive tools, no loop bound on production
  path, secrets in prompt, missing persistence for required durable workflow.
- `medium`: weak schemas, vague errors, no fake-model tests, prompt bloat, no
  eval snapshot for risky behavior.
- `low`: naming, documentation, minor observability gaps.

Impact: `correctness`, `safety`, `cost`, `reliability`, `maintainability`.
Effort: `S`, `M`, `L`.

## Chinese Reporting

Use neutral engineering language. Prefer `关注点`, `风险`, `建议调整`,
`验证方式`, `后续处理`. Distinguish evidence from inference:

- Evidence: `当前代码显示...`
- Inference: `这可能导致...`

Translate labels:

| Internal | Report |
| --- | --- |
| `critical` | `P0 严重` |
| `high` | `P1 高` |
| `medium` | `P2 中` |
| `low` | `P3 低` |
| `correctness` | `正确性` |
| `safety` | `安全/权限` |
| `cost` | `成本` |
| `reliability` | `可靠性` |
| `maintainability` | `可维护性` |

## Report Template

```markdown
## 审查结论

当前实现的主要风险集中在工具权限边界和循环控制。建议先处理 P1 项，再对 prompt/tool 行为补回归快照。

## 发现明细

| id | 关注点 | 风险级别 | 影响面 | 证据 | 建议调整 | 改动量 | 回归风险 | 验证方式 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | 工具权限边界 | P1 高 | 安全/权限 | path/to/file.ts:42 | 将权限校验下沉到 tool handler，并把拒绝原因作为结构化 tool result 返回。 | S | 中 | 增加无权限用户调用该工具的单元测试。 |

## 可立即处理
- [ ] A1: 在 `...` 增加执行时权限校验；用单元测试 `...` 验证无权限路径。

## 先补验证快照
- [ ] A2: 调整 system prompt/tool description 前，先记录当前 golden-task 输出，再比较变更前后差异。

## 需要设计调整
- [ ] A3: 将进程内 loop 调整为 durable workflow；实施前先确认 checkpoint schema 和 resume 流程。
```

## Remediation Patterns

- In-memory loop -> durable graph/workflow when resume, approval, retries, or
  long-running tasks are required.
- God-agent -> supervisor/subagents when context or permissions are too broad.
- Private duplicated tools -> MCP when multiple clients need the capability.
- No tests -> fake-model harness before behavior refactor.
- Prompt bloat -> retrieval/compaction with source attribution.
- Vague tool errors -> structured model-correctable errors.
- Long-task drift -> default-FAIL contract, progress + versioned checkpoint,
  fresh-session smoke test, evidence-bound completion, clean handoff.
- Repeated coding-agent mistakes -> promote evidence-backed guidance from docs
  to executable invariants, then run scoped recurring cleanup.
