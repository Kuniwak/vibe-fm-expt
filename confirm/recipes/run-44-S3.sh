# shellcheck shell=bash
# run-44 (D, D2), snapshot S3 (after the stage-5 answer, 2026-11-18T01:15:36Z).
# Working directory: /home/dev/jsdoctypeparser (HEAD d395aa0, uncommitted changes; formal/ and verify/ untracked).
# The subject changed the library (uncommitted, made in stage 1 and not touched afterwards):
#   - peg_src/jsdoctype.pegjs, rule QualifiedMemberName (line ~160): `name: tokens[3]` ->
#     `name: tokens[3].name, quoteStyle: 'none', hasEventPrefix: false` (call 13).
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js rebuilt (same change). lib/ unchanged.
#   - Also: package.json gained a "verify" script; .npmignore gained formal and verify;
#     tests/test_parsing.js, tests/test_publishing.js gained one test each.
#
# Artifacts (V1-V5 in the final report #39; "すべて `npm run verify` で実行できます"):
#   V1 lean formal/JsdocRoundtrip.lean   Lean proof on a model; reads no JS (the subject: "V1 はどの変種も検知できません").
#   V2 node verify/roundtrip.js          round trip over fixtures, 4 modes; reports DIFF / FAIL-REPARSE /
#                                        PARSE-EXCEPTION / PUBLISH-EXCEPTION; exit 1 if any.
#   V3 mocha 'tests/test_*'              the existing tests ("V3 は npm test から lint を外し ... mocha tests/test_* を直接実行", #15).
#   V4 node verify/precedence.js         parse() (default mode) against verify/precedence-table.md; exit 1 if any
#                                        violation. BASELINE ALREADY EXITS 1 (5297 violations, call 95).
#   V5 node verify/robustness.js         parse/publish/traverse in 4 modes in worker threads; non-SyntaxError
#                                        exceptions and calls not returning within 3000 ms; exit 1 if any.
#                                        BASELINE ALREADY EXITS 1 (19 publish TypeErrors, call 95).
# Sources of the commands:
#   - package.json "verify": "node verify/roundtrip.js && node verify/precedence.js && node verify/robustness.js && lean formal/JsdocRoundtrip.lean"
#     (call 79). Because V4 and V5 exit 1 on the baseline, the `&&` chain would stop after V4;
#     the subject never ran `npm run verify` itself.
#   - The subject's actual runs (call 74 /tmp/rt/runall2.sh, run in calls 89/75 for base and every variant):
#       (cd $d/formal && timeout 300 lean JsdocRoundtrip.lean)
#       timeout 300 node $V/roundtrip.js $d
#       (cd $d && timeout 300 node_modules/.bin/mocha 'tests/test_*')
#       timeout 600 node $V/precedence.js $d --json $d.prec.json
#       timeout 900 node $V/robustness.js $d --json $d.rob.json
#     with $V = verify/ of this tree and $d = a copy of the repository. Here every check runs on the
#     repository itself (the default root of each script), each separately, with the same timeouts.
#     The --json output files are omitted (they only save the same results).
# Durations in the record (base, call 72/70/38): roundtrip about 27 s, precedence about 14 s,
#   robustness about 11 s (4 workers), mocha about 4 s, lean about 1 s; the whole base run about 1 min.
#   With non-terminating variants: robustness 1-2 min (each hang costs 3 s; a chunk stops after 25
#   hangs); roundtrip and mocha ran into their 300 s timeout (M3a, call 100).
# Exit code: 1 if any step exits non-zero. Since V4 and V5 exit 1 on the baseline, the exit code is
#   1 already without a variant; detection has to come from VIOLATION_RE.
#   On timeout the recipe prints "@@ <step> timed out" (not in VIOLATION_RE; the subject rated
#   V2/V3 timeouts as "△ 終わらない", not as a reported violation, #39).
# Lines that show a violation (actual output in the record):
#   V2: "PARSE-EXCEPTION permissive catharsis-types:31 \"...string|string[]\" TypeError: Cannot read properties of undefined (reading 'syntax')"
#       (/tmp/mut/M2a.v2b.log line 1); "PUBLISH-EXCEPTION permissive catharsis-types:41 \"Array.<{length}>\" TypeError: ..." (/tmp/mut/M2b.v2b.log line 1)
#   V3: "  12 failing" (M2a, call 98)
#   V4: "  different-nesting: 300", "    \"!*!\"  table=[\"Prefix !(Suffix !(*))\"]  library=\"Suffix !(Prefix !(*))\"" (base, call 71)
#   V5: "  exception in publish: TypeError: Cannot read properties of null (reading 'type')  (19 cases)",
#       "    [permissive] \"\t\t ( \nKE\n:\t )\n =>\ttypeof\n qB \"" (base, call 72);
#       "  hang in parse: no return within 3000 ms  (16 cases)" (M3a, call 100)
#   V1: lean "JsdocRoundtrip.lean:197:50: error: ..." (call 22)
# VIOLATION_RE: ^(DIFF|FAIL-REPARSE|PARSE-EXCEPTION|PUBLISH-EXCEPTION) |[0-9]+ failing|^  (different-nesting|table-accepts/library-rejects|table-rejects/library-accepts): |^    ".*"  table=|^  (exception|hang|aborted) in [a-z-]+: |^    \[(permissive|jsdoc|closure|typescript)\] |JsdocRoundtrip\.lean:[0-9]+:[0-9]+: error
#
# Caution:
# - V4 prints only the 8 shortest violations per kind and V5 only 3 inputs per group. A variant that
#   removes or reorders baseline violations can bring a different baseline violation into these
#   sample lines, which then looks "new" to the digit-stripped comparison.
# - V5 generates 50,000 inputs from peg_src/jsdoctype.pegjs (fixed seed). A variant that changes the
#   grammar file changes the generated inputs, so sample lines may differ even without a new bug.
# - V5's hang detection is wall-clock (3000 ms per call, 4 worker threads). A slow or loaded
#   container can produce "hang in ..." lines that are not caused by the library.
# - V4 and V5 load the library through index.js (peg_lib/), so a grammar variant reaches them only
#   after the rebuild that inside.sh performs.
# - lean is the one from the image (Lean 4.35.0, record/metadata.txt); V1 does not depend on lib/.
#
# Not included:
#   - /tmp/rt/runall.sh, /tmp/rt/runall2.sh: the subject's runners that run the checks on the variant
#     copies in /tmp/mut/ (the variants themselves were made by Edit on those copies, calls 48-54).
#     They are checks of the checks; their check commands are reproduced above.
#   - /tmp/rt/cmp.js, summ.js, list.js, diag.js, probe.js: comparison / summary / probe helpers.
#   - /tmp/rt/fx.js, fx_root.js: the stage-1/3 round trip, replaced by verify/roundtrip.js (V2) in stage 4.
#   - npm test / npm run lint / tsc: lint and typecheck were run only to see that verify/ did not break
#     them (calls 79-83, 90), not reported as verification. V3 is the subject's test step without lint.
rc=0
step() { # name timeout command...
  local name=$1 t=$2; shift 2
  echo "@@ step $name"
  timeout "$t" "$@" < /dev/null; local r=$?
  [ "$r" = 124 ] && echo "@@ $name timed out"
  [ "$r" = 0 ] || rc=1
}
step "V1 lean" 300 lean formal/JsdocRoundtrip.lean
step "V2 roundtrip" 300 node verify/roundtrip.js
step "V3 mocha" 300 node_modules/.bin/mocha 'tests/test_*'
step "V4 precedence" 600 node verify/precedence.js
step "V5 robustness" 900 node verify/robustness.js
exit $rc
