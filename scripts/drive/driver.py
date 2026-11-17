"""Drive one interactive session according to the fixed procedure.

Runs the agent command (docker run -it ...) in a pseudo-terminal, records all terminal
output, follows the session transcript inside the container, and at each end of the
agent's turn sends one of two fixed messages:

  - PROTOCOL_REPLY  when the blind operator judges that the agent asks the human something
  - PROTOCOL_FIXED  when it does not, or when PROTOCOL_MAX_REPLIES replies were already sent

After the agent answers PROTOCOL_FIXED, the session is ended with /exit.
When the agent opens a choice dialog (AskUserQuestion), PROTOCOL_REPLY is typed into its
free-text field without consulting the operator.

This file is the I/O shell: the terminal, docker exec, the operator subprocess and the records.
Every decision lives in a module without I/O: transcript.py (transcript state), busy.py,
screen.py, dialog.py, role.py, policy.py (main-loop tick), protocol.py (this procedure).

Usage: driver.py --container NAME --log-dir DIR --operator-cmd JSON --operator-prompt FILE
                 --reply TEXT --fixed TEXT --max-replies N [--mirror]
                 [--poll-secs 2] [--quiet-secs 20] [--busy-grace-secs 600] -- CMD...
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
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import busy  # noqa: E402
import dialog  # noqa: E402
import policy  # noqa: E402
import protocol  # noqa: E402
import role  # noqa: E402
import screen  # noqa: E402
from transcript import Transcript  # noqa: E402

ROWS, COLS = 50, 200
QUIET_SECS = 20          # transcript and processes must be quiet this long before acting
POLL_SECS = 2
BUSY_GRACE_SECS = busy.BUSY_GRACE_SECS


@dataclass(frozen=True)
class Timing:
    """Every wait of the harness. The defaults are the preregistered procedure; a test may shorten them."""
    poll_secs: float = POLL_SECS
    quiet_secs: float = QUIET_SECS
    busy_grace_secs: float = BUSY_GRACE_SECS
    dialog_quiet_secs: float = 5        # a pending dialog is answered once the transcript is this quiet
    type_pause: float = 0.5             # after typing a text, and after its Enter
    key_pause: float = 0.7              # after a key
    question_pause: float = dialog.QUESTION_PAUSE
    dialog_polls: int = dialog.CONFIRM_POLLS
    confirm_poll_secs: float = 1
    confirm_polls: int = 30             # driver.py: polls for the delivery of a sent message
    confirm_wait_secs: float = 120      # staged.py: wait for the delivery of a sent message
    exit_pump_secs: float = 30          # after /exit
    role_timeout_secs: float = role.TIMEOUT_SECS

    @classmethod
    def from_args(cls, a):
        return cls(poll_secs=getattr(a, "poll_secs", POLL_SECS), quiet_secs=getattr(a, "quiet_secs", QUIET_SECS),
                   busy_grace_secs=getattr(a, "busy_grace_secs", BUSY_GRACE_SECS))


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


class Terminal:
    """The agent's pseudo-terminal. Everything read is appended to log (terminal.log)."""

    def __init__(self, cmd, log, mirror, timing):
        self.log = log
        self.mirror = mirror
        self.timing = timing
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvp(cmd[0], cmd)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        self.alive = True

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
                if self.mirror:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()

    def write(self, data):
        # The container can be stopped at any moment (overall time limit); a write to the closed
        # terminal then fails. Treat it as the end of the session instead of an exception.
        if not self.alive:
            return
        try:
            os.write(self.fd, data)
        except OSError:
            self.alive = False

    def type(self, text, enter=True):
        self.write(text.encode("utf-8"))
        self.pump(self.timing.type_pause)
        if enter:
            self.write(b"\r")
        self.pump(self.timing.type_pause)

    def key(self, seq):
        self.write(seq)
        self.pump(self.timing.key_pause)

    def tail(self, n):
        """The last n bytes of the terminal log, or None if it cannot be read."""
        try:
            with open(self.log.name, "rb") as f:
                f.seek(0, os.SEEK_END)
                f.seek(max(0, f.tell() - n))
                return f.read()
        except OSError:
            return None

    def hangup(self):
        """SIGHUP the agent command and return its wait status."""
        try:
            os.kill(self.pid, signal.SIGHUP)
        except OSError:
            pass
        _, status = os.waitpid(self.pid, 0)
        return status


class Container:
    """docker exec into the agent's container."""

    def __init__(self, name):
        self.name = name

    def exec(self, script):
        r = subprocess.run(["docker", "exec", self.name, "sh", "-c", script], check=False, capture_output=True)
        return r.stdout

    def find_transcript(self):
        return self.exec('ls -1tr "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | head -1').decode().strip()

    def read_from(self, path, offset):
        """The bytes of path from offset (0-based) on."""
        return self.exec(f"tail -c +{offset + 1} '{path}'")

    def ps(self):
        return self.exec(busy.PS_SCRIPT).decode()

    def snapshot(self, dest, excludes, err):
        """Copy home/dev and tmp of the container into dest; stderr goes to the open file err.
        Returns [exit status of tar in the container, exit status of tar -x]."""
        excl = " ".join(f"--exclude='{e}'" for e in excludes)
        tar = subprocess.Popen(["docker", "exec", self.name, "sh", "-c", f"cd / && tar -cf - {excl} home/dev tmp"],
                               stdout=subprocess.PIPE, stderr=err)
        x = subprocess.run(["tar", "-x", "-C", dest], stdin=tar.stdout, stderr=err, check=False)
        tar.wait()
        return [tar.returncode, x.returncode]


class Session:
    def __init__(self, a, timing=None):
        self.a = a
        self.timing = timing or Timing.from_args(a)
        # Both logs stay open for the whole session; they are closed when the process exits.
        self.log = open(os.path.join(a.log_dir, "terminal.log"), "ab")  # noqa: SIM115
        self.oplog = open(  # noqa: SIM115
            os.path.join(a.log_dir, "operator.jsonl"), "a", encoding="utf-8")
        self.term = Terminal(a.cmd, self.log, a.mirror, self.timing)
        self.container = Container(getattr(a, "container", None))
        self.t = Transcript(now=time.time())
        self.tfile = None
        self.grace_recorded = 0   # turn_ends value for which the grace event was recorded
        self.handled_turns = 0
        self.handled_questions = set()
        self.replies = 0
        self.fixed_sent = False

    # ---------- terminal ----------
    @property
    def alive(self):
        return self.term.alive

    def pump(self, secs):
        self.term.pump(secs)

    def type(self, text, enter=True):
        self.term.type(text, enter)

    def key(self, seq):
        self.term.key(seq)

    def dialog_on_screen(self):
        tail = self.term.tail(screen.TAIL_BYTES)
        return tail is not None and screen.dialog_on_screen(tail)

    def exit(self):
        self.type("/exit")
        self.pump(self.timing.exit_pump_secs)

    # ---------- container ----------
    def poll(self):
        if self.tfile is None:
            out = self.container.find_transcript()
            if not out:
                return
            self.tfile = out
        self.t.feed(self.container.read_from(self.tfile, self.t.offset), time.time())

    def busy(self):
        """True while the agent still has child processes (e.g. a background build)."""
        out = self.container.ps()
        b, event = busy.decide(out, in_turn=self.t.in_turn, turn_end_at=self.t.turn_end_at,
                               turn_ends=self.t.turn_ends, grace_recorded=self.grace_recorded,
                               now=time.time(), grace=self.timing.busy_grace_secs)
        if event is not None:
            self.grace_recorded = self.t.turn_ends
            self.record(event="busy_grace_elapsed", **event)
        return b

    # ---------- model (operator / user role) ----------
    def call_model(self, message, parse):
        prompt = pathlib.Path(self.a.operator_prompt).read_text(encoding="utf-8")
        cmd = json.loads(self.a.operator_cmd) + ["--system-prompt", prompt]

        def run_once(m):
            return subprocess.run(cmd, input=m.encode("utf-8"), check=False, capture_output=True,
                                  timeout=self.timing.role_timeout_secs).stdout
        return role.ask(run_once, message, parse)

    def operator(self, text):
        parsed, result, tries = self.call_model(text or role.NO_TEXT, role.parse_operator)
        if parsed is None:
            return None, "operator gave no valid answer", tries, result
        return parsed[0], parsed[1], tries, result

    # ---------- records ----------
    def record(self, **kw):
        kw["time"] = now()
        self.oplog.write(json.dumps(kw, ensure_ascii=False) + "\n")
        self.oplog.flush()

    def send_and_confirm(self, text):
        before = len(self.t.user_messages())
        self.type(text)
        for _ in range(self.timing.confirm_polls):
            if not self.alive:
                break
            self.pump(self.timing.confirm_poll_secs)
            self.poll()
            msgs = self.t.user_messages()
            if len(msgs) > before and msgs[-1] == text:
                return True
        return False

    # ---------- AskUserQuestion ----------
    def run_ops(self, ops):
        for op in ops:
            if op[0] == "key":
                self.key(op[1])
            elif op[0] == "type":
                self.type(op[1], enter=op[2])
            else:
                self.pump(op[1])

    def dialog_closed(self, qid):
        """Poll up to dialog_polls times; True as soon as the dialog has its result."""
        for _ in range(self.timing.dialog_polls):
            self.pump(self.timing.confirm_poll_secs)
            self.poll()
            if not self.t.dialog_open(qid):
                return True
        return False

    def answer_dialog(self, qid, qinput):
        self.record(event="dialog", **dialog.record_fields(qid, qinput, self.a.reply))
        self.run_ops(dialog.keystrokes(qinput, self.a.reply, self.timing.question_pause))
        # A review screen may follow; press Enter once more only if the dialog is still open.
        if not self.dialog_closed(qid):
            self.key(dialog.ENTER)
            if not self.dialog_closed(qid) and self.alive:
                # a closed terminal is recorded as pty_closed, not as a dialog problem
                self.record(event="dialog_still_open", tool_use_id=qid)
        self.handled_questions.add(qid)

    # ---------- main loop ----------
    def time_up_now(self):
        return False

    def on_time_up(self):
        raise AssertionError("no time limit in this procedure")

    def tick(self):
        """One iteration of the main loop. False when the session is to end."""
        self.pump(self.timing.poll_secs)
        self.poll()
        qid, qinput = self.t.pending_question(self.handled_questions)
        act = policy.decide(now=time.time(), qid=qid, last_change=self.t.last_change,
                            turn_ends=self.t.turn_ends, handled_turns=self.handled_turns, in_turn=self.t.in_turn,
                            time_up=self.time_up_now(), quiet=self.timing.quiet_secs,
                            dialog_quiet=self.timing.dialog_quiet_secs,
                            on_screen=self.dialog_on_screen, busy=self.busy)
        if act == policy.DIALOG:
            self.answer_dialog(qid, qinput)
        elif act == policy.TIME_UP:
            self.on_time_up()
        elif act == policy.BREAK:
            self.handled_turns = self.t.turn_ends
            return self.at_break()
        return True

    def at_break(self):
        last = self.t.last_text()
        what = protocol.at_break(fixed_sent=self.fixed_sent, replies=self.replies, max_replies=self.a.max_replies)
        if what == protocol.END:
            self.record(**protocol.end_record(last))
            self.exit()
            return False
        if what == protocol.LIMIT:
            choice, reason, tries, raw = protocol.limit_answer(self.a.max_replies)
        else:
            choice, reason, tries, raw = self.operator(last[1])
        if choice is None:
            self.record(**protocol.error_record(last, raw))
            self.exit()
            return False
        text, replies, fixed_sent = protocol.after_answer(choice, replies=self.replies, fixed_sent=self.fixed_sent,
                                                          reply=self.a.reply, fixed=self.a.fixed)
        ok = self.send_and_confirm(text)
        self.record(**protocol.sent_record(last, choice, reason, tries, text, ok))
        self.replies, self.fixed_sent = replies, fixed_sent
        return True

    def run(self):
        while self.alive:
            if not self.tick():
                break
        self.finish(self.term.hangup())
        return 0

    def write_summary(self, summary):
        with open(os.path.join(self.a.log_dir, "driver-summary.json"), "w") as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)

    def finish(self, status):
        self.write_summary({**protocol.summary_fields(self.replies, self.fixed_sent),
                            "agent_messages": len(self.t.texts), "turns": self.t.turn_ends,
                            "exit_status": os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode")
                            else status})


def add_timing_args(p):
    p.add_argument("--poll-secs", type=float, default=POLL_SECS)
    p.add_argument("--quiet-secs", type=float, default=QUIET_SECS)
    p.add_argument("--busy-grace-secs", type=float, default=BUSY_GRACE_SECS)


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
    add_timing_args(p)
    p.add_argument("cmd", nargs=argparse.REMAINDER)
    a = p.parse_args()
    if a.cmd and a.cmd[0] == "--":
        a.cmd = a.cmd[1:]
    return Session(a).run()


if __name__ == "__main__":
    sys.exit(main())
