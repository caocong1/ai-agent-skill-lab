---
name: design-agent-tools
description: Design and optimize AI agent tools, tool schemas, model-facing descriptions, context assembly, retrieval, long-document handling, compaction, memory pipelines, and token or cost behavior. Use when building or reviewing the agent-computer interface rather than the whole agent architecture.
metadata:
  version: 2.2.0
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

**Context assembly is append-only.** Freeze the system prompt and the tool set at
session start, and express every later change as an entry appended after the
history, never as an edit to it:

- a new standing instruction → an appended system-role entry at the point where
  it becomes true;
- a tool added or removed → declare the full set up front (deferred loading for
  tools that start hidden) and append the delta;
- a per-turn reminder → append it, and leave earlier copies in place;
- trimming → server-side context editing, or replacing the whole history with a
  summary, rather than splicing out the middle.

Independent harnesses converged on this — incremental tool catalogs, system
prompts logged as entries appended after the cached history, tool declarations
kept in the transcript, append-only context edits — and at least one model
provider now rejects replayed reasoning whose originating prefix was edited,
while another reports a significant drop when history is rebuilt without the
metadata on its output items. Replay provider output items verbatim. What was a
cost item is becoming a correctness contract. Append-only *storage*
is not enough: splicing summaries into the request or rewriting history at
request time breaks the prefix just the same, so list every request-time rewrite
with its cache effect. See `analysis/16-openai-codex-harness.md`,
`analysis/18-deepseek-harness.md`, `analysis/01-pi-source-analysis.md`,
`analysis/27-google-adk.md`, and `analysis/25-harness-shelf-life-research.md`.

Keep an explicit list of everything that enters the prefix: the tool set, the
skill catalog, environment snapshots, timestamps, retrieved boilerplate. For
each item, either **fix its order** — serve tool lists deterministically; a
registry backed by a hash map or concurrent registration reorders between runs
(an MCP `SHOULD`, with prompt-cache hit rate as the stated reason) — or **move it
after the prefix**: current time, working directory, live counters and per-turn
status belong behind the stable region.

State the cache effect alongside the token cost when documenting any capability
that adds to the prompt. "It only adds 200 tokens" is an incomplete answer if
those 200 tokens move every turn. See `analysis/20-mcp-2026-07-28-revision.md`.

## Document What the Model Sees

Give every capability that touches the prompt a written, three-part answer, and
keep it next to the code rather than in a design doc:

- **What the model sees** under each condition — enabled, disabled, degraded,
  error. Conditions matter: a capability that is invisible when idle and verbose
  when active has two different answers.
- **Token effect** — roughly what it adds, and whether that scales with the
  workspace, the conversation, or neither.
- **Prompt-cache effect** — whether it sits in the stable prefix, and whether
  its content or ordering can change between turns.

This is worth mechanizing. A format that is merely conventional drifts; a format
that a check enforces stays accurate. Pair it with a "known limitations and
deferred work" section, so what the capability does *not* do is written down
where a reader will actually find it.

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

Run layers in order of increasing information loss — recoverable steps first,
the one lossy step last:

1. **Persist large new results**: write oversized tool output out; keep a handle
   and a short preview.
2. **Structural snip**: archive the full history, then drop or fold low-value
   middle turns.
3. **Replace old results** — only when over budget, and only after persisting
   them. Every placeholder carries a recovery path the harness issued, never one
   the model or a tool supplied. No lossy placeholder without a recovery path.
4. **Fit an oversized unseen batch**: preview plus handle, so the model sees the
   new result before anything is summarized.
5. **LLM summary checkpoint**: only for what still overflows; update one summary
   rather than stacking many, and carry the active request explicitly.
6. **Reactive compaction** on a context-window error: once, then fail.

Three rules sit above the layering. **Constraints, approvals and pending user
instructions never pass through a lossy summary** — keep them in a separate
store and re-append them after compaction; measured compactors drop most of
them, and agents then act without the approval the user asked for. Know, per
source, what survives — re-injected from disk, rebuilt, summarized, or dropped —
and treat anything stated only in conversation as losable. **A summary
or handoff note is untrusted input** — a model has been observed writing
instructions to its future self into its own summary. **Never cut where an
obligation is open** — a tool call, its result and the reasoning around them
move together, and so does a pending confirmation or auth request.
Make compaction failure-safe: replace history only with a complete, non-empty
summary from a finished response, and keep the incoming input if compaction
fails. See `analysis/10-learn-claude-code.md`, `analysis/16-openai-codex-harness.md`,
and `analysis/26-durable-rules-production-evidence.md`.

Before compaction, run context construction as Gather -> Structure -> Score ->
Compress: gather candidates, structure typed records, score by relevance, and
drop/compress low-score records before the model call.

Good compaction preserves goal, constraints, decisions, open tasks, exact file
paths, commands, error messages, source anchors, and read/modified file lists.

Run tool-result pruning **before** choosing the range to compact, not after.
Pruning changes what is worth summarizing, so selecting the range first wastes
the summary budget on payloads that were about to be replaced by handles anyway.

Bracket the whole compaction operation with a lock that covers replacement as
well as summarization, and release it last. If the process dies mid-operation,
an orphaned lock is detectable and recoverable; a half-replaced history is not.
Express the result as an explicit surface operation — replace this index range
with this content — rather than mutating history in place, so the change is
auditable and reversible. With more than one writer, replace the lock with a
version check on the compaction write that rebases when new appends overtake
it; if the summarizer declines, the view stays unchanged.

Bound any structured handoff you produce. A handoff artifact with no size limit
becomes the next context problem; give it an explicit character or token cap and
truncate deliberately rather than letting it grow to whatever the summarizer
felt like writing.

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

## Skills and Context Files

Skills and context files (`AGENTS.md`, `CLAUDE.md` and the like) are harness
components with a measurable effect, and that effect is often smaller than
assumed. See `analysis/25-harness-shelf-life-research.md`.

- Curated, focused skills help; large bundles and self-generated skills often do
  not. Keep one skill to one procedure.
- Skills act mostly as procedural anchors, not as stores of missing facts.
  Selection precision falls as the catalog grows and every misfired load costs
  tokens, so prune it before adding to it.
- Loading on demand keeps part of a skill's effect, not all of it. A skill with
  clear inputs and outputs can run as a subagent instead of being loaded into
  context.
- Context files earn their tokens with instructions the agent would otherwise get
  wrong — commands, conventions, constraints — not with repository overviews.
- Re-measure on each model generation; vendors are trimming their own prompts and
  skills heavily for new models.

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

Choose the action surface per model and measure it. For models fluent in the
shell, a sandboxed shell has beaten a large typed catalog on both score and
tokens, and typed tools added on top gained nothing; a less shell-fluent model
can lose heavily without them. Give a shell only with real isolation — agents
handed one have read the grader's scripts and colleagues' files. Keep a fixed
typed catalog, or a program mode limited to it, where compliance needs an
enumerable surface. See `analysis/17-mini-swe-agent.md` and
`analysis/25-harness-shelf-life-research.md`.

Decide per error type whether its text reaches the model, and default to no: raw
exception text leaks to the provider, the transcript, memory and the user. Opt
specific errors in with a deliberate model-facing message; argument-parse
errors are usually worth returning. See `analysis/03-java-agent-patterns.md`.

For large inventories or MCP servers:

- namespace by service/resource;
- gate active tools by task, user, role, or phase;
- prefer targeted search/filter over list/read-all;
- expose `concise` vs `detailed` response modes when useful;
- include pagination, range selection, truncation notices, and next-step hints.

When one task routinely chains many tools whose intermediate results are large
and uninteresting, consider letting the model write a short program that calls
the tools instead — the round trips collapse to one and the intermediates stay
in the runtime rather than the context. Declare per tool **who may call it** —
the model directly, a model-written program, or both — and enforce it in the
runtime; several frameworks converged on this per-tool caller list. Making the
two paths mutually exclusive is its coarsest form; one harness dropped its mixed
mode because it duplicated the interface. Any "isolation" label on the program
runtime is a diagnostic descriptor, not a security boundary: run program code in
OS-confined processes, do not replay it automatically after a crash, and route
every side effect it can reach through the same approval as a direct call. Keep
approval-gated tools direct-only unless the program can pause for approval, and
enforce caller lists at execution — some providers document them as hints, not
hard blocks. See
`analysis/01-pi-source-analysis.md`, `analysis/02-agent-framework-patterns.md`,
and `analysis/18-deepseek-harness.md`.

A default tool whose own description tells the model not to use it is a smell:
move it to an opt-in tier instead of discouraging it in prose.

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
provider supports it, a tool can ask for strict schema-constrained sampling
rather than validating afterwards. Distinguish *prefer* from *require*: prefer
falls back to normal tool calling — and should downgrade automatically when a
provider rejects the schema — while require fails up front on an unsupported
model instead of producing invalid output and reporting it late.

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
