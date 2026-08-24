---
name: optimize-agent-skills
description: Improve agent skills, prompts, instructions, or operating guides using SkillOpt-inspired evidence loops. Use for trajectory-driven skill iteration, rollout and eval design, validation-gated edits, bounded add/delete/replace patches, train/validation/test splits, strong optimizer vs frozen target separation, slow or meta updates, staged adoption, and no-inference-overhead deployment artifacts.
metadata:
  version: 2.1.0
  short-description: Improve skills with validation gates
---

# Optimize Agent Skills

Use this when the artifact being improved is natural-language operating
knowledge: a skill, prompt, instruction file, agent playbook, or tool-use guide.
Treat SkillOpt as design guidance, not as a mandatory runtime dependency.

## Mental Model

The skill document is trainable external state for a frozen agent. Improve the
procedure, not the model weights. Deployment should usually consume one compact
artifact and add zero inference-time optimizer calls.

Use a strong optimizer/reviewer model when possible and keep the target/runtime
fixed while measuring candidate skills. A weaker target can execute tasks; a
stronger optimizer should propose edits.

## Shelf Life

Before optimizing a skill's wording, ask whether the rule should still exist at
all. Every instruction that compensates for something the model cannot do
encodes a dated assumption, and those assumptions expire as models improve.

Split the document's rules into two lists and treat them differently:

- **Perishable** — compensates for a model weakness. Record it as "we added this
  because the model at version M could not do Y." On a model upgrade, this list
  is the deletion candidate list: try removing each rule and re-run the eval.
  Removing an obsolete rule is a real improvement, not a regression — it costs
  tokens and constrains a model that no longer needs constraining.
- **Durable** — governs authority, evidence, side effects, or cost. Do not
  ablate these on a model schedule; their value rises as the model gets more
  capable.

Add "a new model generation shipped" to the triggers that start an optimization
cycle, alongside "the eval regressed" and "a failure mode recurs". See
`analysis/19-anthropic-harness-design-long-running-apps.md` and
`analysis/21-lab-design-rethink-2026-08.md`.

## Evidence Loop

Run an explicit loop:

1. **Rollout**: execute real or representative tasks using the current skill.
   Capture messages, tool calls, verifier feedback, task metadata, scores,
   tokens, latency, and failure reasons.
2. **Reflect**: analyze success and failure trajectories. Extract reusable
   operating rules, not task-specific answers.
3. **Aggregate**: merge similar proposed edits and remove duplicates.
4. **Select**: rank edits under a textual learning-rate budget. Prefer a few
   high-confidence edits over a broad rewrite.
5. **Update**: apply bounded add/delete/replace edits to the skill.
6. **Gate**: evaluate the candidate on held-out validation tasks. Accept only
   if it improves the chosen metric, unless the user explicitly opts into greedy
   staging.

Keep rejected edits as negative feedback so the optimizer does not repeat
harmful directions.

## Data Splits

Use three disjoint sets when possible:

- `train`: tasks that drive reflection; can include dream-augmented variants.
- `validation`: real tasks that gate candidate edits.
- `test`: real tasks held back for final reporting.

Never let dream/synthetic tasks into validation or test. If data is scarce,
still separate "used for reflection" from "used for acceptance".

## Scoring

Pick metrics before editing:

- hard score: exact pass/fail or rubric pass;
- soft score: partial credit, F1, quality rubric, or LLM judge with calibration;
- cost: tokens, latency, tool count, repeated calls;
- safety: policy violations, approval bypasses, private-data exposure.

Use multi-objective scoring only when weights are explicit. Otherwise optimize
quality first and report cost/safety as guardrails.

## Edit Rules

Good edits:

- target recurring failure modes;
- preserve behaviors that already pass;
- are concise enough to deploy;
- state when a rule applies and when it does not;
- include examples only when transcripts show confusion.

Bad edits:

- rewrite the whole skill without evidence;
- encode one task's answer as a general rule;
- add broad caveats that weaken precise rules;
- duplicate existing guidance;
- remove validation, approval, or safety constraints to gain score.

Protect long-term memory fields or appendices from step-level edits if the
artifact has them. Slow/meta updates should summarize longitudinal lessons
across runs, not mutate every detail.

## Adoption Workflow

1. Save baseline skill and baseline validation score.
2. Apply candidate edits in a staged proposal, not directly to production.
3. Show accepted/rejected edit log and before/after scores.
4. Run held-out test once on the selected best candidate.
5. Adopt only after review; keep backup and rollback path.

For local coding agents, an offline "sleep" cycle can harvest sessions, mine
recurring tasks, replay them under budget, consolidate lessons, gate on held-out
real tasks, and stage a proposal. Do not let such a cycle silently edit live
skills without user review.

An evaluator or grader is itself a skill under optimization, and the same loop
applies to it. Its evidence is different, though: read its logs, collect the
cases where its judgment diverged from a human's, and update its prompt to
resolve those specific cases. The divergences are its training set. Without this,
a grader drifts across a long pipeline and its scores stop being comparable to
each other.

## Deliverables

- Baseline artifact and baseline score.
- Task split description.
- Rollout/eval transcript summary with failure modes.
- Accepted and rejected edits.
- Candidate skill/prompt.
- Validation and final test score.
- Adoption or rollback note.
