"""Tables for exploratory analysis 3, conditions D and D2 (run-27..run-32).

Run: python3 -I analysis/exploratory-3-d/build.py > analysis/exploratory-3-d/tables.md
Reads only the files in this directory. Disagreements between the original and the
independent coder are not resolved: counts are shown for both, "both" and "either".
"""
import collections
import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = [f"run-{n}" for n in range(27, 33)]
GAPS = ["gap_object", "gap_oracle", "gap_range", "gap_assumption"]
CATS = ["両方の読みで内側", "強い読みでだけ超える", "弱い読みでも超える", "その他"]


def tsv(path):
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def is_detection(x):
    return x.get("claim_subject", "—").strip() not in ("—", "")


STAGE = {}  # (run, id) -> stage from the original ledger (the independent files have no stage column)


def category(x, run=None):
    """Two-readings category of a stage 2-4 detection row (change 4, addenda 1 and 2).

    Stage-1 rows are outside the frame (addendum 2, item 3) even if a coder filled the columns."""
    if not is_detection(x):
        return None
    if STAGE.get((run, x["id"]), x.get("stage", "")).strip() == "1":
        return None
    if x["claim_subject"] == "変種":
        return "変種"
    if x["gap_weak"] == "超えた":
        return "弱い読みでも超える"
    if x["gap_strong"] == "超えた":
        return "強い読みでだけ超える"
    if x["gap_weak"] == "なし" and x["gap_strong"] == "なし":
        return "両方の読みで内側"
    return "その他"


def stage_group(x):
    return "段階1" if x["stage"].strip() == "1" else "段階2〜4"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


orig, indep, find, find_i = {}, {}, {}, {}
for r in RUNS:
    d = os.path.join(HERE, "runs", r)
    orig[r] = tsv(os.path.join(d, "claims.tsv"))
    indep[r] = {x["id"]: x for x in tsv(os.path.join(d, "claims-indep.tsv"))}
    find[r] = tsv(os.path.join(d, "findings.tsv"))
    find_i[r] = {x["id"]: x for x in tsv(os.path.join(d, "findings-indep.tsv"))}
    STAGE.update({(r, x["id"]): x["stage"] for x in orig[r]})
reader = {(x["run"], x["id"]): x for x in tsv(os.path.join(HERE, "first-reading.tsv"))}

print("# 探索的分析3（条件D、D2）：集計表\n")
print("`build.py` が作る。手で直さない。\n")

# Table 1: detection claims in stages 2-4, two readings
print("## 表1　段階2〜4の検知の主張（2つの読み）\n")
print("「種類」「決められない」を主語にした行を3つに分ける。「変種」を主語にした行は、強い読みを当てない（追記2の1）。")
print("元＝元の作業者、独立＝独立の作業者。両方＝2人とも、どちらか＝少なくとも1人がその分類にした行。\n")
rows, tot = [], collections.Counter()
for r in RUNS:
    det_o = [x for x in orig[r] if category(x)]
    c_o = collections.Counter(category(x) for x in det_o)
    keys = {x["id"] for x in det_o} | {i for i, y in indep[r].items() if category(y, r)}
    both, either = collections.Counter(), collections.Counter()
    for i in keys:
        a = next((category(x) for x in orig[r] if x["id"] == i), None)
        b = category(indep[r][i], r) if i in indep[r] else None
        for c in set(filter(None, [a, b])):
            either[c] += 1
        if a and a == b:
            both[a] += 1
    c_i = collections.Counter(category(y, r) for y in indep[r].values() if category(y, r))
    row = [r, len(det_o), sum(c_i.values())]
    for c in ["両方の読みで内側", "強い読みでだけ超える", "弱い読みでも超える", "変種"]:
        row.append(f"{c_o[c]} / {c_i[c]} / {both[c]} / {either[c]}")
        tot[c, "o"] += c_o[c]; tot[c, "i"] += c_i[c]; tot[c, "b"] += both[c]; tot[c, "e"] += either[c]
    tot["n", "o"] += len(det_o); tot["n", "i"] += sum(c_i.values())
    rows.append(row)
rows.append(["計", tot["n", "o"], tot["n", "i"]] + [
    f"{tot[c, 'o']} / {tot[c, 'i']} / {tot[c, 'b']} / {tot[c, 'e']}"
    for c in ["両方の読みで内側", "強い読みでだけ超える", "弱い読みでも超える", "変種"]])
print(table(["run", "行（元）", "行（独立）", "両方で内側 元/独立/両方/どちらか",
             "強い読みでだけ超える 元/独立/両方/どちらか", "弱い読みでも超える 元/独立/両方/どちらか",
             "変種 元/独立/両方/どちらか"], rows))
print()

# Table 2: limit in message for "strong only" rows
print("## 表2　「強い読みでだけ超える」行と、同じ発言の明示の限定（元の作業者）\n")
rows = []
for r in RUNS:
    c = collections.Counter(x["limit_in_message"] for x in orig[r] if category(x) == "強い読みでだけ超える")
    rows.append([r, c["あり"], c["なし"]])
print(table(["run", "限定あり", "限定なし"], rows))
print()

# Table 3: first readings
print("## 表3　最初の読み（first_reading）\n")
print("読み手＝元の台帳を見ていない別の読み手（元の側の値）。主語は元の作業者の `claim_subject`。\n")
cross = collections.Counter()
for r in RUNS:
    for x in orig[r]:
        k = (r, x["id"])
        if category(x) and k in reader:
            cross[x["claim_subject"], reader[k]["first_reading"]] += 1
rows = [[s] + [cross[s, f] for f in ["強い", "弱い", "決められない"]] for s in ["種類", "決められない", "変種"]]
print(table(["主語（元）", "読み手：強い", "読み手：弱い", "読み手：決められない"], rows))
print()
cross2, diff = collections.Counter(), []
for r in RUNS:
    for i, y in indep[r].items():
        k = (r, i)
        f = y.get("first_reading", "—").strip()
        if k in reader and f not in ("—", "") and STAGE.get(k, "").strip() != "1":
            cross2[reader[k]["first_reading"], f] += 1
            if reader[k]["first_reading"] != f:
                diff.append(f"{r} {i}（読み手：{reader[k]['first_reading']}、独立の作業者：{f}）")
rows = [[a] + [cross2[a, b] for b in ["強い", "弱い", "決められない"]] for a in ["強い", "弱い", "決められない"]]
print(table(["読み手", "独立：強い", "独立：弱い", "独立：決められない"], rows))
print()
print("最初の読みが分かれた行：" + ("、".join(diff) if diff else "なし") + "\n")

# Table 4: gaps by stage group
print("## 表4　段階別の、差が「超えた」の主張（元の作業者、検知の主張の2つの読みの列は除く）\n")
print("段階1は A 系と同じ規則。段階2〜4は人間がオラクルを与えた後の別枠で、A 系と並べない。\n")
rows = []
for r in RUNS:
    row = [r]
    for g in ["段階1", "段階2〜4"]:
        xs = [x for x in orig[r] if x["stage"].strip() and stage_group(x) == g]
        n_ex = sum(1 for x in xs if any(x[k] == "超えた" for k in GAPS))
        row += [len(xs), n_ex]
    rows.append(row)
print(table(["run", "段階1 行", "段階1 超えた", "段階2〜4 行", "段階2〜4 超えた"], rows))
print()

# Table 5: findings
print("## 表5　発見（元 / 独立）\n")
rows = []
for r in RUNS:
    for g in ["段階1", "段階2〜4"]:
        fs = [x for x in find[r] if stage_group(x) == g]
        if not fs:
            continue
        a_o = sum(1 for x in fs if x["asserted_defect"].startswith(("yes", "断定")))
        a_i = sum(1 for x in fs if find_i[r].get(x["id"], {}).get("asserted_defect", "").startswith("yes"))
        human = sum(1 for x in fs if "人間" in x["oracle_class"])
        lt = collections.Counter(x.get("later_human_table", "—").split("（")[0].strip() for x in fs)
        rows.append([r, g, len(fs), f"{a_o} / {a_i}", human,
                     "、".join(f"{k} {v}" for k, v in sorted(lt.items()) if k not in ("—", ""))])
print(table(["run", "段階", "発見", "欠陥と断定 元/独立", "人間のオラクルを含む（元）", "later_human_table（元）"], rows))
print()

# Table 6: agreement
print("## 表6　元と独立の一致（独立の符号化の対象の行）\n")
cols = ["claim_kind", "claim_subject", "holds_claim", "intent_check"] + GAPS + ["gap_direction"]
rows = []
n = sum(len(indep[r]) for r in RUNS)
for c in cols:
    ok = sum(1 for r in RUNS for x in orig[r] if x["id"] in indep[r]
             and x.get(c, "").strip() == indep[r][x["id"]].get(c, "").strip())
    rows.append([c, f"{ok}/{n}"])
det = [(r, x) for r in RUNS for x in orig[r] if x["id"] in indep[r] and (category(x) or category(indep[r][x["id"]], r))]
ok = sum(1 for r, x in det if category(x) == category(indep[r][x["id"]], r))
rows.append(["2つの読みの分類（どちらかが検知の主張とした行）", f"{ok}/{len(det)}"])
print(table(["項目", "一致"], rows))
print()
dis = [f"{r} {x['id']}（元：{category(x) or '検知の主張でない'}、独立：{category(indep[r][x['id']], r) or '検知の主張でない'}）"
       for r, x in det if category(x) != category(indep[r][x["id"]], r)]
print("2つの読みの分類が分かれた行：" + "、".join(dis))
