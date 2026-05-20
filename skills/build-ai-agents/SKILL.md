---
name: build-ai-agents
description: Design, implement, review, and test AI agent features across TypeScript, Java, MCP, and general LLM application stacks. Use for tool-calling agents, agent loops, workflows, subagents, memory, approvals, MCP tools, prompt/context assembly, long-document handling, context compaction, retrieval, or agent skill integration.
version: 1.2.0
---

# Build AI Agents

## Mode

Pick the mode before anything else:

- `build`: create a new agent feature.
- `extend`: add capability to an existing agent.
- `review`: audit an existing agent for correctness, safety, cost, reliability, and maintainability, then produce a prioritized remediation plan.

`build` and `extend` follow the Build Workflow. `review` follows the Review Workflow.

## Build Workflow

1. Classify the requested agent shape before implementing:
   - single model call
   - structured workflow
   - tool loop agent
   - durable graph/workflow
   - subagent or multi-agent system
   - MCP server/client capability layer
2. Inspect the host project first. Match its language, framework, dependency injection, test style, logging, persistence, and security patterns.
3. Define the agent contract:
   - user-visible goal
   - model instructions
   - tool list and schemas
   - runtime state
   - memory/session persistence
   - stop conditions and budgets
   - approval rules for sensitive actions
   - events/traces/logs
4. Implement the smallest architecture that satisfies the goal. Do not introduce graph runtimes, MCP, vector memory, or subagents unless the requirement needs them, and do not build an autonomous agent when a fixed workflow or single model call suffices.
5. Add focused tests for tool handlers, orchestration logic, failure paths, permissions, and resume/approval behavior when applicable.
6. Verify with the project's normal test/build commands and record any unverified risk.

## Review Workflow

1. Locate the agent constructs in the host project: model adapter, tool registry, orchestration loop/graph, prompt/context assembly, state and memory, approval/permission boundary, stop conditions and budgets, events/traces, and tests.
2. Assess each construct against the Dual-Use Rubric below. Record evidence as `file:line`.
3. Classify findings by severity (`critical`, `high`, `medium`, `low`), impact (`correctness`, `safety`, `cost`, `reliability`, `maintainability`), effort (`S`, `M`, `L`), and regression risk.
4. Produce a developer-facing Chinese `审查报告` and prioritized `处理计划` with concrete, executable changes.
5. Validate per Definition of Done before finishing.

## Architecture Rules

- Prefer the simplest shape that works and escalate only when the requirement forces it: deterministic code < single model call < structured workflow < autonomous tool loop < durable graph < multi-agent. Build an autonomous agent only when steps are unpredictable, the path cannot be hard-coded, and the tool environment is trustworthy.
- Use plain deterministic code when no model judgment is required.
- Use a single model call when the task is pure generation, classification, extraction, or summarization without external actions.
- Use a structured workflow when steps are known in advance: prompt chaining, routing, parallelization (sectioning or voting), orchestrator-workers, or evaluator-optimizer.
- Use a tool loop when the model must choose tools dynamically and can finish within an in-memory request lifecycle.
- Use a durable graph/workflow when the agent needs checkpointing, replay, resume, long-running execution, or human approval across process boundaries.
- Use subagents when isolation of context, tools, or specialist behavior is worth the latency and complexity.
- Use MCP when external capabilities should be reusable by multiple clients or agents through a stable protocol boundary.

## Dual-Use Rubric

- Tool schemas and descriptions: build with explicit schemas and model-facing descriptions; review for missing/loose schemas or descriptions written only for humans.
- Secrets isolation: build with typed runtime/tool context; review prompts and instruction builders for leaked keys, tokens, tenant ids, or private data.
- Permission enforcement: build checks into dangerous tool handlers; review for tools whose only guard is prompt text.
- Loop bounds: build step, timeout, cost, or stop limits; review for unbounded loops, recursion, or missing `stopWhen`.
- Error classification: build model-correctable tool errors separately from system failures; review for swallowed exceptions, raw stack traces, or vague failures.
- Message contracts: build separate domain, runtime, model, and UI message contracts; review for UI artifacts or internal state leaking into model context.
- Tests and evals: build fake-model orchestration tests plus small eval coverage; review for zero agent tests before recommending risky refactors.

## 中文报告

- `review` 模式的用户可见最终报告默认使用中文，除非用户明确要求其他语言。
- 语气保持事实化、工程化、便于开发人员接受：描述当前实现、具体风险和下一步建议，避免 `违规`, `低级错误`, `设计失败` 这类归责感强的词。
- 内部分类标签在报告中转成开发人员更容易扫描的中文：
  - severity -> `风险级别`，使用 `P0 严重`, `P1 高`, `P2 中`, `P3 低`
  - impact -> `影响面`，使用 `正确性`, `安全/权限`, `成本`, `可靠性`, `可维护性`
  - effort -> `改动量`，使用 `S`, `M`, `L`
  - regression risk -> `回归风险`
- 每条发现都要说明证据、为什么值得处理、一个可执行的建议调整，以及验证方式。
- 区分代码事实和风险推断。直接证据使用 `当前代码显示...`，推断风险使用 `这可能导致...`。

## Deliverables

- `build` / `extend`: working code, focused tests, verification commands, and any unverified risks.
- `review`: a Chinese `审查报告` table with `[id | 关注点 | 风险级别 | 影响面 | 证据 file:line | 建议调整 | 改动量 | 回归风险 | 验证方式]`, plus a `处理计划` ordered into `可立即处理`, `先补验证快照`, and `需要设计调整`.

## Definition of Done

- `build`: every Dual-Use Rubric item is satisfied or its risk is explicitly recorded; project tests/builds requested for the change have been run or the blocker is stated.
- `review`: every finding has `file:line`, concrete change, risk level, effort, and validation; prompt/tool changes include a before/after eval or regression snapshot requirement; non-goals and residual risks are listed in Chinese.

## Load References

- Read `references/agent-architecture.md` when choosing the agent shape or reviewing an agent design.
- Read `references/typescript-patterns.md` for TypeScript, Node, Next.js, OpenAI Agents JS, Vercel AI SDK, LangGraphJS, or Pi-inspired implementations.
- Read `references/java-patterns.md` for Java, Spring AI, LangChain4j, service-layer agents, annotations, or DI-heavy projects.
- Read `references/mcp-patterns.md` when building or consuming MCP servers, tools, resources, prompts, or transports.
- Read `references/review-playbook.md` when auditing or optimizing an existing agent codebase.
- Read `references/anti-patterns.md` to map symptoms to detection, impact, remediation, and validation.
- Read `references/security-and-safety.md` for prompt injection, excessive agency, data exfiltration, multi-tenant isolation, SSRF, and audit review.
- Read `references/context-and-tools.md` for prompt/context compaction, long-document handling, retrieval, token budgets, and tool-description quality.
- Read `references/testing-observability.md` when adding tests, approvals, traces, evals, replay, or production monitoring.
- Read `references/source-map.md` when source evidence, local repo paths, or upstream links are needed.
- If the host project uses a raw provider SDK or an unlisted language, rely on `references/agent-architecture.md` and map the same loop/state/tool/memory/approval concepts manually.
