# Anthropic, Writing Effective Tools for Agents - structured digest

- Source URL: https://www.anthropic.com/engineering/writing-tools-for-agents
- Publish date: 2025-09-11
- Fetch date: 2026-05-20
- Fetch method: Cursor `WebFetch`
- Copyright note: This file is a paraphrased factual digest for analysis, not a verbatim copy of the original article.

## Scope

Anthropic argues that tools for agents are not ordinary developer APIs. They are contracts between deterministic software and non-deterministic model behavior, so their names, descriptions, schemas, outputs, errors, and evaluation cases should be optimized for how agents perceive and use them.

## Main claims

- Tool quality materially limits agent quality. A powerful model can still fail when tools are too broad, too low-level, overlapping, or verbose.
- Tool development should be iterative and evaluation-driven: prototype, run realistic tasks, inspect transcripts and metrics, then refine the tool surface.
- Realistic evaluations should use tasks that resemble production workflows and may require many tool calls, not toy prompts that only test a happy path.
- Tool transcripts reveal design problems: repeated calls suggest missing aggregation or pagination; invalid parameters suggest unclear schemas or examples; high token use suggests response shaping problems.
- Agents can help improve their own tool interface when given eval transcripts, but held-out tests are still needed to avoid overfitting.

## Tool design principles

### Choose the right tools

The article recommends fewer, higher-leverage tools rather than one wrapper per backend endpoint. Agent-facing tools should map to natural work units. For example, a search or scheduling tool can encapsulate several backend calls if that removes irrelevant context and reduces the agent's planning burden.

### Namespace and distinguish tools

When an agent has many tools across MCP servers or services, overlapping names and vague purposes increase selection errors. Grouping related tools with consistent prefixes or resource-oriented names helps agents choose the intended capability. The exact naming convention should be validated with evaluations.

### Return meaningful context

Tool responses should prioritize information that helps the next model step. Human-readable identifiers, names, summaries, and relevant metadata are usually more useful than raw technical IDs. When downstream calls require IDs, expose verbosity controls such as concise vs detailed output.

### Control token cost

Large responses need pagination, filtering, range selection, truncation, and sensible defaults. Truncation should tell the agent how to ask for a narrower result. Validation errors should be actionable and model-correctable rather than opaque stack traces.

### Prompt-engineer tool descriptions

Tool descriptions and parameter specs are part of the model context. They should explain purpose, when to use the tool, when not to use it, expected inputs and outputs, side effects, constraints, examples when useful, and domain terms that a new teammate would need.

## Evaluation loop

The article's practical loop is:

1. Stand up a prototype tool or MCP server.
2. Build an evaluation set from realistic user workflows and data.
3. Run simple tool-use loops programmatically and collect accuracy, tool count, token use, runtime, and errors.
4. Inspect transcripts and model feedback to find rough edges.
5. Refine tool names, schemas, responses, descriptions, pagination, and implementation boundaries.
6. Re-run evaluations and compare against held-out tasks.

## Relevance to this lab

This source deepens the lab's existing ACI guidance from Anthropic's earlier "Building Effective Agents" article. It turns the abstract advice "treat tools like agent-computer interfaces" into concrete design and review criteria: choose agent-shaped tools, avoid endpoint sprawl, shape responses, budget tokens, and verify tool ergonomics with evals.
