# shellcheck shell=bash
# run-29 (D), snapshot S1 (end of stage 1). Working directory /home/dev/jsdoctypeparser
# (HEAD d395aa0, nothing committed by the subject).
# The subject changed the library (uncommitted):
#   - peg_src/jsdoctype.pegjs: QualifiedMemberName puts the name string (not a node) into MEMBER.name,
#     with quoteStyle 'none' and hasEventPrefix false (call 19; fix for `typeof A.b`).
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js: regenerated from it (npm run build).
#   - lib/publishing.js: suffix `?` `!` `...` are published in the suffix form (isSuffixNullability,
#     VARIADIC SUFFIX_DOTS); NAMED_PARAMETER without a type publishes `name:` (calls 26-29, 38).
#   - tests/test_publishing.js: 3 expectations changed, 11 round-trip tests added (calls 39, 57).
#   lib/, peg_src/, peg_lib/ are identical in S1 and S3.
#
# Artifacts: verification/ (untracked): Lake project (QuoteRoundTrip.lean, Roundtrip.lean,
#   executables diff/rtdiff from Diff.lean/RtDiff.lean), diff-test.js, rt-diff-test.js, fuzz-roundtrip.js.
#   diff-test.js and rt-diff-test.js run .lake/build/bin/{diff,rtdiff} (the Lean models) and
#   compare them with the real library (require('..') -> index.js -> lib/ + peg_lib/).
#   fuzz-roundtrip.js checks parse(publish(parse(s))) deep-equals parse(s) on the real library.
#   The Lean proofs themselves are about hand-written models and do not read the JS.
# Sources of the commands:
#   - verification/README.md (written in call 67, quoted in #25 "再実行方法は verification/README.md"):
#       cd verification; lake build; node diff-test.js; node rt-diff-test.js; node fuzz-roundtrip.js 1 100000
#   - call 67 (last run in stage 1): `cd verification && lake build 2>&1 | tail -1 && node diff-test.js &&
#       node rt-diff-test.js 3 && node fuzz-roundtrip.js 21 100000 && cd .. && npm test 2>&1 | grep -E "passing|failing"`
#   - call 72 (/tmp/run-suite.sh, first call of stage 3, verification/ unchanged since S1):
#       lake build; node diff-test.js; node rt-diff-test.js 1 200000; node fuzz-roundtrip.js 1 100000
#   The README's arguments (the defaults; same as call 72) are used here, not call 67's seeds 3 / 21.
#   npm test is included because #25 lists "既存テスト：回帰テスト 11 件を追加し、全 346 件が通ります"
#   under the checks of the real code (call 67 ran it last).
# Exit status: none of the three node scripts sets a non-zero exit status on a violation in S1
#   (#28: 「どのスクリプトも違反があっても 0 で終わります」); only lake build and npm test do.
#   This recipe runs every step (not &&-chained as in call 67) and exits 1 if any step exits non-zero.
# Violation lines (examples from the record):
#   fuzz-roundtrip.js (call 16, 22): `ERR reparse 13308 {"src":"typeof A.b",...}`,
#     `ERR publish 9640 {"src":"(a:) => 1",...}`, `AST differs 29263 {"src":"1!",...}`
#   rt-diff-test.js (call 66, old publisher): `87184 inputs x 4 modes: model accepted 47928, mismatches 35720, ...`
#     followed by `{"s":"A?","mode":"permissive","lean":"(Ns A) A?","js":"(Ns A) ?A"}`;
#     (call 64) `..., accepted only by JS within fragment 3476`
#   diff-test.js prints `model mismatch "..."` / `e2e fail ...` and `N mismatches` / `N failures`.
#   lake build: `error: ...` (e.g. call 60 `Roundtrip.lean:498:6: error: unsolved goals`).
#   npm test: `N failing` (call 61 `14 failing`).
# VIOLATION_RE: ^ERR |^AST differs|^model mismatch|^e2e fail|[1-9][0-9]* mismatches|[1-9][0-9]* failures|mismatches [1-9]|fragment [1-9]|^\{"s":|error:|[1-9][0-9]* failing|ERROR:|^ +[0-9]+:[0-9]+ +error\b
#
# Notes:
# - rt-diff-test.js maps every exception thrown by the library to "none" (= rejected); a non-syntax
#   exception shows up only as a model/JS mismatch (#28, variant 2b).
# - fuzz-roundtrip.js skips inputs whose first parse throws, whatever the exception (#28).
# - None of the scripts has a time limit; on a non-terminating input a script hangs without
#   naming the input (#28, variants 3a/3b). Each step is wrapped in `timeout 600` here so that a hang
#   does not consume the whole 5400 s (npm test: `timeout 900`); this is the harness's addition, not the subject's.
#   Recorded durations: the whole suite (lake build + 3 scripts) took about 41 s (call 72).
# - lake build needs the Lean toolchain (leanprover/lean4:v4.35.0, /home/dev/.elan in the run's
#   container; S1's home copy does not contain .elan, so it must come from the image).
#   .lake/build in the snapshot already holds the built proofs and executables.
# - npm test runs pretest (lint, build: regenerates peg_lib/ from peg_src/) before mocha.
#
# Not included:
# - /tmp/patch.js, /tmp/pub.fixed.js (scratch files), `git stash` checks (call 44: tests fail on the
#   old code) and the old-publisher check of call 66: checks of the checks, not checks of the library.
cd /home/dev/jsdoctypeparser || exit 2
rc=0
cd verification || exit 2
echo "--- lake build"; timeout 600 lake build < /dev/null 2>&1 || rc=1
echo "--- diff-test.js"; timeout 600 node diff-test.js < /dev/null || rc=1
echo "--- rt-diff-test.js"; timeout 600 node rt-diff-test.js < /dev/null || rc=1
echo "--- fuzz-roundtrip.js"; timeout 600 node fuzz-roundtrip.js 1 100000 < /dev/null || rc=1
cd ..
echo "--- npm test"; timeout 900 npm test < /dev/null 2>&1 | grep -E "passing|failing|ERROR:|problems|  error  "; [ "${PIPESTATUS[0]}" = 0 ] || rc=1
exit $rc
