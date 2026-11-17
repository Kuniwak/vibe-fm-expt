"""Edge-case unit tests for the staged driver, one class per component (no model, no container).

Run: python3 -I -m unittest discover -s scripts/drive/tests
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

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import driver  # noqa: E402
import staged  # noqa: E402
from staged import StagedSession  # noqa: E402


def make(**attrs):
    """A StagedSession without __init__: no pty, no container; I/O methods are stubs that log calls."""
    s = StagedSession.__new__(StagedSession)
    d = tempfile.mkdtemp()
    for name, text in (("s2", "段階2の文"), ("s4", "段階4の文"), ("up", "時間です。まとめて"), ("done", "まとめて")):
        with open(os.path.join(d, name), "w", encoding="utf-8") as f:
            f.write(text + "\n")
    s.a = types.SimpleNamespace(
        reply="お任せします", fixed="最後の問い", mirror=False, stage4_minutes=60,
        stage2_file=os.path.join(d, "s2"), stage4_file=os.path.join(d, "s4"),
        timeup_file=os.path.join(d, "up"), done_file=os.path.join(d, "done"),
        remake_text="{n}番を作り直して", evidence_text="{n}番の証拠を", operator_prompt=os.path.join(d, "s2"),
        operator_cmd='["true"]', log_dir=d, snapshot_dir=d, container="c")
    s.oplog = io.StringIO()
    s.alive = True
    s.lines, s.texts = [], []
    s.handled_questions = set()
    s.stage = 1
    s.verdict = {t: None for t in staged.TYPES}
    s.instructions = {t: 0 for t in staged.TYPES}
    s.stage4_start = None
    s.stage45_text = None
    s.texts_at_send = 0
    s.stage_times = {"stage1_start": time.time()}
    s.turn_ends = s.handled_turns = 0
    s.in_turn = False
    s.turn_end_at = None
    s.grace_recorded = 0
    s.last_change = 0
    s.offset, s.tfile = 0, None
    s.calls = []
    s.send = lambda text, **kw: s.calls.append(("send", text, kw.get("rule")))
    s.snapshot = lambda label: s.calls.append(("snapshot", label))
    s.type = lambda text, enter=True: s.calls.append(("type", text))
    s.pump = lambda secs: None
    for k, v in attrs.items():
        setattr(s, k, v)
    return s


def events(s):
    return [json.loads(ln) for ln in s.oplog.getvalue().splitlines()]


def role(*answers):
    """user_role stub returning parsed answers in order (None = no valid answer)."""
    it = iter(answers)

    def f(message):
        a = next(it)
        return a, "raw", 1
    return f


# ---------------------------------------------------------------- parse
class Parse(unittest.TestCase):
    def test_stage1_and_4_accept_only_reply_or_complete_on_first_line(self):
        for stage in (1, 4):
            s = make(stage=stage)
            self.assertEqual(s.parse("REPLY\n理由"), {"choice": "REPLY"})
            self.assertEqual(s.parse("\n\n  COMPLETE  \n理由"), {"choice": "COMPLETE"})
            for bad in ("", "  \n ", "reply", "COMPLETE です", "理由\nCOMPLETE", "1: APPROVE"):
                self.assertIsNone(s.parse(bad), (stage, bad))

    def test_stage3_needs_every_pending_type(self):
        s = make(stage=3)
        full = "1: APPROVE\n2: REMAKE\n3: EVIDENCE"
        self.assertEqual(s.parse(full)["types"], {1: "APPROVE", 2: "REMAKE", 3: "EVIDENCE"})
        self.assertIsNone(s.parse("1: APPROVE\n2: REMAKE"))
        s.verdict[3] = "APPROVE"   # decided earlier: no longer required
        self.assertEqual(s.parse("1: APPROVE\n2: REMAKE")["choice"], "JUDGE")

    def test_stage3_formats(self):
        s = make(stage=3)
        self.assertEqual(s.parse("1：APPROVE\n2 : REMAKE\n3:EVIDENCE 理由")["types"],
                         {1: "APPROVE", 2: "REMAKE", 3: "EVIDENCE"})
        self.assertIsNone(s.parse("1: approve\n2: REMAKE\n3: EVIDENCE"))
        self.assertIsNone(s.parse("1: APPROVED\n2: REMAKE\n3: EVIDENCE"))   # \b after the word
        self.assertIsNone(s.parse("4: APPROVE\n2: REMAKE\n3: EVIDENCE"))
        self.assertEqual(s.parse("REPLY\n1: APPROVE"), {"choice": "REPLY"})

    def test_stage3_repeated_type_last_one_wins(self):
        s = make(stage=3)
        self.assertEqual(s.parse("1: REMAKE\n1: APPROVE\n2: APPROVE\n3: APPROVE")["types"][1], "APPROVE")


# ---------------------------------------------------------------- role_message
class RoleMessage(unittest.TestCase):
    def test_only_texts_since_last_send(self):
        s = make(texts=[(1, "古い"), (2, "新しいA"), (3, "新しいB")], texts_at_send=1)
        m = s.role_message()
        self.assertTrue(m.startswith("現在の段階: 1\n"))
        self.assertNotIn("古い", m)
        self.assertIn("新しいA\n\n新しいB", m)

    def test_no_text(self):
        self.assertIn("（テキストなし）", make(texts=[(1, "x")], texts_at_send=1).role_message())

    def test_stage3_lists_pending_types(self):
        s = make(stage=3)
        s.verdict[2] = "APPROVE"
        self.assertIn("判断が済んでいない種類: 1, 3\n", s.role_message())


# ---------------------------------------------------------------- at_break (state machine)
class AtBreak(unittest.TestCase):
    def test_stage1_reply(self):
        s = make(user_role=role({"choice": "REPLY"}))
        self.assertTrue(s.at_break())
        self.assertEqual(s.calls, [("send", "お任せします", "規則による「お任せします」")])
        self.assertEqual(s.stage, 1)

    def test_stage1_complete_snapshots_and_sends_stage2(self):
        s = make(user_role=role({"choice": "COMPLETE"}))
        self.assertTrue(s.at_break())
        self.assertEqual(s.calls, [("snapshot", "S1"), ("send", "段階2の文", "段階2の固定文")])
        self.assertEqual(s.stage, 3)
        self.assertIn("stage2_start", s.stage_times)

    def test_role_error_exits(self):
        s = make(user_role=role(None))
        self.assertFalse(s.at_break())
        self.assertEqual(s.calls, [("type", "/exit")])
        self.assertEqual(events(s)[-1]["event"], "role_error")

    def judge(self, s, types_):
        s.user_role = role({"choice": "JUDGE", "types": types_})
        return s.at_break()

    def test_stage3_all_approve_moves_to_stage4(self):
        s = make(stage=3)
        self.judge(s, {1: "APPROVE", 2: "APPROVE", 3: "APPROVE"})
        self.assertEqual(s.calls, [("snapshot", "S2"), ("send", "段階4の文", "段階4の固定文")])
        self.assertEqual(s.stage, 4)
        self.assertIsNotNone(s.stage4_start)

    def test_stage3_instructions_are_combined_in_type_order(self):
        s = make(stage=3)
        self.judge(s, {1: "EVIDENCE", 2: "APPROVE", 3: "REMAKE"})
        self.assertEqual(s.calls, [("send", "1番の証拠を\n3番を作り直して", "段階3の規則")])
        self.assertEqual(s.instructions, {1: 1, 2: 0, 3: 1})
        self.assertEqual(s.verdict, {1: None, 2: "APPROVE", 3: None})

    def test_stage3_third_non_approval_fails_the_type(self):
        s = make(stage=3)
        s.verdict.update({2: "APPROVE", 3: "APPROVE"})
        for _ in range(2):
            self.judge(s, {1: "REMAKE"})
        self.assertEqual(s.instructions[1], 2)
        s.calls.clear()
        self.judge(s, {1: "EVIDENCE"})
        self.assertEqual(s.verdict[1], "FAILED")
        self.assertEqual(s.stage, 4)
        self.assertEqual(s.calls[0], ("snapshot", "S2"))

    def test_stage3_decided_types_are_not_judged_again(self):
        s = make(stage=3)
        s.verdict[1] = "APPROVE"
        self.judge(s, {1: "REMAKE", 2: "APPROVE", 3: "APPROVE"})
        self.assertEqual(s.instructions[1], 0)
        self.assertEqual(s.stage, 4)

    def test_stage3_reply(self):
        s = make(stage=3, user_role=role({"choice": "REPLY"}))
        s.at_break()
        self.assertEqual(s.calls, [("send", "お任せします", "規則による「お任せします」")])
        self.assertEqual(s.stage, 3)

    def test_stage4_complete_sends_done_text(self):
        s = make(stage=4, user_role=role({"choice": "COMPLETE"}))
        s.at_break()
        self.assertEqual(s.stage, 45)
        self.assertEqual(s.stage45_text, "まとめて")
        self.assertEqual(s.calls[0][1], "まとめて")

    def test_stage45_waits_for_text_after_closing_message(self):
        s = make(stage=45, stage45_text="まとめて")
        s.lines = [{"type": "user", "message": {"content": "まとめて"}}]
        self.assertTrue(s.at_break())
        self.assertEqual(s.calls, [])
        self.assertEqual(events(s)[-1]["event"], "wait")
        s.lines.append({"type": "assistant", "message": {"content": [{"type": "tool_use"}]}})
        s.at_break()
        self.assertEqual(s.calls, [])
        s.lines.append({"type": "assistant", "message": {"content": [{"type": "text", "text": "要約"}]}})
        s.at_break()
        self.assertEqual(s.calls, [("send", "最後の問い", "段階5の固定文")])
        self.assertEqual(s.stage, 5)

    def test_stage45_message_not_yet_delivered(self):
        s = make(stage=45, stage45_text="まとめて")
        s.lines = [{"type": "assistant", "message": {"content": [{"type": "text", "text": "前の文"}]}}]
        s.at_break()
        self.assertEqual(s.stage, 45)

    def test_stage5_snapshots_and_exits(self):
        s = make(stage=5)
        self.assertFalse(s.at_break())
        self.assertEqual(s.calls, [("snapshot", "S3"), ("type", "/exit")])


# ---------------------------------------------------------------- delivery detection
class Delivery(unittest.TestCase):
    typed = {"type": "user", "message": {"content": "X"}}
    queued = {"type": "attachment", "attachment": {"type": "queued_command", "prompt": "X"}}

    def test_counts_typed_and_queued(self):
        s = make(lines=[self.typed, self.queued, {"type": "user", "message": {"content": "Y"}}])
        self.assertEqual(s.delivered("X"), 2)
        self.assertEqual(s.delivery_index("X"), 1)
        self.assertIsNone(s.delivery_index("Z"))

    def test_odd_records_are_ignored(self):
        s = make(lines=[{"type": "user", "message": "X"}, {"type": "user"},
                        {"type": "attachment", "attachment": "X"},
                        {"type": "user", "message": {"content": [{"type": "text", "text": "X"}]}}])
        self.assertEqual(s.delivered("X"), 0)

    def test_answered_after(self):
        s = make(lines=[self.typed,
                        {"type": "assistant", "message": {"content": [{"type": "text", "text": "  "}]}},
                        {"type": "assistant", "message": {"content": "文字列"}}])
        self.assertFalse(s.answered_after(0))
        s.lines.append({"type": "assistant", "message": {"content": [{"type": "text", "text": "答え"}]}})
        self.assertTrue(s.answered_after(0))
        self.assertFalse(s.answered_after(len(s.lines) - 1))


# ---------------------------------------------------------------- transcript polling
class Poll(unittest.TestCase):
    def session(self, chunks):
        s = make()
        files = iter([b"/home/dev/.claude/projects/p/a.jsonl\n"] + chunks)
        s.dexec = lambda script: next(files)
        return s

    @staticmethod
    def j(*records):
        return b"".join(json.dumps(r).encode() + b"\n" for r in records)

    def test_partial_line_waits_for_the_rest(self):
        rec = self.j({"type": "assistant", "message": {"content": [{"type": "text", "text": "あ"}]}})
        s = self.session([rec[:10], rec])
        s.poll()
        self.assertEqual((s.lines, s.offset), ([], 0))
        s.poll()
        self.assertEqual(s.texts, [(1, "あ")])
        self.assertEqual(s.offset, len(rec))

    def test_turn_end_and_new_turn(self):
        s = self.session([self.j({"type": "assistant", "message": {"content": []}},
                                 {"type": "system", "subtype": "turn_duration"}),
                          self.j({"type": "user", "message": {"content": "<task-notification>"}})])
        s.poll()
        self.assertEqual((s.turn_ends, s.in_turn), (1, False))
        self.assertIsNotNone(s.turn_end_at)
        s.poll()
        self.assertEqual((s.turn_ends, s.in_turn), (1, True))

    def test_sidechain_and_garbage_are_skipped(self):
        s = self.session([b"not json\n" + self.j(
            {"type": "assistant", "isSidechain": True, "message": {"content": [{"type": "text", "text": "子"}]}},
            {"type": "system", "subtype": "turn_duration", "isSidechain": True})])
        s.poll()
        self.assertEqual((s.lines, s.texts, s.turn_ends), ([], [], 0))

    def test_text_blocks_are_numbered_and_blank_ones_skipped(self):
        s = self.session([self.j({"type": "assistant", "message": {"content": [
            {"type": "text", "text": "一"}, {"type": "text", "text": "  "}, {"type": "text", "text": "二"}]}})])
        s.poll()
        self.assertEqual(s.texts, [(1, "一"), (2, "二")])

    def test_no_transcript_yet(self):
        s = make()
        s.dexec = lambda script: b""
        s.poll()
        self.assertIsNone(s.tfile)


# ---------------------------------------------------------------- dialogs in the transcript and on screen
class DialogState(unittest.TestCase):
    ask = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "AskUserQuestion",
                                                         "id": "q1", "input": {"questions": []}}]}}
    result = {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "q1"}]}}

    def test_pending_until_result_or_handled(self):
        s = make(lines=[self.ask])
        self.assertEqual(s.pending_question()[0], "q1")
        self.assertTrue(s.dialog_open("q1"))
        s.lines.append(self.result)
        self.assertEqual(s.pending_question(), (None, None))
        self.assertFalse(s.dialog_open("q1"))
        s = make(lines=[self.ask])
        s.handled_questions.add("q1")
        self.assertEqual(s.pending_question(), (None, None))

    def screen(self, data):
        f = tempfile.NamedTemporaryFile(delete=False)
        f.write(data)
        f.close()
        return make(log=types.SimpleNamespace(name=f.name))

    def test_on_screen(self):
        self.assertTrue(self.screen(b"...Enter to select...").dialog_on_screen())
        self.assertFalse(self.screen(b"Enter to select ... User answered Claude's questions").dialog_on_screen())
        self.assertFalse(self.screen(b"Enter to select ... User declined to answer").dialog_on_screen())
        self.assertTrue(self.screen(b"User answered ... Enter to select").dialog_on_screen())
        self.assertFalse(self.screen(b"").dialog_on_screen())

    def test_only_the_last_64k_are_read(self):
        self.assertFalse(self.screen(b"Enter to select" + b"x" * 70000).dialog_on_screen())

    def test_missing_log(self):
        self.assertFalse(make(log=types.SimpleNamespace(name="/nonexistent/x")).dialog_on_screen())

    def test_answer_dialog_without_questions_still_answers_once(self):
        s = make()
        seq = []
        s.key = lambda k: seq.append(k)
        s.type = lambda text, enter=True: seq.append((text, enter))
        s.poll = lambda: None
        s.dialog_open = lambda qid: False
        s.answer_dialog("q", {})
        self.assertEqual(seq, [("お任せします", True)])


# ---------------------------------------------------------------- time limit of stage 4
class TimeUp(unittest.TestCase):
    def test(self):
        s = make(stage=4, stage4_start=time.time() - 3600)
        self.assertTrue(s.time_up())
        s.stage4_start = time.time() - 3590
        self.assertFalse(s.time_up())
        for stage in (1, 3, 45, 5):
            self.assertFalse(make(stage=stage, stage4_start=time.time() - 9999).time_up())
        self.assertFalse(make(stage=4, stage4_start=None).time_up())


# ---------------------------------------------------------------- user role call
class UserRole(unittest.TestCase):
    def run_with(self, outputs, stage=1):
        s = make(stage=stage)
        outs = iter(outputs)
        with mock.patch.object(staged.subprocess, "run",
                               side_effect=lambda *a, **k: types.SimpleNamespace(stdout=next(outs))):
            return s.user_role("m")

    def test_first_valid_answer(self):
        self.assertEqual(self.run_with([json.dumps({"result": "COMPLETE\nx"}).encode()]),
                         ({"choice": "COMPLETE"}, "COMPLETE\nx", 1))

    def test_retries_then_succeeds(self):
        r = self.run_with([b"", b"not json", json.dumps({"result": "REPLY"}).encode()])
        self.assertEqual((r[0], r[2]), ({"choice": "REPLY"}, 3))

    def test_plain_text_output_is_parsed(self):
        self.assertEqual(self.run_with([b"REPLY\nx"])[0], {"choice": "REPLY"})

    def test_gives_up_after_three(self):
        self.assertEqual(self.run_with([b"x", b"y", b"z"]), (None, "z", 3))

    def test_json_without_result(self):
        self.assertEqual(self.run_with([b"{}", b"{}", b"{}"])[0], None)


# ---------------------------------------------------------------- main loop: what happens at each tick
class Loop(unittest.TestCase):
    """One iteration of StagedSession.run with a given state; poll ends the loop afterwards."""

    def tick(self, **state):
        s = make(**state)
        s.answered, s.broke = [], []
        s.answer_dialog = lambda qid, q: s.answered.append(qid)
        s.at_break = state.get("at_break", lambda: s.broke.append(1) or True)
        s.busy = state.get("busy", lambda: False)
        s.dialog_on_screen = state.get("dialog_on_screen", lambda: False)
        s.pending_question = state.get("pending_question", lambda: (None, None))
        def poll():   # the iteration that calls it is the last one
            s.alive = False
        s.poll = poll
        s.pid = os.getpid()
        with mock.patch.object(staged.os, "kill"), \
             mock.patch.object(staged.os, "waitpid", return_value=(0, 0)), \
             mock.patch.object(staged.os, "waitstatus_to_exitcode", return_value=0):
            s.run()
        return s

    ended = {"turn_ends": 1, "handled_turns": 0}

    def test_turn_end_quiet_calls_at_break(self):
        self.assertEqual(self.tick(**self.ended).broke, [1])

    def test_no_new_turn_end(self):
        self.assertEqual(self.tick(turn_ends=1, handled_turns=1).broke, [])

    def test_in_turn_recent_change_or_busy_wait(self):
        self.assertEqual(self.tick(in_turn=True, **self.ended).broke, [])
        self.assertEqual(self.tick(last_change=time.time(), **self.ended).broke, [])
        self.assertEqual(self.tick(busy=lambda: True, **self.ended).broke, [])

    def test_dialog_has_priority_once_quiet(self):
        s = self.tick(pending_question=lambda: ("q1", {}), **self.ended)
        self.assertEqual((s.answered, s.broke), (["q1"], []))
        s = self.tick(pending_question=lambda: ("q1", {}), last_change=time.time(), **self.ended)
        self.assertEqual(s.answered, [])

    def test_time_up_types_closing_text_even_in_a_turn(self):
        s = self.tick(stage=4, stage4_start=time.time() - 3600, in_turn=True, turn_ends=2, handled_turns=2)
        self.assertEqual(s.stage, 45)
        self.assertEqual(s.calls, [("send", "時間です。まとめて", "段階4の制限時間（60分）")])

    def test_time_up_waits_for_dialog(self):
        s = self.tick(stage=4, stage4_start=time.time() - 3600, dialog_on_screen=lambda: True)
        self.assertEqual(s.stage, 4)
        s = self.tick(stage=4, stage4_start=time.time() - 3600, last_change=time.time(),
                      pending_question=lambda: ("q1", {}))
        self.assertEqual(s.stage, 4)

    def test_turn_ends_before_the_time_up_text_are_answered_again(self):
        # Turn ends counted before the closing text was typed are re-examined at stage 45.
        s = self.tick(stage=4, stage4_start=time.time() - 3600, turn_ends=3, handled_turns=3)
        self.assertEqual(s.handled_turns, 3)

    def test_at_break_false_ends_the_session_and_writes_summary(self):
        s = self.tick(at_break=lambda: False, **self.ended)
        with open(os.path.join(s.a.log_dir, "driver-summary.json"), encoding="utf-8") as f:
            self.assertEqual(json.load(f)["final_stage"], 1)

    def test_closed_terminal_is_recorded(self):
        s = self.tick()
        self.assertEqual(events(s)[-1]["event"], "pty_closed")


if __name__ == "__main__":
    unittest.main()
