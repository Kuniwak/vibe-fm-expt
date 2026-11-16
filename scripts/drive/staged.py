"""Drive one session of conditions D and D2 (preregistration.md ch. 11): the prescription applied
in stages, with a user-role model that follows fixed rules.

Stages
  1  first verification: the first message is sent by the command line; the user role answers
     questions with REPLY and recognises the completion report (COMPLETE).
  2  snapshot S1, then the sensitivity request (fixed text, --stage2-file).
  3  variant review: per bug type APPROVE / REMAKE / EVIDENCE; at most two instructions per type,
     then the type is recorded as "variant could not be made".
  4  snapshot S2, then the fix request (--stage4-file). 60 minutes later the time-up text is typed
     even if the agent is working; if the agent reports completion first, the same text without
     "時間です。" is sent at that break.
  5  after the summary, the final question (--fixed); after its answer, snapshot S3 and /exit.

Everything the user role receives and returns is written to operator.jsonl.
Usage: staged.py --container NAME --log-dir DIR --operator-cmd JSON --operator-prompt FILE
                 --reply TEXT --fixed TEXT --stage2-file F --stage4-file F --timeup-file F
                 --done-file F --snapshot-dir DIR [--stage4-minutes 60] [--mirror] -- CMD...
"""
import argparse
import json
import os
import pathlib
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from driver import POLL_SECS, QUIET_SECS, Session

TYPES = (1, 2, 3)
MAX_INSTRUCTIONS = 2
REMAKE_TEXT = "{n}番の変種は、意図したバグと違います。挙げた記述に当たるバグを埋め込み直して、確かめ直してください。"
EVIDENCE_TEXT = "{n}番は、違反を示す具体的な入力と、そのときの結果を見せてください。"
SNAPSHOT_EXCLUDES = ["home/dev/.elan", "home/dev/.cache", "home/dev/.npm",
                     "home/dev/jsdoctypeparser/node_modules", "*/.lake/packages",
                     "tmp/node-compile-cache"]   # Node's cache from the image build; not readable by dev


def read_text(path):
    t = pathlib.Path(path).read_text(encoding="utf-8")
    return t.removesuffix("\n")


class StagedSession(Session):
    def __init__(self, a):
        super().__init__(a)
        self.stage = 1
        self.verdict = {t: None for t in TYPES}      # APPROVE / FAILED
        self.instructions = {t: 0 for t in TYPES}
        self.stage4_start = None
        self.summary_requested = False
        self.stage45_text = None
        self.texts_at_send = 0       # agent text blocks that existed when the harness last sent a message
        self.stage_times = {"stage1_start": time.time()}

    # ---------- user role ----------
    def user_role(self, message):
        prompt = pathlib.Path(self.a.operator_prompt).read_text(encoding="utf-8")
        cmd = json.loads(self.a.operator_cmd) + ["--system-prompt", prompt]
        raw = ""
        for attempt in range(3):
            r = subprocess.run(cmd, input=message.encode("utf-8"), check=False,
                               capture_output=True, timeout=300)
            raw = r.stdout.decode("utf-8", "replace")
            try:
                result = json.loads(raw).get("result", "")
            except ValueError:
                result = raw
            parsed = self.parse(result)
            if parsed is not None:
                return parsed, result, attempt + 1
        return None, raw, 3

    def parse(self, result):
        lines = [ln.strip() for ln in result.strip().splitlines() if ln.strip()]
        if not lines:
            return None
        if self.stage in (1, 4):
            return {"choice": lines[0]} if lines[0] in ("REPLY", "COMPLETE") else None
        if lines[0] == "REPLY":
            return {"choice": "REPLY"}
        got = {}
        for ln in lines:
            m = re.match(r"^([123])\s*[:：]\s*(APPROVE|REMAKE|EVIDENCE)\b", ln)
            if m:
                got[int(m.group(1))] = m.group(2)
        pending = [t for t in TYPES if self.verdict[t] is None]
        return {"choice": "JUDGE", "types": got} if all(t in got for t in pending) else None

    def role_message(self):
        """Stage header plus every agent text block written since the harness last sent a message."""
        head = f"現在の段階: {self.stage}\n"
        if self.stage == 3:
            pending = [str(t) for t in TYPES if self.verdict[t] is None]
            head += f"判断が済んでいない種類: {', '.join(pending)}\n"
        text = "\n\n".join(t for n, t in self.texts if n > self.texts_at_send)
        return head + "\nアシスタントの最後の発言:\n\n" + (text or "（テキストなし）")

    # ---------- snapshots ----------
    def snapshot(self, label):
        dest = os.path.join(self.a.snapshot_dir, label)
        os.makedirs(dest, exist_ok=True)
        excl = " ".join(f"--exclude='{e}'" for e in SNAPSHOT_EXCLUDES)
        err = os.path.join(self.a.log_dir, f"snapshot-{label}.err")
        with open(err, "wb") as ef:
            tar = subprocess.Popen(["docker", "exec", self.a.container, "sh", "-c",
                                    f"cd / && tar -cf - {excl} home/dev tmp"],
                                   stdout=subprocess.PIPE, stderr=ef)
            x = subprocess.run(["tar", "-x", "-C", dest], stdin=tar.stdout, stderr=ef, check=False)
            tar.wait()
        self.record(event="snapshot", label=label, stage=self.stage,
                    tar_exit=[tar.returncode, x.returncode])

    # ---------- sending ----------
    def delivered(self, text):
        """Count of user messages equal to text, including ones delivered inside a running turn."""
        n = 0
        for d in self.lines:
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            a = d.get("attachment") if isinstance(d.get("attachment"), dict) else {}
            typed = d.get("type") == "user" and m.get("content") == text
            queued = d.get("type") == "attachment" and a.get("type") == "queued_command" and a.get("prompt") == text
            n += typed or queued
        return n

    def delivery_index(self, text):
        """Index in self.lines of the last delivery of text, or None."""
        idx = None
        for i, d in enumerate(self.lines):
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            a = d.get("attachment") if isinstance(d.get("attachment"), dict) else {}
            if (d.get("type") == "user" and m.get("content") == text) or \
               (d.get("type") == "attachment" and a.get("type") == "queued_command" and a.get("prompt") == text):
                idx = i
        return idx

    def answered_after(self, idx):
        """True if an agent display-text block was written after self.lines[idx]."""
        for d in self.lines[idx + 1:]:
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            if d.get("type") == "assistant" and isinstance(m.get("content"), list) and \
               any(c.get("type") == "text" and c.get("text", "").strip() for c in m["content"]):
                return True
        return False

    def send_and_confirm(self, text, wait=120):
        # A message typed during a running turn is written to the transcript only when the turn
        # takes it in (with the next tool result), so the wait is longer than in driver.py.
        before = self.delivered(text)
        self.type(text)
        end = time.time() + wait
        while time.time() < end and self.alive:
            self.pump(1)
            self.poll()
            if self.delivered(text) > before:
                return True
        return False

    def send(self, text, **kw):
        self.texts_at_send = len(self.texts)
        t0 = time.time()
        ok = self.send_and_confirm(text)
        self.record(event="sent", stage=self.stage, sent=text, confirmed=ok,
                    confirm_secs=round(time.time() - t0, 1), pty_alive=self.alive, **kw)

    def at_break(self):
        last = self.texts[-1] if self.texts else (0, "")
        if self.stage == 5:
            self.snapshot("S3")
            self.record(event="end", after_message=last[0], reason="agent answered the final question")
            self.type("/exit")
            self.pump(30)
            return False
        if self.stage == 45:
            # Advance only after the agent has written text following the time-up / done message.
            idx = self.delivery_index(self.stage45_text)
            if idx is None or not self.answered_after(idx):
                self.record(event="wait", stage=45, after_message=last[0],
                            reason="no agent text after the stage-4 closing message yet")
                return True
            self.stage = 5
            self.send(self.a.fixed, after_message=last[0], rule="段階5の固定文")
            return True
        message = self.role_message()
        parsed, raw, tries = self.user_role(message)
        base = {"after_message": last[0], "role_input": message, "role_output": raw, "role_attempts": tries}
        if parsed is None:
            self.record(event="role_error", stage=self.stage, **base)
            self.type("/exit")
            self.pump(30)
            return False
        if parsed["choice"] == "REPLY":
            self.send(self.a.reply, rule="規則による「お任せします」", **base)
            return True
        if self.stage == 1:                       # COMPLETE
            self.stage_times["stage2_start"] = time.time()
            self.snapshot("S1")
            self.stage = 3
            self.send(read_text(self.a.stage2_file), rule="段階2の固定文", **base)
            return True
        if self.stage == 3:                       # JUDGE
            parts, decisions = [], {}
            for t in TYPES:
                if self.verdict[t] is not None:
                    continue
                v = parsed["types"][t]
                if v == "APPROVE":
                    self.verdict[t] = "APPROVE"
                elif self.instructions[t] >= MAX_INSTRUCTIONS:
                    self.verdict[t] = "FAILED"    # 変種を作れなかった
                else:
                    self.instructions[t] += 1
                    parts.append((self.a.remake_text if v == "REMAKE" else self.a.evidence_text).format(n=t))
                decisions[t] = {"judgement": v, "verdict": self.verdict[t], "instructions": self.instructions[t]}
            self.record(event="review", stage=3, decisions=decisions, **base)
            if parts:
                self.send("\n".join(parts), rule="段階3の規則", **{k: v for k, v in base.items() if k == "after_message"})
                return True
            self.stage_times["stage4_start"] = time.time()
            self.snapshot("S2")
            self.stage = 4
            self.stage4_start = time.time()
            self.send(read_text(self.a.stage4_file), rule="段階4の固定文", after_message=last[0])
            return True
        if self.stage == 4:                       # COMPLETE before the time limit
            self.stage = 45
            self.stage45_text = read_text(self.a.done_file)
            self.send(self.stage45_text, rule="段階4の完了の報告を受けた（「時間です。」を省く）", **base)
            return True
        return True

    def dialog_on_screen(self):
        """True if the terminal shows a selection dialog that has not been answered yet.
        The AskUserQuestion record can reach the transcript a few seconds after the dialog is drawn
        (test-07), and text typed into an open dialog selects an option instead of being sent."""
        try:
            with open(self.log.name, "rb") as f:
                f.seek(0, os.SEEK_END)
                f.seek(max(0, f.tell() - 65536))
                tail = f.read()
        except OSError:
            return False
        shown = tail.rfind(b"Enter to select")
        return shown >= 0 and shown > tail.rfind(b"User answered") and shown > tail.rfind(b"User declined")

    def time_up(self):
        return (self.stage == 4 and self.stage4_start is not None
                and time.time() - self.stage4_start >= self.a.stage4_minutes * 60)

    # ---------- main loop ----------
    def run(self):
        while self.alive:
            self.pump(POLL_SECS)
            self.poll()
            qid, qinput = self.pending_question()
            if qid and time.time() - self.last_change > 5:
                self.answer_dialog(qid, qinput)
                continue
            if self.time_up() and not qid and not self.dialog_on_screen():
                # Typed even while the agent works; Claude Code delivers it inside the running turn.
                # Turn ends that happen from here on are handled by at_break (stage 45), which waits
                # until the agent has written text after the message.
                self.stage = 45
                self.stage45_text = read_text(self.a.timeup_file)
                last = self.texts[-1] if self.texts else (0, "")
                ends_before = self.turn_ends
                self.send(self.stage45_text, rule="段階4の制限時間（60分）", after_message=last[0],
                          agent_busy=self.in_turn or self.busy())
                self.handled_turns = min(self.handled_turns, ends_before)
                continue
            if self.turn_ends <= self.handled_turns:
                continue
            if self.in_turn or time.time() - self.last_change < QUIET_SECS or self.busy():
                continue
            self.handled_turns = self.turn_ends
            if not self.at_break():
                break
        if not self.alive:
            self.record(event="pty_closed", stage=self.stage)
        try:
            os.kill(self.pid, signal.SIGHUP)
        except OSError:
            pass
        _, status = os.waitpid(self.pid, 0)
        summary = {"final_stage": self.stage, "verdicts": self.verdict, "instructions": self.instructions,
                   "fixed_sent": self.stage == 5, "agent_messages": len(self.texts), "turns": self.turn_ends,
                   "stage_times": {k: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(v))
                                   for k, v in self.stage_times.items()},
                   "exit_status": os.waitstatus_to_exitcode(status)}
        with open(os.path.join(self.a.log_dir, "driver-summary.json"), "w") as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)
        return 0


def main():
    p = argparse.ArgumentParser()
    for name in ("container", "log-dir", "operator-cmd", "operator-prompt", "reply", "fixed",
                 "stage2-file", "stage4-file", "timeup-file", "done-file", "snapshot-dir"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--stage4-minutes", type=float, default=60)
    p.add_argument("--remake-text", default=REMAKE_TEXT)
    p.add_argument("--evidence-text", default=EVIDENCE_TEXT)
    p.add_argument("--max-replies", type=int, default=0)   # not used: no limit in stage 1 (ch. 11)
    p.add_argument("--mirror", action="store_true")
    p.add_argument("cmd", nargs=argparse.REMAINDER)
    a = p.parse_args()
    if a.cmd and a.cmd[0] == "--":
        a.cmd = a.cmd[1:]
    return StagedSession(a).run()


if __name__ == "__main__":
    sys.exit(main())
