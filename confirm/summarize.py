"""Compare each variant's output with the base output of the same mode.
Detected: the recipe's exit status turns non-zero, or a violation line appears whose kind (the line
with digits removed) is absent from the base output. VIOLATION_RE comes from the recipe header."""
import os
import pathlib
import re
import sys

out, recipe = sys.argv[1], sys.argv[2]
vre = r'failing|^ +[0-9]+\) '
if os.path.exists(recipe):
    m = re.search(r'^# VIOLATION_RE: (.*)$', pathlib.Path(recipe).read_text(encoding='utf-8'), re.MULTILINE)
    if m: vre = m.group(1)
VRE = re.compile(vre)
def read(p):
    t = pathlib.Path(p).read_text(encoding='utf-8', errors='replace')
    m = re.search(r'@@ recipe exit=(\d+)', t)
    rc = int(m.group(1)) if m else None
    body = [l for l in t.splitlines() if not l.startswith('@@')]
    kinds = {re.sub(r'[0-9]+', '#', l.strip()) for l in body if VRE.search(l) and not re.search(r'\b0 failing\b', l)}
    return t, rc, kinds
print(f'# {os.path.basename(os.path.dirname(os.path.dirname(out)))} / {os.path.basename(out)}\n')
print(f'violation pattern: `{vre}`\n')
print('| mode | variant | applied | exit (base -> variant) | new violation kinds | verdict |')
print('|---|---|---|---|---|---|')
for mode in ('tree', 'orig'):
    bp = os.path.join(out, f'{mode}-base.txt')
    if not os.path.exists(bp): continue
    _, brc, bk = read(bp)
    for v in ('M1', 'M2', 'M3', 'M4', 'M5', 'M6'):
        p = os.path.join(out, f'{mode}-{v}.txt')
        if not os.path.exists(p): continue
        t, rc, k = read(p)
        if '@@ patch does not apply' in t: applied, verdict = 'no', 'patch does not apply'
        elif '@@ build failed' in t: applied, verdict = 'yes', 'build failed'
        elif rc is None: applied, verdict = 'yes', '実行不能 (no exit status)'
        else:
            applied = 'yes'; new = sorted(k - bk)
            det = (rc != 0 and brc == 0) or bool(new)
            verdict = '検知' if det else '非検知'
            if rc == 124 or brc == 124: verdict += ' (timeout)'
        new = sorted(k - bk) if rc is not None else []
        print(f'| {mode} | {v} | {applied} | {brc} -> {rc} | {"; ".join(x[:80] for x in new[:3])}{" …" if len(new) > 3 else ""} | {verdict} |')
