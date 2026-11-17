"""The I/O shell (driver.Terminal, driver.Session, staged.StagedSession): the glue that executes
the pure components' decisions. Each test exercises one harness behaviour that a pilot run once
exposed (preregistration.md 12.5) or one path of the glue.

Ported from test_driver.ClosedTerminal / Dialog / Busy and test_staged.Poll / DialogState /
UserRole / Loop; the decisions themselves are tested in the component test files, and the whole
shell is compared with the original in test_equivalence.py.
"""
import io
import json
import os
import sys
import tempfile
import time
import types
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))
import driver  # noqa: E402
import sim  # noqa: E402
import stages  # noqa: E402
import staged  # noqa: E402
from transcript import Transcript  # noqa: E402


def events(s):
    return [json.loads(ln) for ln in s.oplog.getvalue().splitlines()]


class FakeTerm:
    def __init__(self, alive=True, log=b""):
        self.alive, self.ops, self.log = alive, [], log

    def pump(self, secs):
        self.ops.append(("pump", secs))

    def type(self, text, enter=True):
        self.ops.append(("type", text, enter))

    def key(self, seq):
        self.ops.append(("key", seq))

    def tail(self, n):
        return self.log if self.log is not None else None


class FakeContainer:
    def __init__(self, chunks=(), ps=""):
        self.chunks, self.ps_out, self.calls = list(chunks), ps, []

    def find_transcript(self):
        self.calls.append("ls")
        return "/t.jsonl" if self.chunks else ""

    def read_from(self, path, offset):
        self.calls.append(("tail", path, offset))
        return self.chunks.pop(0) if self.chunks else b""

    def ps(self):
        self.calls.append("ps")
        return self.ps_out


def make(cls=staged.StagedSession, **attrs):
    """A session without __init__ (no pty, no container): fakes for the terminal and the container."""
    s = cls.__new__(cls)
    d = tempfile.mkdtemp()
    files = {}
    for name, text in (("s2", "段階2の文"), ("s4", "段階4の文"), ("up", "時間です。まとめて"), ("done", "まとめて"),
                       ("prompt", "役割\n")):
        files[name] = os.path.join(d, name)
        with open(files[name], "w", encoding="utf-8") as f:
            f.write(text + "\n")
    s.a = types.SimpleNamespace(
        reply="お任せします", fixed="最後の問い", mirror=False, stage4_minutes=60, max_replies=3,
        stage2_file=files["s2"], stage4_file=files["s4"], timeup_file=files["up"], done_file=files["done"],
        remake_text="{n}番を作り直して", evidence_text="{n}番の証拠を", operator_prompt=files["prompt"],
        operator_cmd='["role-model", "-p"]', log_dir=d, snapshot_dir=d, container="c")
    s.timing = driver.Timing()
    s.oplog = io.StringIO()
    s.term = FakeTerm()
    s.container = FakeContainer()
    s.t = Transcript(now=0)
    s.tfile = None
    s.grace_recorded = s.handled_turns = s.replies = 0
    s.fixed_sent = False
    s.handled_questions = set()
    if cls is staged.StagedSession:
        s.state = stages.State()
        s.cfg = stages.Config(reply=s.a.reply, fixed=s.a.fixed, remake_text=s.a.remake_text,
                              evidence_text=s.a.evidence_text,
                              read=lambda key: staged.read_text(getattr(s.a, staged.TEXT_FILES[key])))
        s.stage4_start = None
        s.texts_at_send = 0
        s.stage_times = {"stage1_start": time.time()}
    for k, v in attrs.items():
        setattr(s, k, v)
    return s


# ---------------------------------------------------------------- terminal (real pty)
class ClosedTerminal(unittest.TestCase):
    """s2-xp2 (run-34), run-30: the container was stopped at the time limit while the driver typed."""

    def terminal(self, cmd):
        d = tempfile.mkdtemp()
        log = open(os.path.join(d, "terminal.log"), "ab")  # noqa: SIM115
        self.addCleanup(log.close)
        return driver.Terminal(cmd, log, False, driver.Timing())

    def test_type_after_child_exit_does_not_raise(self):
        t = self.terminal(["sh", "-c", "exit 0"])
        deadline = time.time() + 5
        while t.alive and time.time() < deadline:
            t.pump(0.2)
        self.assertFalse(t.alive)
        t.type("お任せします")      # used to raise OSError (EIO)
        t.key(b"\r")
        self.assertFalse(t.alive)
        t.hangup()

    def test_write_failure_marks_session_dead(self):
        t = self.terminal(["sh", "-c", "sleep 30"])
        os.close(t.fd)               # the terminal goes away under the driver
        t.write(b"x")
        self.assertFalse(t.alive)
        t.hangup()

    def test_output_is_logged_and_tail_is_read(self):
        t = self.terminal(["sh", "-c", "printf 'Enter to select'; sleep 1"])
        deadline = time.time() + 5
        while t.alive and time.time() < deadline:
            t.pump(0.2)
        self.assertTrue(t.tail(65536).endswith(b"Enter to select"))
        self.assertEqual(t.tail(5), b"elect")
        self.assertEqual(os.waitstatus_to_exitcode(t.hangup()), 0)

    def test_only_the_last_64k_are_read(self):
        s = make()
        d = tempfile.mkdtemp()
        with open(os.path.join(d, "terminal.log"), "wb") as f:
            f.write(b"Enter to select" + b"x" * 70000)
        t = driver.Terminal.__new__(driver.Terminal)
        t.log = types.SimpleNamespace(name=os.path.join(d, "terminal.log"))
        s.term = t
        self.assertFalse(s.dialog_on_screen())

    def test_tail_of_missing_log(self):
        t = driver.Terminal.__new__(driver.Terminal)
        t.log = types.SimpleNamespace(name="/nonexistent/x")
        self.assertIsNone(t.tail(10))

    def test_staged_send_returns_promptly_when_closed(self):
        s = make()
        s.term.alive = False
        t0 = time.time()
        self.assertFalse(s.send_and_confirm("お任せします", wait=120))
        self.assertLess(time.time() - t0, 5)

    def test_closed_terminal_is_not_a_dialog_problem(self):
        s = make(cls=driver.Session)
        s.term.alive = False
        s.answer_dialog("q1", {"questions": [{"options": [{}, {}], "multiSelect": False}]})
        self.assertNotIn("dialog_still_open", [e["event"] for e in events(s)])


# ---------------------------------------------------------------- dialogs
class AnswerDialog(unittest.TestCase):
    """s2-xp1 (run-33): a multi-select dialog was never submitted."""
    ask = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "AskUserQuestion",
                                                         "id": "q1", "input": {}}]}}
    result = {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "q1"}]}}

    def session(self, closes_after_polls):
        s = make(cls=driver.Session)
        s.tfile = "/t.jsonl"
        s.t.feed(json.dumps(self.ask).encode() + b"\n", now=0)
        s.container.chunks = [b""] * closes_after_polls + [json.dumps(self.result).encode() + b"\n"]
        return s

    def test_keys_then_closed_at_once(self):
        s = self.session(0)
        s.answer_dialog("q1", {"questions": [{"options": [{}, {}], "multiSelect": True}]})
        self.assertEqual(s.term.ops, [("key", b"\x1b[B")] * 2 + [("type", "お任せします", False), ("key", b"\x1b[B"),
                                                              ("key", b"\r"), ("pump", 1.5), ("pump", 1)])
        self.assertIn("q1", s.handled_questions)
        self.assertEqual(events(s)[0]["event"], "dialog")

    def test_fallback_enter_after_five_polls(self):
        s = self.session(5)
        s.answer_dialog("q1", {"questions": [{"options": [{}]}]})
        self.assertEqual(s.term.ops[-7:], [("pump", 1)] * 5 + [("key", b"\r"), ("pump", 1)])
        self.assertEqual([e["event"] for e in events(s)], ["dialog"])

    def test_still_open_is_recorded(self):
        s = self.session(99)
        s.answer_dialog("q1", {"questions": [{"options": [{}]}]})
        self.assertEqual(s.term.ops.count(("pump", 1)), 10)
        self.assertEqual([e["event"] for e in events(s)], ["dialog", "dialog_still_open"])

    def test_dialog_on_screen_uses_the_log_tail(self):
        self.assertTrue(make(term=FakeTerm(log=b"Enter to select")).dialog_on_screen())
        self.assertFalse(make(term=FakeTerm(log=None)).dialog_on_screen())


# ---------------------------------------------------------------- container
class Poll(unittest.TestCase):
    def test_finds_the_transcript_once_then_reads_from_the_offset(self):
        rec = json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "あ"}]}}).encode()
        s = make(container=FakeContainer([rec[:10], rec + b"\n"]))
        s.poll()
        s.poll()
        self.assertEqual(s.container.calls, ["ls", ("tail", "/t.jsonl", 0), ("tail", "/t.jsonl", 0)])
        self.assertEqual((s.t.texts, s.t.offset), ([(1, "あ")], len(rec) + 1))

    def test_no_transcript_yet(self):
        s = make()
        s.poll()
        self.assertEqual((s.tfile, s.container.calls), (None, ["ls"]))


class Busy(unittest.TestCase):
    """run-30: a background wait that never ended kept the operator from being called."""

    def test_grace_is_recorded_once(self):
        s = make(container=FakeContainer(ps="1 docker-init\n1 claude\n1 bash\n1 sleep\n1 ps\n"))
        s.t.turn_ends, s.t.turn_end_at = 1, time.time() - 100
        self.assertTrue(s.busy())
        s.t.turn_end_at = time.time() - driver.BUSY_GRACE_SECS - 1
        self.assertFalse(s.busy())
        self.assertFalse(s.busy())
        self.assertEqual([e["event"] for e in events(s)], ["busy_grace_elapsed"])
        self.assertEqual(s.grace_recorded, 1)

    def test_injected_grace(self):
        s = make(container=FakeContainer(ps="1 sleep\n"), timing=driver.Timing(busy_grace_secs=10))
        s.t.turn_ends, s.t.turn_end_at = 1, time.time() - 11
        self.assertFalse(s.busy())


# ---------------------------------------------------------------- model calls
class UserRole(unittest.TestCase):
    def run_with(self, outputs, stage=1, cls=staged.StagedSession, text="m"):
        s = make(cls=cls)
        s.state = stages.State(stage=stage) if cls is staged.StagedSession else None
        outs = iter(outputs)
        calls = []

        def run(cmd, **kw):
            calls.append((cmd, kw))
            return types.SimpleNamespace(stdout=next(outs))
        with mock.patch.object(driver.subprocess, "run", side_effect=run):
            r = s.user_role(text) if cls is staged.StagedSession else s.operator(text)
        return r, calls

    def test_command_and_input(self):
        _, calls = self.run_with([json.dumps({"result": "COMPLETE\nx"}).encode()])
        self.assertEqual(calls, [(["role-model", "-p", "--system-prompt", "役割\n\n"],   # the file as it is
                                  {"input": "m".encode(), "check": False, "capture_output": True, "timeout": 300})])

    def test_first_valid_answer(self):
        self.assertEqual(self.run_with([json.dumps({"result": "COMPLETE\nx"}).encode()])[0],
                         ({"choice": "COMPLETE"}, "COMPLETE\nx", 1))

    def test_retries_then_succeeds(self):
        r, calls = self.run_with([b"", b"not json", json.dumps({"result": "REPLY"}).encode()])
        self.assertEqual((r[0], r[2], len(calls)), ({"choice": "REPLY"}, 3, 3))

    def test_parse_uses_the_current_stage(self):
        self.assertEqual(self.run_with([b"1: APPROVE\n2: APPROVE\n3: APPROVE"], stage=3)[0][0]["choice"], "JUDGE")

    def test_gives_up_after_three(self):
        self.assertEqual(self.run_with([b"x", b"y", b"z"])[0], (None, "z", 3))

    def test_operator(self):
        r, calls = self.run_with([b"2\nreason"], cls=driver.Session, text="")
        self.assertEqual(r, ("2", "reason", 1, "2\nreason"))
        self.assertEqual(calls[0][1]["input"], "（テキストなし）".encode())
        self.assertEqual(self.run_with([b"x", b"y", b"z"], cls=driver.Session)[0],
                         (None, "operator gave no valid answer", 3, "z"))


# ---------------------------------------------------------------- executing the stage machine's actions
class Execute(unittest.TestCase):
    def test_actions_in_order(self):
        s = make()
        seen = []
        s.snapshot = lambda label, stage: seen.append(("snapshot", label, stage))
        s.send = lambda text, stage, **kw: seen.append(("send", text, stage, list(kw)))
        self.assertTrue(s.execute([stages.MarkTime("stage2_start"), stages.Snapshot("S1", 1),
                                   stages.Send(stages.FileText("stage2"), 3, {"rule": "r", "after_message": 1}),
                                   stages.StartClock(), stages.Record({"event": "x", "a": 1})]))
        self.assertEqual(seen, [("snapshot", "S1", 1), ("send", "段階2の文", 3, ["rule", "after_message"])])
        self.assertIn("stage2_start", s.stage_times)
        self.assertIsNotNone(s.stage4_start)
        self.assertEqual(list(events(s)[0]), ["event", "a", "time"])

    def test_exit_stops(self):
        s = make()
        self.assertFalse(s.execute([stages.Exit(), stages.Record({"event": "never"})]))
        self.assertEqual(s.term.ops, [("type", "/exit", True), ("pump", 30)])
        self.assertEqual(events(s), [])

    def test_unknown_action(self):
        with self.assertRaises(AssertionError):
            make().execute([object()])

    def test_send_record(self):
        s = make()
        s.send_and_confirm = lambda text: True
        s.t.texts = [(1, "a"), (2, "b")]
        s.send("文", 4, rule="r", after_message=2)
        e = events(s)[0]
        self.assertEqual(list(e), ["event", "stage", "sent", "confirmed", "confirm_secs", "pty_alive", "rule",
                                   "after_message", "time"])
        self.assertEqual(s.texts_at_send, 2)

    def test_snapshot(self):
        s = make(container=driver.Container("c"))
        with mock.patch.object(driver.subprocess, "Popen") as popen, \
             mock.patch.object(driver.subprocess, "run", return_value=types.SimpleNamespace(returncode=2)):
            popen.return_value.returncode = 0
            s.snapshot("S1", 1)
        cmd = popen.call_args[0][0]
        self.assertEqual(cmd[:5], ["docker", "exec", "c", "sh", "-c"])
        self.assertIn("--exclude='tmp/node-compile-cache' home/dev tmp", cmd[5])
        self.assertTrue(os.path.isdir(os.path.join(s.a.snapshot_dir, "S1")))
        self.assertTrue(os.path.exists(os.path.join(s.a.log_dir, "snapshot-S1.err")))
        self.assertEqual(events(s)[0], {**events(s)[0], "event": "snapshot", "label": "S1", "stage": 1,
                                        "tar_exit": [0, 2]})


# ---------------------------------------------------------------- at a break
class AtBreak(unittest.TestCase):
    def session(self, *records, **attrs):
        s = make(**attrs)
        s.t.feed(b"".join(json.dumps(r, ensure_ascii=False).encode() + b"\n" for r in records), now=0)
        s.calls = []
        s.send = lambda text, stage, **kw: s.calls.append(("send", text, stage))
        s.snapshot = lambda label, stage: s.calls.append(("snapshot", label))
        return s

    def test_role_gets_the_texts_since_the_last_send(self):
        s = self.session({"type": "assistant", "message": {"content": [{"type": "text", "text": "古い"},
                                                                      {"type": "text", "text": "新しい"}]}},
                         texts_at_send=1)
        seen = []
        s.user_role = lambda m: seen.append(m) or ({"choice": "COMPLETE"}, "COMPLETE", 1)
        self.assertTrue(s.at_break())
        self.assertEqual(seen, ["現在の段階: 1\n\nアシスタントの最後の発言:\n\n新しい"])
        self.assertEqual(s.calls, [("snapshot", "S1"), ("send", "段階2の文", 3)])
        self.assertEqual(s.state.stage, 3)

    def test_stage45_waits_for_text_after_closing_message(self):
        s = self.session({"type": "user", "message": {"content": "まとめて"}},
                         state=stages.State(stage=45, stage45_text="まとめて"))
        self.assertTrue(s.at_break())
        self.assertEqual((s.calls, events(s)[-1]["event"]), ([], "wait"))
        s.t.feed(json.dumps({"type": "assistant", "message": {"content": [{"type": "tool_use"}]}}).encode() + b"\n", 1)
        s.at_break()
        self.assertEqual(s.calls, [])
        s.t.feed(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "要約"}]}},
                            ensure_ascii=False).encode() + b"\n", 2)
        s.at_break()
        self.assertEqual((s.calls, s.state.stage), ([("send", "最後の問い", 5)], 5))

    def test_stage45_message_not_yet_delivered(self):
        s = self.session({"type": "assistant", "message": {"content": [{"type": "text", "text": "前の文"}]}},
                         state=stages.State(stage=45, stage45_text="まとめて"))
        s.at_break()
        self.assertEqual(s.state.stage, 45)

    def test_stage5_snapshots_and_exits(self):
        s = self.session(state=stages.State(stage=5))
        self.assertFalse(s.at_break())
        self.assertEqual(s.calls, [("snapshot", "S3")])
        self.assertEqual(s.term.ops[0], ("type", "/exit", True))

    def test_simple_procedure(self):
        s = make(cls=driver.Session)
        s.t.texts = [(1, "質問")]
        s.operator = lambda text: ("1", "r", 1, "1\nr")
        s.send_and_confirm = lambda text: True
        self.assertTrue(s.at_break())
        self.assertEqual((s.replies, s.fixed_sent), (1, False))
        s.a.max_replies = 1
        self.assertTrue(s.at_break())
        self.assertEqual((s.replies, s.fixed_sent, events(s)[-1]["operator_reason"]), (1, True, "reply limit 1 reached"))
        self.assertFalse(s.at_break())
        self.assertEqual(events(s)[-1]["event"], "end")


# ---------------------------------------------------------------- main loop glue
class Loop(unittest.TestCase):
    """One iteration of the main loop with a given state; poll ends the loop afterwards."""

    def tick(self, **state):
        s = make(**{k: v for k, v in state.items() if k in ("state", "stage4_start")})
        for k in ("turn_ends", "in_turn", "last_change"):
            if k in state:
                setattr(s.t, k, state[k])
        s.handled_turns = state.get("handled_turns", 0)
        s.answered, s.broke = [], []
        s.answer_dialog = lambda qid, q: s.answered.append(qid)
        s.at_break = state.get("at_break", lambda: s.broke.append(1) or True)
        s.busy = state.get("busy", lambda: False)
        s.term.log = state.get("screen", b"")
        if "pending" in state:
            s.t.pending_question = lambda handled: state["pending"]
        s.sent = []
        s.send = lambda text, stage, **kw: s.sent.append((text, stage, kw.get("rule")))

        def poll():   # the iteration that calls it is the last one
            s.term.alive = False
        s.poll = poll
        s.term.hangup = lambda: 0
        s.run()
        return s

    ended = {"turn_ends": 1, "handled_turns": 0}

    def test_turn_end_quiet_calls_at_break(self):
        self.assertEqual(self.tick(**self.ended).broke, [1])

    def test_waits(self):
        self.assertEqual(self.tick(turn_ends=1, handled_turns=1).broke, [])
        self.assertEqual(self.tick(in_turn=True, **self.ended).broke, [])
        self.assertEqual(self.tick(last_change=time.time(), **self.ended).broke, [])
        self.assertEqual(self.tick(busy=lambda: True, **self.ended).broke, [])

    def test_dialog_has_priority_once_quiet(self):
        s = self.tick(pending=("q1", {}), **self.ended)
        self.assertEqual((s.answered, s.broke), (["q1"], []))

    def test_time_up_types_closing_text_even_in_a_turn(self):
        s = self.tick(state=stages.State(stage=4), stage4_start=time.time() - 3600, in_turn=True,
                      turn_ends=2, handled_turns=2)
        self.assertEqual(s.state.stage, 45)
        self.assertEqual(s.sent, [("時間です。まとめて", 45, "段階4の制限時間（60分）")])

    def test_time_up_waits_for_dialog_on_screen(self):
        s = self.tick(state=stages.State(stage=4), stage4_start=time.time() - 3600, screen=b"Enter to select")
        self.assertEqual(s.state.stage, 4)

    def test_at_break_false_ends_the_session_and_writes_summary(self):
        s = self.tick(at_break=lambda: False, **self.ended)
        with open(os.path.join(s.a.log_dir, "driver-summary.json"), encoding="utf-8") as f:
            summary = json.load(f)
        self.assertEqual(list(summary), ["final_stage", "verdicts", "instructions", "fixed_sent", "agent_messages",
                                         "turns", "stage_times", "exit_status"])
        self.assertEqual(summary["final_stage"], 1)

    def test_closed_terminal_is_recorded(self):
        self.assertEqual(events(self.tick())[-1]["event"], "pty_closed")

    def test_simple_summary(self):
        s = make(cls=driver.Session)
        s.finish(0)
        with open(os.path.join(s.a.log_dir, "driver-summary.json"), encoding="utf-8") as f:
            self.assertEqual(list(json.load(f)), ["replies_sent", "fixed_sent", "agent_messages", "turns",
                                                  "exit_status"])


# ---------------------------------------------------------------- timing and command line
class TimingOptions(unittest.TestCase):
    def test_defaults_are_the_preregistered_ones(self):
        t = driver.Timing()
        self.assertEqual((t.poll_secs, t.quiet_secs, t.busy_grace_secs, t.dialog_quiet_secs, t.type_pause,
                          t.key_pause, t.question_pause, t.dialog_polls, t.confirm_poll_secs, t.confirm_polls,
                          t.confirm_wait_secs, t.exit_pump_secs, t.role_timeout_secs),
                         (2, 20, 600, 5, 0.5, 0.7, 1.5, 5, 1, 30, 120, 30, 300))
        self.assertEqual((driver.POLL_SECS, driver.QUIET_SECS, driver.BUSY_GRACE_SECS), (2, 20, 600))

    def test_from_args(self):
        self.assertEqual(driver.Timing.from_args(types.SimpleNamespace()), driver.Timing())
        t = driver.Timing.from_args(types.SimpleNamespace(poll_secs=1.0, quiet_secs=3.0, busy_grace_secs=30.0))
        self.assertEqual((t.poll_secs, t.quiet_secs, t.busy_grace_secs), (1.0, 3.0, 30.0))

    def test_shortened_grace_end_to_end(self):
        # The simulated busy_grace scenario with --busy-grace-secs 30: the grace record comes ~570 s earlier.
        normal = sim.run_scenario("busy_grace", sim.SCENARIOS["busy_grace"], staged, driver)
        short = sim.run_scenario("busy_grace", sim.SCENARIOS["busy_grace"], staged, driver,
                                 extra_argv=["--busy-grace-secs", "30"])

        def grace(r):
            return next(json.loads(ln) for ln in r["operator_jsonl"].splitlines() if "busy_grace" in ln)
        self.assertEqual(grace(normal)["seconds_since_turn_end"], 600)
        self.assertEqual(grace(short)["seconds_since_turn_end"], 30)


if __name__ == "__main__":
    unittest.main()
