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

Layer compaction cheap-first, expensive-last — do not jump straight to a model summary (see `analysis/10-learn-claude-code.md`):

1. **Structural snip** — when message count exceeds a threshold, drop or fold a contiguous middle window of low-value turns first. No tokens spent.
2. **Tool-result micro-replace** — replace older `tool_result` payloads with short placeholders that keep the call/argument shape but lose the body. Cheap and reversible if you keep the bodies on disk.
3. **Tool-result budget with handles** — when a single tool returns a large object, persist it (file, blob store, retrieval index) and put a handle/id back in the conversation. Subsequent steps fetch by id instead of re-pasting the body.
4. **LLM summary checkpoint** — once cheaper layers cannot free enough room, do one model summary that updates the existing checkpoint (do not stack many summaries). Only this step costs a call.
5. **Reactive compaction** — if the provider still returns `prompt_too_long`, run one emergency pass (re-run layers 1–3 more aggressively, summarize again if needed) and retry the same turn once.

Drive the layers in this order on every assembly; only escalate when the previous layer leaves the context above budget.

The cheap-first layers cover "the context is already over budget — how to shrink it." They compose with an upstream phase: "the context is being assembled — what should be allowed in." Treat that upstream phase as a context-construction pipeline, e.g., the four-step GSSC pattern (Gathering → Structuring → Scoring → Compression) from `analysis/11-hello-agents.md` chapter 9: gather candidate context from multiple sources, structure it into typed records, score each record by relevance to the current step, and compress (or drop) low-score records before the model call. GSSC pre-shrinks context so cheap-first compaction triggers less often; the two are sequential, not alternatives. If both fire in the same turn, GSSC should already have removed irrelevant material and cheap-first should only be touching genuinely-needed material that no longer fits.

Good compaction output has:

- goal and constraints
- completed and in-progress work
- decisions and rationale
- next steps
- critical source anchors
- read/modified file lists when applicable

## Memory Pipeline

Memory is a flow, not a container. When you decide an agent needs cross-turn or cross-session memory, design three explicit stages — missing any of them produces either noisy or amnesic memory (see `analysis/10-learn-claude-code.md`):

1. **Selection** — decide which turns, tool results, or decisions are worth remembering at all. Most history should be forgotten. Cheap signals: explicit user instruction, irreversible side effect, decision with rationale, error and its resolution, identity/preference statements. Persist a per-turn "remember? yes/no" classification rather than dumping all history.
2. **Extraction** — turn selected raw content into typed facts with provenance: `{ kind, subject, value, source_turn_id, source_anchor, written_at }`. Extraction lets later writes dedupe and merge correctly. Without it, memory becomes a free-text scrapbook the model cannot reason over.
3. **Consolidation** — merge new facts into the existing memory store: deduplicate, supersede stale entries, attach timestamps and sources, and surface contradictions for resolution. Consolidation is the only stage allowed to mutate the long-term store.

Cross-cutting requirements for any of the three stages:

- Tenant/user isolation: every record carries an owner key; readers filter by it.
- Provenance: every fact links back to a source turn, tool result, or document id so it can be re-verified.
- Forgetting policy: explicit TTL, supersede rules, or user-driven deletion. Memory without forgetting is a liability, not a feature.
- Audit: writes go through one path that logs `who/what/why/when`.

Use this pipeline whether the underlying store is a file (`MEMORY.md`), a structured table, a vector index, or a provider memory tool.

The selection/extraction/consolidation pipeline answers *how memory is written and read*. A parallel question is *which tier holds it*: working / short-term / long-term / permanent (see `analysis/11-hello-agents.md` chapter 8, mirroring cognitive-science conventions). Working memory is the current loop's scratch; short-term holds the active session; long-term is durable across sessions for one tenant/user; permanent holds tenant-wide facts (e.g., catalogs, policies). When you size and TTL the store, decide which tier each fact lives in — the three pipeline stages run inside each tier with different selectivity and forgetting rules. Treat the two views as complementary: pipeline answers "how does a fact get there", tier answers "where does it live and how long".

## Tool Description Rubric

Treat tools as agent-facing product surfaces, not one-to-one wrappers around backend endpoints. A small set of high-value tools that match real user tasks is usually easier for the model to select, evaluate, and recover from than a large set of low-level CRUD tools (see `analysis/08-anthropic-writing-effective-tools.md`).

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

Treat the agent-computer interface (ACI) like a public API: invest in tool names, descriptions, schemas, examples, and error messages with the same rigor as developer-facing API docs, and exercise tool specs against realistic cases before shipping. Tool ergonomics often move agent success more than prompt wording (see `analysis/06-anthropic-building-effective-agents.md`).

## Agent-Facing Tool Design

Use these checks before adding a tool:

- Does this tool map to a natural work unit for the agent, or is it just an internal endpoint exposed verbatim?
- Can the tool consolidate deterministic substeps that the model would otherwise perform wastefully in context?
- Is it distinct from existing tools by name, purpose, parameters, and side effects?
- Does it return high-signal context for the next model step rather than raw internal records?
- Can a failed call return a model-correctable error with examples or narrowing instructions?

For large tool inventories or MCP servers:

- namespace tools by service/resource when names overlap;
- gate active tools by task, user, role, or workflow phase;
- prefer targeted search/filter tools over broad list/read-all tools;
- expose response verbosity such as `concise` vs `detailed` when downstream IDs are sometimes needed;
- include pagination, filtering, range selection, and truncation notices with next-step hints.

Evaluate tool changes with realistic tasks. Track accuracy, tool count, invalid-parameter errors, token usage, runtime, and repeated calls. Read transcripts in addition to metrics: the model may not explicitly explain why a tool description, response shape, or namespace confused it.

## Tool Schema Rubric

- Use enums for closed choices.
- Use strict objects where the framework supports them.
- Add min/max and format constraints when meaningful.
- Avoid catch-all string blobs for structured actions.
- Keep dangerous actions narrow.
- Return structured output for downstream decisions.

## Optimization Moves

- Rewrite broad tools into targeted tools when the model wastes context filtering raw output.
- Merge overlapping tools when the model cannot distinguish them, as long as permission and audit boundaries remain clear.
- Add examples only for tools the model misuses.
- Move sensitive context from prompt to typed tool context.
- Add `activeTools` or equivalent gating by step/user/task.
- Add token/cost budgets and trace token usage per step.
