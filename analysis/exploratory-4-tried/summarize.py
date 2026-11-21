#!/usr/bin/env python3
"""Pick the table-2 rows the reader summary shows (rules.md, "要約の抜き出しの基準").

Usage: python3 -I analysis/exploratory-4-tried/summarize.py   (writes selected.md next to this file)
Rule 1: either worker linked the claim to no run ("見つからない").
Rule 2: either worker's claimed-range column has a universal word.
"""
import pathlib
import re

HERE = pathlib.Path(__file__).parent
UNIVERSAL = re.compile(r"全|すべて|任意|どの|どんな|常に|必ず|\bevery\b|\ball\b", re.I)


def rows(path):
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| C"):
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
        if len(cells) >= 11:
            out[cells[0]] = cells
    return out


def main():
    lines = ["# 要約に載せる行（機械的に抜き出したもの）", "",
             "`summarize.py` が `rules.md` の基準で表2から選んだ行である。",
             "列の中身は、各 run の `claims-a.md`（作業者 a）と `claims-b.md`（作業者 b）から写した。", ""]
    total = {"1": 0, "2": 0, "rows": 0}
    for run_dir in sorted((HERE / "runs").glob("run-*")):
        a, b = rows(run_dir / "claims-a.md"), rows(run_dir / "claims-b.md")
        ids = sorted(set(a) | set(b), key=lambda x: int(x[1:]))
        picked = []
        for i in ids:
            ra, rb = a.get(i), b.get(i)
            reasons = []
            if any(r and "見つからない" in r[6] for r in (ra, rb)):
                reasons.append("1")
            if any(r and UNIVERSAL.search(r[4]) for r in (ra, rb)):
                reasons.append("2")
            if reasons:
                picked.append((i, reasons, ra, rb))
                for k in reasons:
                    total[k] += 1
        total["rows"] += len(ids)
        lines += [f"## {run_dir.name}（{len(picked)} / {len(ids)} 行）", ""]
        for i, reasons, ra, rb in picked:
            r = ra or rb
            lines += [f"### {i}（{r[1]}、基準 {' と '.join(reasons)}）", "",
                      f"- 主張の文：{r[2]}",
                      f"- 主張した範囲：a「{ra[4] if ra else '—'}」、b「{rb[4] if rb else '—'}」",
                      f"- 対応する実行：a「{ra[6] if ra else '—'}」、b「{rb[6] if rb else '—'}」",
                      f"- 実際の範囲（a）：{ra[8] if ra else '—'}",
                      f"- 実際の結果（a）：{ra[9] if ra else '—'}",
                      f"- 備考（a）：{ra[10] if ra else '—'}",
                      f"- 備考（b）：{rb[10] if rb else '—'}", ""]
    lines.insert(4, f"全 {total['rows']} 行のうち、基準1に当たる行は {total['1']}、基準2に当たる行は {total['2']}（重複あり）。")
    lines.insert(5, "")
    (HERE / "selected.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(total)


if __name__ == "__main__":
    main()
