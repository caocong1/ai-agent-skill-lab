---
id: SEED-001
status: dormant
planted: 2026-06-05
planted_during: ai-agent-skill-lab provider API discussion
trigger_when: when starting a new milestone, adding provider API integration guidance, when source snapshots are older than one quarter, when an upstream specification the lab depends on publishes a revision, or when a new model generation ships
scope: medium
last_reviewed: 2026-10-25
---

# SEED-001: Review freshness of learned AI agent sources and provider API assumptions

## Why This Matters

The lab's analysis depends on fast-moving upstream material: agent SDKs, provider API docs, compatibility layers, and vendor-specific model behavior. The useful guidance should stay generic enough to teach developers how to inspect current official docs at implementation time, instead of freezing today's provider-specific fields as permanent rules.

## When to Surface

**Trigger:** when starting a new milestone, adding provider API integration guidance, when source snapshots are older than one quarter, when an upstream specification the lab depends on publishes a revision, or when a new model generation ships.

The last two triggers were added on 2026-08-23. A **spec revision** is a cause that fans out: the MCP 2026-07-28 revision drove material change in three downstream sources within three weeks, and the time-based trigger caught it only by luck. A **new model generation** matters for a different reason — it is the moment to re-run the ablation on guidance that compensates for a model limitation, per `analysis/21-lab-design-rethink-2026-08.md`.

Before relying on older source analysis, review `analysis/SOURCE_INDEX.md` for:

- the original source version or capture date;
- whether the upstream docs or repository have changed materially;
- whether the reusable skill should say "check current provider docs" rather than encode stale field-level assumptions;
- whether a changelog note is needed for changed recommendations.

## Scope Estimate

**Medium** — a source-index audit, path verification against every upstream, targeted re-analysis of the sources that changed, and the matching skill edits. Expect **large** in a quarter that carries a major release line of an analyzed source or a new model generation. (The original estimate was small; it failed on 2026-08-23 and again on 2026-10-25.)

## Breadcrumbs

- `analysis/SOURCE_INDEX.md`
- `skills/build-ai-agents/references/source-map.md`
- `analysis/07-overall-agent-analysis.md`

## Notes

Captured during discussion of provider API differences and OpenAI-compatible limitations. Keep future provider API work framed as a documentation-reading and adaptation discipline, not as a static vendor compatibility table.

## Review Log

This seed is a recurring trigger-based watchdog, not a one-shot task — it stays `dormant` and re-arms after each review.

- **2026-06-05** — first review. Audited all 13 sources (9 repos + 3 articles + 1 synthesis): all reachable, none stale-by-time, only Vercel AI SDK materially changed (v7 canary `onFinish`→`onEnd`, flagged for re-analysis). Skill already free of frozen provider specifics; landed minor framing-hygiene edits (provider error names → behavior-named; MCP/A2A/ANP maturity → dated observations). Shipped as `1.5.1` (patch). Full report: `../freshness-reviews/2026-06-05-source-freshness-review.md`. Outstanding: Vercel re-analysis; routine re-snapshots of additively-drifted repos. Consumed only the "snapshots aging" trigger.
- **2026-08-23** — second review. Audited 14 repos + 6 articles/specs + 1 synthesis. **5 materially changed** (vs 1 last time): MCP spec 2026-07-28 drove MCP TS SDK v2 package rename, OpenAI Agents JS v2 negotiation, and LangChain4j's 2026-07-28 client; Vercel AI SDK v7 went stable; Spring AI examples aligned to Spring AI 2.0; learn-claude-code restructured 20→17 lessons; Pi grew a durable-execution harness doc. Found **10 dead file paths** in `SOURCE_INDEX.md` / `source-map.md` — the first hard error this seed has caught, from files renamed rather than repos moving. Method upgraded: verify referenced paths (not just repo drift), use npm dist-tags for monorepos, register upstream specs as first-class sources with a version row, and record un-verifiable drift as pending rather than optimistically clean. Actual scope **medium**, not the seed's estimated small. Shipped as `2.2.0` (minor). Full report: `../freshness-reviews/2026-08-23-source-freshness-review.md`. Outstanding: OpenAI Codex deep check (+858 commits, deferred); routine re-snapshots. Consumed only the "snapshots aging" trigger.
- **2026-10-25** — third review. Audited 14 repos + 6 articles + 1 spec + 1 synthesis, plus 3 uncommitted drafts left by an interrupted 2026-09-04 iteration. **11 of 14 repos changed materially** (5 last time, 1 the time before); no spec revision this quarter — the drivers were major release lines (Pi 1.x moved durable execution out of its core; DeepSeek Harness 0.1 → 0.2; MCP TS SDK 2.4) and a new model generation (Claude 5.x, GPT-6, Gemini 4). Hard errors found in the lab's own records: dead paths again (4 of them already dead at the previous review and missed), a three-way commit mismatch for learn-claude-code, DeepSeek Harness missing from `source-map.md`, a compaction order that had been wrong since the first analysis, and three factual errors in the September drafts. Method upgraded: read stable release notes only; check paths for every source including non-material ones; commit records are now mechanically checked (C7); diff articles against Wayback rather than trusting modified dates; treat an interrupted iteration's drafts as unverified. Consumed the "snapshots aging" and "new model generation" triggers; the latter ran the lab's first desk re-check of perishable guidance and the first falsifiability check of `analysis/21`. Actual scope **large**; seed estimate raised to medium. Shipped as `2.3.0` (minor). Full report: `../freshness-reviews/2026-10-25-source-freshness-review.md`. Outstanding: a script that verifies cited paths against the recorded upstream commit; the minimal validation set for skill changes.
