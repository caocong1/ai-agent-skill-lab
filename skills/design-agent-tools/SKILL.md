---
name: design-agent-tools
description: Design and optimize AI agent tools, tool schemas, model-facing descriptions, context assembly, retrieval, long-document handling, compaction, memory pipelines, and token or cost behavior. Use when building or reviewing the agent-computer interface rather than the whole agent architecture.
metadata:
  version: 2.0.0
  short-description: Design tools, context, retrieval, memory
---

# Design Agent Tools

Use this skill when the hard part is what the model sees, which tools it can
call, and what comes back into the next step.

## Prompt Structure

Keep prompts layered:

- stable role/instructions
- task-specific goal
- tool-use policy
- safety/approval policy
- compact relevant context with sources
- output contract

Avoid mixing transient UI state, raw private records, secrets, or full logs into
the system prompt.

## Context Management

Prefer deliberate context assembly over unbounded message growth:

- trim old tool chatter that is no longer needed;
- summarize completed phases with source ids;
- retrieve only relevant documents;
- keep large tool outputs outside the prompt and refer to handles/resources;
- preserve recent tool calls needed for correctness;
- store durable state outside model messages.

Trouble signs: system prompt grows with every feature, repeated long policy
blocks, full tool outputs pasted into context, no compaction threshold, retrieval
without source labels or tenant filters.

## Long Documents and Retrieval

Do not paste full long documents into context by default. Select, slice,
summarize, and cite.

Preferred pipeline:

1. Classify the task: full-document synthesis, targeted Q&A, extraction,
   comparison, review, or code/log analysis.
2. Build an inventory: path, type, size, headings, and metadata.
3. Read bounded slices first: line ranges, page ranges, section ids, chunk ids,
   or search results.
4. Retrieve/select only relevant chunks.
5. Preserve source anchors in every note.
6. Summarize at the smallest useful unit, then synthesize.
7. Keep large raw excerpts outside the prompt and pass handles or short quotes.
8. Re-open sources for exact wording, numbers, names, dates, or high-stakes
   precision.

Choose retrieval by corpus size first and query type second:

- Small corpus, roughly under 200K tokens or one project with tens of files:
  prefer agentic `search`/`read` tools or full context. Do not build a RAG index
  by reflex.
- Larger corpus, semantic queries, cross-document questions, high-frequency
  low-latency needs, or tenant isolation: use hybrid keyword/BM25 + vector with
  reranking. Start with the database already in the stack, such as pgvector,
  before a dedicated vector DB.
- Static corpus that fits a long window and is mostly relevant: long-context
  with prompt caching may beat retrieval.

Design against silent retrieval failure:

- Exact strings, IDs, SKUs, model numbers, clause numbers, and negations need
  literal keyword/BM25/grep channels.
- Natural-language questions over keyword indexes need query expansion into
  likely document wording.
- Record which spans were read and which claims they support.

## Compaction Strategy

Use compaction for accumulated conversation or tool history, not as a substitute
for retrieval.

Run layers cheap-first:

1. Structural snip: drop or fold low-value middle turns.
2. Tool-result micro-replace: replace old payloads with placeholders.
3. Tool-result handles: persist large outputs and pass ids/handles.
4. LLM summary checkpoint: update one existing summary, do not stack many.
5. Reactive compaction: on context-window errors, rerun layers 1-3 more
   aggressively, summarize if needed, and retry once.

Before compaction, run context construction as Gather -> Structure -> Score ->
Compress: gather candidates, structure typed records, score by relevance, and
drop/compress low-score records before the model call.

Good compaction preserves goal, constraints, decisions, open tasks, exact file
paths, commands, error messages, source anchors, and read/modified file lists.

## Memory Pipeline

Memory is a flow, not a container:

1. **Selection**: decide which turns/results/decisions are worth remembering.
2. **Extraction**: turn raw content into typed facts with provenance.
3. **Consolidation**: dedupe, supersede stale facts, timestamp, attach sources,
   and surface contradictions.

Every stage needs tenant/user isolation, provenance, forgetting policy, and audit
logs. Use the pipeline whether memory is a file, table, vector index, or provider
tool.

Also decide the tier: working, short-term, long-term, or permanent. The pipeline
answers how facts get written; the tier answers where they live and for how long.

## Tool Design

Treat tools as agent-facing product surfaces, not one-to-one wrappers around
backend endpoints. A small set of high-value tools that match real tasks usually
beats a large set of CRUD wrappers.

Good descriptions tell the model:

- what the tool does;
- when to use it;
- when not to use it;
- what each parameter means;
- assumptions and permissions;
- what the output represents.

Before adding a tool, check:

- Does it map to a natural work unit?
- Does it consolidate deterministic substeps the model would otherwise do in
  context?
- Is it distinct by name, purpose, parameters, and side effects?
- Does it return high-signal context for the next step?
- Can failed calls return model-correctable errors with examples?

For large inventories or MCP servers:

- namespace by service/resource;
- gate active tools by task, user, role, or phase;
- prefer targeted search/filter over list/read-all;
- expose `concise` vs `detailed` response modes when useful;
- include pagination, range selection, truncation notices, and next-step hints.

## Tool Schema Rubric

- Use enums for closed choices.
- Use strict objects where supported.
- Add min/max and format constraints when meaningful.
- Avoid catch-all string blobs for structured actions.
- Keep dangerous actions narrow.
- Return structured output for downstream decisions.

Evaluate tool changes with realistic tasks. Track accuracy, tool count,
invalid-parameter errors, token usage, runtime, repeated calls, and transcript
confusion.
