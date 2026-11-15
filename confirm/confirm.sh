#!/usr/bin/env bash
# Independent check (preregistration.md 10.4): run the agent's final checks of a run against each
# reference variant. Usage: confirm/confirm.sh runs/run-NN [suite]
#   default: the recipe confirm/recipes/run-NN.sh;  suite: the repository's mocha suite of the final tree.
# Results: runs/run-NN/confirm/<recipe>/<mode>-<variant>.txt and summary.md
# shellcheck source=../scripts/common.sh
source "$(dirname "$0")/../scripts/common.sh"
RUN_DIR="$(cd "$1" && pwd)"; WHAT="${2:-recipe}"
RUN="$(basename "$RUN_DIR")"
RECIPE="$ROOT/confirm/recipes/$RUN.sh"
[ "$WHAT" = suite ] || [ -f "$RECIPE" ] || { echo "no recipe for $RUN" >&2; exit 1; }
IMAGE="$(sed -n 's/^image=//p' "$RUN_DIR/record/metadata.txt")"
OUT="$RUN_DIR/confirm/$WHAT"; mkdir -p "$OUT"
REPO="$RUN_DIR/home/dev/jsdoctypeparser"
BASE=5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb
# Does the agent's tree differ from the pinned commit in the library? Then also run on the original library.
modes=(tree)
git -C "$REPO" diff --quiet "$BASE" -- lib peg_src peg_lib index.js || modes+=(orig)
one() {
  local v="$1" mode="$2" name; name="$(new_name)"
  docker create --name "$name" --network none --user "$IN_USER" -w "$IN_HOME" "$IMAGE" sleep infinity >/dev/null
  docker start "$name" >/dev/null
  tar --no-mac-metadata --no-xattrs -C "$RUN_DIR/home/dev" -cf - . | docker exec -i "$name" tar -x -C /home/dev
  [ -d "$RUN_DIR/tmp" ] && { tar --no-mac-metadata --no-xattrs -C "$RUN_DIR/tmp" -cf - . | docker exec -i "$name" tar -x -C /tmp 2>/dev/null || true; }
  docker exec -i "$name" mkdir -p /tmp/confirm-tools/patches
  tar --no-mac-metadata --no-xattrs -C "$ROOT/reference/patches" -cf - . | docker exec -i "$name" tar -x -C /tmp/confirm-tools/patches
  docker exec -i "$name" sh -c 'cat > /tmp/confirm-tools/inside.sh' < "$ROOT/confirm/inside.sh"
  [ "$WHAT" = suite ] || docker exec -i "$name" sh -c 'cat > /tmp/confirm-tools/recipe.sh' < "$RECIPE"
  docker exec "$name" bash /tmp/confirm-tools/inside.sh "$v" "$([ "$WHAT" = suite ] && echo suite || echo recipe)" "$mode" > "$OUT/$mode-$v.txt" 2>&1
  docker rm -f "$name" >/dev/null
}
for mode in "${modes[@]}"; do
  for v in base M1 M2 M3 M4 M5 M6; do
    echo "--- $RUN $WHAT $mode $v $(now)"
    one "$v" "$mode"
  done
done
python3 -I "$ROOT/confirm/summarize.py" "$OUT" "$([ "$WHAT" = suite ] && echo none || echo "$RECIPE")" > "$OUT/summary.md"
cat "$OUT/summary.md"
