"""Old-vs-new equivalence: each simulated scenario must give exactly what the original harness
(commit 85624a4) gave: every byte typed and its virtual time, every docker exec / user-role /
tar call, every select timeout and read (as a digest), operator.jsonl, driver-summary.json,
terminal.log and the files left in the log directory. See sim.py.
"""
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))
import driver  # noqa: E402
import sim  # noqa: E402
import staged  # noqa: E402

GOLDEN = os.path.join(HERE, "golden")


class Equivalence(unittest.TestCase):
    maxDiff = None

    def test_golden_covers_every_scenario(self):
        self.assertEqual(sorted(f[:-5] for f in os.listdir(GOLDEN)), sorted(sim.SCENARIOS))

    def check(self, name):
        with open(os.path.join(GOLDEN, name + ".json"), encoding="utf-8") as f:
            want = json.load(f)
        got = json.loads(json.dumps(sim.run_scenario(name, sim.SCENARIOS[name], staged, driver),
                                    ensure_ascii=False))
        for key in ("trace", "operator_jsonl", "summary", "terminal_log", "files", "rc", "fine_sha256"):
            self.assertEqual(got[key], want[key], f"{name}: {key}")


def _add(name):
    setattr(Equivalence, "test_" + name, lambda self: self.check(name))


for _name in sim.SCENARIOS:
    _add(_name)


if __name__ == "__main__":
    unittest.main()
