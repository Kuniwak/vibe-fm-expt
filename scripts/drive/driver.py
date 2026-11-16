"""Drive one interactive session according to the fixed procedure.

Runs the agent command (docker run -it ...) in a pseudo-terminal, records all terminal
output, follows the session transcript inside the container, and at each end of the
agent's turn sends one of two fixed messages:

  - PROTOCOL_REPLY  when the blind operator judges that the agent asks the human something
  - PROTOCOL_FIXED  when it does not, or when PROTOCOL_MAX_REPLIES replies were already sent

After the agent answers PROTOCOL_FIXED, the session is ended with /exit.
When the agent opens a choice dialog (AskUserQuestion), PROTOCOL_REPLY is typed into its
free-text field without consulting the operator.

Usage: driver.py --container NAME --log-dir DIR --operator-cmd JSON --operator-prompt FILE
                 --reply TEXT --fixed TEXT --max-replies N [--mirror] -- CMD...
"""
import argparse
import fcntl
import json
import os
import pathlib
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time

ROWS, COLS = 50, 200
QUIET_SECS = 20          # transcript and processes must be quiet this long before acting
POLL_SECS = 2
# Preregistration 12.5: once the agent's turn has ended, leftover child processes (e.g. a background
# wait that never finishes) delay the operator by at most this long.
BUSY_GRACE_SECS = 600


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


class Session:
    def __init__(self, a):
        self.a = a
        # Both logs stay open for the whole session; they are closed when the process exits.
        self.log = open(os.path.join(a.log_dir, "terminal.log"), "ab")  # noqa: SIM115
        self.oplog = open(  # noqa: SIM115
            os.path.join(a.log_dir, "operator.jsonl"), "a", encoding="utf-8")
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvp(a.cmd[0], a.cmd)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        self.lines = []           # parsed transcript records (main session only)
        self.offset = 0
        self.tfile = None
        self.texts = []           # (number, text) of every agent display-text block
        self.turn_ends = 0
        self.turn_end_at = None   # time.time() of the latest turn end
        self.grace_recorded = 0   # turn_ends value for which the grace event was recorded
        self.in_turn = False   # True from the first user/assistant record after a turn end until the next turn end
        self.handled_turns = 0
        self.last_change = time.time()
        self.replies = 0
        self.fixed_sent = False
        self.fixed_turn = None
        self.alive = True
        self.handled_questions = set()

    # ---------- terminal ----------
    def pump(self, secs):
        end = time.time() + secs
        while time.time() < end and self.alive:
            r, _, _ = select.select([self.fd], [], [], max(0.0, min(0.5, end - time.time())))
            if r:
                try:
                    data = os.read(self.fd, 65536)
                except OSError:
                    data = b""
                if not data:
                    self.alive = False
                    break
                self.log.write(data)
                self.log.flush()
                if self.a.mirror:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()

    def type(self, text, enter=True):
        os.write(self.fd, text.encode("utf-8"))
        self.pump(0.5)
        if enter:
            os.write(self.fd, b"\r")
        self.pump(0.5)

    def key(self, seq):
        os.write(self.fd, seq)
        self.pump(0.7)

    # ---------- transcript ----------
    def dexec(self, script):
        r = subprocess.run(["docker", "exec", self.a.container, "sh", "-c", script],
                           check=False, capture_output=True)
        return r.stdout

    def poll(self):
        if self.tfile is None:
            out = self.dexec('ls -1tr "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | head -1').decode().strip()
            if not out:
                return
            self.tfile = out
        chunk = self.dexec(f"tail -c +{self.offset + 1} '{self.tfile}'")
        if not chunk:
            return
        cut = chunk.rfind(b"\n") + 1
        if cut == 0:
            return
        self.offset += cut
        self.last_change = time.time()
        for raw in chunk[:cut].splitlines():
            try:
                d = json.loads(raw)
            except ValueError:
                continue
            if d.get("isSidechain"):
                continue
            self.lines.append(d)
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            if d.get("type") == "assistant" and isinstance(m.get("content"), list):
                for c in m["content"]:
                    if c.get("type") == "text" and c.get("text", "").strip():
                        self.texts.append((len(self.texts) + 1, c["text"]))
            if d.get("type") == "system" and d.get("subtype") == "turn_duration":
                self.turn_ends += 1
                self.in_turn = False
                self.turn_end_at = time.time()
            elif d.get("type") in ("user", "assistant"):
                # e.g. a task-notification from a finished background task starts a new turn
                self.in_turn = True

    def busy(self):
        """True while the agent still has child processes (e.g. a background build)."""
        out = self.dexec("ps -eo comm= | sort | uniq -c").decode()
        names = {ln.split()[-1] for ln in out.splitlines() if ln.strip()}
        others = names - {"docker-init", "claude", "ps", "sort", "uniq", "sh"}
        if not others:
            return False
        # Preregistration 12.5: the turn has ended and the processes have outlived the grace period.
        if not self.in_turn and self.turn_end_at is not None and time.time() - self.turn_end_at >= BUSY_GRACE_SECS:
            if self.grace_recorded != self.turn_ends:
                self.grace_recorded = self.turn_ends
                self.record(event="busy_grace_elapsed", turn=self.turn_ends,
                            seconds_since_turn_end=int(time.time() - self.turn_end_at),
                            processes=sorted(others))
            return False
        return True

    def pending_question(self):
        """Return the tool_use id of an AskUserQuestion call that has no result yet."""
        asked, answered = {}, set()
        for d in self.lines:
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            for c in m.get("content", []) if isinstance(m.get("content"), list) else []:
                if c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                    asked[c["id"]] = c.get("input", {})
                if c.get("type") == "tool_result":
                    answered.add(c.get("tool_use_id"))
        for k, v in asked.items():
            if k not in answered and k not in self.handled_questions:
                return k, v
        return None, None

    def user_messages(self):
        out = []
        for d in self.lines:
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            if d.get("type") == "user" and isinstance(m.get("content"), str):
                out.append(m["content"])
        return out

    # ---------- operator ----------
    def operator(self, text):
        prompt = pathlib.Path(self.a.operator_prompt).read_text(encoding="utf-8")
        cmd = json.loads(self.a.operator_cmd) + ["--system-prompt", prompt]
        for attempt in range(3):
            r = subprocess.run(cmd, input=(text or "（テキストなし）").encode("utf-8"),
                               check=False, capture_output=True, timeout=300)
            out = r.stdout.decode("utf-8", "replace")
            try:
                result = json.loads(out).get("result", "")
            except ValueError:
                result = out
            first = result.strip().splitlines()[0].strip() if result.strip() else ""
            if first in ("1", "2"):
                reason = " ".join(result.strip().splitlines()[1:]).strip()
                return first, reason, attempt + 1, result
        return None, "operator gave no valid answer", 3, out

    def record(self, **kw):
        kw["time"] = now()
        self.oplog.write(json.dumps(kw, ensure_ascii=False) + "\n")
        self.oplog.flush()

    def send_and_confirm(self, text):
        before = len(self.user_messages())
        self.type(text)
        for _ in range(30):
            self.pump(1)
            self.poll()
            msgs = self.user_messages()
            if len(msgs) > before and msgs[-1] == text:
                return True
        return False

    # ---------- AskUserQuestion ----------
    def answer_dialog(self, qid, qinput):
        n = len(qinput.get("questions", [])) or 1
        self.record(event="dialog", tool_use_id=qid, questions=qinput.get("questions"),
                    action=f"typed {self.a.reply!r} into the free-text option of {n} question(s)")
        # Layout per question: options 1..k, then "k+1. Type something." (free text), then a
        # separator and "Chat about this". The cursor starts on option 1, so k presses of the
        # down arrow land on the free-text entry; typing there and pressing Enter answers it.
        for q in qinput.get("questions", []) or [{}]:
            for _ in range(len(q.get("options", []))):
                self.key(b"\x1b[B")
            self.type(self.a.reply, enter=True)
            self.pump(1.5)
        # A review screen may follow; press Enter once more only if the dialog is still open.
        for _ in range(5):
            self.pump(1)
            self.poll()
            if not self.dialog_open(qid):
                break
        else:
            self.key(b"\r")
        self.handled_questions.add(qid)

    def dialog_open(self, qid):
        for d in self.lines:
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            for c in m.get("content", []) if isinstance(m.get("content"), list) else []:
                if c.get("type") == "tool_result" and c.get("tool_use_id") == qid:
                    return False
        return True

    # ---------- main loop ----------
    def run(self):
        while self.alive:
            self.pump(POLL_SECS)
            self.poll()
            qid, qinput = self.pending_question()
            if qid and time.time() - self.last_change > 5:
                self.answer_dialog(qid, qinput)
                continue
            if self.turn_ends <= self.handled_turns:
                continue
            # Act only at a break: the latest turn has ended and nothing has started since.
            if self.in_turn or time.time() - self.last_change < QUIET_SECS or self.busy():
                continue
            self.handled_turns = self.turn_ends
            last = self.texts[-1] if self.texts else (0, "")
            if self.fixed_sent:
                self.record(event="end", after_message=last[0], reason="agent answered the fixed message")
                self.type("/exit")
                self.pump(30)
                break
            if self.replies >= self.a.max_replies:
                choice, reason, tries, raw = "2", f"reply limit {self.a.max_replies} reached", 0, ""
            else:
                choice, reason, tries, raw = self.operator(last[1])
            if choice is None:
                self.record(event="operator_error", after_message=last[0], raw=raw)
                self.type("/exit")
                self.pump(30)
                break
            text = self.a.reply if choice == "1" else self.a.fixed
            ok = self.send_and_confirm(text)
            self.record(event="sent", after_message=last[0], agent_text=last[1], operator_choice=choice,
                        operator_reason=reason, operator_attempts=tries, sent=text, confirmed=ok)
            if choice == "1":
                self.replies += 1
            else:
                self.fixed_sent = True
        try:
            os.kill(self.pid, signal.SIGHUP)
        except OSError:
            pass
        _, status = os.waitpid(self.pid, 0)
        summary = {"replies_sent": self.replies, "fixed_sent": self.fixed_sent,
                   "agent_messages": len(self.texts), "turns": self.turn_ends,
                   "exit_status": os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status}
        with open(os.path.join(self.a.log_dir, "driver-summary.json"), "w") as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)
        return 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--container", required=True)
    p.add_argument("--log-dir", required=True)
    p.add_argument("--operator-cmd", required=True)
    p.add_argument("--operator-prompt", required=True)
    p.add_argument("--reply", required=True)
    p.add_argument("--fixed", required=True)
    p.add_argument("--max-replies", type=int, required=True)
    p.add_argument("--mirror", action="store_true")
    p.add_argument("cmd", nargs=argparse.REMAINDER)
    a = p.parse_args()
    if a.cmd and a.cmd[0] == "--":
        a.cmd = a.cmd[1:]
    return Session(a).run()


if __name__ == "__main__":
    sys.exit(main())
