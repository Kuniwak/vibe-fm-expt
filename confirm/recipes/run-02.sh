# shellcheck shell=bash
# run-02 (A). Lean: formal/ (Lake project) has no executable link to the real code -> 検知不能.
# Executable check left by the agent: /tmp/fuzz.js, run as in the session (call 20).
# VIOLATION_RE: ^(MISMATCH|MEMBER MISMATCH|BAD PARENT|BAD PROP)|Error
node /tmp/fuzz.js "$PWD/index.js"
