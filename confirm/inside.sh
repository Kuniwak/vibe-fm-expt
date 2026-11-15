#!/bin/bash
# Runs inside a throwaway container of the run's image (no network, no agent). The collected home
# and /tmp are already restored. Usage: inside.sh VARIANT RECIPE MODE
#   VARIANT: base | M1..M6        MODE: tree (the agent's final tree) | orig (library at the pinned commit)
set -u
V="$1"; RECIPE="$2"; MODE="$3"
# The pinned commit: the recreated one (preregistration.md, 12.) or, for series-1 runs, the upstream one.
BASE=d395aa070e17b600969e18139e43ace2fbe2f78f
git -C /home/dev/jsdoctypeparser cat-file -e "$BASE^{commit}" 2>/dev/null || BASE=5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb
cd /home/dev/jsdoctypeparser || exit 2
if [ "$MODE" = orig ]; then
  git checkout -q "$BASE" -- lib peg_src peg_lib index.js 2>/dev/null || { echo "@@ cannot restore the pinned library"; exit 2; }
fi
if [ "$V" != base ]; then
  P=/tmp/confirm-tools/patches/$V.patch
  if ! git apply "$P" 2>/tmp/apply.err; then echo "@@ patch does not apply"; cat /tmp/apply.err; exit 3; fi
  echo "@@ patch applied ($MODE)"
fi
if [ "$V" != base ] && grep -q '^+++ b/peg_src' "/tmp/confirm-tools/patches/$V.patch"; then
  npm run build </dev/null >/tmp/build.log 2>&1 || { echo "@@ build failed"; tail -5 /tmp/build.log; exit 4; }
  echo "@@ parsers rebuilt"
fi
echo "@@ recipe start $(date -u +%FT%TZ)"
if [ "$RECIPE" = suite ]; then
  timeout 1800 npx mocha 'tests/*.js' </dev/null 2>&1 | grep -E '^ +[0-9]+ (passing|failing)|^ +[0-9]+\) ' ; rc=${PIPESTATUS[0]}
else
  timeout 5400 bash "/tmp/confirm-tools/recipe.sh" </dev/null 2>&1; rc=$?
fi
echo "@@ recipe exit=$rc$([ "$rc" = 124 ] && echo ' (timeout)') $(date -u +%FT%TZ)"
