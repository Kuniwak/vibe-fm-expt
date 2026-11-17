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
This file is the I/O shell; the procedure itself is the state machine in stages.py.
Usage: staged.py --container NAME --log-dir DIR --operator-cmd JSON --operator-prompt FILE
                 --reply TEXT --fixed TEXT --stage2-file F --stage4-file F --timeup-file F
                 --done-file F --snapshot-dir DIR [--stage4-minutes 60] [--mirror]
                 [--poll-secs 2] [--quiet-secs 20] [--busy-grace-secs 600] -- CMD...
"""
import argparse
import os
import pathlib
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import policy  # noqa: E402
import role  # noqa: E402
import stages  # noqa: E402
from driver import POLL_SECS, QUIET_SECS, Session, add_timing_args  # noqa: E402,F401
from stages import MAX_INSTRUCTIONS, TYPES  # noqa: E402,F401

REMAKE_TEXT = "{n}番の変種は、意図したバグと違います。挙げた記述に当たるバグを埋め込み直して、確かめ直してください。"
EVIDENCE_TEXT = "{n}番は、違反を示す具体的な入力と、そのときの結果を見せてください。"
SNAPSHOT_EXCLUDES = ["home/dev/.elan", "home/dev/.cache", "home/dev/.npm",
                     "home/dev/jsdoctypeparser/node_modules", "*/.lake/packages",
                     "tmp/node-compile-cache"]   # Node's cache from the image build; not readable by dev
TEXT_FILES = {"stage2": "stage2_file", "stage4": "stage4_file", "timeup": "timeup_file", "done": "done_file"}


def read_text(path):
    t = pathlib.Path(path).read_text(encoding="utf-8")
    return t.removesuffix("\n")


class StagedSession(Session):
    def __init__(self, a, timing=None):
        super().__init__(a, timing)
        self.state = stages.State()
        self.cfg = stages.Config(reply=a.reply, fixed=a.fixed, remake_text=a.remake_text,
                                 evidence_text=a.evidence_text,
                                 read=lambda key: read_text(getattr(a, TEXT_FILES[key])))
        self.stage4_start = None
        self.texts_at_send = 0       # agent text blocks that existed when the harness last sent a message
        self.stage_times = {"stage1_start": time.time()}

    # ---------- user role ----------
    def user_role(self, message):
        return self.call_model(message, lambda r: role.parse_role(r, self.state.stage, self.state.verdict))

    # ---------- snapshots ----------
    def snapshot(self, label, stage):
        dest = os.path.join(self.a.snapshot_dir, label)
        os.makedirs(dest, exist_ok=True)
        err = os.path.join(self.a.log_dir, f"snapshot-{label}.err")
        with open(err, "wb") as ef:
            tar_exit = self.container.snapshot(dest, SNAPSHOT_EXCLUDES, ef)
        self.record(event="snapshot", label=label, stage=stage, tar_exit=tar_exit)

    # ---------- sending ----------
    def send_and_confirm(self, text, wait=None):
        # A message typed during a running turn is written to the transcript only when the turn
        # takes it in (with the next tool result), so the wait is longer than in driver.py.
        wait = self.timing.confirm_wait_secs if wait is None else wait
        before = self.t.delivered(text)
        self.type(text)
        end = time.time() + wait
        while time.time() < end and self.alive:
            self.pump(self.timing.confirm_poll_secs)
            self.poll()
            if self.t.delivered(text) > before:
                return True
        return False

    def send(self, text, stage, **kw):
        self.texts_at_send = len(self.t.texts)
        t0 = time.time()
        ok = self.send_and_confirm(text)
        self.record(event="sent", stage=stage, sent=text, confirmed=ok,
                    confirm_secs=round(time.time() - t0, 1), pty_alive=self.alive, **kw)

    def execute(self, actions):
        """Carry out the actions of a stages step in order. False after Exit."""
        for act in actions:
            if isinstance(act, stages.MarkTime):
                self.stage_times[act.key] = time.time()
            elif isinstance(act, stages.Snapshot):
                self.snapshot(act.label, act.stage)
            elif isinstance(act, stages.StartClock):
                self.stage4_start = time.time()
            elif isinstance(act, stages.Send):
                text = self.cfg.read(act.text.key) if isinstance(act.text, stages.FileText) else act.text
                self.send(text, act.stage, **act.fields)
            elif isinstance(act, stages.Record):
                self.record(**act.fields)
            elif isinstance(act, stages.Exit):
                self.exit()
                return False
            else:
                raise AssertionError(f"unknown action {act!r}")
        return True

    # ---------- main loop ----------
    def at_break(self):
        last = self.t.last_text()
        kind = stages.break_kind(self.state)
        if kind == "final":
            self.state, actions = stages.final(self.state, last)
        elif kind == "closing":
            idx = self.t.delivery_index(self.state.stage45_text)
            answered = idx is not None and self.t.answered_after(idx)
            self.state, actions = stages.closing(self.state, self.cfg, last, answered)
        else:
            message = role.role_message(self.state.stage, self.state.verdict, self.t.texts, self.texts_at_send)
            parsed, raw, tries = self.user_role(message)
            self.state, actions = stages.after_role(self.state, self.cfg, last, message, parsed, raw, tries)
        return self.execute(actions)

    def time_up_now(self):
        return stages.is_time_up(self.state.stage, self.stage4_start, time.time(), self.a.stage4_minutes)

    def on_time_up(self):
        # Typed even while the agent works; Claude Code delivers it inside the running turn.
        # Turn ends that happen from here on are handled by at_break (stage 45), which waits
        # until the agent has written text after the message.
        last = self.t.last_text()
        ends_before = self.t.turn_ends
        agent_busy = self.t.in_turn or self.busy()
        self.state, actions = stages.time_up(self.state, self.cfg, last, agent_busy)
        self.execute(actions)
        self.handled_turns = policy.handled_after_time_up(self.handled_turns, ends_before)

    def run(self):
        while self.alive:
            if not self.tick():
                break
        if not self.alive:
            self.record(event="pty_closed", stage=self.state.stage)
        self.finish(self.term.hangup())
        return 0

    def finish(self, status):
        self.write_summary({**stages.summary_fields(self.state), "agent_messages": len(self.t.texts),
                            "turns": self.t.turn_ends,
                            "stage_times": {k: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(v))
                                            for k, v in self.stage_times.items()},
                            "exit_status": os.waitstatus_to_exitcode(status)})


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
    add_timing_args(p)
    p.add_argument("cmd", nargs=argparse.REMAINDER)
    a = p.parse_args()
    if a.cmd and a.cmd[0] == "--":
        a.cmd = a.cmd[1:]
    return StagedSession(a).run()


if __name__ == "__main__":
    sys.exit(main())
