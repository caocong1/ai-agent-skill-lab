#!/usr/bin/env bash
# Mechanical gate for this lab's own conventions.
#
# Rationale: analysis/14 (OpenAI Harness Engineering) concludes that repeated
# feedback should be promoted from prose to mechanical constraint, and
# analysis/18 (DeepSeek Harness) gates its README and Agent Notes formats.
# analysis/21 records that this lab taught both and enforced neither. This
# script is the smallest thing that closes that gap.
#
# Usage: scripts/check-lab-invariants.sh
# Exit 0 = all invariants hold. Exit 1 = at least one violation.

set -uo pipefail
cd "$(dirname "$0")/.."

exec python3 - "$PWD" <<'PYEOF'
import re, sys, os, pathlib

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
