# shellcheck shell=bash
# run-29 (D), snapshot S3 (after stage 5). Working directory /home/dev/jsdoctypeparser
# (HEAD d395aa0, nothing committed by the subject).
# The subject changed the library in stage 1 (uncommitted); lib/, peg_src/, peg_lib/ are identical
# in S1 and S3 (stages 3-5 did not change the library; #47 「ライブラリのコードには手を入れていません」):
#   - peg_src/jsdoctype.pegjs: QualifiedMemberName puts the name string into MEMBER.name (call 19).
#   - peg_lib/*.js: regenerated from it.
#   - lib/publishing.js: suffix `?` `!` `...` published in the suffix form; NAMED_PARAMETER without a
#     type publishes `name:` (calls 26-29, 38).
#   - tests/test_publishing.js: 3 expectations changed, 11 round-trip tests added.
#
# Artifacts: verification/ (untracked). The subject's final check is verification/run-all.sh, which runs
#   with a per-step time limit and prints "=== <step>" then "--> PASS|FAIL|TIMEOUT after Ns":
#     lake build                  (Lean proofs about hand-written models; do not read the JS)
#     node precedence.js          (class 1: library parse vs. an operator-precedence parser driven by
#                                  verification/precedence-table.md, permissive mode, seed 1, 60000 random)
#     node robustness.js          (classes 2, 3: parse/publish/traverse/re-parse in a worker with a 2 s
#                                  watchdog and 512 MB heap; reports non-syntax exceptions and hangs)
#     node diff-test.js           (quote escaping: Lean model vs JS; e2e parse(publish(ast)))
#     node rt-diff-test.js        (operator core: Lean model (.lake/build/bin/rtdiff) vs library)
#     node fuzz-roundtrip.js      (parse(publish(parse(s))) deep-equals parse(s))
#   All scripts exit 1 on a violation (calls 107-109).
# Sources of the commands:
#   - call 122 (final run): `LIMIT=300 verification/run-all.sh > /tmp/runall-final.txt 2>&1; ...;
#       npm test 2>&1 | grep -E "passing|failing|problem|error" | head`
#   - call 126 (after the lint fixes): `npm test 2>&1 | grep ...; LIMIT=300 verification/run-all.sh 2>&1 | grep -E "^===|^-->" | paste - -`
#   - verification/README.md: `verification/run-all.sh  # LIMIT=<seconds> per step, default 600`
#   - #47 「一括実行（新規 run-all.sh）：各手順を時間制限付きで実行し、全体を PASS/FAIL で判定します」;
#     #49 lists the classes 1-3 checks and 「その他の検査：Lean の証明、モデルと実装の差分テスト2つ、往復ファジング」.
#   npm test is included because #47 reports 「既存の 346 テストと lint は通っています」 and #50 cites the
#   regression tests; the subject ran it right before/after run-all.sh (calls 122, 125, 126).
# IMPORTANT: on the unmodified tree run-all.sh already FAILs and exits 1: precedence.js reports
#   11,251 table violations (call 110, /tmp/runall-final.txt). The subject judged variants by
#   "new" violations against a saved baseline (#47), so the exit status cannot change 0 -> non-0.
#   precedence.js prints only the shortest 40 distinct operator patterns
#   ("distinct operator patterns: 5112 (shortest 40 shown)"); a new violation whose pattern is longer
#   than these 40 changes only the counts, which lose their digits in the comparison. New label lines
#   (e.g. "library throws a non-syntax error: N", "[library did not finish: ...]") are new kinds.
#   The subject's own baseline comparison (precedence.js/robustness.js --save + /tmp/newviol.js) is
#   part of its variant procedure (/tmp/mutants2.sh) and is not included; see notes.md.
# Violation lines (examples from the record):
#   precedence.js (/tmp/runall-final.txt:14-57):
#     `  table accepts, library rejects: 9725`
#     `  [table accepts, library rejects] "= A"  table: (pre= A)  library: SyntaxError  (465 inputs)`
#     `  [both accept, different nesting] "? A ?"  table: (pre? (suf? A))  library: (suf? (pre? A))  (27 inputs)`
#     hangs (/tmp/runall-3a.txt, variant): `  [library did not finish: timeout in parse] input "external: 'e'"`
#   robustness.js (call 121, variants): `did not terminate: 10`, `  [parse] timeout  input "external:A" (permissive)`,
#     `  [traverse] out-of-memory (...)  input "A[]" (permissive)`; (#47) `[parse] TypeError ...  e.g. "typeof A" ...`
#   run-all.sh: `--> TIMEOUT after 300s` (call 121, variants 3a/3b)
#   diff-test.js / rt-diff-test.js / fuzz-roundtrip.js: as in recipe-S1.sh (`mismatches 12572`, `{"s":...}`,
#     `ERR publish ...`); fuzz-roundtrip.js now also `ERR parse <Type> ...` and `failures N`.
#   lake build: `error: ...`.  npm test: `N failing`, eslint `  error  ...`.
# VIOLATION_RE: ^  \[|^  (table accepts, library rejects|both accept, different nesting|table rejects, library accepts|library throws a non-syntax error): |exceptions other than syntax errors: [1-9]|did not terminate: [1-9]|stopped (early|after)|^--> TIMEOUT|^ERR |^AST differs|^model mismatch|^e2e fail|[1-9][0-9]* mismatches|[1-9][0-9]* failures|mismatches [1-9]|fragment [1-9]|failures [1-9]|^\{"s":|error:|[1-9][0-9]* failing|ERROR:|^ +[0-9]+:[0-9]+ +error\b
#
# Notes:
# - LIMIT=300 as in calls 122/126. Recorded duration: run-all.sh on the unmodified tree about 83 s
#   (call 110: 08:15:53 -> 08:17:16); with a non-terminating variant a step runs into the per-step limit
#   (call 121: TIMEOUT after 120s with LIMIT=120), so the worst case is about 6 x 300 s = 30 min.
# - "--> FAIL" lines are not in VIOLATION_RE: the line does not name the step, so a FAIL of another
#   step looks like the baseline's precedence FAIL; the steps' own violation lines carry the information.
# - lake build needs the Lean toolchain (leanprover/lean4:v4.35.0; /home/dev/.elan in the run's
#   container, not in the S3 home copy). .lake/build in the snapshot already holds the built targets.
# - npm test runs pretest (lint incl. verification/ with verification/.eslintrc.json, build) first.
#   Wrapped in `timeout 900` here (harness addition; the subject used no limit).
cd /home/dev/jsdoctypeparser || exit 2
rc=0
LIMIT=300 verification/run-all.sh < /dev/null 2>&1 || rc=1
echo "--- npm test"; timeout 900 npm test < /dev/null 2>&1 | grep -E "passing|failing|ERROR:|problems|  error  "; [ "${PIPESTATUS[0]}" = 0 ] || rc=1
exit $rc
