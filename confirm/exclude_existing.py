"""Auxiliary verdict that excludes the repository's existing tests (preregistration.md 12, 2026-11-19).

The main verdict (summarize.py) counts any new violation line. This one first removes what the
existing tests produced, then compares the same way:
  - mocha failure blocks (and their inline markers in the suite listing) whose full title is one of
    the tests at the pinned commit (confirm/existing-titles.txt); failures of tests the agent added stay;
  - mocha summary lines (N passing / failing / pending), which mix both;
  - npm-run-all and nyc threshold errors, which only say that the repository's test script failed.
When either output contains a mocha summary, a change of the exit status is not used, because it
cannot be told which step caused it.
Usage: python3 -I confirm/exclude_existing.py OUTDIR RECIPE [TITLES]   (prints a table like summarize.py)
"""
import os
import pathlib
import re
import sys

SUMMARY = re.compile(r'^\s+\d+ (passing|failing|pending)\b')
FAILING = re.compile(r'^\s+\d+ failing\b')
HEADER = re.compile(r'^  (\d+)\) (.*)$')
INLINE = re.compile(r'^\s{3,}(\d+)\) ')
PLUMBING = [re.compile(r'^ERROR: Coverage for '), re.compile(r'^ERROR: "[^"]+" exited with \d+\.?$')]


def kind(line):
    """Same as summarize.kind: digits replaced by '#', a trailing comma dropped."""
    return re.sub(r'[0-9]+', '#', line.strip()).rstrip(',')


def block_title(block):
    """Full title of a mocha failure block: its path components joined by spaces, up to the line ending in ':'."""
    m = HEADER.match(block[0])
    parts = [m.group(2).strip()]
    if not parts[0].endswith(':'):
        for line in block[1:]:
            if not line.strip():
                break
            parts.append(line.strip())
            if line.rstrip().endswith(':'):
                break
    parts[-1] = parts[-1][:-1] if parts[-1].endswith(':') else parts[-1]
    return ' '.join(parts)


def _blocks(lines, i):
    """Failure blocks after the 'N failing' line at i: [(number, start, end)], and the index after them."""
    blocks, j = [], i + 1
    while j < len(lines) and not lines[j].strip():
        j += 1
    while j < len(lines) and HEADER.match(lines[j]):
        start, j = j, j + 1
        while j < len(lines) and not HEADER.match(lines[j]) and (not lines[j].strip() or lines[j].startswith('   ')):
            j += 1
        blocks.append((int(HEADER.match(lines[start]).group(1)), start, j))
    return blocks, j


def strip(lines, titles):
    """Lines without what the existing tests produced, and whether a mocha summary was seen."""
    drop, section_start, i = set(), 0, 0
    suite = any(SUMMARY.match(l) for l in lines)
    while i < len(lines):
        if FAILING.match(lines[i]):
            blocks, end = _blocks(lines, i)
            existing = {n for n, s, e in blocks if block_title(lines[s:e]) in titles}
            for n, s, e in blocks:
                if n in existing:
                    drop.update(range(s, e))
            for k in range(section_start, i):
                m = INLINE.match(lines[k])
                if m and int(m.group(1)) in existing:
                    drop.add(k)
            section_start, i = end, end
            continue
        i += 1
    kept = [l for k, l in enumerate(lines) if k not in drop
            and not SUMMARY.match(l) and not any(p.match(l) for p in PLUMBING)]
    return kept, suite


def _read(text, vre, titles):
    m = re.search(r'@@ recipe exit=(\d+)', text)
    rc = int(m.group(1)) if m else None
    body = [l for l in text.splitlines() if not l.startswith('@@')]
    kept, suite = strip(body, titles)
    kinds = {kind(l) for l in kept if vre.search(l) and not re.search(r'\b0 failing\b', l)}
    return rc, kinds, suite


def verdict(base_text, var_text, vre, titles):
    if '@@ patch does not apply' in var_text:
        return 'patch does not apply'
    if '@@ build failed' in var_text:
        return 'build failed'
    vre = re.compile(vre)
    brc, bk, bs = _read(base_text, vre, titles)
    rc, k, s = _read(var_text, vre, titles)
    if rc is None:
        return '実行不能 (no exit status)'
    det = bool(k - bk) or (rc != 0 and brc == 0 and not (bs or s))
    return ('検知' if det else '非検知') + (' (timeout)' if 124 in (rc, brc) else '')


def main(out, recipe, titles_path):
    vre = r'failing|^ +[0-9]+\) '
    if os.path.exists(recipe):
        m = re.search(r'^# VIOLATION_RE: (.*)$', pathlib.Path(recipe).read_text(encoding='utf-8'), re.MULTILINE)
        if m:
            vre = m.group(1)
    titles = set(pathlib.Path(titles_path).read_text(encoding='utf-8').splitlines())
    read = lambda p: pathlib.Path(p).read_text(encoding='utf-8', errors='replace')
    print(f'# {os.path.basename(os.path.dirname(os.path.dirname(out)))} / {os.path.basename(out)}（既存テストを除いた判定）\n')
    print('| mode | variant | verdict |')
    print('|---|---|---|')
    for mode in ('tree', 'orig'):
        bp = os.path.join(out, f'{mode}-base.txt')
        if not os.path.exists(bp):
            continue
        for v in ('M1', 'M2', 'M3', 'M4', 'M5', 'M6'):
            p = os.path.join(out, f'{mode}-{v}.txt')
            if os.path.exists(p):
                print(f'| {mode} | {v} | {verdict(read(bp), read(p), vre, titles)} |')


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, 'existing-titles.txt'))
