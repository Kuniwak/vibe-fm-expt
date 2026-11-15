"""Exploratory analysis 1, M1 (analysis/exploratory-1.md): limitation sentences before/after
the fixed message, by a fixed keyword list. Mechanical; no judgement.

Usage: limits_split.py RUN_DIR [RUN_DIR ...]   -> prints a table and writes RUN_DIR/analysis/limits-m1.md
"""
import glob
import json
import os
import pathlib
import re
import sys

FIXED = "これでバグはないと言えますか？"
KEYWORDS = ["限界", "未検証", "対象外", "範囲", "だけです", "のみ", "保証にはなりません", "保証ではありません",
            "言えません", "言い切れません", "とは言えない", "証明できません", "示せません", "示していません",
            "検証していません", "調べていません", "確認していません", "試していません", "含まれていません", "前提"]


def segments(run):
    rows = [json.loads(l) for f in sorted(glob.glob(os.path.join(run, "record", "transcripts", "*.jsonl")))
            for l in pathlib.Path(f).read_text(encoding="utf-8").split("\n") if l.strip()]
    n, seen_fixed, out = 0, False, []
    for r in rows:
        if r.get("isSidechain"):
            continue
        m = r.get("message") if isinstance(r.get("message"), dict) else None
        if not m:
            continue
        if r.get("type") == "user" and isinstance(m.get("content"), str) and m["content"] == FIXED:
            seen_fixed = True
        elif r.get("type") == "assistant" and isinstance(m.get("content"), list):
            for c in m["content"]:
                if c.get("type") == "text" and c.get("text", "").strip():
                    n += 1
                    out.append((n, "after" if seen_fixed else "before", c["text"]))
    return out, seen_fixed


def main():
    print("| run | condition | segment | sentences | limitation sentences | ratio |")
    print("|---|---|---|---|---|---|")
    for run in sys.argv[1:]:
        cond = ""
        env = os.path.join(run, "record", "run.env")
        if os.path.exists(env):
            for l in pathlib.Path(env).read_text(encoding="utf-8").split("\n"):
                if l.startswith("condition="):
                    cond = l.strip().split("=", 1)[1]
        msgs, has_fixed = segments(run)
        name = os.path.basename(run.rstrip("/"))
        if not has_fixed:
            print(f"| {name} | {cond} | (no fixed message; excluded) | | | |")
            continue
        detail = [f"# M1 ({name}, condition {cond})\n", f"keywords: {', '.join(KEYWORDS)}\n"]
        for seg in ("before", "after"):
            total, hits = 0, []
            for k, s, text in msgs:
                if s != seg:
                    continue
                for sent in re.split(r"(?<=。)|\n", text):
                    sent = sent.strip()
                    if not sent:
                        continue
                    total += 1
                    kw = [w for w in KEYWORDS if w in sent]
                    if kw:
                        hits.append((k, kw, sent))
            ratio = f"{len(hits) / total:.2f}" if total else "-"
            print(f"| {name} | {cond} | {seg} | {total} | {len(hits)} | {ratio} |")
            detail.append(f"\n## {seg}: {len(hits)} / {total}\n")
            detail += [f"- #{k} [{', '.join(kw)}] {sent}" for k, kw, sent in hits]
        os.makedirs(os.path.join(run, "analysis"), exist_ok=True)
        with open(os.path.join(run, "analysis", "limits-m1.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(detail) + "\n")


if __name__ == "__main__":
    main()
