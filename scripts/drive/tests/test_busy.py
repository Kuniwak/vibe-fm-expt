"""busy: whether the agent still has child processes, with the grace period of preregistration 12.5.

Ported from test_driver.Busy (run-30), plus edge cases.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import busy  # noqa: E402

PS_IDLE = "      1 claude\n      1 docker-init\n      1 ps\n      1 sh\n      1 sort\n      1 uniq\n"
PS_SLEEP = PS_IDLE + "      2 sleep\n      1 bash\n"


def decide(ps, in_turn=False, turn_end_at=0.0, turn_ends=1, grace_recorded=0, now=100.0, grace=600):
    return busy.decide(ps, in_turn=in_turn, turn_end_at=turn_end_at, turn_ends=turn_ends,
                       grace_recorded=grace_recorded, now=now, grace=grace)


class OtherProcesses(unittest.TestCase):
    def test_harness_and_agent_processes_are_ignored(self):
        self.assertEqual(busy.other_processes(PS_IDLE), set())
        self.assertEqual(busy.other_processes(PS_SLEEP), {"sleep", "bash"})

    def test_blank_lines_and_last_word(self):
        self.assertEqual(busy.other_processes("\n   \n 3 node\nmake\n"), {"node", "make"})

    def test_script(self):
        self.assertEqual(busy.PS_SCRIPT, "ps -eo comm= | sort | uniq -c")
        self.assertEqual(busy.IGNORED, {"docker-init", "claude", "ps", "sort", "uniq", "sh"})


class Decide(unittest.TestCase):
    def test_no_other_process_is_not_busy(self):
        self.assertEqual(decide(PS_IDLE, in_turn=True, turn_end_at=None), (False, None))

    def test_processes_within_grace(self):
        self.assertEqual(decide(PS_SLEEP, turn_end_at=0, now=599.9), (True, None))

    def test_grace_elapsed_once_per_turn(self):
        b, ev = decide(PS_SLEEP, turn_end_at=0, now=600, turn_ends=3, grace_recorded=2)
        self.assertFalse(b)
        self.assertEqual(ev, {"turn": 3, "seconds_since_turn_end": 600, "processes": ["bash", "sleep"]})
        self.assertEqual(list(ev), ["turn", "seconds_since_turn_end", "processes"])
        self.assertEqual(decide(PS_SLEEP, turn_end_at=0, now=900, turn_ends=3, grace_recorded=3), (False, None))

    def test_seconds_are_truncated(self):
        self.assertEqual(decide(PS_SLEEP, turn_end_at=0.5, now=701.4)[1]["seconds_since_turn_end"], 700)

    def test_in_turn_or_no_turn_end_stays_busy(self):
        self.assertEqual(decide(PS_SLEEP, in_turn=True, turn_end_at=0, now=9999), (True, None))
        self.assertEqual(decide(PS_SLEEP, turn_end_at=None, now=9999), (True, None))

    def test_grace_is_injectable(self):
        self.assertEqual(decide(PS_SLEEP, turn_end_at=0, now=30, grace=30)[0], False)
        self.assertEqual(decide(PS_SLEEP, turn_end_at=0, now=29, grace=30)[0], True)

    def test_default_grace(self):
        self.assertEqual(busy.BUSY_GRACE_SECS, 600)


if __name__ == "__main__":
    unittest.main()
