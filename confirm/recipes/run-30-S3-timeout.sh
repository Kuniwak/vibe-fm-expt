# shellcheck shell=bash
# run-30 (D2), snapshot S3-timeout. The run hit the 180-minute limit after the stage-3 report (#13);
# stages 4 and 5 did not happen, so the check was never changed after stage 1.
# Working directory: /home/dev/jsdoctypeparser (HEAD d395aa0, uncommitted changes).
# lib/, peg_src/, peg_lib/, tests/ and /tmp/verify/check.js are byte-identical to S1.
#
# Library changes by the subject (uncommitted, made in stage 1, call 12):
#   - lib/publishing.js: NULLABLE / NOT_NULLABLE go through a new publishNullability(); when the
#     operand is itself NULLABLE or NOT_NULLABLE the operator is printed in suffix form.
#   - peg_src/jsdoctype.pegjs (QualifiedMemberName): MEMBER.name = tokens[3].name, plus
#     quoteStyle: 'none', hasEventPrefix: false (was name: tokens[3], a NAME node).
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js: regenerated from the above.
#   - tests/test_parsing.js (+1 test), tests/test_publishing.js (+5 tests): regression tests.
#
# Artifact: /tmp/verify/check.js (bounded exhaustive check; require(argv[2]) -> index.js -> lib/ + peg_lib/).
#   All token sequences of length <= 3 over 40 tokens, plus 200000 random sequences of length 4-11
#   (fixed seed), 4 modes x 5 startRules. Properties P4 (non-SyntaxError exception from parse, judged
#   by e.name), P0 (publish throws), P1 (reparse / round trip, meta ignored), P2 (idempotence),
#   P3 (traverse throws / incomplete).
# Source of the command: call 25 (stage 3; the unchanged check run on the base copy and on each mutant):
#   `timeout 900 node /tmp/verify/check.js /tmp/mutants/$m 3 200000`
#   described in #13 「前回と同じ検証（/tmp/verify/check.js、長さ3以下の全列とランダム20万件）を変更せずに
#   実行しました。各実行には15分のタイムアウトを設けています」. Here the library path is the real tree,
#   as in the stage-1 command (call 17: `node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 200000`).
# Output: JSON summary line, then util.inspect(fails); `{}` when nothing is found (base.out, call 26).
#   Violation output examples (call 26 / call 32, subject's mutants):
#     'P4 non-SyntaxError exception': [
#       {
#         s: '{}',
#     'P3 traverse throws': [
#       {
#         s: 'b.c',
# VIOLATION_RE: '(P[0-9][^']*)': \[|\bs: '
#
# Notes:
# - check.js always exits 0. Non-zero exit: a crash (line 43 `publish(ast2)` is outside try), or
#   124 from the subject's `timeout 900` when an input does not terminate or the check slows down.
#   The subject's m3a (publish infinite loop) ended with exit 124 and no output at all, since results
#   are printed only at the end; m3b (traverse infinite recursion) took 815 s (#13, call 32).
# - Duration: 135 s for the base copy with 9 checks running in parallel (call 25/26, base.out
#   "ms":134546); about 63 s alone (call 17).
# - The `s:` alternative lets a newly failing input show up when the property key already exists in
#   the base output (orig mode: the pinned library already fails P1/P2). Only the first 15 entries per
#   property are printed.
#
# Not included:
# - /tmp/mutants/apply.py and the /tmp/mutants/* copies: the subject's own mutants (a check of the check).
# - /tmp/verify/show.js (call 27): prints parse/publish/reparse of hand-picked inputs for a given
#   library; it has no pass/fail criterion. Used to explain mutants and the `...a|b` table mismatch.
# - The subject's hand comparison with the precedence table (call 21) is not a script.
# - npm test: last run in stage 1 (call 17); not described as the verification in #13.
timeout 900 node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 200000 < /dev/null
