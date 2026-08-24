---
id: SEED-001
status: dormant
planted: 2026-06-05
planted_during: ai-agent-skill-lab provider API discussion
trigger_when: when starting a new milestone, adding provider API integration guidance, or when source snapshots are older than one quarter
scope: small
last_reviewed: 2026-08-23
---

# SEED-001: Review freshness of learned AI agent sources and provider API assumptions

## Why This Matters

The lab's analysis depends on fast-moving upstream material: agent SDKs, provider API docs, compatibility layers, and vendor-specific model behavior. The useful guidance should stay generic enough to teach developers how to inspect current official docs at implementation time, instead of freezing today's provider-specific fields as permanent rules.

## When to Surface

**Trigger:** when starting a new milestone, adding provider API integration guidance, or when source snapshots are older than one quarter.

Before relying on older source analysis, review `analysis/SOURCE_INDEX.md` for:

- the original source version or capture date;
- whether the upstream docs or repository have changed materially;
- whether the reusable skill should say "check current provider docs" rather than encode stale field-level assumptions;
- whether a changelog note is needed for changed recommendations.

## Scope Estimate

**Small** — usually a source-index audit plus targeted updates to analysis headers, `CHANGELOG.md`, and relevant skill references.

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
