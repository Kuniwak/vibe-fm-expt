#!/bin/bash
# Inside a throwaway devenv container: apply each patch to a fresh copy of the repository,
# rebuild the generated parsers when the grammar changed, run the symptom checks and npm test.
set -u
for p in /tmp/patches/*.patch; do
  n=$(basename "$p" .patch); w=/tmp/w-$n
  rm -rf "$w"; cp -a /home/dev/jsdoctypeparser "$w"; cd "$w" || continue
  git apply "$p" || { echo "== $n: patch failed"; continue; }
  if grep -q peg_src "$p"; then npm run build </dev/null >/tmp/build-"$n".log 2>&1 || { echo "== $n: build failed"; tail -5 /tmp/build-"$n".log; continue; }; fi
  git diff --stat | tail -1 > /tmp/stat-"$n"
  echo "== $n ($(cat /tmp/stat-"$n"))"
  node /tmp/check-symptoms.js "$w" | tr -d '\n' | sed 's/  */ /g'; echo
  npx mocha tests/*.js </dev/null 2>&1 | grep -E '^ +[0-9]+ (passing|failing)' | tr '\n' ' '; echo
done
