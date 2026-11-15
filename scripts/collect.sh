#!/usr/bin/env bash
# Collect artifacts and records of a finished run into runs/run-NN/.
# Usage: collect.sh [runs/run-NN]   (default: latest run)
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

runs=("$ROOT"/runs/run-*)   # glob expansion is sorted
RUN_DIR="${1:-${runs[${#runs[@]}-1]}}"
[ -n "$RUN_DIR" ] && [ -f "$RUN_DIR/record/run.env" ] || { echo "error: no run to collect" >&2; exit 1; }
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
NAME="$(sed -n 's/^container=//p' "$RUN_DIR/record/run.env")"
NETNAME="$(sed -n 's/^netns_container=//p' "$RUN_DIR/record/run.env")"
docker inspect "$NAME" >/dev/null 2>&1 || { echo "error: container $NAME not found (already collected?)" >&2; exit 1; }
docker stop -t 10 "$NAME" >/dev/null 2>&1 || true

echo "collecting from $NAME into $RUN_DIR"
# Home directory (includes the working directory, ~/.claude transcripts and memory) and /tmp.
# Toolchains, the pre-filled Mathlib cache, Lake package checkouts and node_modules are
# reproducible from the image / manifests and are left out.
EXCL=(--exclude 'dev/.elan' --exclude 'dev/.cache/mathlib' --exclude '*/.lake/packages'
      --exclude 'dev/jsdoctypeparser/node_modules' --exclude 'tmp/*/.lake/packages')
mkdir -p "$RUN_DIR/home" "$RUN_DIR/tmp"
docker cp "$NAME:$IN_HOME" - | tar -x -C "$RUN_DIR/home" "${EXCL[@]}"
docker cp "$NAME:/tmp" - | tar -x -C "$RUN_DIR" "${EXCL[@]}" 2>/dev/null || true
docker diff "$NAME" > "$RUN_DIR/record/fs-diff.txt"

# Session transcripts, copied out for convenience.
mkdir -p "$RUN_DIR/record/transcripts"
if [ -d "$RUN_DIR/home/dev/.claude/projects" ]; then
  find "$RUN_DIR/home/dev/.claude/projects" -name '*.jsonl' -exec cp {} "$RUN_DIR/record/transcripts/" \;
fi

# Versions, measured in a separate throwaway container from the same image (no network).
VERS="$(docker run --rm --network none --user "$IN_USER" "$IMAGE" bash -c \
  'echo "claude_code=$(claude --version)"; echo "lean=$(lean --version)"; echo "lake=$(lake --version)";
   echo "elan=$(elan --version)"; echo "node=$(node --version)"; echo "npm=$(npm --version)"
   if command -v java >/dev/null; then echo "java=$(java -version 2>&1 | head -1)"; fi
   if command -v tlc >/dev/null; then echo "tla2tools=$(tlc -h 2>&1 | grep -m1 -o "Version [0-9.]* of .*")"; fi
   if command -v z3 >/dev/null; then echo "z3=$(z3 --version)"; fi
   if python3 -c "import z3" 2>/dev/null; then echo "z3py=$(python3 -c "import z3; print(z3.get_version_string())")"; fi')"
IMAGE_ID="$(docker image inspect -f '{{.Id}}' "$IMAGE")"
CONTAINER_IMAGE="$(docker inspect -f '{{.Image}}' "$NAME")"
NET_IMAGE_ID="$(docker image inspect -f '{{.Id}}' "$NET_IMAGE")"

# Models actually used, from the transcripts.
MODELS="$(cat "$RUN_DIR"/record/transcripts/*.jsonl 2>/dev/null | python3 -c '
import json, sys
seen = {}
for line in sys.stdin:
    try: m = json.loads(line).get("message", {}).get("model")
    except Exception: continue
    if m: seen[m] = seen.get(m, 0) + 1
print(", ".join(f"{k} ({v} msgs)" for k, v in seen.items()) or "<none>")
')"

{
  cat "$RUN_DIR/record/run.env"
  echo "models_in_transcript=$MODELS"
  echo "$VERS"
  echo "mathlib_cached=$MATHLIB_TAG ($MATHLIB_REV)"
  echo "target_repo_commit=$REPO_COMMIT"
  echo "image=$IMAGE"
  echo "image_id=$IMAGE_ID"
  echo "container_image_id=$CONTAINER_IMAGE"
  echo "netguard_image_id=$NET_IMAGE_ID"
  echo "agent_env=${AGENT_ENV[*]} CLAUDE_CODE_OAUTH_TOKEN=<redacted>"
  echo "permission_prompts=skipped (--dangerously-skip-permissions; skipDangerousModePermissionPrompt=true in ~/.claude/settings.json)"
  echo "collected=$(now)"
} > "$RUN_DIR/record/metadata.txt"
cp "$ALLOW_FILE" "$RUN_DIR/record/allow-domains.txt"
# Container config with the token value removed.
docker inspect "$NAME" | sed -E 's/(CLAUDE_CODE_OAUTH_TOKEN=)[^"]*/\1<redacted>/' > "$RUN_DIR/record/container-inspect.json"

docker rm -f "$NAME" >/dev/null
net_down "$NETNAME"
echo "collected: $RUN_DIR"
