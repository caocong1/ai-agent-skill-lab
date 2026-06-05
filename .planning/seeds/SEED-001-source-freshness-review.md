---
id: SEED-001
status: dormant
planted: 2026-06-05
planted_during: ai-agent-skill-lab provider API discussion
trigger_when: when starting a new milestone, adding provider API integration guidance, or when source snapshots are older than one quarter
scope: small
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
