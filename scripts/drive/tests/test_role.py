"""role: the user role's / blind operator's output (claude -p JSON), its parsing, the role message,
and the retry rule. Ported from test_staged.Parse / RoleMessage / UserRole, plus edge cases.
"""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import role  # noqa: E402

PENDING = {1: None, 2: None, 3: None}


def parse(result, stage=1, verdict=None):
    return role.parse_role(result, stage, verdict or dict(PENDING))


class ModelResult(unittest.TestCase):
    def test_envelope(self):
        self.assertEqual(role.model_result(json.dumps({"result": "REPLY\nx"}).encode()),
                         (json.dumps({"result": "REPLY\nx"}), "REPLY\nx"))

    def test_envelope_without_result(self):
        self.assertEqual(role.model_result(b"{}"), ("{}", ""))

    def test_plain_text_and_invalid_utf8(self):
        self.assertEqual(role.model_result(b"REPLY\nx"), ("REPLY\nx", "REPLY\nx"))
        self.assertEqual(role.model_result(b"\xff"), ("�", "�"))
        self.assertEqual(role.model_result(b""), ("", ""))

    def test_json_that_is_not_an_object(self):
        # Fixed after the refactor (bug in 85624a4): stdout that is a JSON scalar or list (e.g. a bare "1" or
        # "null") makes .get raise AttributeError, which stops the harness instead of a retry.
        self.assertEqual(role.model_result(b"1"), ("1", "1"))


class ParseRole(unittest.TestCase):
    def test_stage1_and_4_accept_only_reply_or_complete_on_first_line(self):
        for stage in (1, 4):
            self.assertEqual(parse("REPLY\n理由", stage), {"choice": "REPLY"})
            self.assertEqual(parse("\n\n  COMPLETE  \n理由", stage), {"choice": "COMPLETE"})
            for bad in ("", "  \n ", "reply", "COMPLETE です", "理由\nCOMPLETE", "1: APPROVE", "JUDGE"):
                self.assertIsNone(parse(bad, stage), (stage, bad))

    def test_stage3_needs_every_pending_type(self):
        full = "1: APPROVE\n2: REMAKE\n3: EVIDENCE"
        self.assertEqual(parse(full, 3), {"choice": "JUDGE", "types": {1: "APPROVE", 2: "REMAKE", 3: "EVIDENCE"}})
        self.assertIsNone(parse("1: APPROVE\n2: REMAKE", 3))
        self.assertEqual(parse("1: APPROVE\n2: REMAKE", 3, {1: None, 2: None, 3: "APPROVE"})["choice"], "JUDGE")

    def test_stage3_with_nothing_pending_accepts_any_text(self):
        done = {1: "APPROVE", 2: "FAILED", 3: "APPROVE"}
        self.assertEqual(parse("なにか", 3, done), {"choice": "JUDGE", "types": {}})

    def test_stage3_formats(self):
        self.assertEqual(parse("1：APPROVE\n2 : REMAKE\n3:EVIDENCE 理由", 3)["types"],
                         {1: "APPROVE", 2: "REMAKE", 3: "EVIDENCE"})
        self.assertIsNone(parse("1: approve\n2: REMAKE\n3: EVIDENCE", 3))
        self.assertIsNone(parse("1: APPROVED\n2: REMAKE\n3: EVIDENCE", 3))   # \b after the word
        self.assertIsNone(parse("4: APPROVE\n2: REMAKE\n3: EVIDENCE", 3))
        self.assertIsNone(parse("- 1: APPROVE\n2: REMAKE\n3: EVIDENCE", 3))  # must start the line
        self.assertEqual(parse("  1: APPROVE  \n2:REMAKE\n3: EVIDENCE", 3)["types"][1], "APPROVE")
        self.assertEqual(parse("REPLY\n1: APPROVE", 3), {"choice": "REPLY"})
        self.assertIsNone(parse("", 3))

    def test_stage3_repeated_type_last_one_wins(self):
        self.assertEqual(parse("1: REMAKE\n1: APPROVE\n2: APPROVE\n3: APPROVE", 3)["types"][1], "APPROVE")

    def test_other_stages_use_the_stage3_rule(self):
        # parse is called only in stages 1, 3 and 4; any other stage is read like stage 3.
        self.assertEqual(parse("REPLY", 5), {"choice": "REPLY"})
        self.assertIsNone(parse("COMPLETE", 45))


class RoleMessage(unittest.TestCase):
    def test_only_texts_since_last_send(self):
        m = role.role_message(1, PENDING, [(1, "古い"), (2, "新しいA"), (3, "新しいB")], 1)
        self.assertEqual(m, "現在の段階: 1\n\nアシスタントの最後の発言:\n\n新しいA\n\n新しいB")

    def test_no_text(self):
        self.assertEqual(role.role_message(4, PENDING, [(1, "x")], 1),
                         "現在の段階: 4\n\nアシスタントの最後の発言:\n\n（テキストなし）")

    def test_stage3_lists_pending_types(self):
        m = role.role_message(3, {1: None, 2: "APPROVE", 3: None}, [(1, "変種")], 0)
        self.assertEqual(m, "現在の段階: 3\n判断が済んでいない種類: 1, 3\n\nアシスタントの最後の発言:\n\n変種")

    def test_stage3_with_nothing_pending(self):
        self.assertIn("判断が済んでいない種類: \n", role.role_message(3, {1: "A", 2: "A", 3: "A"}, [], 0))


class ParseOperator(unittest.TestCase):
    def test_choice_and_reason(self):
        self.assertEqual(role.parse_operator("1\n質問している\n二行目"), ("1", "質問している 二行目"))
        self.assertEqual(role.parse_operator("  2  \n"), ("2", ""))
        self.assertEqual(role.parse_operator("\n2\n理由"), ("2", "理由"))

    def test_invalid(self):
        for bad in ("", "  ", "3", "1 です", "理由\n1", "１"):
            self.assertIsNone(role.parse_operator(bad), bad)


class Retry(unittest.TestCase):
    def ask(self, outputs, parse=lambda r: {"choice": r} if r == "OK" else None):
        sent = []
        outs = iter(outputs)

        def run_once(message):
            sent.append(message)
            return next(outs)
        return role.ask(run_once, "m", parse), sent

    def test_first_valid_answer(self):
        self.assertEqual(self.ask([json.dumps({"result": "OK"}).encode()]), (({"choice": "OK"}, "OK", 1), ["m"]))

    def test_retries_then_succeeds(self):
        r, sent = self.ask([b"", b"not json", b"OK"])
        self.assertEqual((r, sent), (({"choice": "OK"}, "OK", 3), ["m"] * 3))

    def test_gives_up_after_three_with_the_last_raw_output(self):
        self.assertEqual(self.ask([b"x", b"{}", b'{"result": "y"}'])[0], (None, '{"result": "y"}', 3))

    def test_attempts(self):
        self.assertEqual(role.ATTEMPTS, 3)
        self.assertEqual(role.TIMEOUT_SECS, 300)
        self.assertEqual(role.NO_TEXT, "（テキストなし）")


if __name__ == "__main__":
    unittest.main()
