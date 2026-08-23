---
name: build-ai-agents
description: Router and backward-compatible entrypoint for designing, implementing, reviewing, securing, testing, and optimizing AI agent features. Use for agent loops, ReAct/tool-use agents, workflows, subagents, memory, approvals, MCP, tool schemas, context engineering, retrieval, TypeScript or Java agent implementation, safety review, evals, observability, and agent skill optimization.
metadata:
  version: 2.2.0
  short-description: Route AI agent work to focused skills
---

# Build AI Agents

Use this skill as the suite entrypoint. It keeps the old `build-ai-agents`
name working, then routes the task to the smallest focused skill set.

## Route First

Read only the child skill(s) needed for the current task:

| Need | Read |
| --- | --- |
| Decide if an agent is needed; choose deterministic code, single call, workflow, ReAct/tool loop, graph, subagents, memory, approval, or state shape | `../design-ai-agent/SKILL.md` |
| Design tool schemas, tool descriptions, active tool gating, prompt/context assembly, long-document handling, retrieval, compaction, or memory pipeline | `../design-agent-tools/SKILL.md` |
| Build or consume MCP servers/clients, resources, prompts, transports, A2A/ANP-adjacent protocol choices | `../build-mcp-capabilities/SKILL.md` |
| Implement in TypeScript, Node, Next.js, OpenAI Agents JS, Vercel AI SDK, LangGraphJS, or Pi-inspired runtimes | `../implement-ts-agents/SKILL.md` |
| Implement in Java, Spring AI, LangChain4j, service-layer agents, annotations, or DI-heavy projects | `../implement-java-agents/SKILL.md` |
| Audit existing agent code and produce a Chinese findings table plus remediation plan | `../review-ai-agents/SKILL.md` |
| Threat-model or harden prompt injection, excessive agency, tenant isolation, SSRF, approvals, audit, or redaction | `../secure-ai-agents/SKILL.md` |
| Add tests, fake model harnesses, evals, replay, traces, production guardrails, or monitoring | `../test-ai-agents/SKILL.md` |
| Improve a skill/prompt/instruction artifact from trajectories with validation-gated edits inspired by SkillOpt | `../optimize-agent-skills/SKILL.md` |
| Need source evidence, upstream links, local repo paths, or commit pins | `references/source-map.md` |

For substantial build work, usually read `design-ai-agent` first, then one
implementation skill and one supporting skill (`design-agent-tools`,
`secure-ai-agents`, or `test-ai-agents`) as the project requires.

## Modes

- `build`: create a new agent feature.
- `extend`: add capability to an existing agent.
- `review`: audit an existing agent for correctness, safety, cost, reliability,
  and maintainability, then produce a prioritized remediation plan.
- `optimize-skill`: improve agent skills/prompts/instructions from evidence.

## Baseline Workflow

1. Inspect the host project first. Match its language, framework, dependency
   injection, test style, logging, persistence, and security patterns.
2. Qualify whether the request needs an agent. Prefer deterministic code or a
   simpler LLM workflow unless the task has complex judgment, brittle rules,
   heavy unstructured data, or a path that cannot be hard-coded.
3. Route to child skills and read only what is needed.
4. Define the contract: user-visible goal, model instructions, tool list,
   schemas, state, memory, budgets, stop conditions, approval rules, human
   intervention triggers, and events/traces.
5. Establish a small realistic eval or golden task baseline before expanding
   tools, splitting agents, optimizing cost, or changing prompts.
6. Implement the smallest architecture that satisfies the goal.
7. Add focused tests for tool handlers, orchestration logic, failure paths,
   permissions, approvals, resume behavior, and eval snapshots as applicable.
8. Verify with the project's normal commands and record unverified risk.

## Core Rules

- Separate agent from harness. Agency comes from the trained model; engineering
  shapes tools, knowledge, context management, observations, permissions, and
  evaluation around it.
- Escalate complexity only when requirements force it:
  deterministic code < single model call < structured workflow < tool loop <
  durable graph/workflow < multi-agent.
- Put permission checks at the tool execution boundary. Prompt policy explains;
  code policy enforces.
- Treat tool schemas, descriptions, outputs, and errors as an agent-facing API.
- Keep domain state, runtime state, memory, model messages, UI messages, and
  traces separate.
- Every loop needs stop conditions, cost/step/time budgets, error
  classification, and observable stop reasons.
- Use MCP for reusable external capabilities, not as a substitute for the host
  application's agent runtime.
- Exhaust inference-time levers (instructions, tools, context, retrieval,
  memory, evals) before considering model fine-tuning.

## Deliverables

- `build` / `extend`: working code, focused tests, verification commands, and
  explicit residual risks.
- `review`: Chinese `审查报告` table with file/line evidence and a prioritized
  `处理计划`.
- `optimize-skill`: baseline evidence, accepted/rejected edit log, updated skill
  or prompt artifact, held-out validation result, and adoption notes.

## Definition of Done

- Relevant child skills were read and applied.
- Every tool, context, permission, loop, state, test, and eval risk is satisfied
  or explicitly recorded.
- Prompt/tool/skill changes include before/after behavior evidence when they can
  change agent behavior.
- Project tests/builds requested for the change were run, or the blocker is
  stated.
