"""Simulated world for characterization tests of driver.py and staged.py (no docker, no model).

The whole I/O boundary of the harness is replaced at the standard-library level, so the same
simulation runs the original harness (commit 85624a4) and the refactored one unchanged:

  time.time / time.gmtime      a virtual clock (only select, the user role and tar advance it)
  pty.fork / fcntl.ioctl       a fake terminal (fd FAKE_FD); os.read / os.write on it
  select.select                waits on the fake terminal in virtual time
  subprocess.run / Popen       docker exec (transcript, ps, tar), the user role / operator, tar -x
  os.kill / os.waitpid         the end of the session

The simulated agent reacts to what is typed: a submitted line starts the next scripted turn
(or is queued into the running turn), Enter presses close an open AskUserQuestion dialog, and
"/exit" closes the terminal. Every call across the boundary is written to a trace with its
virtual time; the trace, operator.jsonl, driver-summary.json, terminal.log and the files left in
the log directory are the observable behaviour that must not change.

Regenerate the reference traces from the original code:
  git show 85624a4:scripts/drive/driver.py > tmp-old/driver.py   (and staged.py)
  python3 -I scripts/drive/tests/sim.py --impl-dir tmp-old --write-golden scripts/drive/tests/golden
"""
import argparse
import hashlib
import heapq
import importlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import types
from unittest import mock

import fcntl
import pty
import select

START = 1_800_000_000.0
FAKE_FD = 987
PID = 4242
MAX_SECS = 30000
TRANSCRIPT = "/home/dev/.claude/projects/p/s.jsonl"
BASE_PROCS = ["docker-init", "claude", "ps", "sort", "uniq", "sh"]
ROLE_CMD = ["role-model", "-p"]

_real = types.SimpleNamespace(time=time.time, gmtime=time.gmtime, read=os.read, write=os.write,
                              select=select.select, run=subprocess.run, popen=subprocess.Popen,
                              kill=os.kill, waitpid=os.waitpid, ioctl=fcntl.ioctl)


class World:
    def __init__(self, sc, d):
        self.sc, self.d = sc, d
        self.now = START
        self.heap, self.seq = [], 0
        self.out = bytearray()
        self.transcript = bytearray()
        self.closed = False
        self.inbuf = bytearray()
        self.turns = [list(t) for t in sc["turns"]]
        self.role = list(sc.get("role", []))
        self.procs = []
        self.busy_turn = False
        self.queued = []
        self.dialog = None          # [enters_needed, enters, remaining steps]
        self.drop = list(sc.get("drop", []))   # submissions lost once each (never reach the transcript)
        self.trace = []
        self.fine = hashlib.sha256()
        self.after(1.0, lambda: self.start_turn(sc.get("prompt", "最初の依頼")))
        if "close_at" in sc:
            self.after(sc["close_at"], self.close)

    # ---------- bookkeeping ----------
    def t(self):
        return round(self.now - START, 6)

    def log(self, kind, *data):
        rec = [self.t(), kind, *data]
        self.trace.append(rec)
        self.fine.update(json.dumps(rec, ensure_ascii=False).encode() + b"\n")

    def finelog(self, kind, *data):
        self.fine.update(json.dumps([self.t(), kind, *data], ensure_ascii=False).encode() + b"\n")

    def after(self, secs, fn):
        self.seq += 1
        heapq.heappush(self.heap, (self.now + secs, self.seq, fn))

    def run_due(self):
        while self.heap and self.heap[0][0] <= self.now:
            _, _, fn = heapq.heappop(self.heap)
            fn()

    def advance(self, secs):
        self.now += secs
        if self.now - START > MAX_SECS:
            raise RuntimeError("scenario did not end")
        self.run_due()

    def screen(self, text):
        if not self.closed:
            self.out += text.encode("utf-8") + b"\r\n"

    def append(self, rec):
        self.transcript += (rec if isinstance(rec, bytes) else
                            json.dumps(rec, ensure_ascii=False).encode("utf-8") + b"\n")

    # ---------- the simulated agent ----------
    def start_turn(self, text):
        self.busy_turn = True
        steps = self.turns.pop(0) if self.turns else [(1, "text", "（台本なし）"), (1, "end")]
        self.append({"type": "user", "message": {"content": text}})
        self.screen("> " + text)
        self.next_step(steps)

    def next_step(self, steps):
        if not steps:
            return
        delay, kind, *arg = steps[0]
        self.after(delay, lambda: self.step(kind, arg, steps[1:]))

    def step(self, kind, arg, rest):
        if self.closed:
            return
        if kind != "end":     # a message typed during the turn is taken in with the next step
            for q in self.queued:
                self.append({"type": "attachment", "attachment": {"type": "queued_command", "prompt": q}})
            self.queued = []
        if kind == "text":
            self.append({"type": "assistant", "message": {"content": [{"type": "text", "text": arg[0]}]}})
        elif kind == "tool":
            self.append({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash",
                                                                       "id": "b", "input": {}}]}})
        elif kind == "result":
            self.append({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "b"}]}})
        elif kind == "raw":
            self.append(arg[0].encode("utf-8"))
        elif kind == "record":
            self.append(arg[0])
        elif kind == "screen":       # drawn before its record reaches the transcript (test-07)
            self.screen(arg[0])
            self.next_step(rest)
            return
        elif kind == "procs":
            self.procs = list(arg[0])
        elif kind == "end":
            self.append({"type": "system", "subtype": "turn_duration"})
            self.busy_turn = False
            if self.queued:   # ... or, at the end of the turn, starts the next turn
                text = self.queued.pop(0)
                self.after(0.3, lambda: self.start_turn(text))
        elif kind == "close":
            self.close()
            return
        elif kind == "ask":
            qid, qinput, enters = arg
            self.append({"type": "assistant", "message": {"content": [
                {"type": "tool_use", "name": "AskUserQuestion", "id": qid, "input": qinput}]}})
            self.screen(f"[{kind}] ☐ choose  Enter to select · ↑/↓ to navigate · Esc to cancel")
            self.dialog = [enters, 0, rest, qid]
            return
        self.screen(f"[{kind}]")
        self.next_step(rest)

    def close(self):
        self.closed = True

    def typed(self, data):
        if self.dialog is not None:
            self.dialog[1] += data.count(b"\r")
            if self.dialog[1] >= self.dialog[0]:
                _, _, rest, qid = self.dialog
                self.dialog = None

                def answered():
                    self.append({"type": "user", "message": {"content": [
                        {"type": "tool_result", "tool_use_id": qid, "content": "answered"}]}})
                    self.screen("User answered Claude's questions")
                    self.next_step(rest)
                self.after(0.5, answered)
            return
        for b in data:
            if b == 13:
                text = self.inbuf.decode("utf-8", "replace")
                self.inbuf = bytearray()
                if not text:
                    continue
                if text in self.drop:
                    self.drop.remove(text)
                elif text == "/exit":
                    if not self.sc.get("ignore_exit"):
                        self.after(1.0, self.close)
                elif self.busy_turn:
                    self.queued.append(text)
                else:
                    self.after(0.3, lambda text=text: self.start_turn(text))
            else:
                self.inbuf.append(b)

    # ---------- the fake I/O boundary ----------
    def time(self):
        return self.now

    def gmtime(self, *a):
        return _real.gmtime(a[0] if a else self.now)

    def fork(self):
        self.log("fork")
        return PID, FAKE_FD

    def ioctl(self, fd, req, arg, *rest):
        if fd != FAKE_FD:
            return _real.ioctl(fd, req, arg, *rest)
        self.log("ioctl", req, arg.hex())
        return arg

    def select(self, r, w, x, timeout=None):
        if FAKE_FD not in r:
            return _real.select(r, w, x, timeout)
        self.finelog("select", round(timeout, 6))
        self.run_due()
        if self.out or self.closed:
            return [FAKE_FD], [], []
        nxt = self.heap[0][0] if self.heap else None
        if nxt is not None and nxt <= self.now + timeout:
            self.advance(nxt - self.now)
            if self.out or self.closed:
                return [FAKE_FD], [], []
            return [], [], []
        self.advance(timeout)
        return [], [], []

    def read(self, fd, n):
        if fd != FAKE_FD:
            return _real.read(fd, n)
        data = bytes(self.out[:n])
        del self.out[:n]
        self.finelog("read", len(data))
        if not data and self.closed:
            raise OSError(5, "Input/output error")
        return data

    def write(self, fd, data):
        if fd != FAKE_FD:
            return _real.write(fd, data)
        if self.closed:
            self.log("write-failed", data.decode("utf-8", "replace"))
            raise OSError(5, "Input/output error")
        self.log("write", data.decode("utf-8", "replace"))
        self.typed(bytes(data))
        return len(data)

    def norm(self, v):
        return v.replace(self.d, "<D>") if isinstance(v, str) else v

    def run(self, cmd, input=None, **kw):
        cmd = [self.norm(c) for c in cmd]
        opts = {k: (v if isinstance(v, (int, float, bool, str, type(None))) else type(v).__name__)
                for k, v in sorted(kw.items())}
        if cmd[:2] == ["docker", "exec"]:
            script = cmd[-1]
            self.log("exec", cmd[:-1], script, opts)
            if script.startswith("ls -1tr"):
                out = (TRANSCRIPT + "\n").encode() if self.transcript else b""
            elif script.startswith("tail -c +"):
                off = int(script.split("+", 1)[1].split()[0])
                out = bytes(self.transcript[off - 1:])
            elif script.startswith("ps -eo"):
                out = b"".join(f"      1 {p}\n".encode() for p in sorted(BASE_PROCS + self.procs))
            else:
                raise AssertionError("unknown docker exec " + script)
            return types.SimpleNamespace(stdout=out, stderr=b"", returncode=0)
        if cmd[:1] == ["tar"]:
            self.log("run", cmd, opts)
            return types.SimpleNamespace(stdout=None, stderr=None, returncode=0)
        if cmd[:len(ROLE_CMD)] == ROLE_CMD:
            self.log("run", cmd, input.decode("utf-8"), opts)
            self.advance(3.0)                # the model takes a while
            out = self.role.pop(0) if self.role else b""
            return types.SimpleNamespace(stdout=out.encode("utf-8") if isinstance(out, str) else out,
                                         stderr=b"", returncode=0)
        raise AssertionError(f"unexpected subprocess {cmd}")

    def popen(self, cmd, **kw):
        cmd = [self.norm(c) for c in cmd]
        self.log("popen", cmd, sorted(kw))
        world = self

        class P:
            stdout = "PIPE"
            returncode = None

            def wait(self):
                world.advance(5.0)       # the snapshot takes a while
                self.returncode = 0
                return 0
        return P()

    def kill(self, pid, sig):
        if pid != PID:
            return _real.kill(pid, sig)
        self.log("kill", int(sig))

    def waitpid(self, pid, opts):
        if pid != PID:
            return _real.waitpid(pid, opts)
        self.log("waitpid")
        return PID, 0


STAGE_FILES = {"stage2": "段階2の固定文です。", "stage4": "段階4の固定文です。",
               "timeup": "時間です。まとめてください。", "done": "まとめてください。"}


def run_scenario(name, sc, staged_mod=None, driver_mod=None, extra_argv=()):
    """Run one scenario against the given modules; return the observable behaviour as a dict."""
    d = tempfile.mkdtemp(prefix="sim-")
    try:
        world = World(sc, d)
        with open(os.path.join(d, "prompt.txt"), "w", encoding="utf-8") as f:
            f.write("役割の指示\n")
        argv = ["--container", "ctr", "--log-dir", d, "--operator-cmd", json.dumps(ROLE_CMD),
                "--operator-prompt", os.path.join(d, "prompt.txt"),
                "--reply", "お任せします", "--fixed", "最後の問いです。"]
        if sc.get("kind", "staged") == "staged":
            mod = staged_mod
            os.makedirs(os.path.join(d, "stage"))
            for k, v in STAGE_FILES.items():
                with open(os.path.join(d, "stage", k), "w", encoding="utf-8") as f:
                    f.write(v + "\n")
            argv += ["--stage2-file", os.path.join(d, "stage", "stage2"),
                     "--stage4-file", os.path.join(d, "stage", "stage4"),
                     "--timeup-file", os.path.join(d, "stage", "timeup"),
                     "--done-file", os.path.join(d, "stage", "done"),
                     "--snapshot-dir", os.path.join(d, "snap")]
        else:
            mod = driver_mod
        argv += list(sc.get("argv", [])) + list(extra_argv) + ["--", "docker", "run", "-it", "img"]
        patches = [mock.patch.object(time, "time", world.time), mock.patch.object(time, "gmtime", world.gmtime),
                   mock.patch.object(pty, "fork", world.fork), mock.patch.object(fcntl, "ioctl", world.ioctl),
                   mock.patch.object(select, "select", world.select),
                   mock.patch.object(os, "read", world.read), mock.patch.object(os, "write", world.write),
                   mock.patch.object(subprocess, "run", world.run),
                   mock.patch.object(subprocess, "Popen", world.popen),
                   mock.patch.object(os, "kill", world.kill), mock.patch.object(os, "waitpid", world.waitpid),
                   mock.patch.object(sys, "argv", [mod.__name__ + ".py"] + argv)]
        for p in patches:
            p.start()
        try:
            rc = mod.main()
        except RuntimeError as e:      # the simulated time ran out: still compare what happened
            rc = "error: " + str(e)
        finally:
            for p in reversed(patches):
                p.stop()

        def read(rel):
            p = os.path.join(d, rel)
            return open(p, encoding="utf-8").read() if os.path.exists(p) else None
        files = sorted(os.path.relpath(os.path.join(r, f), d) for r, ds, fs in os.walk(d) for f in fs + ds)
        return {"scenario": name, "rc": rc, "trace": world.trace, "fine_sha256": world.fine.hexdigest(),
                "operator_jsonl": read("operator.jsonl"), "summary": read("driver-summary.json"),
                "terminal_log": read("terminal.log"), "files": files}
    finally:
        shutil.rmtree(d, ignore_errors=True)


# ------------------------------------------------------------------ scenarios
def j(**kw):
    return json.dumps(kw, ensure_ascii=False)


def R(text):
    """The user role's / operator's stdout in the claude -p JSON envelope."""
    return j(type="result", result=text)


Q2 = {"questions": [{"question": "どれ?", "options": [{"label": "a"}, {"label": "b"}], "multiSelect": True},
                    {"question": "どちら?", "options": [{"label": "x"}, {"label": "y"}, {"label": "z"}]}]}
DONE_TURN = [(2, "tool"), (3, "result"), (2, "text", "完了しました。"), (1, "end")]

SCENARIOS = {
    # stage 1: REPLY, then the user role fails three times
    "stage1_reply_then_role_error": {
        "turns": [[(5, "text", "どちらにしますか?"), (1, "end")], DONE_TURN],
        "role": [R("REPLY\n質問がある"), "garbage", R("たぶん完了"), "{}"]},
    # stages 1 -> 2 -> 3 (remake / evidence / reply / fail) -> 4 complete -> 45 -> 5 -> exit
    "full_procedure": {
        "turns": [DONE_TURN,
                  [(4, "text", "変種を三つ作りました。"), (1, "end")],
                  [(4, "text", "作り直しと証拠です。"), (1, "end")],
                  [(4, "text", "どれを先に?"), (1, "end")],
                  [(4, "text", "再度作り直しました。"), (1, "end")],
                  [(3, "tool"), (40, "result"), (4, "text", "修正しました。"), (1, "end")],
                  [(4, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答えです。"), (1, "end")]],
        "role": [R("COMPLETE\n完了報告"),
                 R("1: APPROVE\n2: REMAKE\n3：EVIDENCE"),
                 R("REPLY"),
                 "2: EVIDENCE\n3: REMAKE",
                 R("2: REMAKE\n3: APPROVE"),
                 R("COMPLETE")]},
    # stage-4 limit reached inside a long turn: the closing text is queued into the turn
    "timeup_inside_turn": {
        "argv": ["--stage4-minutes", "2"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "tool"), (30, "result"), (2, "tool"), (40, "result"), (2, "tool"), (60, "result"),
                   (3, "text", "途中経過"), (2, "tool"), (30, "result"), (3, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE")]},
    # stage-4 limit reached at a break held by leftover processes (agent_busy from ps)
    "timeup_busy_processes": {
        "argv": ["--stage4-minutes", "1"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "procs", ["sleep", "node"]), (3, "text", "裏で動かしています。"), (1, "end")],
                  [(1, "procs", []), (4, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE")]},
    # stage-4 limit after an early text but before the agent answers (turn ends re-examined at 45)
    "timeup_after_break_wait": {
        "argv": ["--stage4-minutes", "1"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(3, "text", "質問です"), (1, "end")],
                  [(2, "tool"), (90, "result"), (1, "end"),
                   (40, "record", {"type": "user", "message": {"content": "<task-notification>"}}),
                   (3, "text", "要約"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE"), R("REPLY")]},
    # the stage-4 limit passes while a dialog is drawn but not yet in the transcript, then pending
    "timeup_waits_for_dialog": {
        "argv": ["--stage4-minutes", "1"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "tool"), (50, "screen", "☐ a  Enter to select"),
                   (30, "ask", "q4", {"questions": [{"options": [{"label": "a"}, {"label": "b"}]}]}, 1),
                   (2, "text", "了解"), (20, "text", "要約"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE")]},
    # the grace elapses at a stage-4 break, the reply is lost, then the limit: busy() is asked again
    # for the same turn end (no second grace record) and the unconfirmed send waits 120 s
    "grace_then_timeup": {
        "argv": ["--stage4-minutes", "13"], "drop": ["お任せします"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "procs", ["sleep"]), (3, "text", "裏で動かしています。"), (1, "end")],
                  [(1, "procs", []), (4, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE"), R("REPLY")]},
    # a dialog drawn and declined before the limit does not hold the time-up text back
    "timeup_after_declined_dialog": {
        "argv": ["--stage4-minutes", "1"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "tool"), (5, "screen", "☐ a  Enter to select"),
                   (3, "screen", "User declined to answer questions"), (100, "result"),
                   (3, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE")]},
    # the terminal closes while the harness waits for a dialog to close
    "dialog_terminal_closes": {
        "turns": [[(1, "ask", "q1", {"questions": [{"options": [{"label": "a"}]}]}, 99)]], "close_at": 14},
    # the limit passes while an AskUserQuestion record is pending (< 5 s quiet) but not drawn
    "timeup_pending_question_not_drawn": {
        "argv": ["--stage4-minutes", "1"],
        "turns": [DONE_TURN, [(4, "text", "変種です。"), (1, "end")],
                  [(2, "tool"),
                   (55, "record", {"type": "assistant", "message": {"content": [
                       {"type": "tool_use", "name": "AskUserQuestion", "id": "q7", "input": {}}]}}),
                   (8, "record", {"type": "user", "message": {"content": [
                       {"type": "tool_result", "tool_use_id": "q7"}]}}),
                   (20, "text", "要約です。"), (1, "end")],
                  [(4, "text", "最後の答え。"), (1, "end")]],
        "role": [R("COMPLETE"), R("1: APPROVE\n2: APPROVE\n3: APPROVE")]},
    # a multi-select + single-select dialog, closed by the two Enters
    "dialog_two_questions": {
        "turns": [[(3, "text", "選んでください"), (1, "ask", "q1", Q2, 2), (2, "text", "了解"), (1, "end")],
                  DONE_TURN],
        "role": [R("COMPLETE")], "close_at": 200},
    # a dialog that needs the fallback Enter
    "dialog_fallback_enter": {
        "turns": [[(1, "ask", "q1", {"questions": [{"options": [{"label": "a"}]}]}, 2), (2, "text", "了解"),
                   (1, "end")]],
        "role": [R("REPLY")], "close_at": 120},
    # a dialog that never closes, without questions
    "dialog_stuck": {
        "turns": [[(1, "ask", "q9", {}, 99)]], "close_at": 80},
    # the terminal closes during the agent's turn
    "closed_terminal": {"turns": [[(3, "tool"), (20, "close")]]},
    # the terminal closes while the harness waits for its message to be delivered
    "closed_while_sending": {
        "turns": [[(4, "text", "質問"), (1, "end")], [(10, "close")]],
        "role": [R("REPLY")]},
    # leftover processes after the turn end: the grace period of 12.5
    "busy_grace": {
        "turns": [[(1, "procs", ["sleep"]), (3, "text", "待っています"), (1, "end")]],
        "role": ["x", "x", "x"]},
    # transcript oddities: partial line, garbage, sidechain, task notification after a turn end
    "transcript_oddities": {
        "turns": [[(2, "raw", "not json\n"),
                   (1, "record", {"type": "assistant", "isSidechain": True,
                                  "message": {"content": [{"type": "text", "text": "子"}]}}),
                   (1, "raw", '{"type": "assistant", "message": {"content": [{"type": "text", "te'),
                   (3, "raw", 'xt": "前半"}, {"type": "text", "text": "  "}, {"type": "text", "text": "後半"}]}}\n'),
                   (1, "end"),
                   (8, "record", {"type": "user", "message": {"content": "<task-notification>"}}),
                   (2, "text", "通知を処理しました"), (1, "end")]],
        "role": [R("REPLY"), "x", "x", "x"]},
    # condition A-C driver: reply, then fixed, then end
    "simple_reply_fixed": {
        "kind": "simple", "argv": ["--max-replies", "3"],
        "turns": [[(3, "text", "どうしますか?"), (1, "end")], DONE_TURN, [(3, "text", "答え"), (1, "end")]],
        "role": [R("1\n質問している"), R("2\n質問していない")]},
    # reply limit reached; an empty agent text
    "simple_reply_limit": {
        "kind": "simple", "argv": ["--max-replies", "1"],
        "turns": [[(3, "text", "どうしますか?"), (1, "end")], [(2, "tool"), (1, "end")],
                  [(3, "text", "答え"), (1, "end")]],
        "role": [R("1\n質問")]},
    # operator error after a dialog
    "simple_dialog_operator_error": {
        "kind": "simple", "argv": ["--max-replies", "3"],
        "turns": [[(1, "ask", "q1", Q2, 2), (2, "text", "了解"), (1, "end")]],
        "role": [R("3"), "x", R("")]},
    # simple driver: a reply that never arrives (30 polls), then /exit that does not end the session.
    # A notification turn ends in the middle of those 30 polls, so the quiet time and the grace
    # are measured from a poll that is not on the 2-s grid of the main loop.
    "simple_unconfirmed_exit_ignored": {
        "kind": "simple", "argv": ["--max-replies", "3"], "drop": ["お任せします"], "ignore_exit": True,
        "turns": [[(3, "text", "どうしますか?"), (1, "end"),
                   (45, "record", {"type": "user", "message": {"content": "<task-notification>"}}),
                   (0, "procs", ["sleep"]), (2, "text", "通知"), (1, "end"), (700, "procs", [])],
                  [(3, "text", "答え"), (1, "end")]],
        "role": [R("1\n質問"), R("2")]},
    # simple driver: the terminal closes before the reply arrives
    "simple_closed_while_confirming": {
        "kind": "simple", "argv": ["--max-replies", "3"], "drop": ["お任せします"], "close_at": 40,
        "turns": [[(3, "text", "どうしますか?"), (1, "end")]],
        "role": [R("1")]},
    # simple driver: terminal closes while confirming, leftover processes
    "simple_closed": {
        "kind": "simple", "argv": ["--max-replies", "3"],
        "turns": [[(1, "procs", ["make"]), (3, "text", "ビルド中"), (1, "end")], [(5, "close")]],
        "role": [R("1")]},
}


def load(impl_dir):
    sys.path.insert(0, os.path.abspath(impl_dir))
    driver = importlib.import_module("driver")
    staged = importlib.import_module("staged")
    return staged, driver


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--impl-dir", required=True)
    p.add_argument("--write-golden")
    p.add_argument("--only")
    a = p.parse_args()
    staged, driver = load(a.impl_dir)
    for name, sc in SCENARIOS.items():
        if a.only and name != a.only:
            continue
        r = run_scenario(name, sc, staged, driver)
        if a.write_golden:
            os.makedirs(a.write_golden, exist_ok=True)
            with open(os.path.join(a.write_golden, name + ".json"), "w", encoding="utf-8") as f:
                json.dump(r, f, ensure_ascii=False, indent=1)
                f.write("\n")
        print(name, len(r["trace"]), r["fine_sha256"][:12])


if __name__ == "__main__":
    main()
