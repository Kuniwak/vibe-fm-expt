"""Tests for exclude_existing.py. Run: python3 -I confirm/test_exclude_existing.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exclude_existing as X  # noqa: E402

TITLES = {
    'Parser Tuple types should return a tuple type node when "[A, ...]" arrived',
    'traversing should visit an arrow function with no params and `new`',
}
VRE = r'[0-9]+ failing|^ +[0-9]+\) |^ERROR:|P[0-9]-[a-z-]+'


def mocha(failures, passing=335, inline=()):
    """A mocha spec-reporter section: suite listing with inline markers, summary, failure blocks."""
    out = ['', '  Parser', '    Tuple types']
    for n, leaf in inline:
        out.append(f'      {n}) {leaf}')
    out.append('      ✓ should return a name node')
    out += ['', '', f'  {passing} passing (6s)']
    if failures:
        out.append(f'  {len(failures)} failing')
        out.append('')
        for n, path in enumerate(failures, 1):
            out.append(f'  {n}) {path[0]}')
            for depth, comp in enumerate(path[1:], 1):
                out.append(' ' * (5 + 2 * depth) + comp + (':' if depth == len(path) - 1 else ''))
            out += ['', '      AssertionError: expected 1 to equal 2', '      at Context.<anonymous> (tests/t.js:1:2)', '']
    return out


EXISTING = ['Parser', 'Tuple types', 'should return a tuple type node when "[A, ...]" arrived']
ADDED = ['Parser', 'Mine', 'should keep my property']


class Strip(unittest.TestCase):
    def test_no_mocha_output_is_unchanged(self):
        lines = ['P2-publish-throws closure "x"', 'ok']
        self.assertEqual(X.strip(lines, TITLES), (lines, False))

    def test_summary_lines_are_dropped_and_suite_is_seen(self):
        kept, suite = X.strip(mocha([]), TITLES)
        self.assertTrue(suite)
        self.assertFalse(any('passing' in l for l in kept))

    def test_existing_failure_block_and_inline_marker_are_dropped(self):
        lines = mocha([EXISTING], inline=[(1, EXISTING[-1])])
        kept, _ = X.strip(lines, TITLES)
        self.assertFalse(any('1)' in l or 'failing' in l or 'AssertionError' in l for l in kept), kept)

    def test_added_failure_block_is_kept(self):
        lines = mocha([ADDED], inline=[(1, ADDED[-1])])
        kept, _ = X.strip(lines, TITLES)
        self.assertIn('  1) Parser', kept)
        self.assertIn('      1) should keep my property', kept)
        self.assertFalse(any('failing' in l for l in kept))

    def test_mixed_blocks_keep_only_added(self):
        lines = mocha([EXISTING, ADDED], inline=[(1, EXISTING[-1]), (2, ADDED[-1])])
        kept, _ = X.strip(lines, TITLES)
        self.assertNotIn('  1) Parser', kept)
        self.assertIn('  2) Parser', kept)
        self.assertNotIn('      1) ' + EXISTING[-1], kept)
        self.assertIn('      2) ' + ADDED[-1], kept)

    def test_two_mocha_runs_number_independently(self):
        lines = mocha([EXISTING], inline=[(1, EXISTING[-1])]) + ['plain output'] + mocha([ADDED], inline=[(1, ADDED[-1])])
        kept, _ = X.strip(lines, TITLES)
        self.assertEqual([l for l in kept if l.startswith('  1) ')], ['  1) Parser'])
        self.assertIn('plain output', kept)
        self.assertIn('      1) ' + ADDED[-1], kept)

    def test_lines_after_blocks_are_kept(self):
        lines = mocha([EXISTING]) + ['----------|------', 'P5-traverse-throws jsdoc "y"']
        kept, _ = X.strip(lines, TITLES)
        self.assertIn('P5-traverse-throws jsdoc "y"', kept)
        self.assertIn('----------|------', kept)

    def test_npm_run_all_and_coverage_errors_are_dropped(self):
        lines = ['ERROR: Coverage for lines (90%) does not meet global threshold (95%)',
                 'ERROR: "coverage" exited with 4.', 'ERROR: my own check failed']
        kept, _ = X.strip(lines, TITLES)
        self.assertEqual(kept, ['ERROR: my own check failed'])

    def test_hook_failure_is_kept(self):
        hook = ['Parser', '"before all" hook for "x"']
        kept, _ = X.strip(mocha([hook]), TITLES)
        self.assertIn('  1) Parser', kept)


def out(lines, rc=0):
    return '\n'.join(lines + [f'@@ recipe exit={rc}']) + '\n'


class Verdict(unittest.TestCase):
    def test_only_existing_test_newly_fails_is_not_detected(self):
        base = out(mocha([]))
        var = out(mocha([EXISTING], passing=334, inline=[(1, EXISTING[-1])]), rc=1)
        self.assertEqual(X.verdict(base, var, VRE, TITLES), '非検知')

    def test_added_test_newly_fails_is_detected(self):
        base = out(mocha([]))
        var = out(mocha([ADDED], inline=[(1, ADDED[-1])]), rc=1)
        self.assertEqual(X.verdict(base, var, VRE, TITLES), '検知')

    def test_own_check_line_is_detected_next_to_existing_failures(self):
        base = out(mocha([]))
        var = out(mocha([EXISTING], inline=[(1, EXISTING[-1])]) + ['P2-publish-throws closure "x"'], rc=1)
        self.assertEqual(X.verdict(base, var, VRE, TITLES), '検知')

    def test_exit_change_counts_without_a_suite(self):
        self.assertEqual(X.verdict(out(['fine']), out(['fine'], rc=1), VRE, TITLES), '検知')

    def test_exit_change_ignored_with_a_suite(self):
        self.assertEqual(X.verdict(out(mocha([])), out(mocha([]), rc=1), VRE, TITLES), '非検知')

    def test_patch_not_applied_and_build_failed(self):
        self.assertEqual(X.verdict(out([]), '@@ patch does not apply\n', VRE, TITLES), 'patch does not apply')
        self.assertEqual(X.verdict(out([]), '@@ patch applied (tree)\n@@ build failed\n', VRE, TITLES), 'build failed')

    def test_no_exit_status(self):
        self.assertEqual(X.verdict(out([]), '@@ patch applied (tree)\n', VRE, TITLES), '実行不能 (no exit status)')


class Title(unittest.TestCase):
    def test_full_title_from_block(self):
        block = ['  3) Parser', '       Tuple types', '         should x when "a: b" arrived:', '', '      Error']
        self.assertEqual(X.block_title(block), 'Parser Tuple types should x when "a: b" arrived')


if __name__ == '__main__':
    unittest.main()
