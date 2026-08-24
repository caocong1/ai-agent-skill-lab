---
name: design-agent-tools
description: Design and optimize AI agent tools, tool schemas, model-facing descriptions, context assembly, retrieval, long-document handling, compaction, memory pipelines, and token or cost behavior. Use when building or reviewing the agent-computer interface rather than the whole agent architecture.
metadata:
  version: 2.1.0
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

## Prompt Prefix Economics

Whatever sits at the front of the prompt is a cache prefix. Change it and every
token after it loses its cached state, so prefix instability has a direct
latency and cost price — it is a budget item, not a style preference.

Keep an explicit list of everything that enters the prefix: the tool set, the
skill catalog, environment snapshots, timestamps, retrieved boilerplate. For
each item, decide one of two things:

- **Fix its order.** Serve tool lists in a deterministic order. A tool registry
  backed by a hash map or by concurrent registration will reorder between runs
  and quietly halve the cache hit rate. This is now a protocol-level `SHOULD`
  in MCP, with prompt-cache hit rate given as the reason.
- **Move it after the prefix.** Anything that legitimately changes every turn
  (current time, live counters, per-turn status) belongs behind the stable
  region, not inside it.

State the cache effect alongside the token cost when documenting any capability
that adds to the prompt. "It only adds 200 tokens" is an incomplete answer if
those 200 tokens move every turn. See `analysis/20-mcp-2026-07-28-revision.md`
and `analysis/18-deepseek-harness.md`.

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

When one task routinely chains many tools whose intermediate results are large
and uninteresting, consider letting the model write a short program that calls
the tools instead — the round trips collapse to one and the intermediates stay
in the runtime rather than the context. Two constraints make this safe: it is
**mutually exclusive** with native tool calling in the same turn (reject direct
calls while in program mode, or the model oscillates between the two paths), and
any "isolation" label on the runtime is a diagnostic descriptor, not a security
boundary. See `analysis/02-agent-framework-patterns.md` and
`analysis/18-deepseek-harness.md`.

### State, Retries, and Large Results

**Cross-call state travels as an explicit handle.** When a tool needs continuity
between calls, mint a handle server-side and pass it as an ordinary parameter.
Do not rely on a transport session, a connection, or process memory to remember
anything for you. Design the handle's lifetime, authorization, and reclamation
at the same time — that complexity does not disappear when you make it implicit,
it just becomes invisible.

**Ask for missing input by returning a gap, not by blocking.** When a tool needs
something it does not have, return a structured description of what is missing
and let the caller retry with the answer supplied. That is far easier to route,
replay, and test than calling back into the caller mid-execution.

**Retry-safe means side effects come last.** Once a caller may legitimately
retry the same logical operation, a tool that writes before it asks will write
twice. Gather everything you need first, then act — or deduplicate on a
server-minted key.

**Spill large results instead of inlining them.** Above a threshold, write the
payload out and return a locator plus a short retrieval hint. Two rules keep
this honest: the locator is opaque to the model (never a raw path it can
manipulate), and spilling is best-effort — a failed spill returns the inline
result, and must never turn a successful call into an error.

**Constrain generation with the schema, not just validation.** Where the
provider supports it, a tool can require strict schema-constrained sampling
rather than validating afterwards. Gate it on model capability metadata so an
unsupported combination fails up front instead of producing invalid output and
reporting it late.

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
