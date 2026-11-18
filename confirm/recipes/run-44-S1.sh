# shellcheck shell=bash
# run-44 (D, D2), snapshot S1 (end of stage 1, 2026-11-18T00:27:29Z).
# Working directory: /home/dev/jsdoctypeparser (HEAD d395aa0, uncommitted changes; formal/ is untracked).
# The subject changed the library (uncommitted):
#   - peg_src/jsdoctype.pegjs, rule QualifiedMemberName (line ~160): the MEMBER node built after
#     `typeof` now gets `name: tokens[3].name, quoteStyle: 'none', hasEventPrefix: false`
#     instead of `name: tokens[3]` (call 13).
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js rebuilt from it (same change).
#   - lib/ is unchanged. tests/test_parsing.js and tests/test_publishing.js got one test each.
#
# Artifacts (the checks the subject reported as its verification in #11):
#   V1 formal/JsdocRoundtrip.lean: Lean 4 proof (roundtrip, pub_injective) on a hand-written model
#      of publish. It reads no JS, so it cannot react to library changes; it is included because
#      the report names it as the verification ("`lean formal/JsdocRoundtrip.lean` で検証できます").
#   V2 /tmp/rt/fx.js: parse -> publish -> parse round trip over all fixtures in 4 modes, against
#      require('/home/dev/jsdoctypeparser'). Exists only in the snapshot's /tmp.
#      Prints "DIFF ..." / "FAIL-REPARSE ..." per mismatch and "total N bad M"; exit 0 unless it
#      crashes (it catches parse errors silently, does not catch publish exceptions).
#   V3 npm test: pretest = lint + build; test = nyc mocha (check-coverage 100%) + tsc.
# Sources of the commands (analysis/commands.md):
#   - V1: #11 "`lean formal/JsdocRoundtrip.lean` で検証できます" (calls 22/32/33 ran `lean JsdocRoundtrip.lean` in formal/).
#   - V2: call 19 `node /tmp/rt/fx.js | tail -3` (call 8: `cd /tmp/rt && node fx.js > out.txt`).
#   - V3: call 35 `npm test 2>&1 | grep -E "passing|failing|problems?|All files"` (also call 19).
# Durations in the record: lean about 1 s; fx.js about 27 s (call 38); npm test about 7 s (call 35).
# Timeouts: `timeout 300` on V2 and V3 is taken from the subject's own runner for the same two
#   checks in stage 3 (/tmp/rt/runall.sh, call 56). At S1 the subject ran them without a timeout.
#   Without it, a non-terminating input would use up the whole 5400 s and stop the later checks.
#   On timeout the recipe prints "@@ <step> timed out" (not in VIOLATION_RE: the subject itself
#   rated a timeout as "not a reported violation", #15).
# Exit code: 1 if any of V1-V3 exits non-zero, else 0 (baseline in the record: all three 0).
#   Note: V2 also exits non-zero when publish throws (the script crashes with a stack trace and
#   prints no input); the subject rated that as "△ 異常終了するが入力は示さない" (#15).
#   V3 also exits non-zero on lint errors or coverage below 100% ("ERROR: Coverage for ...").
# Lines that show a violation:
#   V2: "FAIL-REPARSE permissive definitely-typed-types:14447 \"(() => typeof Backbone.View) | typeof Backbone.View\" -> ..."
#       (/tmp/rt/out.txt line 1, before the fix; 3144 such lines, call 8 "total 621251 bad 3144")
#   V3: "  12 failing" (stage 3, /tmp/mut/M2a, call 57 output); nyc "ERROR: Coverage for ..." (form as in run-14)
#   V1: lean "JsdocRoundtrip.lean:197:50: error: ..." (call 22, while the proof was being written)
# VIOLATION_RE: ^(DIFF|FAIL-REPARSE) |[0-9]+ failing|ERROR:|JsdocRoundtrip\.lean:[0-9]+:[0-9]+: error
#
# Not included:
#   - /tmp/rt/rt.js: a one-off probe with hand-picked string inputs (call 5), not reported as verification.
#   - /tmp/rt/check.lean: a copy of the proof with `#print axioms` appended (call 34); same content as V1.
#   - Nothing in S1 applies variants (variants were created only in stage 3).
rc=0
echo "@@ step V1 lean"
lean formal/JsdocRoundtrip.lean < /dev/null || rc=1
echo "@@ step V3 npm test"
timeout 300 npm test < /dev/null; r=$?; [ "$r" = 124 ] && echo "@@ npm test timed out"; [ "$r" = 0 ] || rc=1
echo "@@ step V2 roundtrip (/tmp/rt/fx.js)"
timeout 300 node /tmp/rt/fx.js < /dev/null; r=$?; [ "$r" = 124 ] && echo "@@ fx.js timed out"; [ "$r" = 0 ] || rc=1
exit $rc
