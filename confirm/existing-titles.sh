#!/usr/bin/env bash
# List the full titles of the tests that exist at the pinned commit (preregistration.md 12, the auxiliary
# verdict that excludes existing tests). Runs the pinned commit's mocha suite once, in a throwaway
# container of the run's image, from a run's collected home (only for its git objects and node_modules).
# Usage: confirm/existing-titles.sh runs/run-NN [SRC-SUBDIR]   > confirm/existing-titles.txt
# shellcheck source=../scripts/common.sh
source "$(dirname "$0")/../scripts/common.sh"
RUN_DIR="$(cd "$1" && pwd)"; SRC="$RUN_DIR/${2:-.}"
IMAGE="$(sed -n 's/^container_image_id=//p' "$RUN_DIR/record/metadata.txt")"
BASE=d395aa070e17b600969e18139e43ace2fbe2f78f
name="$(new_name)"
docker create --name "$name" --cpus 1 --network none --user "$IN_USER" -w "$IN_HOME" "$IMAGE" sleep infinity >/dev/null
docker start "$name" >/dev/null
tar --no-mac-metadata --no-xattrs -C "$SRC/home/dev" -cf - . | docker exec -i "$name" tar -x -C /home/dev
docker exec -i "$name" bash -c "
  set -e
  cd /home/dev/jsdoctypeparser
  git checkout -q $BASE -- .
  git clean -qfd -- tests lib peg_src peg_lib index.js
  timeout 1800 npx mocha --reporter json 'tests/test_*' > /tmp/titles.json 2>/dev/null || true
  node -e 'const r=require(\"/tmp/titles.json\"); const s=new Set(r.tests.map(t=>t.fullTitle)); for (const t of [...s].sort()) console.log(t); console.error(\"tests:\", r.stats.tests, \"passes:\", r.stats.passes, \"failures:\", r.stats.failures)'
"
docker rm -f "$name" >/dev/null
