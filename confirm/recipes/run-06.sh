# shellcheck shell=bash
# run-06 (A2). Final checks as in the session (04:40:43 and 04:51:01): length-4 exhaustive,
# 1,000,000 random of length <= 20, and the fixture check.
# VIOLATION_RE: ^(publish-throws|roundtrip-unparsable|roundtrip-ast-differs|non-syntax-error|traverse-[a-z]+) |violations [1-9]|Error
cd /tmp/verify || exit 2
s=0
node check.js 4 0 </dev/null | cut -c1-800 || s=1
node check.js 0 1000000 20 </dev/null | cut -c1-800 || s=1
node fx.js /home/dev/jsdoctypeparser/tests/fixtures/* </dev/null || s=1
exit $s
