"""screen.dialog_on_screen (terminal-log tail) and dialog (keystrokes for an AskUserQuestion dialog).

Ported from test_staged.DialogState (on screen) and test_driver.Dialog (keystrokes), plus edge cases.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import dialog  # noqa: E402
import screen  # noqa: E402

DOWN, ENTER = ("key", b"\x1b[B"), ("key", b"\r")
PAUSE = ("pump", 1.5)


class OnScreen(unittest.TestCase):
    def test_on_screen(self):
        f = screen.dialog_on_screen
        self.assertTrue(f(b"...Enter to select..."))
        self.assertFalse(f(b"Enter to select ... User answered Claude's questions"))
        self.assertFalse(f(b"Enter to select ... User declined to answer"))
        self.assertTrue(f(b"User answered ... Enter to select"))
        self.assertTrue(f(b"User declined ... Enter to select"))
        self.assertFalse(f(b""))
        self.assertFalse(f(b"User answered"))

    def test_tail_size(self):
        self.assertEqual(screen.TAIL_BYTES, 65536)


class Keystrokes(unittest.TestCase):
    def keys(self, qinput):
        return dialog.keystrokes(qinput, "お任せします")

    def test_single_select(self):
        self.assertEqual(self.keys({"questions": [{"options": [{}, {}, {}]}]}),
                         [DOWN] * 3 + [("type", "お任せします", True), PAUSE])

    def test_multi_select_types_without_enter_then_steps_to_submit(self):
        self.assertEqual(self.keys({"questions": [{"options": [{}, {}], "multiSelect": True}]}),
                         [DOWN] * 2 + [("type", "お任せします", False), DOWN, ENTER, PAUSE])

    def test_mixed_questions(self):
        self.assertEqual(self.keys({"questions": [{"options": [{}], "multiSelect": True}, {"options": [{}, {}]}]}),
                         [DOWN, ("type", "お任せします", False), DOWN, ENTER, PAUSE,
                          DOWN, DOWN, ("type", "お任せします", True), PAUSE])

    def test_without_questions_still_answers_once(self):
        for qinput in ({}, {"questions": []}, {"questions": None}):
            self.assertEqual(self.keys(qinput), [("type", "お任せします", True), PAUSE], qinput)

    def test_question_without_options(self):
        self.assertEqual(self.keys({"questions": [{}]}), [("type", "お任せします", True), PAUSE])

    def test_pause_is_injectable(self):
        self.assertEqual(dialog.keystrokes({}, "x", pause=0.1)[-1], ("pump", 0.1))

    def test_multi_select_false_is_single(self):
        self.assertEqual(self.keys({"questions": [{"options": [{}], "multiSelect": False}]}),
                         [DOWN, ("type", "お任せします", True), PAUSE])


class Record(unittest.TestCase):
    def test_fields(self):
        q = [{"options": [{}]}, {"options": []}]
        r = dialog.record_fields("q1", {"questions": q}, "お任せします")
        self.assertEqual(list(r), ["tool_use_id", "questions", "action"])
        self.assertEqual(r, {"tool_use_id": "q1", "questions": q,
                             "action": "typed 'お任せします' into the free-text option of 2 question(s)"})

    def test_no_questions_counts_one(self):
        r = dialog.record_fields("q1", {}, "x")
        self.assertEqual((r["questions"], r["action"]), (None, "typed 'x' into the free-text option of 1 question(s)"))

    def test_null_questions(self):
        # Fixed after the refactor (bug in 85624a4): "questions": null makes len(None) raise, so the harness stops
        # at the dialog record; the keystrokes themselves would treat it like no questions.
        self.assertIn("1 question(s)", dialog.record_fields("q1", {"questions": None}, "x")["action"])


if __name__ == "__main__":
    unittest.main()
