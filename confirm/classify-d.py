"""Independent check for conditions D and D2, kind 1 (preregistration.md 11.6).

Usage: python3 -I confirm/classify-d.py runs/run-NN SNAP INPUTS.tsv

INPUTS.tsv lists the inputs the agent reported as violations up to the snapshot (column `input`).
Runs the experimenter's classify.js on the unmodified library of the run's image, in a throwaway
container without network:
  - formal: the inputs as written;
  - auxiliary: every name replaced by a one-letter name (distinct names get distinct letters,
    operators and brackets unchanged; keywords are kept, so classify.js reports them out of scope).
Writes runs/run-NN/confirm/SNAP/classify-formal.jsonl, classify-aux.jsonl and classify.md.
"""
import csv
import json
import pathlib
import re
import secrets
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEYWORDS = {'typeof', 'keyof', 'function', 'import', 'new', 'this', 'null', 'undefined',
            'module', 'external', 'true', 'false', 'void', 'class', 'extends'}
NAME = re.compile(r'[A-Za-z_$][A-Za-z0-9_$]*')


def one_letter(s):
    seen = {}

    def sub(m):
        w = m.group(0)
        if w in KEYWORDS:
            return w
        if w not in seen:
            seen[w] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[len(seen) % 26]
        return seen[w]
    return NAME.sub(sub, s)


def run_classify(image, inputs):
    if not inputs:
        return []
    name = 'dv-' + secrets.token_hex(5)
    subprocess.run(['docker', 'create', '--name', name, '--network', 'none', '--user', 'dev', '-w', '/home/dev',
                    image, 'sleep', 'infinity'], check=True, capture_output=True)
    try:
        subprocess.run(['docker', 'start', name], check=True, capture_output=True)
        subprocess.run(['docker', 'exec', name, 'mkdir', '-p', '/tmp/confirm-tools/answer-key'], check=True)
        tar = subprocess.run(['tar', '--no-mac-metadata', '--no-xattrs', '-C', str(ROOT / 'reference/d/answer-key'),
                              '-cf', '-', '.'], check=True, capture_output=True).stdout
        subprocess.run(['docker', 'exec', '-i', name, 'tar', '-x', '-C', '/tmp/confirm-tools/answer-key'],
                       input=tar, check=True)
        # The library must be the pinned, unmodified one.
        head = subprocess.run(['docker', 'exec', name, 'git', '-C', '/home/dev/jsdoctypeparser', 'status',
                               '--porcelain', '--', 'lib', 'peg_src', 'peg_lib', 'index.js'],
                              check=True, capture_output=True, text=True).stdout
        if head.strip():
            sys.exit('library in the image is modified:\n' + head)
        out = subprocess.run(['docker', 'exec', name, 'node', '/tmp/confirm-tools/answer-key/classify.js',
                              '/home/dev/jsdoctypeparser', *inputs], capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit('classify.js failed:\n' + out.stderr)
        return [json.loads(line) for line in out.stdout.splitlines() if line.strip()]
    finally:
        subprocess.run(['docker', 'rm', '-f', name], capture_output=True)


def main():
    run_dir, snap, tsv = pathlib.Path(sys.argv[1]).resolve(), sys.argv[2], sys.argv[3]
    meta = (run_dir / 'record/metadata.txt').read_text(encoding='utf-8')
    m = re.search(r'^container_image_id=(.+)$', meta, re.M) or re.search(r'^image=(.+)$', meta, re.M)
    image = m.group(1).strip()
    with open(tsv, encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f, delimiter='\t'))
    inputs = [r['input'].strip() for r in rows if r.get('input', '').strip()]
    uniq = list(dict.fromkeys(inputs))
    aux_map = {s: one_letter(s) for s in uniq}
    formal = run_classify(image, uniq)
    aux = run_classify(image, list(dict.fromkeys(aux_map.values())))
    out = run_dir / 'confirm' / snap
    out.mkdir(parents=True, exist_ok=True)
    (out / 'classify-formal.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in formal))
    (out / 'classify-aux.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in aux))
    by_aux = {r['input']: r for r in aux}
    lines = [f'# {run_dir.name} / {snap} / kind 1 (classify.js)', '',
             f'inputs listed: {len(inputs)} (distinct {len(uniq)}), source: `{tsv}`', '',
             '| input | formal verdict | formal family | one-letter input | aux verdict | aux family |',
             '|---|---|---|---|---|---|']
    def fam(r):
        f = r.get('family') or r.get('families') or ''
        return ', '.join(f) if isinstance(f, list) else str(f)
    for r in formal:
        a = by_aux.get(aux_map[r['input']], {})
        lines.append(f"| `{r['input']}` | {r.get('verdict')} | {fam(r)} | `{aux_map[r['input']]}` | {a.get('verdict')} | {fam(a)} |")
    for label, res in (('formal', formal), ('auxiliary', aux)):
        fams = sorted({x for r in res if fam(r) for x in fam(r).split(', ')})
        oos = sum(1 for r in res if r.get('verdict') == 'out of scope')
        lines += ['', f'{label}: families reported = {", ".join(fams) or "none"}; out of scope = {oos}/{len(res)}']
    (out / 'classify.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
