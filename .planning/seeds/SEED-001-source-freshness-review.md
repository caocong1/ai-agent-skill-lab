---
id: SEED-001
status: dormant
planted: 2026-06-05
planted_during: ai-agent-skill-lab provider API discussion
trigger_when: when starting a new milestone, adding provider API integration guidance, or when source snapshots are older than one quarter
scope: small
last_reviewed: 2026-06-05
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
