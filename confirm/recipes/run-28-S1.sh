# shellcheck shell=bash
# run-28 (D2), snapshot S1 (end of stage 1, 2026-11-16T05:34:17Z).
# Working directory: /home/dev/jsdoctypeparser (branch fix/property-based-verification,
# HEAD 624a2f3, clean tree).
#
# Library changes by the subject (commit 624a2f3 on top of the pinned d395aa0):
#   - peg_src/jsdoctype.pegjs (QualifiedMemberName: MEMBER.name is a string, for `typeof a.b`)
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js (rebuilt from the above)
#   - lib/publishing.js (NAMED_PARAMETER without a type; suffix `?`/`!` kept under
#     `keyof`/`[]`/stacked modifiers)
#   The same commit adds tests/test_properties.js and regression tests in
#   tests/test_parsing.js and tests/test_publishing.js.
#
# Artifacts (the subject's checks at the end of stage 1):
#   1. /tmp/pv/prop.js: the subject's exploratory property checker (totality, round trip,
#      idempotence, traverse) over generated/mutated inputs; requires /home/dev/jsdoctypeparser
#      (index.js -> lib/ -> peg_lib/). Exists only in the snapshot's /tmp.
#   2. tests/test_properties.js (fixtures + generated/mutated inputs, all 4 modes), run
#      with several seeds.
#   3. npm test (pretest: lint + build; test: nyc mocha tests/test_* with a 100% coverage
#      threshold, then tsc).
# Sources of the commands (analysis/commands.md):
#   - call 20: `cd /tmp/pv && ... for s in 12345 1 777 99991 31337 2026; do SKIPKEYOF=1 SEED=$s N=40000 node prop.js | head -4; done`
#     #14: 「生成・変異させた入力は延べ約100万ケース（シード違いで複数回）すべて成立」(6 x 160000 cases).
#   - call 30: `for s in 1 42 777 99991 31337; do SEED=$s PROPERTY_CASES=30000 npx mocha tests/test_properties.js -g generated 2>&1 | grep -E "passing|failing|Error:|AssertionError" ; done`
#   - call 29: `npm test 2>&1 | grep -E "should hold|passing|failing|ERROR|All files|..." ; echo exit=$?`
#     #14: 「`npm test`（lint・typecheck・カバレッジ100%）は通過しています。」#17 also.
#   The grep filters of calls 29/30 are dropped so that all lines reach the harness;
#   the `| head -4` of call 20 is kept (it is part of what the subject looked at).
# Durations in the record: call 20 about 40 s in total (6 seeds); call 30 about 4 s per seed;
#   npm test about 24 s of mocha plus lint/build/tsc (call 29: under 1 min).
#
# Violation output (examples from the record):
#   - prop.js prints one JSON line per distinct failure, e.g. (call 20)
#     {"mode":"permissive","input":"()=>*!=[]","result":"P2 publish output not reparsable: \"() => !*=[]\"","orig":"new (...null:*) =>*!=[]"}
#     The summary line "cases 160000 distinct failures 2" is not matched (its digit-free form
#     is already in the base output; the JSON lines carry the input).
#     Note: with the subject's own library, seed 99991 already reports `()=>*!=[]` (call 20),
#     so the base output is not empty.
#   - mocha: "  3 failing" (call 15), "AssertionError: expected 'module:foo/bar?' to equal ..." (call 16);
#     test_properties.js fails with `expect(failure, mode + ': ' + JSON.stringify(str)).to.equal(null)`,
#     i.e. an "AssertionError: <mode>: \"<input>\": expected '<failure>' to equal null" line.
#   - nyc: "ERROR: Coverage for branches (98.72%) does not meet global threshold (100%)" (call 15).
# VIOLATION_RE: "result":"P[0-9]|[1-9][0-9]* failing|AssertionError|^ERROR:
#
# Notes:
# - The S1 checks are synchronous. With a non-terminating variant they never return
#   (the subject found this in stage 3: #30 「テストが止まったまま、何も報告しません」, and
#   ran them under `timeout 240` / `timeout 300` in /tmp/mut/run.sh, call 42).
#   The timeouts below are added by this recipe for that reason only; on timeout the
#   command exits 124 and the recipe exits non-zero.
# - npm test runs `eslint .` and `npm run build` first; a variant that breaks lint fails
#   npm test before any test runs (exit non-zero, "ERROR:" or eslint "error" lines).
#   npm test also fails when a variant adds code that is not 100% covered.
# - The recipe exits with the first non-zero exit status among the three steps
#   (the subject ran them as separate commands).
# - The checks read peg_lib/ (through index.js / lib/parsing.js); npm test rebuilds it.
#
# Not included:
# - /tmp/pv/rt.js (call 4): one-off fixture round-trip check, superseded by prop.js.
# - Runs of /tmp/pv/prop.js before call 20 (calls 6, 7, 15, 18): same script with other
#   options; call 20 is its last run in stage 1.
# - node -e one-liners (calls 9, 17, 18): manual inspection of single inputs.
rc=0
step() { "$@"; local r=$?; [ "$rc" = 0 ] && [ "$r" != 0 ] && rc=$r; return 0; }

echo "@@ step 1: /tmp/pv/prop.js (call 20)"
step bash -c 'e=0; cd /tmp/pv && for s in 12345 1 777 99991 31337 2026; do SKIPKEYOF=1 SEED=$s N=40000 timeout 120 node prop.js < /dev/null 2>&1 | head -4; r=${PIPESTATUS[0]}; [ "$e" = 0 ] && e=$r; done; exit $e'

echo "@@ step 2: test_properties.js with seeds (call 30)"
step bash -c 'e=0; for s in 1 42 777 99991 31337; do SEED=$s PROPERTY_CASES=30000 timeout 120 npx mocha tests/test_properties.js -g generated < /dev/null 2>&1; r=$?; [ "$e" = 0 ] && e=$r; done; exit $e'

echo "@@ step 3: npm test (call 29)"
step timeout 900 npm test < /dev/null

exit $rc
