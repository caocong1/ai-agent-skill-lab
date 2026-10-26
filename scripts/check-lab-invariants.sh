#!/usr/bin/env bash
# Mechanical gate for this lab's own conventions.
#
# Rationale: analysis/14 (OpenAI Harness Engineering) concludes that repeated
# feedback should be promoted from prose to mechanical constraint, and
# analysis/18 (DeepSeek Harness) gates its README and Agent Notes formats.
# analysis/21 records that this lab taught both and enforced neither. This
# script is the smallest thing that closes that gap.
#
# Checks: C1 analysis metadata blockquote; C2 suite version in four places;
# C3 lab-owned paths exist; C4 three <td> per index.html row; C5 SOURCE_INDEX
# date not older than its newest row; C6 raw/repos paths (warn only);
# C7 gitlink / SOURCE_INDEX / source-map commits agree; C8 every SKILL.md obeys
# the Agent Skills spec limits (name, description, under 500 lines; token
# budget warns).
#
# Usage: scripts/check-lab-invariants.sh
# Exit 0 = all invariants hold. Exit 1 = at least one violation.

set -uo pipefail
cd "$(dirname "$0")/.."

exec python3 - "$PWD" <<'PYEOF'
import re, sys, os, pathlib, subprocess

root = pathlib.Path(sys.argv[1])
violations = []
warnings = []

def v(check, msg):
    violations.append(f"[{check}] {msg}")

def w(check, msg):
    warnings.append(f"[{check}] {msg}")

# --- C1: every numbered analysis file carries a well-formed metadata blockquote ---
META = re.compile(r'^> 分析版本：\d+\.\d+ ｜ 最后更新：(\d{4}-\d{2}-\d{2}) ｜ ')
for f in sorted((root / 'analysis').glob('[0-9][0-9]-*.md')):
    lines = f.read_text().split('\n')
    if len(lines) < 3 or not META.match(lines[2]):
        v('C1', f'{f.relative_to(root)}: line 3 is not a well-formed metadata blockquote '
                f'(expected "> 分析版本：X.Y ｜ 最后更新：YYYY-MM-DD ｜ ...")')

# --- C2: the suite version agrees across SKILL.md, README.md, docs/index.html, CHANGELOG.md ---
skill = (root / 'skills/build-ai-agents/SKILL.md').read_text()
m = re.search(r'^\s*version:\s*(\d+\.\d+\.\d+)\s*$', skill, re.M)
if not m:
    v('C2', 'skills/build-ai-agents/SKILL.md: no metadata.version found')
else:
    ver = m.group(1)
    readme = (root / 'README.md').read_text()
    if f'suite 当前 {ver}' not in readme:
        v('C2', f'README.md does not state the current suite version {ver} '
                f'(expected the literal "suite 当前 {ver}")')
    index = (root / 'docs/index.html').read_text()
    if f'v{ver}' not in index:
        v('C2', f'docs/index.html does not mention v{ver}')
    changelog = (root / 'CHANGELOG.md').read_text()
    heads = re.findall(r'^## \[(\d+\.\d+\.\d+)\]', changelog, re.M)
    if not heads:
        v('C2', 'CHANGELOG.md has no version headings')
    elif heads[0] != ver:
        v('C2', f'CHANGELOG.md newest entry is [{heads[0]}] but SKILL.md is {ver}')

# --- C3: repo-internal paths mentioned in backticks actually exist ---
# Only lab-owned prefixes. `docs/<anything>` is deliberately NOT here: analysis
# files and SOURCE_INDEX list paths relative to each *source* repo, and many of
# those start with docs/. The lab's own docs/ holds a single file.
OWNED = ('analysis/', 'skills/', 'raw/docs/', 'scripts/', '.planning/', 'docs/index.html')
PATH = re.compile(r'`([A-Za-z0-9_./-]+\.(?:md|html|sh|json|yml|yaml))`')
scan = []
for sub in ('analysis', 'skills', '.planning'):
    scan += sorted((root / sub).rglob('*.md'))
scan.append(root / 'README.md')
scan.append(root / 'CHANGELOG.md')
for f in scan:
    text = f.read_text()
    for hit in set(PATH.findall(text)):
        if not hit.startswith(OWNED):
            continue
        if not (root / hit).exists():
            v('C3', f'{f.relative_to(root)}: references missing path `{hit}`')

# --- C4: every data row in docs/index.html tables has exactly 3 <td> cells ---
index_html = (root / 'docs/index.html').read_text()
for i, row in enumerate(re.findall(r'<tr>(.*?)</tr>', index_html, re.S)):
    if '<th' in row:
        continue
    n = len(re.findall(r'<td', row))
    if n != 3:
        v('C4', f'docs/index.html: table row #{i+1} has {n} <td> cells, expected 3')

# --- C5: SOURCE_INDEX 更新时间 is not older than the newest 最后更新 it records ---
si = (root / 'analysis/SOURCE_INDEX.md').read_text()
m = re.search(r'更新时间：(\d{4}-\d{2}-\d{2})', si)
dates = re.findall(r'\| (\d{4}-\d{2}-\d{2}) \|', si)
if not m:
    v('C5', 'analysis/SOURCE_INDEX.md: no 更新时间 found')
elif dates and max(dates) > m.group(1):
    v('C5', f'analysis/SOURCE_INDEX.md: 更新时间 {m.group(1)} is older than its newest '
            f'最后更新 {max(dates)}')

# --- C6: paths into raw/repos/* — verifiable only where a checkout exists ---
# Most raw/repos entries are gitlinks with no local checkout (the lab stores a
# commit, not content), so this can only warn, never fail. analysis/21 records
# the structural fix (carry the commit with the path) as future work.
REPO_PATH = re.compile(r'`(raw/repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+)`')
checked = skipped = 0
for f in scan:
    for hit in sorted(set(REPO_PATH.findall(f.read_text()))):
        repo = root / '/'.join(hit.split('/')[:3])
        if not repo.is_dir() or not any(repo.iterdir()):
            skipped += 1
            continue
        checked += 1
        if not (root / hit).exists():
            w('C6', f'{f.relative_to(root)}: `{hit}` not present in the local checkout '
                    f'(upstream rename, or a sparse checkout)')
if skipped:
    w('C6', f'{skipped} raw/repos reference(s) unverifiable: no local checkout '
            f'({checked} verified)')

# --- C7: the three records of a repo snapshot agree: gitlink, SOURCE_INDEX, source-map ---
# A snapshot is recorded three times: the gitlink under raw/repos/ (the actual
# pointer), the first full hash in SOURCE_INDEX's 来源版本 cell, and the
# source-map Local Repositories table. The 2026-10-25 review found all three
# disagreeing for one repo and a repo missing from source-map entirely.
ls = subprocess.run(['git', '-C', str(root), 'ls-files', '-s', 'raw/repos'],
                    capture_output=True, text=True).stdout
gitlinks = {}
for line in ls.splitlines():
    meta, path = line.split('\t', 1)
    mode, sha = meta.split()[:2]
    if mode == '160000':
        gitlinks[path.split('/', 2)[2]] = sha

def table_commits(text, heading, path_re):
    m = re.search(rf'^## {re.escape(heading)}\s*$(.*?)(?=^## |\Z)', text, re.M | re.S)
    found = {}
    if not m:
        return found
    rows = [r for r in m.group(1).splitlines() if r.startswith('|') and not r.startswith('| ---')]
    for r in rows[1:]:
        cells = [c.strip() for c in r.strip('|').split('|')]
        if len(cells) < 3:
            continue
        pm = re.search(path_re, cells[1])
        hm = re.search(r'\b([0-9a-f]{40})\b', cells[2])
        if pm and hm:
            found[pm.group(1)] = hm.group(1)
    return found

si_commits = table_commits(si, 'Repositories', r'`raw/repos/([^`/]+)`')
sm_text = (root / 'skills/build-ai-agents/references/source-map.md').read_text()
sm_commits = table_commits(sm_text, 'Local Repositories', r'`([^`/]+)`')
for name in sorted(set(gitlinks) | set(si_commits) | set(sm_commits)):
    g, s, mm = gitlinks.get(name), si_commits.get(name), sm_commits.get(name)
    if g is None:
        v('C7', f'{name}: recorded in SOURCE_INDEX/source-map but has no gitlink under raw/repos/')
        continue
    if s is None:
        v('C7', f'{name}: gitlink {g[:8]} has no row in SOURCE_INDEX.md ## Repositories')
    elif s != g:
        v('C7', f'{name}: SOURCE_INDEX records {s[:8]} but the gitlink is {g[:8]}')
    if mm is None:
        v('C7', f'{name}: gitlink {g[:8]} has no row in source-map.md ## Local Repositories')
    elif mm != g:
        v('C7', f'{name}: source-map records {mm[:8]} but the gitlink is {g[:8]}')

# --- C8: every SKILL.md obeys the Agent Skills specification it is written to ---
# Spec: agentskills/agentskills docs/specification.mdx (commit 69ef37e9, 2026-08-09).
# name and description limits are hard; "keep SKILL.md under 500 lines" is
# imperative in the spec and treated as hard here; the ~5000-token body budget is
# a recommendation and can only be estimated, so it warns.
for f in sorted((root / 'skills').glob('*/SKILL.md')):
    rel = f.relative_to(root)
    text = f.read_text()
    m = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.S)
    if not m:
        v('C8', f'{rel}: missing YAML frontmatter fences')
        continue
    fm, body = m.group(1), m.group(2)
    nm = re.search(r'^name:\s*(.+?)\s*$', fm, re.M)
    ds = re.search(r'^description:\s*(.+?)\s*$', fm, re.M)
    if not nm or not re.fullmatch(r'[a-z0-9]+(-[a-z0-9]+)*', nm.group(1)) or len(nm.group(1)) > 64:
        v('C8', f'{rel}: name must be 1-64 chars of lowercase letters, digits and single hyphens')
    elif nm.group(1) != f.parent.name:
        v('C8', f'{rel}: name "{nm.group(1)}" does not match its directory')
    if not ds or not (1 <= len(ds.group(1)) <= 1024):
        v('C8', f'{rel}: description must be 1-1024 characters')
    lines = text.count('\n') + (0 if text.endswith('\n') else 1)
    if lines >= 500:
        v('C8', f'{rel}: {lines} lines; the spec says keep SKILL.md under 500 lines')
    est = len(body) // 4
    if est > 5000:
        w('C8', f'{rel}: body is ~{est} tokens (chars/4); the spec recommends under 5000')

# --- report ---
for line in warnings:
    print(f'WARN  {line}')
for line in violations:
    print(f'FAIL  {line}')
if violations:
    print(f'\n{len(violations)} invariant violation(s).')
    sys.exit(1)
print(f'OK  all invariants hold ({len(warnings)} warning(s)).')
PYEOF
