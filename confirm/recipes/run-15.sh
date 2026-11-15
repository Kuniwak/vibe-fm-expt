# shellcheck shell=bash
# run-15 (C, c5). Proposed recipe for the independent check (preregistration 10.4).
# Working directory: /home/dev/jsdoctypeparser (the agent's final tree; verification/ is untracked).
#
# Artifact: verification/run.sh (written in call 53; README: "Run `./run.sh` (or `./run.sh --mutants`).").
#   run.sh = `node extract.js` -> `(cd lean && lake build)` -> `node difftest.js` (set -e).
#   - extract.js re-reads peg_src/jsdoctype.pegjs and lib/*.js and regenerates
#     lean/JsdocVerify/Generated.lean, so the Lean theorems (lean/JsdocVerify/Checks.lean,
#     bug1..bug6 + positive controls, proved by native_decide) are re-evaluated on the
#     patched sources. A false theorem makes `lake build` fail:
#       "error: JsdocVerify/Checks.lean:NN:2: Tactic `native_decide` evaluated that the proposition ... is false"
#     The Lean artifact is therefore tied to the real code by an executable step (not 検知不能).
#   - difftest.js compares the real library (lib/parsing.js, i.e. the rebuilt peg_lib) with the
#     Lean model; it prints "MISMATCH ..." and exits 1 on any disagreement. It only runs if lake build passed.
# Based on: call 53 (`./run.sh --mutants`, the agent's last full run from scratch) and
#           call 54 (`(cd lean && lake build ...) && node difftest.js ...`, the agent's last check).
# Not included: `--mutants` (verification/mutants.js). It runs the agent's own six variants on a
#   throw-away copy of the tree and checks the checks; it is not the check of the tree itself, and its
#   edit sites assume the unpatched sources (it throws "edit site not unique" when a site is absent).
# Not included: `--dt 1000000` (README mentions it, run.sh does not pass it; default sample = 3000).
# Lean toolchain: leanprover/lean4:v4.35.0 (verification/lean/lean-toolchain), no Lake packages,
#   so no network is needed. lean/.lake from the run is reused if restored; otherwise lake rebuilds (~1 min).
# Baseline (audit rerun / call 54): lake build succeeds; "difftest: 6559 inputs x 4 modes x 3 = 78708 cases,
#   0 mismatches; ..."; "model declined (unsupported) on 54 cases" (not a violation; also in the baseline).
# VIOLATION_RE: error:|MISMATCH|[1-9][0-9]* mismatches|extract: unsupported|Error:
export PATH="$HOME/.elan/bin:$PATH"
sh verification/run.sh
