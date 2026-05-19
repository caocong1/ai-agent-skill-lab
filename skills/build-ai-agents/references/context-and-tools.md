# Context and Tool Quality

Use this reference when optimizing prompts, context assembly, tool descriptions, or token/cost behavior.

## Prompt Structure

Keep prompts layered:

- stable role/instructions
- task-specific goal
- tool-use policy
- safety/approval policy
- compact relevant context with sources
- output contract

Avoid mixing transient UI state, raw private records, secrets, or full logs into the system prompt.

## Context Management

Prefer deliberate context assembly over unbounded message growth.

Patterns:

- trim old tool chatter that is no longer needed
- summarize completed phases with source ids
- retrieve only relevant documents
- keep large tool outputs outside the prompt and refer to handles/resources
- preserve the last few tool calls when they are needed for correctness
- store durable state outside model messages

Review signs of context trouble:

- system prompt grows with every feature
- model receives the same long policy or document repeatedly
- tool outputs are pasted in full without filtering
- no compaction threshold
- retrieval has no source labels or tenant filter

## Tool Description Rubric

Good tool descriptions tell the model:

- what the tool does
- when to use it
- when not to use it
- what each parameter means
- what assumptions or permissions apply
- what the output represents

Weak descriptions:

- restate an internal method name
- use human-only API jargon
- omit units, ids, formats, or constraints
- hide side effects
- overlap heavily with another tool

## Tool Schema Rubric

- Use enums for closed choices.
- Use strict objects where the framework supports them.
- Add min/max and format constraints when meaningful.
- Avoid catch-all string blobs for structured actions.
- Keep dangerous actions narrow.
- Return structured output for downstream decisions.

## Optimization Moves

- Rewrite broad tools into small composable tools.
- Merge overlapping tools when the model cannot distinguish them.
- Add examples only for tools the model misuses.
- Move sensitive context from prompt to typed tool context.
- Add `activeTools` or equivalent gating by step/user/task.
- Add token/cost budgets and trace token usage per step.

