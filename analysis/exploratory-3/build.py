"""Builds the aggregate tables of exploratory analysis 3 from the per-run ledgers (runs/run-NN/).
Usage: python3 -I build.py  -> writes claims-merged.tsv and tables.md"""
import csv, glob, os, collections
csv.field_size_limit(10**8)
COND = {'run-02': 'A', 'run-05': 'A', 'run-08': 'A', 'run-03': 'A2', 'run-06': 'A2', 'run-09': 'A2', 'run-04': 'B', 'run-07': 'B', 'run-10': 'B'}
ORDER = ['run-02', 'run-05', 'run-08', 'run-03', 'run-06', 'run-09', 'run-04', 'run-07', 'run-10']
ITEMS = ['object', 'oracle', 'range', 'assumption']
JP = {'object': '対象', 'oracle': 'オラクル', 'range': '範囲', 'assumption': '仮定'}

def gv(v):
    v = v.strip()
    for k in ['超えた', '両論', '証拠なし', '不明', 'なし']:
        if v.startswith(k):
            return k
    return v[:6]

def dv(v):
    v = v.strip()
    if '成立側' in v and '不一致側' in v:
        return '成立側・不一致側'
    for k in ['成立側', '不一致側', 'その他']:
        if v.startswith(k):
            return k
    return '—'

def load(run, name):
    p = f'runs/{run}/{name}'
    return list(csv.DictReader(open(p, encoding='utf-8'), delimiter='\t')) if os.path.exists(p) else []

merged, lines = [], []
stats = {}
for run in ORDER:
    cl = load(run, 'claims.tsv')
    ind = {x['id']: x for x in load(run, 'claims-indep.tsv')}
    s = collections.Counter()
    s['claims'] = len(cl)
    for x in cl:
        kind = x.get('claim_kind', '').strip()[:3]
        s['holds_yes'] += x['holds_claim'].strip() == 'yes'
        s['kind_' + kind] += 1
        d = dv(x['gap_direction'])
        o_ex = [k for k in ITEMS if gv(x['gap_' + k]) == '超えた']
        o_both = [k for k in ITEMS if gv(x['gap_' + k]) == '両論']
        o_solo = [k for k in ITEMS if gv(x['solo_gap_' + k]) == '超えた']
        o_noev = [k for k in ITEMS if gv(x['gap_' + k]) == '証拠なし']
        i = ind.get(x['id'])
        i_ex = [k for k in ITEMS if i and gv(i['gap_' + k]) == '超えた']
        i_both = [k for k in ITEMS if i and gv(i['gap_' + k]) == '両論']
        agree = 'indep なし' if not i else ('一致' if set(o_ex) == set(i_ex) and set(o_both) == set(i_both) else '食い違い')
        if o_ex:
            s['ex_orig_' + d] += 1
        if o_ex and (not i or i_ex):
            s['ex_both_' + d] += 1
        if o_ex or i_ex:
            s['ex_either_' + (d if o_ex else dv(i['gap_direction']))] += 1
        if o_both:
            s['both_sides'] += 1
        if o_solo:
            s['ex_solo_' + d] += 1
        if o_noev:
            s['no_evidence'] += 1
        ic = x.get('intent_check', '')
        s['intent_a'] += ic.startswith('尋ねた(a)')
        s['intent_b'] += ic.startswith('尋ねた(b)')
        s['fact_error'] += '【事実の誤り】' in x.get('note', '')
        merged.append([run, COND[run], x['id'], x['msg'], x.get('claim_kind', ''), d,
                       ','.join(JP[k] for k in o_ex), ','.join(JP[k] for k in o_both), ','.join(JP[k] for k in o_solo),
                       ','.join(JP[k] for k in i_ex) if i else '', ','.join(JP[k] for k in i_both) if i else '', agree,
                       x['quote']])
        if o_ex or i_ex or o_both:
            lines.append((run, x['id'], x['msg'], d, o_ex, i_ex if i else None, o_both, x['quote'], agree))
    fi = load(run, 'findings.tsv')
    s['findings'] = len(fi)
    has = lambda v: bool(v.strip()) and not v.strip().startswith(('なし', '—', '-', '該当なし'))
    s['added_repo_oracle'] = sum(1 for x in fi if has(x.get('added_repo_oracle', '')))
    s['overwrote_repo_oracle'] = sum(1 for x in fi if has(x.get('overwrote_repo_oracle', '')))
    stats[run] = s

with open('claims-merged.tsv', 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, delimiter='\t')
    w.writerow(['run', 'condition', 'id', 'msg', 'claim_kind', 'direction', 'exceeded_orig', 'both_sides_orig', 'exceeded_solo_orig', 'exceeded_indep', 'both_sides_indep', 'agreement', 'quote'])
    w.writerows(merged)

A = list(csv.DictReader(open('assertions.tsv', encoding='utf-8'), delimiter='\t'))
out = []
out.append('# 探索的分析3 の集計表\n\n`build.py` が run ごとの台帳から機械的に作る。\n')
out.append('## 表1：主張の差（run ごと、発言単位）\n')
out.append('「両方」は元の作業者と独立の作業者がともに「超えた」とした行、「どちらか」はどちらか一方でも「超えた」とした行。独立の符号化は、論点に関わる行だけに行った（それ以外の行は元の符号だけ）。\n')
out.append('| 条件 | run | 主張 | 成立 | 成立側 超えた（両方／どちらか） | 不一致側 超えた（両方／どちらか） | その他 超えた | 両論 | 単独で読むと成立側が超えた | 証拠なしを含む | 事実の誤り |')
out.append('|---|---|---|---|---|---|---|---|---|---|---|')
for run in ORDER:
    s = stats[run]
    out.append(f"| {COND[run]} | {run} | {s['claims']} | {s['kind_成立']} | {s['ex_both_成立側']}／{s['ex_either_成立側']} | {s['ex_both_不一致側']}／{s['ex_either_不一致側']} | {s['ex_orig_その他']} | {s['both_sides']} | {s['ex_solo_成立側']} | {s['no_evidence']} | {s['fact_error']} |")
out.append('\n## 表2：欠陥の断定（発見の単位）\n')
out.append('束ねた発見ごとに、固定発言より前に欠陥と断定した run と、その断定のオラクルの差（変更2の1、変更3）。\n')
out.append('| 条件 | run | 断定した発見 | うち、証拠を超えた断定 | 超えた発見 |')
out.append('|---|---|---|---|---|')
for run in ORDER:
    a = [x for x in A if x['run'] == run]
    ex = [x['bundle'] for x in a if x['gap_oracle'].startswith('超えた')]
    out.append(f"| {COND[run]} | {run} | {len(a)} | {len(ex)} | {', '.join(ex) or '—'} |")
out.append('\n## 表3：意図の確認、リポジトリ内のオラクルへの書き込み\n')
out.append('| 条件 | run | 成立の主張 | 尋ねた(a) 性質の候補を選ばせた | 尋ねた(b) 意図を尋ねた | 発見（束ねる前の行） | テストを書き加えた行 | 既存の期待値を書き換えた行 |')
out.append('|---|---|---|---|---|---|---|---|')
for run in ORDER:
    s = stats[run]
    out.append(f"| {COND[run]} | {run} | {s['kind_成立']} | {s['intent_a']} | {s['intent_b']} | {s['findings']} | {s['added_repo_oracle']} | {s['overwrote_repo_oracle']} |")
out.append('\n## 表4：差のある主張の一覧（どちらかの作業者が「超えた」、または元の作業者が「両論」とした行）\n')
for run in ORDER:
    out.append(f'\n### {run}（条件{COND[run]}）\n')
    out.append('| id | 発言 | 向き | 元の符号 | 独立の符号 | 原文 |')
    out.append('|---|---|---|---|---|---|')
    for (r, i, m, d, oe, ie, ob, q, ag) in [l for l in lines if l[0] == run]:
        oc = ','.join(JP[k] for k in oe) + (('；両論:' + ','.join(JP[k] for k in ob)) if ob else '')
        ic = '（対象外）' if ie is None else (','.join(JP[k] for k in ie) or 'なし')
        qq = q.replace('|', '\\|')
        qq = qq if len(qq) <= 220 else qq[:220] + '…'
        out.append(f'| {i} | {m} | {d} | {oc or "なし"} | {ic} | {qq} |')
open('tables.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('\n'.join(out[:40]))
