"""Unit tests for the terminal driver (no model, no container).

Run: python3 -I -m unittest discover -s scripts/drive/tests
Each test exercises one harness behaviour that a pilot run once exposed (preregistration.md 12.5).
"""
import io
import os
import sys
import tempfile
import time
import types
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import driver  # noqa: E402
import staged  # noqa: E402


def bare(cls=driver.Session, **attrs):
    """An instance without __init__ (no pty, no container)."""
    s = cls.__new__(cls)
    s.oplog = io.StringIO()
    s.alive = True
    s.lines = []
    s.handled_questions = set()
    s.a = types.SimpleNamespace(reply="お任せします", mirror=False)
    for k, v in attrs.items():
        setattr(s, k, v)
    return s


def events(s):
    return [__import__("json").loads(ln)["event"] for ln in s.oplog.getvalue().splitlines()]


class ClosedTerminal(unittest.TestCase):
    """s2-xp2 (run-34), run-30: the container was stopped at the time limit while the driver typed."""

    def session(self, cmd):
        d = tempfile.mkdtemp()
        return driver.Session(types.SimpleNamespace(log_dir=d, cmd=cmd, mirror=False))

    def test_type_after_child_exit_does_not_raise(self):
        s = self.session(["sh", "-c", "exit 0"])
        deadline = time.time() + 5
        while s.alive and time.time() < deadline:
            s.pump(0.2)
        self.assertFalse(s.alive)
        s.type("お任せします")      # used to raise OSError (EIO)
        s.key(b"\r")
        self.assertFalse(s.alive)

    def test_write_failure_marks_session_dead(self):
        s = self.session(["sh", "-c", "sleep 30"])
        os.close(s.fd)               # the terminal goes away under the driver
        s.write(b"x")
        self.assertFalse(s.alive)

    def test_staged_send_returns_promptly_when_closed(self):
        s = bare(staged.StagedSession)
        s.write = lambda data: setattr(s, "alive", False)
        s.pump = lambda secs: None
        s.poll = lambda: None
        t0 = time.time()
        self.assertFalse(s.send_and_confirm("お任せします", wait=120))
        self.assertLess(time.time() - t0, 5)

    def test_closed_terminal_is_not_a_dialog_problem(self):
        s = bare(alive=False)
        s.key = s.type = lambda *a, **k: None
        s.pump = lambda secs: None
        s.poll = lambda: None
        s.dialog_open = lambda qid: True
        s.answer_dialog("q1", {"questions": [{"options": [{}, {}], "multiSelect": False}]})
        self.assertNotIn("dialog_still_open", events(s))


class Dialog(unittest.TestCase):
    """s2-xp1 (run-33): a multi-select dialog was never submitted."""

    def keystrokes(self, questions):
        s = bare()
        seq = []
        s.key = lambda k: seq.append(("key", k))
        s.type = lambda text, enter=True: seq.append(("type", text, enter))
        s.pump = lambda secs: None
        s.poll = lambda: None
        s.dialog_open = lambda qid: False
        s.answer_dialog("q1", {"questions": questions})
        return seq, s

    def test_single_select(self):
        seq, s = self.keystrokes([{"options": [{}, {}, {}]}])
        self.assertEqual(seq, [("key", b"\x1b[B")] * 3 + [("type", "お任せします", True)])
        self.assertIn("q1", s.handled_questions)

    def test_multi_select_types_without_enter_then_steps_to_submit(self):
        seq, _ = self.keystrokes([{"options": [{}, {}], "multiSelect": True}])
        self.assertEqual(seq, [("key", b"\x1b[B")] * 2 + [("type", "お任せします", False),
                                                           ("key", b"\x1b[B"), ("key", b"\r")])

    def test_mixed_questions(self):
        seq, _ = self.keystrokes([{"options": [{}], "multiSelect": True}, {"options": [{}, {}]}])
        self.assertEqual(seq, [("key", b"\x1b[B"), ("type", "お任せします", False), ("key", b"\x1b[B"),
                               ("key", b"\r"), ("key", b"\x1b[B"), ("key", b"\x1b[B"),
                               ("type", "お任せします", True)])

    def test_still_open_is_recorded(self):
        s = bare()
        s.key = s.type = lambda *a, **k: None
        s.pump = lambda secs: None
        s.poll = lambda: None
        s.dialog_open = lambda qid: True
        s.answer_dialog("q1", {"questions": [{"options": [{}]}]})
        self.assertIn("dialog_still_open", events(s))


class Busy(unittest.TestCase):
    """run-30: a background wait that never ended kept the operator from being called."""

    def test_grace(self):
        ps = {"v": b"1 docker-init\n1 claude\n1 bash\n1 sleep\n1 ps\n"}
        s = bare(turn_ends=1, in_turn=False, grace_recorded=0, turn_end_at=time.time() - 100)
        s.dexec = lambda script: ps["v"]
        self.assertTrue(s.busy())
        s.turn_end_at = time.time() - driver.BUSY_GRACE_SECS - 1
        self.assertFalse(s.busy())
        self.assertFalse(s.busy())
        self.assertEqual(events(s).count("busy_grace_elapsed"), 1)
        s.in_turn = True
        self.assertTrue(s.busy())
        s.in_turn, s.turn_end_at = False, None
        self.assertTrue(s.busy())
        ps["v"] = b"1 docker-init\n1 claude\n1 ps\n"
        self.assertFalse(s.busy())


if __name__ == "__main__":
    unittest.main()
