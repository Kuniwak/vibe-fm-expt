"""Tests for summarize.py. Run: python3 -I confirm/test_summarize.py"""
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
RECIPE = '# VIOLATION_RE: "(P[1-6]|T1)-[a-z-]+\\|\n'


def verdicts(base, variants, recipe=RECIPE):
    with tempfile.TemporaryDirectory() as d:
        out = pathlib.Path(d, 'run-00', 'confirm', 'S1')
        out.mkdir(parents=True)
        out.joinpath('tree-base.txt').write_text(base)
        for v, text in variants.items():
            out.joinpath(f'tree-{v}.txt').write_text(text)
        r = pathlib.Path(d, 'recipe.sh')
        r.write_text(recipe)
        s = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'summarize.py'), str(out), str(r)],
                           capture_output=True, text=True, check=True).stdout
    return {l.split('|')[2].strip(): l.split('|')[-2].strip() for l in s.splitlines() if l.startswith('| tree |')}


def out(lines, rc=0):
    return '\n'.join(lines + [f'@@ recipe exit={rc}']) + '\n'


BASE = ['{', ' "fails": {', '  "T1-a|permissive": 17,', '  "T1-b|permissive": 5', ' }', '}']


class Summarize(unittest.TestCase):
    def test_same_output_is_not_detected(self):
        self.assertEqual(verdicts(out(BASE), {'M1': out(BASE)}), {'M1': '非検知'})

    def test_json_key_order_swap_is_not_detected(self):
        swapped = ['{', ' "fails": {', '  "T1-b|permissive": 5,', '  "T1-a|permissive": 17', ' }', '}']
        self.assertEqual(verdicts(out(BASE), {'M1': out(swapped)}), {'M1': '非検知'})

    def test_count_change_alone_is_not_detected(self):
        changed = ['{', ' "fails": {', '  "T1-a|permissive": 18,', '  "T1-b|permissive": 5', ' }', '}']
        self.assertEqual(verdicts(out(BASE), {'M1': out(changed)}), {'M1': '非検知'})

    def test_new_kind_is_detected(self):
        new = ['{', ' "fails": {', '  "P2-publish-throws|closure": 3,', '  "T1-a|permissive": 17,',
               '  "T1-b|permissive": 5', ' }', '}']
        self.assertEqual(verdicts(out(BASE), {'M1': out(new)}), {'M1': '検知'})

    def test_new_kind_as_last_key_is_detected(self):
        new = ['{', ' "fails": {', '  "T1-a|permissive": 17,', '  "T1-b|permissive": 5,',
               '  "P5-traverse-throws|jsdoc": 1', ' }', '}']
        self.assertEqual(verdicts(out(BASE), {'M1': out(new)}), {'M1': '検知'})

    def test_exit_turning_nonzero_is_detected(self):
        self.assertEqual(verdicts(out(BASE), {'M1': out(BASE, rc=1)}), {'M1': '検知'})

    def test_exit_nonzero_in_both_is_not_detected_by_exit(self):
        self.assertEqual(verdicts(out(BASE, rc=1), {'M1': out(BASE, rc=1)}), {'M1': '非検知'})

    def test_patch_not_applied(self):
        self.assertEqual(verdicts(out(BASE), {'M1': '@@ patch does not apply\n'}), {'M1': 'patch does not apply'})


if __name__ == '__main__':
    unittest.main()
