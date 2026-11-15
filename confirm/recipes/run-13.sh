# shellcheck shell=bash
# run-13 (C, c3). Working directory: /home/dev/jsdoctypeparser
#
# Artifact: verification/ (untracked). Lean 4 Lake project verification/lean,
#   theorems bug1_absent..bug6_absent in verification/lean/JsdocVerify/Spec.lean
#   (each `bugN_failures = [] := by native_decide`, definitions in Checks.lean).
# Link to the real code: verification/extract.js reads peg_src/jsdoctype.pegjs
#   (4 flavors) and lib/{NodeType,SyntaxType,publishing,traversing}.js and
#   regenerates verification/lean/JsdocVerify/Extracted.lean; the Lean
#   interpreters (Js.lean, Peg.lean) run that extracted code. So the Lean check
#   is executable against the real code (not 検知不能).
#   Not seen by this check: peg_lib/*.js, lib/parsing.js, index.js and other
#   files not listed above (extract.js does not read them).
#
# Commands, verbatim from the agent:
#   #34 "To re-run: `node verification/extract.js && (cd verification/lean && lake build)`"
#   verification/README.md "## Commands" (same two lines).
#   The same steps inside verification/run-mutants.sh check() (calls 40, 42, 49, 62):
#     node verification/extract.js >/dev/null
#     (cd verification/lean && lake build failures >/dev/null 2>&1)
#     out=$(cd verification/lean && lake build JsdocVerify.Spec 2>&1)
#     (cd verification/lean && lake exe failures) | grep -v ": 0 violation" | sed 's/^/  /'
#   `lake exe failures` (verification/lean/Failures.lean, call 49) prints the
#   violating cases; it is the agent's diagnostic in run-mutants.sh.
#
# Not included:
#   - verification/run-mutants.sh: applies the agent's own patches (verification/mutants/*.patch).
#   - verification/demo-bugs.js: the agent's "node oracle" to confirm that a variant
#     really has the bug (calls 40, 50, 63); not the check it reported as detecting.
#   - verification/crosscheck.js: compares the Lean interpreters with Node; needs
#     `npm run build`; not the check reported as detecting (audit rerun timed out at 600 s).
#   - npm run build: not needed by extract.js / lake build (README: "needed by crosscheck/run-mutants").
#
# Baseline (clean code): "Build completed successfully", exit 0; `failures` prints "bugN: 0 violation(s)".
# Violation (call 61 output):
#   error: JsdocVerify/Spec.lean:15:47: Tactic `native_decide` evaluated that the proposition
#     bug1_failures = []
#   is false
#   and `lake build` exits non-zero; `failures` prints "bugN: K violation(s)" with K > 0.
# Each `lake build` of Spec takes about 60-70 s (calls 34, 68).
# No network: the Lake project has no package dependencies (lake-manifest.json "packages": []).
#
# VIOLATION_RE: native_decide. evaluated that the proposition|error:|bug[1-6]: [1-9][0-9]* violation
node verification/extract.js
(cd verification/lean && lake build)
(cd verification/lean && lake build failures && lake exe failures)
