"""stages: the staged procedure (preregistration ch. 11) as a pure state machine.

Ported from test_staged.AtBreak / TimeUp, plus edge cases. Each step returns the new state and
the actions the shell executes in order; record field order is part of the expected behaviour.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import stages  # noqa: E402
from stages import Exit, FileText, MarkTime, Record, Send, Snapshot, StartClock, State  # noqa: E402

CFG = stages.Config(reply="お任せします", fixed="最後の問い", remake_text="{n}番を作り直して",
                    evidence_text="{n}番の証拠を", read={"done": "まとめて", "timeup": "時間です。まとめて"}.get)
LAST = (7, "最後の発言")


def role(state, parsed, last=LAST):
    return stages.after_role(state, CFG, last, "入力", parsed, "出力", 2)


BASE = {"after_message": 7, "role_input": "入力", "role_output": "出力", "role_attempts": 2}


def judge(state, **types):
    return role(state, {"choice": "JUDGE", "types": {int(k[1:]): v for k, v in types.items()}})


class Initial(unittest.TestCase):
    def test_state(self):
        s = State()
        self.assertEqual((s.stage, s.verdict, s.instructions, s.stage45_text),
                         (1, {1: None, 2: None, 3: None}, {1: 0, 2: 0, 3: 0}, None))

    def test_constants(self):
        self.assertEqual((stages.TYPES, stages.MAX_INSTRUCTIONS), ((1, 2, 3), 2))

    def test_break_kind(self):
        self.assertEqual([stages.break_kind(State(stage=n)) for n in (1, 3, 4, 45, 5)],
                         ["role", "role", "role", "closing", "final"])


class Stage1(unittest.TestCase):
    def test_reply(self):
        s, acts = role(State(), {"choice": "REPLY"})
        self.assertEqual(s.stage, 1)
        self.assertEqual(acts, [Send("お任せします", 1, dict(rule="規則による「お任せします」", **BASE))])
        self.assertEqual(list(acts[0].fields), ["rule", "after_message", "role_input", "role_output",
                                                "role_attempts"])

    def test_complete_snapshots_and_sends_stage2(self):
        s, acts = role(State(), {"choice": "COMPLETE"})
        self.assertEqual(s.stage, 3)
        self.assertEqual(acts, [MarkTime("stage2_start"), Snapshot("S1", 1),
                                Send(FileText("stage2"), 3, dict(rule="段階2の固定文", **BASE))])

    def test_role_error_exits(self):
        for stage in (1, 3, 4):
            s, acts = role(State(stage=stage), None)
            self.assertEqual(s.stage, stage)
            self.assertEqual(acts, [Record(dict(event="role_error", stage=stage, **BASE)), Exit()])
            self.assertEqual(list(acts[0].fields)[:2], ["event", "stage"])

    def test_input_state_is_not_mutated(self):
        s0 = State()
        role(s0, {"choice": "COMPLETE"})
        self.assertEqual(s0.stage, 1)


class Stage3(unittest.TestCase):
    def test_all_approve_moves_to_stage4(self):
        s, acts = judge(State(stage=3), t1="APPROVE", t2="APPROVE", t3="APPROVE")
        self.assertEqual((s.stage, s.verdict), (4, {1: "APPROVE", 2: "APPROVE", 3: "APPROVE"}))
        dec = {t: {"judgement": "APPROVE", "verdict": "APPROVE", "instructions": 0} for t in (1, 2, 3)}
        self.assertEqual(acts, [Record(dict(event="review", stage=3, decisions=dec, **BASE)),
                                MarkTime("stage4_start"), Snapshot("S2", 3), StartClock(),
                                Send(FileText("stage4"), 4, {"rule": "段階4の固定文", "after_message": 7})])

    def test_instructions_are_combined_in_type_order(self):
        s, acts = judge(State(stage=3), t3="REMAKE", t1="EVIDENCE", t2="APPROVE")
        self.assertEqual(acts[1], Send("1番の証拠を\n3番を作り直して", 3, {"rule": "段階3の規則", "after_message": 7}))
        self.assertEqual(len(acts), 2)
        self.assertEqual((s.instructions, s.verdict), ({1: 1, 2: 0, 3: 1}, {1: None, 2: "APPROVE", 3: None}))
        self.assertEqual(list(acts[0].fields["decisions"]), [1, 2, 3])
        self.assertEqual(acts[0].fields["decisions"][3], {"judgement": "REMAKE", "verdict": None, "instructions": 1})

    def test_third_non_approval_fails_the_type(self):
        s = State(stage=3, verdict={1: None, 2: "APPROVE", 3: "APPROVE"})
        for _ in range(2):
            s, _ = judge(s, t1="REMAKE")
        self.assertEqual((s.instructions[1], s.stage), (2, 3))
        s, acts = judge(s, t1="EVIDENCE")
        self.assertEqual((s.verdict[1], s.stage, s.instructions[1]), ("FAILED", 4, 2))
        self.assertEqual(acts[0].fields["decisions"], {1: {"judgement": "EVIDENCE", "verdict": "FAILED",
                                                           "instructions": 2}})
        self.assertEqual(acts[2], Snapshot("S2", 3))

    def test_failed_type_alongside_new_instructions_stays_in_stage3(self):
        s = State(stage=3, instructions={1: 2, 2: 0, 3: 0}, verdict={1: None, 2: None, 3: "APPROVE"})
        s, acts = judge(s, t1="REMAKE", t2="REMAKE")
        self.assertEqual((s.stage, s.verdict[1], s.instructions[2]), (3, "FAILED", 1))
        self.assertEqual(acts[1].text, "2番を作り直して")

    def test_decided_types_are_not_judged_again(self):
        s = State(stage=3, verdict={1: "APPROVE", 2: None, 3: None})
        s, acts = judge(s, t1="REMAKE", t2="APPROVE", t3="APPROVE")
        self.assertEqual((s.instructions[1], s.stage), (0, 4))
        self.assertNotIn(1, acts[0].fields["decisions"])

    def test_reply(self):
        s, acts = role(State(stage=3), {"choice": "REPLY"})
        self.assertEqual((s.stage, acts), (3, [Send("お任せします", 3, dict(rule="規則による「お任せします」", **BASE))]))


class Stage4(unittest.TestCase):
    def test_complete_sends_done_text(self):
        s, acts = role(State(stage=4), {"choice": "COMPLETE"})
        self.assertEqual((s.stage, s.stage45_text), (45, "まとめて"))
        self.assertEqual(acts, [Send("まとめて", 45, dict(rule="段階4の完了の報告を受けた（「時間です。」を省く）", **BASE))])

    def test_reply(self):
        s, acts = role(State(stage=4), {"choice": "REPLY"})
        self.assertEqual((s.stage, acts[0].text), (4, "お任せします"))

    def test_branch_is_chosen_by_stage_not_by_choice(self):
        # As in 85624a4: any answer other than REPLY is the stage's own answer (parse_role only
        # lets COMPLETE through in stages 1 and 4); a stage without a role step does nothing.
        self.assertEqual(role(State(stage=4), {"choice": "JUDGE", "types": {}})[0].stage, 45)
        self.assertEqual(role(State(stage=1), {"choice": "JUDGE", "types": {}})[0].stage, 3)
        s, acts = role(State(stage=2), {"choice": "COMPLETE"})
        self.assertEqual((s.stage, acts), (2, []))

    def test_time_up(self):
        s, acts = stages.time_up(State(stage=4), CFG, LAST, agent_busy=True)
        self.assertEqual((s.stage, s.stage45_text), (45, "時間です。まとめて"))
        self.assertEqual(acts, [Send("時間です。まとめて", 45, {"rule": "段階4の制限時間（60分）", "after_message": 7,
                                                            "agent_busy": True})])

    def test_is_time_up(self):
        f = stages.is_time_up
        self.assertTrue(f(4, 0, 3600, 60))
        self.assertFalse(f(4, 10, 3609, 60))
        self.assertTrue(f(4, 0, 90, 1.5))
        for stage in (1, 3, 45, 5):
            self.assertFalse(f(stage, 0, 9999, 60))
        self.assertFalse(f(4, None, 9999, 60))


class Closing(unittest.TestCase):
    def test_waits_for_text_after_closing_message(self):
        s0 = State(stage=45, stage45_text="まとめて")
        s, acts = stages.closing(s0, CFG, LAST, answered=False)
        self.assertEqual(s.stage, 45)
        self.assertEqual(acts, [Record({"event": "wait", "stage": 45, "after_message": 7,
                                        "reason": "no agent text after the stage-4 closing message yet"})])

    def test_answered_sends_the_final_question(self):
        s, acts = stages.closing(State(stage=45, stage45_text="まとめて"), CFG, LAST, answered=True)
        self.assertEqual(s.stage, 5)
        self.assertEqual(acts, [Send("最後の問い", 5, {"after_message": 7, "rule": "段階5の固定文"})])
        self.assertEqual(list(acts[0].fields), ["after_message", "rule"])

    def test_final_snapshots_and_exits(self):
        s, acts = stages.final(State(stage=5), LAST)
        self.assertEqual(s.stage, 5)
        self.assertEqual(acts, [Snapshot("S3", 5), Record({"event": "end", "after_message": 7,
                                                           "reason": "agent answered the final question"}), Exit()])


class Summary(unittest.TestCase):
    def test_fields(self):
        s = State(stage=5, verdict={1: "APPROVE", 2: "FAILED", 3: "APPROVE"})
        self.assertEqual(stages.summary_fields(s), {"final_stage": 5, "verdicts": s.verdict,
                                                    "instructions": s.instructions, "fixed_sent": True})
        self.assertFalse(stages.summary_fields(State(stage=45))["fixed_sent"])


if __name__ == "__main__":
    unittest.main()
