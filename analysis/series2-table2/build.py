"""Table 2 (summary-method.md) for series 2: statements (a)(b)(c) by cutoff, two independent readers.

Usage: python3 -I analysis/series2-table2/build.py   (reads {primary,indep}/run-NN/statements.tsv here)
Writes tables.md next to this file. Missing data follow preregistration.md 12.5.
"""
import csv
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
RUNS = HERE.parent.parent / 'runs'
READERS = ('primary', 'indep')
ORDER = {'A': 0, 'A2': 1, 'B': 2, 'D': 3, 'D2': 4}


def env(run):
    t = (RUNS / run / 'record/run.env').read_text(encoding='utf-8')
    g = lambda k: (re.search(rf'^{k}=(.*)$', t, re.M) or [None, ''])[1]
    return {'condition': g('condition'), 'seq': g('sequence_index'), 'fixed': g('fixed_sent') == 'True'}


def load(reader, run):
    p = HERE / reader / run / 'statements.tsv'
    if not p.exists():
        return None
    with open(p, encoding='utf-8', newline='') as f:
        rows = [r for r in csv.DictReader(f, delimiter='\t') if r.get('kind', '').strip() not in ('', '境界')]
    out = {}
    for r in rows:
        key = r['msg'] if r['msg'] != 'UI' else 'UI@' + r['time'][11:19]
        stage = r.get('stage', '—').strip()
        ph = r['phase'].strip()
        if ph == '質問前' and stage not in ('', '—'):
            ph = '段階1' if stage == '1' else '段階2〜4'
        out.setdefault(ph, {}).setdefault(key, (r['time'], r['quote']))
    return out


def main():
    runs = sorted(p.name for p in (HERE / 'primary').iterdir() if p.name.startswith('run-'))
    info = {r: env(r) for r in runs}
    runs.sort(key=lambda r: (ORDER.get(info[r]['condition'], 9), r))
    L = ['# 表2（系列2）：「バグがないとは言えない」旨の表明', '',
         '`build.py` が作る。基準は `analysis/summary-method.md`（results.md 3.1 の (a)(b)(c)）。',
         '判定は2人の作業者（元の判定 P、独立の判定 I）による。境界例は数えない。欠測は事前登録 12.5 による。', '']
    # main table: cumulative, run counts
    L += ['## 主な表：区切りまでに表明が一度でもあった run の数（累積）', '',
          '| 条件 | 判定者 | 着手前 | 最後の質問前まで | 最後の質問後まで |', '|---|---|---|---|---|']
    per = {}
    for r in runs:
        for rd in READERS:
            d = load(rd, r)
            if d is None:
                continue
            fixed = info[r]['fixed']
            pre = bool(d.get('着手前'))
            before = pre or bool(d.get('質問前') or d.get('段階1') or d.get('段階2〜4'))
            after = before or bool(d.get('質問後'))
            c_pre = 'あり' if pre else 'なし'
            c_before = 'あり' if before else ('なし' if fixed else '欠測')
            c_after = 'あり' if after else ('なし' if fixed else '欠測')
            per[(r, rd)] = (c_pre, c_before, c_after, d)
    conds = sorted({info[r]['condition'] for r in runs}, key=lambda c: ORDER.get(c, 9))
    for c in conds:
        for rd in READERS:
            cells = []
            for i in range(3):
                vals = [per[(r, rd)][i] for r in runs if info[r]['condition'] == c and (r, rd) in per]
                n = sum(v != '欠測' for v in vals)
                cells.append(f"{sum(v == 'あり' for v in vals)}/{n}" + (f"（欠測 {len(vals) - n}）" if n < len(vals) else ''))
            L.append(f"| {c} | {'P' if rd == 'primary' else 'I'} | " + ' | '.join(cells) + ' |')
    # per-run detail
    L += ['', '## run ごと：区切りごと（累積にしない）の、表明を含む発言の数と発言番号', '',
          '| run | 条件 | 判定者 | 着手前 | 質問前（D 系は 段階1 / 段階2〜4） | 質問後 |', '|---|---|---|---|---|---|']
    for r in runs:
        for rd in READERS:
            if (r, rd) not in per:
                continue
            d = per[(r, rd)][3]
            fmt = lambda ph: f"{len(d.get(ph, {}))}（{'、'.join(d[ph])}）" if d.get(ph) else '0'
            if info[r]['condition'] in ('D', 'D2'):
                mid = f"{fmt('段階1')} / {fmt('段階2〜4')}"
            else:
                mid = fmt('質問前')
            post = fmt('質問後') if info[r]['fixed'] else '欠測'
            L.append(f"| {r} | {info[r]['condition']} | {'P' if rd == 'primary' else 'I'} | {fmt('着手前')} | {mid} | {post} |")
    # disagreements
    L += ['', '## 2人の判定の食い違い（表明を含むとした発言の集合の差）', '']
    for r in runs:
        if (r, 'primary') not in per or (r, 'indep') not in per:
            continue
        a, b = per[(r, 'primary')][3], per[(r, 'indep')][3]
        for ph in ('着手前', '質問前', '段階1', '段階2〜4', '質問後'):
            sa, sb = set(a.get(ph, {})), set(b.get(ph, {}))
            if sa != sb:
                L.append(f"- {r} {ph}：P だけ {sorted(sa - sb) or 'なし'}、I だけ {sorted(sb - sa) or 'なし'}")
    # first occurrences (primary) with quotes
    L += ['', '## 区切りごとの最初の該当（原文）', '']
    for r in runs:
        for rd in READERS:
            if (r, rd) not in per:
                continue
            d = per[(r, rd)][3]
            for ph in ('着手前', '質問前', '段階1', '段階2〜4', '質問後'):
                if d.get(ph):
                    k, (t, q) = sorted(d[ph].items(), key=lambda kv: kv[1][0])[0]
                    L.append(f"- {r} {'P' if rd == 'primary' else 'I'} {ph} {k}：「{q[:200]}」")
    (HERE / 'tables.md').write_text('\n'.join(L) + '\n', encoding='utf-8')
    print('\n'.join(L[:40]))


if __name__ == '__main__':
    main()
