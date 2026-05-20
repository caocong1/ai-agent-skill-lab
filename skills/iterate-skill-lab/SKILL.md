---
name: iterate-skill-lab
description: Iterate this ai-agent-skill-lab repository when there is new AI agent research, framework, paper, article, or technique to absorb. Use to add a brand-new source analysis, refresh an existing source against a newer upstream version, or apply a skill-only optimization. Codifies versioning, CHANGELOG, SOURCE_INDEX metadata, analysis-file format, synthesis update, build-ai-agents optimization, docs/README updates, commit cadence, and PR flow.
version: 1.0.1
---

# Iterate Skill Lab

This skill is the maintenance counterpart to `build-ai-agents`. Use it only inside this lab repository. For implementing or reviewing agents in other projects, use `build-ai-agents` instead.

## When to Use

- A new authoritative AI agent source (paper, engineering article, or code repository) should be analyzed.
- An already-analyzed source has a new upstream version and the analysis needs to be refreshed.
- The `build-ai-agents` skill needs an optimization without a new source (rare).

## Mode

Pick the mode before anything else:

- `add-source`: brand-new source. Runs the full workflow.
- `update-source`: refresh an existing source against a newer upstream version. Skips creating new analysis/synthesis files; updates the existing report and bumps its `分析版本`.
- `skill-only`: optimization to `build-ai-agents` with no source change. Skips snapshot/analysis steps.

## Inputs to Confirm Up Front

Before any file change, get explicit answers:

- Source URL and identity. For repos: shallow-clone target. For articles/papers: fetchable URL.
- Source type: `repo`, `article`, or `paper`.
- Whether this is a new source (`add-source`) or a refresh (`update-source`).
- Expected `build-ai-agents` version bump (MAJOR/MINOR/PATCH) per the rules below.
- Whether the source materially changes cross-source consensus (drives whether `analysis/07-overall-agent-analysis.md` needs update).

## Versioning Rules (SemVer on the build-ai-agents contract)

- MAJOR: a mode, deliverable, or reference file is removed or renamed; the skill contract breaks.
- MINOR: additive guidance, new analyzed source that expands guidance, new reference file.
- PATCH: wording fix, snapshot refresh with no guidance change, broken-link repair.

Per-source `分析版本` is **independent** of the skill version. Bump `分析版本` 1.0 → 1.1 on minor re-analysis, 1.0 → 2.0 on full rewrite. Bump the skill version only if guidance actually changed.

## Per-Source Metadata (canonical schema)

Maintained in two places. Both must stay in sync.

1. `analysis/SOURCE_INDEX.md`:
   - Top line: `更新时间：YYYY-MM-DD。…`
   - `## Repositories` table columns: `项目 | 本地路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点`. `来源版本` = full commit hash.
   - `## Articles and Papers` table columns: `来源 | 快照路径 | 来源版本 | 分析版本 | 最后更新 | 学习重点`. `来源版本` = `发布 YYYY-MM-DD / 抓取 YYYY-MM-DD`.
   - `## 重点阅读文件` gets one new block per source pointing at snapshot + analysis paths.

2. Per-analysis-file metadata blockquote, immediately after the H1 (plain Markdown, no YAML):
   - Single source: `> 分析版本：X.Y ｜ 最后更新：YYYY-MM-DD ｜ 来源：<name>（commit `xxxxxxx`，详见 SOURCE_INDEX.md）` or `… ｜ 来源：<name>（发布 YYYY-MM-DD，抓取 YYYY-MM-DD）｜ 快照：raw/docs/<file>`
   - Multi-source: `> 分析版本：X.Y ｜ 最后更新：YYYY-MM-DD ｜ 覆盖来源：… ｜ 版本见 \`analysis/SOURCE_INDEX.md\``

## Workflow

Run these steps in order. Omit ones the mode does not need. Each step is a separate commit (see Commit Discipline).

1. **Bump skill version** (when applicable). Edit `skills/build-ai-agents/SKILL.md` frontmatter `version:` to the target X.Y.Z. Do this first so subsequent commits can reference it.
2. **Update CHANGELOG.md**. Add a new top entry `## [X.Y.Z] - YYYY-MM-DD` with `新增 / 变更 / 文档 / 来源版本与最后更新` subsections. The per-source table must reflect the post-iteration state of any changed sources.
3. **Acquire and snapshot the source** (skip for `update-source` when the file already exists — instead bump it):
   - **Repository**: shallow clone into `raw/repos/<slug>/`. Record the full commit hash.
   - **Article/paper**: fetch via `WebFetch` and write a structured factual digest (paraphrase, NOT verbatim — respect copyright) to `raw/docs/<slug>.md`. The header must contain the source URL, publish date, fetch date, fetch method, and a clear note that the file is a paraphrased digest, not the original.
4. **Write the analysis report** at `analysis/NN-<slug>.md` where NN is the next zero-padded index:
   - `# 标题` + metadata blockquote + 1–2 paragraph intro relating this source to already-analyzed ones.
   - Body sections (Chinese, matching existing files): `## 核心抽象`, `## 重要模式`, `## 工程启发`, `## 适用场景`, `## 注意`.
   - End with `## 对最终 skill 的影响` listing the exact `build-ai-agents` edits this analysis motivates. This list must match what step 7 actually does.
5. **Update `SOURCE_INDEX.md`**. Bump `更新时间:`; add the row to the right table; append the new `重点阅读文件` block. Also add a metadata blockquote to any analysis files that still lack one (consistency across `analysis/01..NN`).
6. **Update synthesis** at `analysis/07-overall-agent-analysis.md` when cross-source consensus changes:
   - Add the source as a column in `## 跨来源共识矩阵`.
   - Adjust `## 形态选择光谱` if the source introduces a new shape or distinction.
   - Bump the metadata block (`最后更新`, `覆盖来源`).
   - Append leads to `## 后续可分析方向` if the source surfaces new candidates.
7. **Optimize `build-ai-agents`** (additive by default, to keep MINOR scope):
   - Sharpen wording in existing references; cite the originating analysis file (e.g. `see analysis/NN-…md`).
   - Add new reference files only for genuinely new cross-cutting topics (this is contract-adjacent — verify MAJOR scope is intentional).
   - Touch `SKILL.md` content only when the new source changes a decision rule or a workflow step.
8. **Update `docs/index.html`**:
   - Append a `<tr>` to the `#sources` `<tbody>` with exactly three `<td>` (项目 / 简介 / 学习点), matching existing markup.
   - Tweak the `#sources` `section-note` only when scope language changes (e.g., first article addition warrants "和权威文章").
   - Update the `<footer>` skill version string and CHANGELOG link.
   - **Never modify `<style>` or `<script>`**: the ECharts code is self-contained and not part of normal iterations. Verify a zero `+`/`-` diff in those ranges before committing.
9. **Update `README.md`**:
   - Add the new source under `## 当前资料集` (article block under "除代码项目外，还分析了权威文章：" or new repo bullet under the existing list).
   - Bump the skill version mentioned in `## 版本与变更`.

## Commit Discipline

One commit per logical step. Stage only that step's files (never `git add -A`). Suggested order and messages, omitting steps that don't apply:

1. `chore(skill): bump SKILL.md version to X.Y.Z`
2. `docs: add CHANGELOG.md entry for X.Y.Z`
3. `analysis: add <Source> source analysis (NN)` — snapshot + analysis file
4. `analysis: track per-source metadata for <Source>` — SOURCE_INDEX + analysis header blocks
5. `analysis: update overall synthesis (07)` — when consensus changes
6. `skill: <one-line guidance change summary>` — SKILL.md content + references
7. `docs: surface <Source> in index.html`
8. `docs: note <Source> and version in README`

For `skill-only`: collapse to one or two commits (e.g., 1 + 6).
For `update-source`: typical sequence is 1 + 2 + (3 or 4) + 5 + 6 + 7 + 8.

## Branch and PR

- Branch from latest `main`. Name like `claude/<short-slug>` (e.g., `claude/add-react-paper`).
- Push with `git push -u origin <branch>`; retry on network errors with exponential backoff (2s, 4s, 8s, 16s).
- Create a **draft PR** with a Test plan checklist mirroring Definition of Done.
- Do not merge unless the user explicitly authorizes it. When authorized, prefer the `merge` method (preserves all step commits).

## Verification (Definition of Done)

Before marking the iteration complete:

- `git status` clean after each commit; only intended text files staged.
- `SKILL.md` frontmatter is valid YAML with `name`, `description`, `version`; `---` fences intact; no tabs.
- `CHANGELOG.md` has the new `## [X.Y.Z] - YYYY-MM-DD` entry; per-source table pipe-balanced; date matches reality.
- `SOURCE_INDEX.md`: top date bumped; both tables 6 columns; new `重点阅读文件` block points at files that actually exist.
- New `analysis/NN-…md` starts with `# 标题` + metadata blockquote and ends with `## 对最终 skill 的影响` whose items match the actual skill diff.
- Snapshot file (for articles/papers) is a paraphrased digest with explicit source URL + publish date + fetch date + fetch method header and a "not verbatim" note.
- `docs/index.html`: new `<tr>` has exactly three `<td>`; `git diff` shows zero changes in `<style>` and `<script>` ranges; tag balance (`tr/td/table/section/tbody/thead/footer`) is preserved.
- `README.md`: new source listed; `## 版本与变更` version reflects current `SKILL.md`.

If a `quick_validate.py` (or equivalent) exists at the repo root, run it as a final check.

## Lab-Specific Anti-Patterns

- **Verbatim copy of copyrighted source text into `raw/docs/`**. Always paraphrase; mark the snapshot as a structured digest.
- **Single commit lumping multiple steps together.** The user explicitly values step-per-commit.
- **Bumping `SKILL.md` `version` without a matching `CHANGELOG.md` entry**, or vice versa.
- **Touching `<style>` or `<script>` in `docs/index.html`** during a normal iteration. They're self-contained; touching them without an explicit reason is out of scope.
- **Adding new reference files inside `build-ai-agents/references/` for a MINOR bump.** New references are contract-adjacent; prefer extending existing references additively.
- **Overwriting `analysis/04-distilled-skill-design.md` or `analysis/05-claude-review-and-applied-changes.md`**. They have historical roles (skill-design rationale and prior review record). New synthesis content goes in `07` or a new file.
- **Listing skill edits in `## 对最终 skill 的影响` that don't match what was actually committed.** That section is a contract with the reader; keep it truthful.
- **Stale `更新时间` in `SOURCE_INDEX.md`.** This is the canonical registry; a wrong date here misleads future iterations and any tooling that reads it.

## Deliverables

- New or refreshed analysis file at `analysis/NN-<slug>.md` with metadata block and `对最终 skill 的影响` list.
- Snapshot at `raw/docs/<slug>.md` (article/paper) or `raw/repos/<slug>/` shallow clone (repo).
- Updated `analysis/SOURCE_INDEX.md`, `analysis/07-overall-agent-analysis.md` (when applicable), `CHANGELOG.md`, `skills/build-ai-agents/SKILL.md` (frontmatter and possibly content), affected `references/*.md`, `docs/index.html`, `README.md`.
- Feature branch pushed and a draft PR opened against `main` with a Test plan that mirrors Definition of Done.
