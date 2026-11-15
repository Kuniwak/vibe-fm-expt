# shellcheck shell=bash
# run-14 (C2). Proposal for the independent check (preregistration 10.4).
# Working directory: /home/dev/jsdoctypeparser (the subject's tree: lib/publishing.js
# and tests/test_publishing.js are modified, verification/ is untracked).
#
# Artifacts: verification/check.js (bounded exhaustive check of P1-P6b against the
# real code: require(ROOT) -> index.js -> lib/ + peg_lib/), the subject's final check.
# Sources of the commands (analysis/commands.md):
#   - call 35: (node verification/check.js; echo check_exit=$?; node verification/mutants.js; ...)
#   - #9: 「再実行するには `node verification/check.js`（約3分）と `node verification/mutants.js` を実行します。」
#   - call 9 / mutants.js build(): `npm run build` (peg_lib/ is generated from peg_src/;
#     check.js reads peg_lib/, so a grammar variant reaches the check only after a build).
#   - calls 33, 34: `npm test` (the subject's last test run; includes the 2 tests the
#     subject added to tests/test_publishing.js; pretest runs lint and build).
# Not included:
#   - verification/mutants.js: mutation analysis of check.js itself (it embeds the
#     subject's own six mutants, rebuilds, and restores the files). It is not a check
#     of the code under test. On a tree with a reference variant applied, its
#     "baseline Px: N counterexamples" lines would carry the same information as
#     check.js, and its own edits may fail with "pattern found 0 times" if a
#     reference variant touches the same lines. Takes about 14 minutes (call 35).
#   - No Lean, TLA+ or Z3 artifacts exist in this run.
# check.js exits 1 and prints "VIOLATED" on any counterexample; it takes about 3 min
# (worker threads, one per CPU). npm test prints "N failing" and "ERROR:" on failure.
# stdin is closed (< /dev/null) and npm test is wrapped in `timeout 300` as in the
# subject's calls 34 and 35. In call 31, `npm test` (run without these) stayed in
# build:jsdoc (frs-replace/pegjs processes) for over 10 minutes; the cause was not
# established by the subject or by this report.
# VIOLATION_RE: VIOLATED|[1-9][0-9]* failing|ERROR:
npm run build < /dev/null
node verification/check.js < /dev/null
timeout 300 npm test < /dev/null
