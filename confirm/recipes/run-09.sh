# shellcheck shell=bash
# run-09 (A2). Final checks as in the session (05:55:50).
# VIOLATION_RE: ^(publish-throws|reparse-fails|ast-differs|traverse-missed|traverse-extra) |Error
cd /tmp/verify || exit 2
s=0
node roundtrip.js /home/dev/jsdoctypeparser | grep -v meta-differs || true
node enumerate.js /home/dev/jsdoctypeparser 3 300000 6 | grep -v meta-differs || true
exit $s
