# shellcheck shell=bash
# run-39 (D, D2), snapshot S1 (end of stage 1, 2026-11-17T10:59:53Z).
# Working directory: /home/dev/jsdoctypeparser (branch master at d395aa0, nothing committed).
# The subject changed the library (uncommitted):
#   - lib/publishing.js: publish() writes a nullable/not-nullable node in suffix form
#     (`A?`, `A!`) when its operand is itself `?`/`!`, and inside `[]` (isNullabilityNode,
#     publishSuffixNullability). Fixes the round-trip bugs `?A?`, `!A?`, `?A!`, `() => A?[]`.
#   - peg_src/jsdoctype.pegjs: QualifiedMemberName (used by `typeof A.b`) now builds a
#     MEMBER node whose `name` is a string (plus quoteStyle/hasEventPrefix).
#   - peg_lib/*.js rebuilt from it; tests/test_parsing.js (+1) and tests/test_publishing.js (+6)
#     regression tests (call 45-47). lean/ is new and untracked.
#
# Artifacts (the checks the subject reported in #12 as the verification):
#   - npm test (lint, build, mocha, typecheck); 342 passing at S1 (call 48).
#   - /tmp/verify/fuzz.js (permissive, parse -> publish -> parse round trip, seeds 1-5).
#   - /tmp/verify/fuzz2.js (the same in 4 modes, seeds 11-55); #12「4つのモード…合計約176万件」.
#   - /tmp/verify/cmp.js /tmp/verify/model.tsv (JS parse/publish vs. the Lean model's table,
#     all 97,656 inputs of length <= 7); #12「モデルが実装と一致することの確認」.
#   - lean/ (`cd lean && lake build`, theorems in JsdocTypeParser/Roundtrip.lean, native_decide);
#     #12「`cd lean && lake build` で検証できます（約2分）」.
# Sources of the commands:
#   - The first block is the subject's /tmp/verify/run_all.sh as written in call 51
#     (2026-11-17T11:01:51Z, right after S1, with the comment "Runs the existing verification
#     unchanged. `timeout` is only an outer guard for observing hangs."). That file does not
#     exist in S1 (it was created after the snapshot and later rewritten), so its body is copied
#     here verbatim. Its commands match the subject's stage-1 runs: call 5
#     (`for s in 1 2 3 4 5; do node fuzz.js $s; done`), call 25 (`for m in permissive jsdoc
#     closure typescript; do for s in 11 22 33 44 55; do node fuzz2.js $s $m; done; done`),
#     call 36 (`node /tmp/verify/cmp.js /tmp/verify/model.tsv`), call 48 (`npm test`).
#     The `timeout` guards (600 s / 300 s) come from call 51, not from stage 1.
#   - The last block is #12 `cd lean && lake build` (call 42 ran `lake build 2>&1 | grep -E
#     "error|Build"`). The subject left Lean out of run_all.sh because it does not read the JS
#     code (#22「これは JS のコードを読まないので、変種を入れても結果は変わりません」); it is
#     included here only because #12 reports it as part of the verification.
#
# Output that shows a violation (record):
#   - npm test: "exit=1", "  N failing", "  1) publish" (call 48 on the original lib:
#     "  7 failing", "  1) publish"); timeout -> "exit=124" (call 66/m3.log).
#   - fuzz.js / fuzz2.js: "  REPARSE_FAIL ...", "  AST_DIFF:ARROW ...", "PUBLISH_THROW:..."
#     (call 6: `  REPARSE_FAIL "?b#b?=" => "??b#b="`, `  AST_DIFF:ARROW "() => import?[]" => ...`;
#     call 20: `  REPARSE_FAIL "typeof A.b" => "typeof A.{ type: 'NAME', name: 'b' }"`);
#     a timeout prints "[permissive] seed 11 exit=124" (m3.log).
#   - cmp.js: `"[]" model - js ?TUPLE` and `publish "<input>" <model> <js>` lines (call 34).
#   - lake build: "error: ..." / "error: build failed" (call 28).
# VIOLATION_RE: exit=[1-9]|[1-9][0-9]* failing|^  [0-9]+\) |REPARSE_FAIL|AST_DIFF|PUBLISH_THROW|^".*" model .* js |^publish "|^error
#
# Notes:
# - The exit code of this recipe is not meaningful (the last line is an echo); judge by
#   VIOLATION_RE. Baseline output on S1 (call 51): "exit=0", "  342 passing (4s)", 20 lines
#   "[mode] parsed=N roundtrip_ok=N", "compared 97656 mismatches 0", "publish mismatches 0".
#   Lines "[mode] parsed=N roundtrip_ok=M" with N != M also mean a round-trip failure but are
#   not in VIOLATION_RE (the digits are stripped); the REPARSE_FAIL/AST_DIFF lines that follow
#   carry the same information.
# - Time on the subject's machine: the run_all.sh block took about 1 min 45 s (call 51,
#   11:01:51 -> 11:03:36). `lake build` is a no-op when lean/.lake is up to date (S1 contains
#   lean/.lake/build); a full rebuild took 2 min 10 s (call 41/42). With a non-terminating
#   variant the guards add up to 600 + 5*300 + 20*300 + 600 s, which exceeds the harness limit
#   of 5400 s; in the subject's own run (m3.log, stage 3) every fuzz2 run hit its timeout.
#   The "exit=124" lines printed before the limit are already violations.
# - cmp.js and fuzz*.js require('/home/dev/jsdoctypeparser') -> index.js -> peg_lib/ and lib/.
#   npm test runs `npm run build` (pretest), so peg_lib/ is rebuilt from peg_src/ first.
# - In MODE=orig (library reset to the pinned commit) the subject's 7 regression tests fail
#   (call 48: "283 passing", "7 failing") and fuzz2 reports REPARSE_FAIL/AST_DIFF already in
#   the base run.
# - lean/ needs /home/dev/.elan (in the image, not in the snapshot; lean-toolchain
#   leanprover/lean4:v4.35.0, no packages, no network).
#
# Not included:
# - /tmp/verify/min.js, Check.lean, Dump.lean, Ax.lean: one-off probes (Check.lean lists
#   counterexamples of the old publish in the Lean model; Dump.lean regenerates model.tsv;
#   Ax.lean prints axioms). They do not read the JS code except min.js, which only takes
#   inputs on the command line.

# --- /tmp/verify/run_all.sh as of call 51 (verbatim body) ---
cd /home/dev/jsdoctypeparser
echo "== npm test (lint, build, mocha, typecheck)"
timeout 600 npm test > /tmp/verify/npmtest.log 2>&1; echo "exit=$?"
grep -E "passing|failing|pending" /tmp/verify/npmtest.log
grep -E "^  [0-9]+\) " -A3 /tmp/verify/npmtest.log | head -40
echo "== fuzz.js (permissive, seeds 1-5)"
for s in 1 2 3 4 5; do timeout 300 node /tmp/verify/fuzz.js $s; e=$?; [ $e -ne 0 ] && echo "seed $s exit=$e"; done
echo "== fuzz2.js (4 modes x seeds 11-55)"
for m in permissive jsdoc closure typescript; do for s in 11 22 33 44 55; do timeout 300 node /tmp/verify/fuzz2.js $s $m; e=$?; [ $e -ne 0 ] && echo "[$m] seed $s exit=$e"; done; done
echo "== cmp.js (JS vs Lean model, length <= 7)"
timeout 600 node /tmp/verify/cmp.js /tmp/verify/model.tsv; e=$?; [ $e -ne 0 ] && echo "exit=$e"

# --- #12: cd lean && lake build ---
echo "== lean (lake build)"
( cd /home/dev/jsdoctypeparser/lean && lake build < /dev/null > /tmp/verify/lake.log 2>&1; e=$?
  grep -E "^error|Build" /tmp/verify/lake.log | head -20; echo "lake build exit=$e" )
