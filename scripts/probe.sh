#!/usr/bin/env bash
# Start a throwaway container exactly like `run` (same image, user, env, network,
# Claude Code flags, interactive TTY) and list everything loaded into the agent.
# The first message is `/context` (local, no model call), the second a neutral "hello".
# Exits non-zero when anything outside probe/baseline.json shows up.
source "$(dirname "$0")/common.sh"
[ -n "${MODEL:-}" ] || { echo "error: MODEL is required" >&2; exit 1; }
load_token
agent_flags
OUT="${PROBE_OUT:-$ROOT/runs/probe-latest}"
rm -rf "$OUT"; mkdir -p "$OUT"

NETNAME="$(new_name)"; NAME="$(new_name)"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; net_down "$NETNAME"' EXIT
net_up "$NETNAME" "$OUT/network.log"
agent_run_opts "$NETNAME"
CMD=(docker run -it --name "$NAME" "${RUN_OPTS[@]}" "$IMAGE" claude "${CLAUDE_FLAGS[@]}" -- "/context")
quote_cmd "${CMD[@]}" > "$OUT/launch-command.txt"
{ echo "probed=$(now)"; echo "image_id=$(docker image inspect -f '{{.Id}}' "$IMAGE")"; echo "net_mode=$NET_MODE"; } > "$OUT/probe-env.txt"

if ! expect "$ROOT/scripts/probe/drive.exp" "$NAME" "$ROOT/scripts/probe/probe-inside.sh" "$OUT/raw.txt" "$MODEL" -- "${CMD[@]}" > "$OUT/drive.log" 2>&1; then
  cat "$OUT/drive.log" >&2
  echo "PROBE FAILED: interactive session did not complete" | tee "$OUT/report.txt"
  exit 1
fi
mkdir -p "$OUT/transcripts"
docker cp "$NAME:$IN_HOME/.claude/projects" - | tar -x -C "$OUT/transcripts"

python3 -I "$ROOT/scripts/probe/evaluate.py" "$OUT/raw.txt" "$OUT/transcripts" "$ROOT/probe/baseline-${MODEL:-default}.json" ${PROBE_WRITE_BASELINE:+--write} | tee "$OUT/report.txt"
exit "${PIPESTATUS[0]}"
