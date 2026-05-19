---
name: build-ai-agents
description: Design, implement, review, and test AI agent features across TypeScript, Java, MCP, and general LLM application stacks. Use for tool-calling agents, agent loops, workflows, subagents, memory, approvals, MCP tools, prompt/context assembly, long-document handling, context compaction, retrieval, or agent skill integration.
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
4. Implement the smallest architecture that satisfies the goal. Do not introduce graph runtimes, MCP, vector memory, or subagents unless the requirement needs them.
5. Add focused tests for tool handlers, orchestration logic, failure paths, permissions, and resume/approval behavior when applicable.
6. Verify with the project's normal test/build commands and record any unverified risk.

## Review Workflow

1. Locate the agent constructs in the host project: model adapter, tool registry, orchestration loop/graph, prompt/context assembly, state and memory, approval/permission boundary, stop conditions and budgets, events/traces, and tests.
2. Assess each construct against the Dual-Use Rubric below. Record evidence as `file:line`.
3. Classify findings by severity (`critical`, `high`, `medium`, `low`), impact (`correctness`, `safety`, `cost`, `reliability`, `maintainability`), effort (`S`, `M`, `L`), and regression risk.
4. Produce a Review Report and Prioritized Remediation Plan with concrete, executable changes.
5. Validate per Definition of Done before finishing.

## Architecture Rules

- Use plain deterministic code when no model judgment is required.
- Use a single model call when the task is pure generation, classification, extraction, or summarization without external actions.
- Use a structured workflow when steps are known in advance: chain, router, parallel workers, evaluator-optimizer, or orchestrator-worker.
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

## Deliverables

- `build` / `extend`: working code, focused tests, verification commands, and any unverified risks.
- `review`: a Review Report table with `[id | construct | severity | impact | evidence file:line | recommended change | effort | regression risk]`, plus a Remediation Plan ordered into `safe now`, `needs eval snapshot`, and `needs design change`.

## Definition of Done

- `build`: every Dual-Use Rubric item is satisfied or its risk is explicitly recorded; project tests/builds requested for the change have been run or the blocker is stated.
- `review`: every finding has `file:line`, concrete change, severity, effort, and validation; prompt/tool changes include a before/after eval or regression snapshot requirement; non-goals and residual risks are listed.

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
