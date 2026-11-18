#!/usr/bin/env python3
"""Collect the independent confirmation results of conditions D and D2 (preregistration 11.6, 11.7 item 4).

Reads runs/run-NN/confirm/<SNAP>/{summary.md,classify-formal.jsonl,classify-aux.jsonl},
runs/run-NN/record/{run.env,operator.jsonl} and writes tables.md next to this script.
runs/ is not tracked; this script and its output are.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
# argv[1] = sequence prefix: s2-d (default, tables.md) or s2-y (the added runs of 12.5, tables-s2-y.md)
PREFIX = sys.argv[1] if len(sys.argv) > 1 else "s2-d"
OUT = pathlib.Path(__file__).with_name("tables.md" if PREFIX == "s2-d" else f"tables-{PREFIX}.md")
FAMILIES = ["F1", "F2", "F3", "F4", "F5", "F6"]
VARIANTS = ["M1", "M2", "M3"]


def env(run):
    d = {}
    for line in (ROOT / "runs" / run / "record" / "run.env").read_text().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            d[k] = v
    return d


def stage_times(run):
    snaps = {}
    for line in (ROOT / "runs" / run / "record" / "operator.jsonl").read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        if r.get("event") == "snapshot":
            snaps.setdefault(str(r.get("stage")), r["time"])
    return snaps


def kind2(path):
    rows = {}
    for line in path.read_text().splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 6 and cells[0] in ("tree", "orig") and cells[1] in VARIANTS:
            # the verdict is the last cell; violation text may contain '|', so do not index the middle
            rows[(cells[0], cells[1])] = (cells[2], cells[-1])
    return rows


def kind1(path):
    fams, oos, n = set(), 0, 0
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        n += 1
        if r.get("verdict") == "out of scope":
            oos += 1
        for f in r.get("families") or []:
            fams.add(f)
    return fams, oos, n


def cell2(rows, mode, v):
    if (mode, v) not in rows:
        return "—"
    applied, verdict = rows[(mode, v)]
    return verdict if applied == "yes" else "当たらず"


def main():
    runs = sorted(p.name for p in (ROOT / "runs").glob("run-*") if (p / "confirm").is_dir())
    runs = [r for r in runs if env(r).get("condition") in ("D", "D2")
            and env(r).get("sequence_index", "").startswith(PREFIX)]
    label = "s2-d1〜s2-d6" if PREFIX == "s2-d" else "追加の run、" + PREFIX + "*"
    out = [f"# 条件D、D2 の独立な確認の結果（系列2、{label}）", "",
           "`build.py` が `runs/run-NN/confirm/` から作る。手で編集しない。", "",
           "種類2：参照変種 M1〜M3 を当てたときにだけ現れる違反があれば「検知」。",
           "`tree` は写しのライブラリ（被験側の変更を含む）に当てたもの、`orig` は対象のコミットのライブラリに当てたもの。",
           "種類1：抜き出した入力を `classify.js` にかけ、食い違いの種類（F1〜F6）に当たる入力が1つでもあれば ✓。",
           "正式は入力のまま、補助は名前を1文字に置き換えたもの。", ""]
    out += ["## 段階の時刻", "",
            "| run | 条件 | seq | 開始 | S1（段階2の直前） | S2（段階4の直前） | S3（終了） | 打ち切り |",
            "|---|---|---|---|---|---|---|---|"]
    for r in runs:
        e, s = env(r), stage_times(r)
        out.append(f"| {r} | {e.get('condition')} | {e.get('sequence_index')} | {e.get('start','')[11:16]} | "
                   f"{s.get('1','—')[11:16] or '—'} | {s.get('3','—')[11:16] or '—'} | {s.get('5','—')[11:16] or '—'} | "
                   f"{e.get('timeout','')[11:16] or 'なし'} |")
    out += ["", "## 種類2（例外の変種）", "",
            "| run | 条件 | 写し | tree M1 | tree M2 | tree M3 | orig M1 | orig M2 | orig M3 |",
            "|---|---|---|---|---|---|---|---|---|"]
    k1 = []
    for r in runs:
        cond = env(r).get("condition")
        for snapdir in sorted((ROOT / "runs" / r / "confirm").iterdir()):
            snap = snapdir.name
            sm = snapdir / "summary.md"
            if sm.exists():
                rows = kind2(sm)
                cells = [cell2(rows, m, v) for m in ("tree", "orig") for v in VARIANTS]
                out.append(f"| {r} | {cond} | {snap} | " + " | ".join(cells) + " |")
            elif (snapdir / "missing.md").exists():
                out.append(f"| {r} | {cond} | {snap} | 実行不能 |||||| ")
            f = snapdir / "classify-formal.jsonl"
            a = snapdir / "classify-aux.jsonl"
            if f.exists():
                ff, fo, fn = kind1(f)
                af, ao, an = kind1(a) if a.exists() else (set(), 0, 0)
                k1.append((r, cond, snap, ff, fo, fn, af, ao, an))
    out += ["", "## 種類1（表との食い違い）", "",
            "| run | 条件 | 写し | " + " | ".join(FAMILIES) + " | 正式の種類数 | 正式の対象外 | 補助 | 補助の対象外 |",
            "|---|---|---|" + "---|" * len(FAMILIES) + "---|---|---|---|"]
    for r, cond, snap, ff, fo, fn, af, ao, an in k1:
        marks = ["✓" if x in ff else "" for x in FAMILIES]
        aux = ", ".join(sorted(af)) or "なし"
        out.append(f"| {r} | {cond} | {snap} | " + " | ".join(marks) +
                   f" | {len(ff)} | {fo}/{fn} | {aux} | {ao}/{an} |")
    out.append("")
    OUT.write_text("\n".join(out))
    print(f"wrote {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
