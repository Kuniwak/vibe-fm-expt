"""Mechanical extraction from a collected run (no judgement).

Usage: extract.py RUN_DIR   -> writes RUN_DIR/analysis/{messages,keywords,commands,operator}.md

Numbering (preregistered): every display-text block of the agent in the main session gets
a number from 1 in order (#1, #2, ...). Tool calls and thinking are not numbered.
Human-side messages are U1, U2, ...
Keyword extraction: sentences (split at 。 and line breaks) of numbered agent messages that
contain a keyword from config/extract-keywords.json, quoted verbatim.
"""
import glob
import json
import os
import pathlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    run = sys.argv[1]
    out = os.path.join(run, "analysis")
    os.makedirs(out, exist_ok=True)
    files = sorted(glob.glob(os.path.join(run, "record", "transcripts", "*.jsonl")))
    rows = [json.loads(l) for f in files for l in pathlib.Path(f).read_text(encoding="utf-8").split("\n") if l.strip()]
    rows = [r for r in rows if not r.get("isSidechain")]
    events, n, u = [], 0, 0
    for r in rows:
        m = r.get("message") if isinstance(r.get("message"), dict) else None
        if not m:
            continue
        if r.get("type") == "user" and isinstance(m.get("content"), str):
            u += 1
            events.append(("U", u, m["content"], r.get("timestamp", "")))
        elif r.get("type") == "user" and isinstance(m.get("content"), list):
            for c in m["content"]:
                if c.get("type") == "tool_result":
                    t = c.get("content")
                    t = t if isinstance(t, str) else json.dumps(t, ensure_ascii=False)
                    events.append(("R", None, t, r.get("timestamp", "")))
        elif r.get("type") == "assistant" and isinstance(m.get("content"), list):
            for c in m["content"]:
                if c.get("type") == "text" and c.get("text", "").strip():
                    n += 1
                    events.append(("A", n, c["text"], r.get("timestamp", "")))
                elif c.get("type") == "tool_use":
                    events.append(("T", c.get("name"), c.get("input", {}), r.get("timestamp", "")))

    with open(os.path.join(out, "messages.md"), "w", encoding="utf-8") as f:
        f.write(f"# Messages ({os.path.basename(run)})\n\nAgent display texts are numbered #1..#{n}; human messages U1..U{u}.\n\n")
        for kind, k, body, ts in events:
            if kind == "U":
                f.write(f"## U{k}  ({ts})\n\n{body}\n\n")
            elif kind == "A":
                f.write(f"## #{k}  ({ts})\n\n{body}\n\n")
            elif kind == "T":
                summary = body.get("command") or body.get("file_path") or json.dumps(body, ensure_ascii=False)
                f.write(f"> [tool {k}] {str(summary).splitlines()[0][:200] if summary else ''}\n\n")

    kw = json.loads(pathlib.Path(ROOT, "config", "extract-keywords.json").read_text(encoding="utf-8"))
    with open(os.path.join(out, "keywords.md"), "w", encoding="utf-8") as f:
        f.write("# Keyword extraction (mechanical)\n\nKeywords: config/extract-keywords.json. Sentences quoted verbatim.\n\n")
        for cat, words in kw.items():
            f.write(f"## {cat}  (keywords: {', '.join(words)})\n\n")
            for kind, k, body, _ in events:
                if kind != "A":
                    continue
                for s in re.split(r"(?<=。)|\n", body):
                    s = s.strip()
                    hit = [w for w in words if w in s]
                    if s and hit:
                        f.write(f"- #{k} [{', '.join(hit)}] {s}\n")
            f.write("\n")

    with open(os.path.join(out, "commands.md"), "w", encoding="utf-8") as f:
        f.write("# Tool calls by the agent (verbatim)\n\nLines mentioning tlc / tla2tools / z3 / lean / lake / node / python are marked with *.\n\n")
        i = 0
        for kind, k, body, ts in events:
            if kind != "T":
                continue
            i += 1
            text = body.get("command") if isinstance(body, dict) and "command" in body else json.dumps(body, ensure_ascii=False)
            mark = "*" if re.search(r"\b(tlc|tla2tools|tla2sany|pcal|z3|lean|lake|node|python3?)\b", str(text)) else " "
            f.write(f"### {mark} call {i}: {k}  ({ts})\n\n```\n{str(text)[:6000]}\n```\n\n")

    op = os.path.join(run, "record", "operator.jsonl")
    with open(os.path.join(out, "operator.md"), "w", encoding="utf-8") as f:
        f.write("# Operator decisions and the agent messages they answered\n\n")
        if not os.path.exists(op):
            f.write("(no operator log: this run was not driven by the blind operator)\n")
        else:
            q = 0
            for line in pathlib.Path(op).read_text(encoding="utf-8").split("\n"):
                if not line.strip():
                    continue
                d = json.loads(line)
                if d.get("event") == "sent":
                    if d.get("operator_choice") == "1":
                        q += 1
                    f.write(f"## after #{d.get('after_message')}: sent 「{d.get('sent')}」 (choice {d.get('operator_choice')}, confirmed {d.get('confirmed')})\n\n"
                            f"operator reason: {d.get('operator_reason')}\n\nagent message (verbatim):\n\n{d.get('agent_text')}\n\n")
                elif d.get("event") == "dialog":
                    q += 1
                    f.write(f"## dialog (AskUserQuestion): {d.get('action')}\n\nquestions (verbatim): {json.dumps(d.get('questions'), ensure_ascii=False)}\n\n")
                else:
                    f.write(f"## {d.get('event')}: {d.get('reason') or d.get('raw', '')}\n\n")
            f.write(f"\nquestions answered with the fixed reply: {q}\n")
    print(f"wrote {out}: {n} agent messages, {u} human messages")


if __name__ == "__main__":
    main()
