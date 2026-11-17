"""The user role (staged.py) and the blind operator (driver.py): a model called as `claude -p
--output-format json`. Output parsing, the role message and the retry rule. No I/O."""
import json
import re

from stages import TYPES

ATTEMPTS = 3
TIMEOUT_SECS = 300
NO_TEXT = "（テキストなし）"


def model_result(stdout):
    """(raw, result): stdout decoded, and its "result" field (or the whole text if not JSON)."""
    raw = stdout.decode("utf-8", "replace")
    try:
        result = json.loads(raw).get("result", "")
    except ValueError:
        result = raw
    return raw, result


def ask(run_once, message, parse):
    """Up to ATTEMPTS calls of run_once(message) -> stdout until parse(result) is not None.
    Returns (parsed, result, attempts), or (None, raw output of the last call, ATTEMPTS)."""
    raw = ""
    for attempt in range(ATTEMPTS):
        raw, result = model_result(run_once(message))
        parsed = parse(result)
        if parsed is not None:
            return parsed, result, attempt + 1
    return None, raw, ATTEMPTS


def parse_role(result, stage, verdict):
    """The user role's answer: {"choice": "REPLY" | "COMPLETE"} in stages 1 and 4,
    {"choice": "REPLY"} or {"choice": "JUDGE", "types": {type: verdict word}} otherwise, or None."""
    lines = [ln.strip() for ln in result.strip().splitlines() if ln.strip()]
    if not lines:
        return None
    if stage in (1, 4):
        return {"choice": lines[0]} if lines[0] in ("REPLY", "COMPLETE") else None
    if lines[0] == "REPLY":
        return {"choice": "REPLY"}
    got = {}
    for ln in lines:
        m = re.match(r"^([123])\s*[:：]\s*(APPROVE|REMAKE|EVIDENCE)\b", ln)
        if m:
            got[int(m.group(1))] = m.group(2)
    pending = [t for t in TYPES if verdict[t] is None]
    return {"choice": "JUDGE", "types": got} if all(t in got for t in pending) else None


def role_message(stage, verdict, texts, texts_at_send):
    """Stage header plus every agent text block written since the harness last sent a message."""
    head = f"現在の段階: {stage}\n"
    if stage == 3:
        pending = [str(t) for t in TYPES if verdict[t] is None]
        head += f"判断が済んでいない種類: {', '.join(pending)}\n"
    text = "\n\n".join(t for n, t in texts if n > texts_at_send)
    return head + "\nアシスタントの最後の発言:\n\n" + (text or NO_TEXT)


def parse_operator(result):
    """The blind operator's answer: (choice "1" | "2", reason) or None."""
    first = result.strip().splitlines()[0].strip() if result.strip() else ""
    if first in ("1", "2"):
        return first, " ".join(result.strip().splitlines()[1:]).strip()
    return None
