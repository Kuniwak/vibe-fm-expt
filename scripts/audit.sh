#!/usr/bin/env bash
# Inventory a collected run in a new container without the agent.
# Usage: audit.sh [runs/run-NN]   (default: latest run)
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

runs=("$ROOT"/runs/run-*)   # glob expansion is sorted
RUN_DIR="${1:-${runs[${#runs[@]}-1]}}"
[ -n "$RUN_DIR" ] && [ -d "$RUN_DIR/home/dev" ] || { echo "error: no collected run found" >&2; exit 1; }
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
OUT="$RUN_DIR/audit"
rm -rf "$OUT"; mkdir -p "$OUT"

NAME="$(new_name)"
# Audit with the same image the run used (tools such as tlc/z3 exist only in devenv-b).
# By ID when recorded, so series-1 runs are audited in the series-1 image (preregistration.md, 12.).
RUN_IMAGE="$(sed -n 's/^container_image_id=//p' "$RUN_DIR/record/metadata.txt" 2>/dev/null)"
[ -n "$RUN_IMAGE" ] || RUN_IMAGE="$(sed -n 's/^image=//p' "$RUN_DIR/record/metadata.txt" 2>/dev/null)"
IMAGE="${RUN_IMAGE:-$IMAGE}"
# No token, no agent; network open so Lake can re-fetch package checkouts that collect left out.
docker create --name "$NAME" --user "$IN_USER" -w "$IN_HOME" "$IMAGE" sleep infinity >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
docker start "$NAME" >/dev/null
# Restore collected files (as the container user), then the audit scripts in a separate directory.
docker exec -i "$NAME" mkdir -p /tmp/audit-tools
# Restore the collected home over /home/dev and the collected /tmp over /tmp (as the container user).
tar --no-mac-metadata --no-xattrs -C "$RUN_DIR/home/dev" -cf - . | docker exec -i "$NAME" tar -x -C /home/dev
if [ -d "$RUN_DIR/tmp" ]; then
  tar --no-mac-metadata --no-xattrs -C "$RUN_DIR/tmp" -cf - . | docker exec -i "$NAME" tar -x -C /tmp 2>/dev/null || true
fi
tar --no-mac-metadata --no-xattrs -C "$ROOT/scripts/audit" -cf - . | docker exec -i "$NAME" tar -x -C /tmp/audit-tools

echo "auditing $RUN_DIR (container $NAME, image $IMAGE)"
docker exec "$NAME" bash /tmp/audit-tools/audit-inside.sh /tmp/audit-out 2>&1 | tee "$OUT/audit.log"
docker exec "$NAME" tar -C /tmp/audit-out -cf - . | tar -x -C "$OUT"
echo "image_id=$(docker image inspect -f '{{.Id}}' "$IMAGE")" > "$OUT/audit-env.txt"
echo "audited=$(now)" >> "$OUT/audit-env.txt"
echo "audit written to $OUT"
