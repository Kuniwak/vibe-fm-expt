# shellcheck shell=bash
# run-39 (D, D2), snapshot S3 (after stage 5, 2026-11-17T13:05:07Z).
# Working directory: /home/dev/jsdoctypeparser (branch master at d395aa0, nothing committed).
# The subject's library change is the same as in S1 (made in stage 1, unchanged since;
# `git diff lib peg_src` is identical in S1 and S3):
#   - lib/publishing.js: suffix form for nested `?`/`!` and inside `[]` (isNullabilityNode,
#     publishSuffixNullability).
#   - peg_src/jsdoctype.pegjs: QualifiedMemberName builds MEMBER with a string `name`.
#   - peg_lib/*.js rebuilt; tests/test_parsing.js and tests/test_publishing.js have 7 added tests.
# Also changed: package.json (+ "verify": "node verification/check.js"), .npmignore
# (+ lean, verification). New untracked: lean/, verification/ (check.js, oracle.js,
# generators.js, precedence-table.md). All three variants of stages 3-4 were removed
# (call 166: `git diff --stat lib peg_src` shows only the stage-1 change).
#
# Artifacts:
#   - /tmp/verify/run_all.sh: the subject's runner of "the whole verification" (#36「実行スクリプト」):
#     npm test (timeout 300), fuzz.js (5 seeds, timeout 60), fuzz2.js (4 modes x 5 seeds,
#     timeout 60), cmp.js vs /tmp/verify/model.tsv, and
#     `node verification/check.js --examples=6 --baseline=/tmp/verify/baseline-violations.json`.
#   - verification/check.js: precedence-table oracle (kind 1), exceptions other than
#     SyntaxError in parse/publish/traverse/re-parse in 4 modes (kind 2), and per-input
#     progress watchdog of 3000 ms (kind 3). Reads the library via require('..')
#     (index.js -> lib/ + peg_lib/).
#   - /tmp/verify/baseline-violations.json: the 12,032 table violations of the unmodified
#     library, saved by the subject in call 153 (`--save=... --examples=100000`) after the
#     last change to check.js (call 152). With --baseline, check.js prints and counts only
#     violations that are not in that file and exits 0 when there are none (call 166:
#     "== 1. precedence table: 0 violation(s)", "== 2. ...: 0 violation(s), 0 distinct",
#     "== 3. ...: 0 violation(s), 0 distinct").
#   - lean/ (`cd lean && lake build`), reported as part of the verification in #12 and #43.
# Sources of the commands:
#   - /tmp/verify/run_all.sh is in S3 and is run as is. Its final form: call 119 (rewrite),
#     call 127 (adds --baseline), call 146 (`sleep 6; pkill -9 -f ...`). The subject ran it
#     for the stage-4 re-check (call 120 base, 139 variant 3). Its last runs of check.js alone
#     were call 158/163 (`node verification/check.js --baseline=/tmp/verify/baseline-violations.json
#     --examples=4`) and call 166 (`--examples=0`), with the same check and baseline.
#   - #36「`npm run verify` で実行できます（約12秒）」 is check.js without --baseline; see notes.md.
#   - lean: #12 `cd lean && lake build`.
#
# Output that shows a violation (record):
#   - npm test: "exit=1" / "exit=124" and "did not terminate within 300 s; last finished test:
#     ✓ should return a string value type with escaped quote" (v2_m3.log); "  N failing", "  1) ...".
#   - fuzz*.js: "  REPARSE_FAIL:UNION:...", "  AST_DIFF:UNION ..." (v2_m1.log),
#     "[permissive] seed 11 exit=124" (v2_m3.log).
#   - check.js (with --baseline): example lines
#       `    "! * | *"  expected: |(pre !(*), *)  actual: pre !(|(*, *))` (call 158, variant 1),
#       `  [permissive] "{a}"  traverse: TypeError: Cannot read properties of null (reading 'type')`
#       (v2_m2.log, variant 2),
#       `  [jsdoc] "\"a\\\\\""  publish: no progress for 3000 ms` (v2_m3.log, variant 3),
#     group headers `  [expected accept, actual a different tree] 234`,
#     "143511 input(s) left unchecked after 3 hangs in a chunk", and "exit=1".
#   - cmp.js: `"<input>" model X js Y` / `publish "<input>" ...` (call 34).
#   - lake build: "error: ..." (call 28).
# VIOLATION_RE: exit=[1-9]|[1-9][0-9]* failing|^  [0-9]+\) |did not terminate|REPARSE_FAIL|AST_DIFF|PUBLISH_THROW|^".*" model .* js |^publish "|^    ".*"  expected: |^  \[expected |^  \[[a-z]+\] "|left unchecked|^error
#
# Notes:
# - The exit code of this recipe is not meaningful (run_all.sh always ends with an echo);
#   judge by VIOLATION_RE. Base output on the subject's machine: v2_baseline.log up to cmp.js
#   ("exit=0", "  342 passing (4s)", 20 "[mode] parsed=N roundtrip_ok=N", "compared 97656
#   mismatches 0", "publish mismatches 0"), then check.js as in call 166 and "exit=0".
# - Time: the whole run_all.sh took about 2 min on the base library (call 120, 11:53:31 ->
#   11:55:26; check.js alone about 12 s). With a non-terminating publish (variant 3) it took
#   about 26 min (call 139, 12:01:43 -> 12:27:31): npm test 300 s, each of 20 fuzz2 runs 60 s.
#   Upper bound of the guards: about 311 + 25*60 + 600 s plus check.js.
# - The 60 s fuzz timeouts and the 3000 ms watchdog of check.js are wall-clock limits; on a
#   slower or loaded machine they could fire on the base library. check.js uses up to 4
#   worker threads.
# - The baseline file matches violations by exact [kind, mode, input, step, actual, detail].
#   A change that alters the actual tree of an input already in the baseline shows up as a
#   new violation. In MODE=orig, the subject's 7 regression tests fail in npm test (call 48)
#   and fuzz2 reports REPARSE_FAIL/AST_DIFF in the base run; the table part of check.js is
#   not expected to differ (the stage-1 change touches publish and `typeof A.b` only), but
#   this was not run.
# - lean/ needs /home/dev/.elan (in the image). lean/ is identical in S1 and S3.
#
# Not included:
# - The subject's variant edits (sed on peg_src/jsdoctype.pegjs and lib/traversing.js, Edit of
#   lib/publishing.js), applied and reverted by hand; no script in the snapshot does this.
# - /tmp/verify/group.js, group2.js, classify.js (grouping of full_baseline.txt), show.js,
#   min.js, oracle_try.js, oracle_one.js (probes), and the --save run that regenerates the
#   baseline (it would overwrite /tmp/verify/baseline-violations.json).
# - `npm run verify` (check.js without --baseline): exits 1 on the base library (12,032
#   violations) and prints only the first 12 examples per group; see notes.md.

bash /tmp/verify/run_all.sh < /dev/null

echo "== lean (lake build)"
( cd /home/dev/jsdoctypeparser/lean && lake build < /dev/null > /tmp/verify/lake.log 2>&1; e=$?
  grep -E "^error|Build" /tmp/verify/lake.log | head -20; echo "lake build exit=$e" )
