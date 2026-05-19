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

## Long Document Handling

Do not paste a full long document into the model context by default. Treat long documents as external evidence that must be selected, sliced, summarized, and cited.

Preferred pipeline:

1. Classify the task as full-document synthesis, targeted Q&A, extraction, comparison, or review.
2. Build an inventory first: file path, type, size, headings or sections, and available metadata.
3. Read a bounded slice before reading more. Use offsets, line ranges, page ranges, section ids, or search results when available.
4. Retrieve or select only the chunks relevant to the task.
5. Preserve source anchors in every intermediate note: file path plus line, page, section, chunk id, or document id.
6. Summarize at the smallest useful unit, then synthesize across summaries.
7. Keep raw large excerpts outside the prompt; pass handles, ids, or short quoted snippets instead.
8. Re-open original sources for claims that need exact wording, numbers, names, dates, or legal/financial/medical precision.

Use these shapes:

- Targeted answer: search/index -> read top chunks -> answer with source anchors.
- Whole-document summary: outline -> summarize sections -> synthesize executive summary and caveats.
- Multi-document comparison: normalize per-document summaries -> compare dimensions -> cite the source for each difference.
- Long code or log analysis: search for errors/symbols first -> read surrounding windows -> expand only when the local context is insufficient.
- Extraction: define a schema -> extract per chunk -> merge/dedupe -> validate against source anchors.

For read tools, prefer contracts that support:

- `path` plus optional `offset`/`limit`, line range, page range, section id, or chunk id
- explicit truncation notices with next offsets
- stable chunk identifiers
- total line/page counts when known
- structured metadata for document type, headings, and source location

## Compaction Strategy

Use compaction for accumulated conversation or tool history, not as a replacement for source retrieval.

Apply these rules:

- Compact before the next model call when context approaches the model window or cost budget.
- Keep a recent working window intact; summarize older turns into a structured checkpoint.
- Preserve user goals, constraints, decisions, open tasks, exact file paths, commands, error messages, and source anchors.
- Track files or documents read and modified as compaction metadata.
- On repeated compaction, update the previous summary instead of stacking many summaries.
- If a single turn is too large, summarize the early prefix and keep the recent suffix.
- Never compact away pending approvals, unresolved tool calls, or facts needed to validate side effects.

Good compaction output has:

- goal and constraints
- completed and in-progress work
- decisions and rationale
- next steps
- critical source anchors
- read/modified file lists when applicable

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
