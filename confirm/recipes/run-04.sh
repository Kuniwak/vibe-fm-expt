# shellcheck shell=bash
# run-04 (B). formal/run.sh (committed on fix/publish-roundtrip): self-checks, exit 0 iff verdicts match expectations.
# VIOLATION_RE: FAILED|MISSED|mismatch|VIOLATE \(|Error
sh formal/run.sh
