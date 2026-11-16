# shellcheck shell=bash
# run-30 (D2), snapshot S1 (end of stage 1). Working directory: /home/dev/jsdoctypeparser
# (HEAD d395aa0, uncommitted changes; the check itself lives only in /tmp/verify/).
#
# Library changes by the subject (uncommitted, call 12; peg_lib rebuilt by npm test's pretest, call 15-17):
#   - lib/publishing.js: NULLABLE / NOT_NULLABLE go through a new publishNullability(); when the
#     operand is itself NULLABLE or NOT_NULLABLE the operator is printed in suffix form.
#   - peg_src/jsdoctype.pegjs (QualifiedMemberName): MEMBER.name = tokens[3].name, plus
#     quoteStyle: 'none', hasEventPrefix: false (was name: tokens[3], a NAME node).
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js: regenerated from the above.
#   - tests/test_parsing.js (+1 test), tests/test_publishing.js (+5 tests): regression tests.
#
# Artifact: /tmp/verify/check.js (bounded exhaustive check; require(argv[2]) -> index.js -> lib/ + peg_lib/).
#   All token sequences of length <= 3 over 40 tokens, plus 200000 random sequences of length 4-11
#   (fixed seed), parsed in 4 modes x 5 startRules. Properties: P4 parse throws only SyntaxError
#   (judged by e.name), P0 publish does not throw, P1 publish output reparses to the same AST
#   (meta ignored), P2 publish idempotent, P3 traverse visits every node once, balanced.
# Source of the command: call 17 (the last check run in stage 1, after the fixes):
#   `node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 200000`
#   reported in #6 「長さ3以下の全入力と、長さ4〜11のランダム入力20万件を検査しました ... P1〜P4 の違反は0件でした」.
# Output: line 1 is a JSON summary, then util.inspect(fails). No violations prints `{}` (call 17).
#   Violations print one key per property, e.g. (call 5, before the fixes):
#     'P1 published string not reparseable': [
#       {
#         s: '?a?',
#   and in short form (call 4): { s: 'a?', mode: 'jsdoc', startRule: 'TopTypeExpr', out: '?a' },
#   Stage-3 mutant runs (S3 tree, same check.js) showed e.g. 'P4 non-SyntaxError exception': [ ,
#   'P3 traverse throws': [  (call 25, call 32).
# VIOLATION_RE: '(P[0-9][^']*)': \[|\bs: '
#
# Notes:
# - check.js always exits 0 (it only prints). A non-zero exit means a crash: e.g. line 43
#   `publish(ast2)` is outside try, so a publish exception on the reparsed AST aborts the run
#   with a stack trace, or the require of the library fails.
# - There is no per-input timeout and the result is printed only at the end. A non-terminating
#   input makes the whole run hang until the harness's 5400 s limit (exit 124, no output);
#   the subject observed this with its own mutant m3a (#13).
# - Duration: about 63 s in the subject's container (call 17: "ms":63445); 135 s when 9 copies
#   ran in parallel (call 25, base.out).
# - The `s:` alternative lets a newly failing input show up when the property key already
#   exists in the base output (e.g. in orig mode, where the pinned library already fails P1/P2
#   on `?a?`, `typeof b.c`, `??!`, ...). Only the first 15 entries per property are printed.
#
# Not included:
# - npm test: run together in call 17 (341 passing). The subject's report treats the existing
#   tests separately from the verification (#4 「既存のテスト（npm test）は335件すべて通っており ...
#   以下の2件は今のテストでは検出されていません」). If the harness wants it, the command text is
#   `npm test` (call 17, piped to grep).
# - /tmp/verify/check_all.js: a sed-modified copy of an earlier check.js used only to list all
#   failing inputs (calls 6-7; output in /tmp/verify/all.txt). Same properties as check.js.
node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 200000 < /dev/null
