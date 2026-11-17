"""The session transcript (JSONL inside the container) as state, with pure queries. No I/O.

feed() takes the bytes read from the current offset on; only complete lines are consumed.
"""
import json


def _message(d):
    return d.get("message") if isinstance(d.get("message"), dict) else {}


def _contents(d):
    m = _message(d)
    return m.get("content", []) if isinstance(m.get("content"), list) else []


def _is_delivery(d, text):
    """A user message equal to text: typed at a break, or queued into a running turn."""
    m = _message(d)
    a = d.get("attachment") if isinstance(d.get("attachment"), dict) else {}
    typed = d.get("type") == "user" and m.get("content") == text
    queued = d.get("type") == "attachment" and a.get("type") == "queued_command" and a.get("prompt") == text
    return typed or queued


class Transcript:
    def __init__(self, now):
        self.lines = []           # parsed transcript records (main session only)
        self.offset = 0           # bytes consumed
        self.texts = []           # (number, text) of every agent display-text block
        self.turn_ends = 0
        self.turn_end_at = None   # time of the latest turn end
        self.in_turn = False      # True from the first user/assistant record after a turn end until the next turn end
        self.last_change = now    # time complete lines last arrived

    def feed(self, chunk, now):
        """Consume the complete lines of chunk (the file from self.offset on). True if any."""
        if not chunk:
            return False
        cut = chunk.rfind(b"\n") + 1
        if cut == 0:
            return False
        self.offset += cut
        self.last_change = now
        for raw in chunk[:cut].splitlines():
            try:
                d = json.loads(raw)
            except ValueError:
                continue
            if d.get("isSidechain"):
                continue
            self.lines.append(d)
            m = _message(d)
            if d.get("type") == "assistant" and isinstance(m.get("content"), list):
                for c in m["content"]:
                    if c.get("type") == "text" and c.get("text", "").strip():
                        self.texts.append((len(self.texts) + 1, c["text"]))
            if d.get("type") == "system" and d.get("subtype") == "turn_duration":
                self.turn_ends += 1
                self.in_turn = False
                self.turn_end_at = now
            elif d.get("type") in ("user", "assistant"):
                # e.g. a task-notification from a finished background task starts a new turn
                self.in_turn = True
        return True

    # ---------- queries ----------
    def last_text(self):
        return self.texts[-1] if self.texts else (0, "")

    def user_messages(self):
        out = []
        for d in self.lines:
            m = _message(d)
            if d.get("type") == "user" and isinstance(m.get("content"), str):
                out.append(m["content"])
        return out

    def pending_question(self, handled):
        """(tool_use id, input) of the first AskUserQuestion call with no result that is not in
        handled, or (None, None)."""
        asked, answered = {}, set()
        for d in self.lines:
            for c in _contents(d):
                if c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                    asked[c["id"]] = c.get("input", {})
                if c.get("type") == "tool_result":
                    answered.add(c.get("tool_use_id"))
        for k, v in asked.items():
            if k not in answered and k not in handled:
                return k, v
        return None, None

    def dialog_open(self, qid):
        for d in self.lines:
            for c in _contents(d):
                if c.get("type") == "tool_result" and c.get("tool_use_id") == qid:
                    return False
        return True

    def delivered(self, text):
        """Count of user messages equal to text, including ones delivered inside a running turn."""
        return sum(1 for d in self.lines if _is_delivery(d, text))

    def delivery_index(self, text):
        """Index in self.lines of the last delivery of text, or None."""
        idx = None
        for i, d in enumerate(self.lines):
            if _is_delivery(d, text):
                idx = i
        return idx

    def answered_after(self, idx):
        """True if an agent display-text block was written after self.lines[idx]."""
        for d in self.lines[idx + 1:]:
            m = _message(d)
            if d.get("type") == "assistant" and isinstance(m.get("content"), list) and \
               any(c.get("type") == "text" and c.get("text", "").strip() for c in m["content"]):
                return True
        return False
