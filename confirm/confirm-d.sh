#!/usr/bin/env bash
# Independent check for conditions D and D2, kind 2 (preregistration.md 11.6): run the agent's checks
# as of a snapshot (S1, S3, or S3-timeout) against the reference variants M1-M3.
# Usage: confirm/confirm-d.sh runs/run-NN SNAP      (recipe: confirm/recipes/run-NN-SNAP.sh)
# Results: runs/run-NN/confirm/SNAP/<mode>-<variant>.txt and summary.md
# shellcheck source=../scripts/common.sh
source "$(dirname "$0")/../scripts/common.sh"
RUN_DIR="$(cd "$1" && pwd)"; SNAP="$2"; WHAT=recipe
RUN="$(basename "$RUN_DIR")"
RECIPE="$ROOT/confirm/recipes/$RUN-$SNAP.sh"
SRC="$RUN_DIR/snapshots/$SNAP"
[ -f "$RECIPE" ] || { echo "no recipe $RECIPE" >&2; exit 1; }
[ -d "$SRC/home/dev" ] || { echo "no snapshot $SRC" >&2; exit 1; }
# The exact image the run used (by ID), so series-1 runs are checked in the series-1 image.
IMAGE="$(sed -n 's/^container_image_id=//p' "$RUN_DIR/record/metadata.txt")"
[ -n "$IMAGE" ] || IMAGE="$(sed -n 's/^image=//p' "$RUN_DIR/record/metadata.txt")"
OUT="$RUN_DIR/confirm/$SNAP"; mkdir -p "$OUT"
REPO="$SRC/home/dev/jsdoctypeparser"
# The pinned commit: the recreated one (preregistration.md, 12.) or, for series-1 runs, the upstream one.
BASE=d395aa070e17b600969e18139e43ace2fbe2f78f
git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null || BASE=5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb
# Does the agent's tree differ from the pinned commit in the library? Then also run on the original library.
modes=(tree)
git -C "$REPO" diff --quiet "$BASE" -- lib peg_src peg_lib index.js || modes+=(orig)
one() {
  local v="$1" mode="$2" name; name="$(new_name)"
  docker create --name "$name" --network none --user "$IN_USER" -w "$IN_HOME" "$IMAGE" sleep infinity >/dev/null
  docker start "$name" >/dev/null
  tar --no-mac-metadata --no-xattrs -C "$SRC/home/dev" -cf - . | docker exec -i "$name" tar -x -C /home/dev
  [ -d "$SRC/tmp" ] && { tar --no-mac-metadata --no-xattrs -C "$SRC/tmp" --exclude ./cc-socks -cf - . | docker exec -i "$name" tar -x -C /tmp 2>/dev/null || true; }
  docker exec -i "$name" mkdir -p /tmp/confirm-tools/patches
  tar --no-mac-metadata --no-xattrs -C "$ROOT/reference/patches" -cf - . | docker exec -i "$name" tar -x -C /tmp/confirm-tools/patches
  docker exec -i "$name" sh -c 'cat > /tmp/confirm-tools/inside.sh' < "$ROOT/confirm/inside.sh"
  [ "$WHAT" = suite ] || docker exec -i "$name" sh -c 'cat > /tmp/confirm-tools/recipe.sh' < "$RECIPE"
  docker exec "$name" bash /tmp/confirm-tools/inside.sh "$v" "$([ "$WHAT" = suite ] && echo suite || echo recipe)" "$mode" > "$OUT/$mode-$v.txt" 2>&1
  docker rm -f "$name" >/dev/null
}
for mode in "${modes[@]}"; do
  for v in base M1 M2 M3; do
    echo "--- $RUN $WHAT $mode $v $(now)"
    one "$v" "$mode"
  done
done
python3 -I "$ROOT/confirm/summarize.py" "$OUT" "$([ "$WHAT" = suite ] && echo none || echo "$RECIPE")" > "$OUT/summary.md"
cat "$OUT/summary.md"
