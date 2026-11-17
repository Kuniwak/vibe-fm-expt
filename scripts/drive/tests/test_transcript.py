"""transcript.Transcript: the session transcript (JSONL) as state, with pure queries.

Ported from test_staged.Poll / Delivery / DialogState and test_driver (pending_question),
plus edge cases of every branch.
"""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from transcript import Transcript  # noqa: E402


def j(*records):
    return b"".join(json.dumps(r, ensure_ascii=False).encode() + b"\n" for r in records)


def text(*texts):
    return {"type": "assistant", "message": {"content": [{"type": "text", "text": t} for t in texts]}}


TURN_END = {"type": "system", "subtype": "turn_duration"}


def with_lines(*records):
    t = Transcript(now=0)
    t.feed(j(*records), now=1)
    return t


class Feed(unittest.TestCase):
    def test_initial_state(self):
        t = Transcript(now=7.5)
        self.assertEqual((t.lines, t.texts, t.offset, t.turn_ends, t.turn_end_at, t.in_turn, t.last_change),
                         ([], [], 0, 0, None, False, 7.5))

    def test_empty_chunk_changes_nothing(self):
        t = Transcript(now=1)
        self.assertFalse(t.feed(b"", now=5))
        self.assertEqual((t.offset, t.last_change), (0, 1))

    def test_partial_line_waits_for_the_rest(self):
        rec = j(text("あ"))
        t = Transcript(now=0)
        self.assertFalse(t.feed(rec[:10], now=3))
        self.assertEqual((t.lines, t.offset, t.last_change), ([], 0, 0))
        self.assertTrue(t.feed(rec, now=4))
        self.assertEqual(t.texts, [(1, "あ")])
        self.assertEqual((t.offset, t.last_change), (len(rec), 4))

    def test_only_complete_lines_are_consumed(self):
        rec = j(text("一"), text("二"))
        t = Transcript(now=0)
        t.feed(rec[:-3], now=1)
        self.assertEqual(t.texts, [(1, "一")])
        self.assertEqual(t.offset, len(j(text("一"))))

    def test_turn_end_and_new_turn(self):
        t = Transcript(now=0)
        t.feed(j({"type": "assistant", "message": {"content": []}}), now=1)
        self.assertTrue(t.in_turn)
        t.feed(j(TURN_END), now=2)
        self.assertEqual((t.turn_ends, t.in_turn, t.turn_end_at), (1, False, 2))
        t.feed(j({"type": "user", "message": {"content": "<task-notification>"}}), now=3)
        self.assertEqual((t.turn_ends, t.in_turn, t.turn_end_at), (1, True, 2))

    def test_other_record_types_do_not_touch_the_turn(self):
        t = with_lines(TURN_END, {"type": "attachment", "attachment": {}}, {"type": "system", "subtype": "x"},
                       {"type": "summary"})
        self.assertEqual((t.turn_ends, t.in_turn, len(t.lines)), (1, False, 4))

    def test_sidechain_and_garbage_are_skipped(self):
        t = Transcript(now=0)
        t.feed(b"not json\n" + j(
            {"type": "assistant", "isSidechain": True, "message": {"content": [{"type": "text", "text": "子"}]}},
            {"type": "system", "subtype": "turn_duration", "isSidechain": True}), now=1)
        self.assertEqual((t.lines, t.texts, t.turn_ends), ([], [], 0))
        self.assertGreater(t.offset, 0)

    def test_text_blocks_are_numbered_and_blank_ones_skipped(self):
        t = with_lines(text("一", "  ", "二"), {"type": "assistant", "message": {"content": "文字列"}},
                       {"type": "assistant", "message": "x"}, {"type": "user", "message": {"content": [
                           {"type": "text", "text": "利用者"}]}}, text("三"))
        self.assertEqual(t.texts, [(1, "一"), (2, "二"), (3, "三")])

    def test_text_block_without_text_field(self):
        self.assertEqual(with_lines({"type": "assistant", "message": {"content": [{"type": "text"}]}}).texts, [])

    def test_crlf_and_blank_lines(self):
        t = Transcript(now=0)
        t.feed(b"\n" + json.dumps(text("a")).encode() + b"\r\n", now=1)
        self.assertEqual(t.texts, [(1, "a")])

    @unittest.expectedFailure
    def test_non_object_json_line_is_skipped(self):
        # Kept bug (also in 85624a4): a JSON line that is not an object (e.g. `1`) raises
        # AttributeError in feed instead of being skipped like other unreadable lines.
        t = Transcript(now=0)
        t.feed(b"1\n" + j(text("a")), now=1)
        self.assertEqual(t.texts, [(1, "a")])

    def test_last_text(self):
        self.assertEqual(Transcript(now=0).last_text(), (0, ""))
        self.assertEqual(with_lines(text("a", "b")).last_text(), (2, "b"))


class UserMessages(unittest.TestCase):
    def test_only_string_user_contents(self):
        t = with_lines({"type": "user", "message": {"content": "A"}},
                       {"type": "user", "message": {"content": [{"type": "tool_result"}]}},
                       {"type": "assistant", "message": {"content": "B"}},
                       {"type": "user", "message": "C"}, {"type": "user"},
                       {"type": "attachment", "attachment": {"type": "queued_command", "prompt": "D"}},
                       {"type": "user", "message": {"content": "E"}})
        self.assertEqual(t.user_messages(), ["A", "E"])


class Delivery(unittest.TestCase):
    typed = {"type": "user", "message": {"content": "X"}}
    queued = {"type": "attachment", "attachment": {"type": "queued_command", "prompt": "X"}}

    def test_counts_typed_and_queued(self):
        t = with_lines(self.typed, self.queued, {"type": "user", "message": {"content": "Y"}})
        self.assertEqual(t.delivered("X"), 2)
        self.assertEqual(t.delivery_index("X"), 1)
        self.assertEqual(t.delivery_index("Y"), 2)
        self.assertIsNone(t.delivery_index("Z"))
        self.assertEqual(t.delivered("Z"), 0)

    def test_odd_records_are_ignored(self):
        t = with_lines({"type": "user", "message": "X"}, {"type": "user"},
                       {"type": "attachment", "attachment": "X"},
                       {"type": "attachment", "attachment": {"type": "other", "prompt": "X"}},
                       {"type": "user", "attachment": {"type": "queued_command", "prompt": "X"}},
                       {"type": "assistant", "message": {"content": "X"}},
                       {"type": "user", "message": {"content": [{"type": "text", "text": "X"}]}})
        self.assertEqual(t.delivered("X"), 0)
        self.assertIsNone(t.delivery_index("X"))

    def test_answered_after(self):
        t = with_lines(self.typed, text("  "), {"type": "assistant", "message": {"content": "文字列"}},
                       {"type": "user", "message": {"content": [{"type": "text", "text": "利用者"}]}})
        self.assertFalse(t.answered_after(0))
        t.feed(j(text("答え")), now=2)
        self.assertTrue(t.answered_after(0))
        self.assertFalse(t.answered_after(len(t.lines) - 1))

    def test_answered_after_counts_sidechain_free_lines_only(self):
        t = with_lines(self.typed)
        t.feed(j({"type": "assistant", "isSidechain": True, "message": {"content": [{"type": "text", "text": "子"}]}}),
               now=2)
        self.assertFalse(t.answered_after(0))


class Questions(unittest.TestCase):
    def ask(self, qid, inp=None):
        c = {"type": "tool_use", "name": "AskUserQuestion", "id": qid}
        if inp is not None:
            c["input"] = inp
        return {"type": "assistant", "message": {"content": [c]}}

    @staticmethod
    def result(qid):
        return {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": qid}]}}

    def test_pending_until_result_or_handled(self):
        t = with_lines(self.ask("q1", {"questions": []}))
        self.assertEqual(t.pending_question(set()), ("q1", {"questions": []}))
        self.assertTrue(t.dialog_open("q1"))
        t.feed(j(self.result("q1")), now=2)
        self.assertEqual(t.pending_question(set()), (None, None))
        self.assertFalse(t.dialog_open("q1"))
        t = with_lines(self.ask("q1", {}))
        self.assertEqual(t.pending_question({"q1"}), (None, None))

    def test_missing_input_is_empty(self):
        self.assertEqual(with_lines(self.ask("q1")).pending_question(set()), ("q1", {}))

    def test_first_unanswered_in_order(self):
        t = with_lines(self.ask("q1"), self.ask("q2"), self.ask("q3"), self.result("q1"))
        self.assertEqual(t.pending_question(set())[0], "q2")
        self.assertEqual(t.pending_question({"q2"})[0], "q3")

    def test_result_before_question_still_counts(self):
        self.assertEqual(with_lines(self.result("q1"), self.ask("q1")).pending_question(set()), (None, None))

    def test_other_tools_and_odd_contents_are_ignored(self):
        t = with_lines({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "id": "b"}]}},
                       {"type": "assistant", "message": {"content": "AskUserQuestion"}},
                       {"type": "assistant", "message": "x"})
        self.assertEqual(t.pending_question(set()), (None, None))

    def test_dialog_open_for_an_unknown_id(self):
        self.assertTrue(Transcript(now=0).dialog_open("never-asked"))


if __name__ == "__main__":
    unittest.main()
