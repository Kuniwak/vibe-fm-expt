"""policy (what the main loop does this tick) and protocol (conditions A-C at a break).

Ported from test_staged.Loop, plus edge cases; the probes on_screen and busy do I/O, so the
tests also check that they are consulted only where the original loop consulted them.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import policy  # noqa: E402
import protocol  # noqa: E402


class Probe:
    def __init__(self, value):
        self.value, self.calls = value, 0

    def __call__(self):
        self.calls += 1
        return self.value


def decide(**kw):
    view = dict(now=100.0, qid=None, last_change=0.0, turn_ends=1, handled_turns=0, in_turn=False,
                time_up=False, quiet=20, dialog_quiet=5, on_screen=Probe(False), busy=Probe(False))
    view.update(kw)
    return policy.decide(**view), view


class Decide(unittest.TestCase):
    def test_turn_end_quiet_is_a_break(self):
        got, v = decide()
        self.assertEqual(got, policy.BREAK)
        self.assertEqual((v["busy"].calls, v["on_screen"].calls), (1, 0))

    def test_no_new_turn_end_waits_without_probing(self):
        got, v = decide(turn_ends=1, handled_turns=1)
        self.assertEqual((got, v["busy"].calls), (policy.WAIT, 0))
        self.assertEqual(decide(turn_ends=0, handled_turns=1)[0], policy.WAIT)

    def test_in_turn_or_recent_change_waits_without_probing_busy(self):
        got, v = decide(in_turn=True)
        self.assertEqual((got, v["busy"].calls), (policy.WAIT, 0))
        got, v = decide(last_change=80.01)
        self.assertEqual((got, v["busy"].calls), (policy.WAIT, 0))

    def test_quiet_boundary(self):
        self.assertEqual(decide(last_change=80.0)[0], policy.BREAK)       # exactly QUIET_SECS

    def test_busy_waits(self):
        got, v = decide(busy=Probe(True))
        self.assertEqual((got, v["busy"].calls), (policy.WAIT, 1))

    def test_dialog_has_priority_once_quiet(self):
        self.assertEqual(decide(qid="q1")[0], policy.DIALOG)
        self.assertEqual(decide(qid="q1", time_up=True)[0], policy.DIALOG)
        self.assertEqual(decide(qid="q1", last_change=95.0)[0], policy.WAIT)    # exactly 5 s: not yet
        self.assertEqual(decide(qid="q1", last_change=94.9)[0], policy.DIALOG)
        self.assertEqual(decide(qid="q1", last_change=99.0, in_turn=True)[0], policy.WAIT)

    def test_time_up_even_in_a_turn(self):
        got, v = decide(time_up=True, in_turn=True, turn_ends=2, handled_turns=2)
        self.assertEqual((got, v["on_screen"].calls, v["busy"].calls), (policy.TIME_UP, 1, 0))

    def test_time_up_waits_for_dialog(self):
        got, v = decide(time_up=True, on_screen=Probe(True))
        self.assertEqual(got, policy.BREAK)            # falls through to the break rules
        got, v = decide(time_up=True, qid="q1", last_change=99.0, in_turn=True)
        self.assertEqual((got, v["on_screen"].calls), (policy.WAIT, 0))

    def test_time_up_not_set_does_not_look_at_the_screen(self):
        self.assertEqual(decide()[1]["on_screen"].calls, 0)

    def test_handled_turns_after_time_up(self):
        # Turn ends counted before the closing text was typed are re-examined at stage 45.
        self.assertEqual(policy.handled_after_time_up(3, 3), 3)
        self.assertEqual(policy.handled_after_time_up(3, 2), 2)
        self.assertEqual(policy.handled_after_time_up(1, 2), 1)


class Protocol(unittest.TestCase):
    def test_at_break(self):
        self.assertEqual(protocol.at_break(fixed_sent=True, replies=0, max_replies=3), protocol.END)
        self.assertEqual(protocol.at_break(fixed_sent=False, replies=3, max_replies=3), protocol.LIMIT)
        self.assertEqual(protocol.at_break(fixed_sent=False, replies=4, max_replies=3), protocol.LIMIT)
        self.assertEqual(protocol.at_break(fixed_sent=False, replies=2, max_replies=3), protocol.ASK)
        self.assertEqual(protocol.at_break(fixed_sent=False, replies=0, max_replies=0), protocol.LIMIT)

    def test_limit_answer(self):
        self.assertEqual(protocol.limit_answer(3), ("2", "reply limit 3 reached", 0, ""))

    def test_after_answer(self):
        self.assertEqual(protocol.after_answer("1", replies=1, fixed_sent=False, reply="R", fixed="F"),
                         ("R", 2, False))
        self.assertEqual(protocol.after_answer("2", replies=1, fixed_sent=False, reply="R", fixed="F"),
                         ("F", 1, True))

    def test_records(self):
        self.assertEqual(protocol.end_record((4, "x")),
                         {"event": "end", "after_message": 4, "reason": "agent answered the fixed message"})
        self.assertEqual(protocol.error_record((4, "x"), "raw"),
                         {"event": "operator_error", "after_message": 4, "raw": "raw"})
        r = protocol.sent_record((4, "x"), "1", "why", 2, "R", True)
        self.assertEqual(list(r.items()), [("event", "sent"), ("after_message", 4), ("agent_text", "x"),
                                           ("operator_choice", "1"), ("operator_reason", "why"),
                                           ("operator_attempts", 2), ("sent", "R"), ("confirmed", True)])

    def test_summary(self):
        self.assertEqual(list(protocol.summary_fields(1, True)), ["replies_sent", "fixed_sent"])


if __name__ == "__main__":
    unittest.main()
