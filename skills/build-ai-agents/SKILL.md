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
| Judge whether a harness component still deserves to exist after a model upgrade | `../design-ai-agent/SKILL.md` and `../optimize-agent-skills/SKILL.md` |

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
- Answer two questions per capability, not one: **what the model sees** (with
  its token and prompt-cache cost) and **who has authority** to make it happen.
  Visibility is not authority.
- A turn ending is not a goal being met. For any task whose goal is a verifiable
  end state, put the completion decision outside the agent doing the work.
- Authorization is never inherited from serialized state. State can be restored;
  approvals and credentials must be re-obtained on resume, fork, or replay.
- Side effects need all three of: knowing whether they happened, not repeating
  them on retry, and being able to undo them. Retry and approval cover two.
- Keep the prompt prefix stable. A tool list whose order changes between runs
  quietly discards the prompt cache.
- Every component compensating for a model limitation is a dated assumption.
  Record why it exists, and re-run the ablation on each model generation.
  Components governing authority, evidence, side effects, and cost are not on
  that list.
- Publish a non-goals list beside the capability list, with equal prominence.

## Contract Stability

This suite's contract is its **modes**, its **deliverables**, and its
**reference paths**. Changes to that contract follow semantic versioning:
MAJOR removes or renames one of them, MINOR adds guidance or a newly analyzed
source, PATCH refreshes wording or a snapshot.

SemVer alone only answers "does this release break?". Consumers also need to
know where the *next* one will break, so removals go through three states:

- **active** — supported, no scheduled change;
- **deprecated** — still functional, listed in `CHANGELOG.md` under a
  `弃用登记` heading with its replacement and its earliest removal release, and
  kept for at least two MINOR releases;
- **removed** — only in a MAJOR release, and only after a deprecation period.

Nothing in the contract is removed without first appearing as deprecated. See
`analysis/20-mcp-2026-07-28-revision.md` for where this policy comes from and
`analysis/21-lab-design-rethink-2026-08.md` for why this suite adopted it.

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
