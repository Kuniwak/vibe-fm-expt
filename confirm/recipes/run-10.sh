# shellcheck shell=bash
# run-10 (B). formal/enumerate.js (full bounds) and formal/escape.js; each exits 0 iff verdicts match
# expectations. formal/diff.js compares two parser builds and is not a check of one tree; not run.
# VIOLATION_RE: ^FAIL|RESULT: [A-Z]*(MISMATCH|FAIL)|Error
s=0
node formal/enumerate.js </dev/null || s=1
node formal/escape.js </dev/null || s=1
exit $s
