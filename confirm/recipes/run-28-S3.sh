# shellcheck shell=bash
# run-28 (D2), snapshot S3 (after stage 5, 2026-11-16T07:20:28Z; not a timeout run).
# Working directory: /home/dev/jsdoctypeparser (branch fix/property-based-verification,
# HEAD 624a2f3; working tree: tests/test_properties.js modified, tests/properties/ untracked).
#
# Library changes by the subject: the same as at S1, all in commit 624a2f3 on top of the
# pinned d395aa0 (peg_src/jsdoctype.pegjs, peg_lib/*.js rebuilt, lib/publishing.js).
# No library change after S1: the subject restored lib/ peg_src/ peg_lib/ after its variant
# runs (calls 88, 89; `git status --short` shows only the two test paths).
#
# Artifacts (the subject's final verification, stage 4):
#   tests/test_properties.js + tests/properties/{generators,precedence,runner,shared,worker}.js,
#   tests/properties/precedence-table.md (the stage-2 table), and
#   tests/properties/known-precedence-violations.txt (2,931 patterns of table violations that
#   the base library already has; the precedence test fails only on patterns not in it).
#   Four tests: fixtures, hand-generated/mutated inputs, grammar-generated inputs (each:
#   totality incl. non-SyntaxError exceptions, round trip, idempotence, traverse; every
#   parse/publish/traverse call runs in a worker and is reported if it does not return
#   within 5000 ms), and agreement with the precedence table (permissive mode only).
#   The worker requires ../../lib/*.js (-> peg_lib/).
# Sources of the commands:
#   - /tmp/mut/run2.sh (call 68, used for the final check of every variant in call 83 via
#     /tmp/mut/all2.sh, results in /tmp/mut/res4/):
#       PROPERTY_REPORT=$out/failures.jsonl timeout 900 npx mocha tests/test_properties.js > $out/prop 2>&1
#       timeout 600 npx mocha 'tests/test_*' > $out/full 2>&1
#     #48 reports the per-variant results of this check ("検知できる" for kinds 1-3).
#   - #48: 「変種なしの状態で `npm test` は通ります（lint・カバレッジ100%・typecheck を含む）」(call 82).
#   PROPERTY_REPORT only appends JSON lines to a file; it is left out (the same failures are
#   printed by mocha). The `npm run build` line of run2.sh is done by the harness when a
#   variant touches peg_src/ (inside.sh), and the git checkout / apply.py lines are the
#   subject's variant handling, so they are left out.
# Durations in the record: test_properties.js 15 s on the base (res4/base/prop), 13-34 s on
#   most variants, 63 s with a non-terminating parse (M3a); mocha 'tests/test_*' about 20 s.
#   With a non-terminating variant, 'tests/test_*' does not end (test_no_hang.js and other
#   synchronous tests run first in the same process; #40) and is stopped by `timeout 600`.
#
# Violation output (examples from the record):
#   - "      AssertionError: 98 件の違反（51 種類）:" (call 85, M1a/prop)
#   - "- [演算子順位の表と食い違い] permissive / parse: 入力 \"function():1|5\" → 表の結果: UNION(FUNCTION(1), 5) / parse の結果: FUNCTION(UNION(1, 5))（同種 24 件）" (call 85)
#   - "- [SyntaxError 以外の例外] permissive / parse: 入力 \"[]\" → TypeError: Cannot read properties of undefined (reading 'type')（同種 7 件）: expected 7 to equal 0" (call 85)
#   - "- [終わらない] permissive / parse: 入力 \"(Array|Object.<string, ?>)\" → parse did not return within 5000ms（同種 3 件）" (call 85)
#   - "- [ラウンドトリップ違反] permissive / reparse: 入力 \"()=>typeof\nT!|1\" → AST changed by round trip via ..." (call 85)
#   - "  2 failing" (call 84: "2 passing (16s)  2 failing exit=2")
#   The line "      precedence: {\"ok\":13272,\"violation\":1554,...,\"known-violation\":1554}" is printed
#   on every run, including the base, and is not matched.
# VIOLATION_RE: ^- \[|件の違反|[1-9][0-9]* failing|AssertionError
#
# Notes:
# - The precedence test depends on the fixed seed (SEED default 20201116, PROPERTY_CASES
#   default 3000). The known list was made with PROPERTY_CASES=20000 (header of the list);
#   the subject warns that another SEED may report old patterns as new (#48). The recipe
#   uses the defaults, as run2.sh did.
# - The base run passes (res4/base/prop: "4 passing", exit=0; call 82: npm test "345 passing").
# - The recipe exits with the first non-zero exit status of the two steps.
#
# Not included:
# - /tmp/mut/run.sh, run2.sh, all*.sh, apply.py, mutants.py: the subject's own variants
#   (applied and reverted); a check of the check.
# - /tmp/mut/ref.js, rel.py, show*.js, demo.js, fixcount.js, newfail.py: helper scripts for
#   manual inspection and for diffing variant results.
# - npm test: its mocha part is the same 'tests/test_*' run (under nyc); the rest is lint,
#   build, coverage threshold and tsc. The subject did not use npm test for the variant
#   checks. If the harness wants it, the subject's command is call 82
#   `npm test 2>&1 | grep -E "passing|failing|ERROR|All files|precedence:|error"`.
# - /tmp/pv/prop.js and the stage-1 seed loop: superseded by the rewritten test_properties.js
#   (the old test file was replaced in call 62); the subject did not run them after stage 1.
rc=0
step() { "$@"; local r=$?; [ "$rc" = 0 ] && [ "$r" != 0 ] && rc=$r; return 0; }

echo "@@ step 1: tests/test_properties.js (run2.sh)"
step timeout 900 npx mocha tests/test_properties.js < /dev/null

echo "@@ step 2: mocha 'tests/test_*' (run2.sh)"
step timeout 600 npx mocha 'tests/test_*' < /dev/null

exit $rc
