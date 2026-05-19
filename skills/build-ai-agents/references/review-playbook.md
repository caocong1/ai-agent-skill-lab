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

## 中文报告措辞

最终报告应使用中文，并让开发人员能快速判断要先处理什么、为什么处理、怎么验证。

使用中性的工程化表达：

- 优先使用 `关注点`, `风险`, `建议调整`, `验证方式`, `后续处理`，少用 `违规`, `问责`, `整改` 这类流程压力更强的词。
- 优先写 `当前实现缺少...`，不要写 `代码没有...`；优先写 `建议下沉到...`，不要写 `必须重写...`。
- `严重` 只用于已确认的 P0 场景，例如数据泄露、未授权写操作、生产成本无上限、命令执行缺少强制校验。
- 如果风险来自推断，用 `这可能导致...`；如果证据来自代码事实，用 `当前代码显示...`。
- 表格单元格保持短句。只有用户需要更多推理时，才在表格后补充展开说明。

面向用户的报告中使用这些中文标签：

| 内部标签 | 报告标签 |
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

常用替换：

| 不建议 | 建议 |
| --- | --- |
| `权限只靠 prompt，很危险` | `权限约束目前主要在模型指令层，建议在工具执行边界增加强制校验。` |
| `没有 stopWhen，会无限循环` | `当前循环缺少明确上限，生产环境可能出现延迟或成本不可控。` |
| `schema 太松` | `工具入参约束偏宽，模型更容易生成不可执行或越权参数。` |
| `没有测试，不能改` | `这里缺少可回放的行为保护，建议先补 fake-model 或 golden-task 快照再调整。` |
| `需要重构` | `这类问题涉及状态/审批边界，建议先确认设计后再拆分实施。` |

## 中文审查报告模板

```markdown
## 审查结论

当前实现的主要风险集中在工具权限边界和循环控制。建议先处理 P1 项，再对 prompt/tool 行为补回归快照。

## 发现明细

| id | 关注点 | 风险级别 | 影响面 | 证据 | 建议调整 | 改动量 | 回归风险 | 验证方式 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | 工具权限边界 | P1 高 | 安全/权限 | path/to/file.ts:42 | 将权限校验下沉到 tool handler，并把拒绝原因作为结构化 tool result 返回。 | S | 中 | 增加无权限用户调用该工具的单元测试。 |
```

## 中文处理计划模板

```markdown
## 可立即处理
- [ ] A1: 在 `...` 增加执行时权限校验；用单元测试 `...` 验证无权限路径。

## 先补验证快照
- [ ] A2: 调整 system prompt/tool description 前，先记录当前 golden-task 输出，再比较变更前后差异。

## 需要设计调整
- [ ] A3: 将进程内 loop 调整为 durable workflow；实施前先确认 checkpoint schema 和 resume 流程。
```

## Optimization Patterns

- In-memory loop to durable graph/workflow when resume, approval, retries, or long-running tasks are required.
- God-agent to supervisor/subagents when context or tool permissions are too broad.
- Private duplicated tools to MCP server when multiple agents or clients need the capability.
- No tests to fake-model harness before behavior refactor.
- Prompt bloat to context compaction/retrieval with source attribution.
- Vague tool errors to structured model-correctable errors.
