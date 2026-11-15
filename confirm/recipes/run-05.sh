# shellcheck shell=bash
# run-05 (A). Lean: verification/lean/QuoteEscape.lean has no executable link -> 検知不能.
# Executable check: verification/lean/differential.js (the agent's differential test of the real code).
# VIOLATION_RE: fail: [1-9]|Error
node verification/lean/differential.js
