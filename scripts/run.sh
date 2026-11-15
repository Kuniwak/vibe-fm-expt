#!/usr/bin/env bash
# Run one session of a preregistered condition, driven by the fixed procedure.
# Env: COND (A|A2|B, required), MODEL (required; must equal PROTOCOL_MODEL),
#      NET (allowlist|open), OFF_PROTOCOL=1 to allow a model other than PROTOCOL_MODEL.
source "$(dirname "$0")/common.sh"
source "$ROOT/config/protocol.env"

[ -n "${COND:-}" ] || { echo "error: COND is required (A, A2 or B; see config/conditions.tsv)" >&2; exit 1; }
[ -n "${MODEL:-}" ] || { echo "error: MODEL is required (preregistered: $PROTOCOL_MODEL)" >&2; exit 1; }
if [ "$MODEL" != "$PROTOCOL_MODEL" ] && [ "${OFF_PROTOCOL:-}" != 1 ]; then
  echo "error: MODEL=$MODEL differs from the preregistered $PROTOCOL_MODEL (set OFF_PROTOCOL=1 for an off-protocol trial)" >&2; exit 1
fi
if [ "$COND" = TEST ]; then
  # Harness check with an unrelated prompt; never counts as a run.
  [ "${OFF_PROTOCOL:-}" = 1 ] && [ -n "${PROMPT_FILE:-}" ] || { echo "error: COND=TEST needs OFF_PROTOCOL=1 and PROMPT_FILE" >&2; exit 1; }
  IMAGE="${IMAGE:-devenv:latest}"; PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
  PROMPT_SHA="$(shasum -a 256 < "$PROMPT_FILE" | awk '{print $1}')"
  RUNS_BASE="$ROOT/runs/_test"; RUN_PREFIX=test
else
  row="$(awk -F'\t' -v c="$COND" '$1 == c' "$ROOT/config/conditions.tsv")"
  [ -n "$row" ] || { echo "error: unknown condition $COND" >&2; exit 1; }
  IMAGE="$(cut -f2 <<<"$row")"; PROMPT_FILE="$ROOT/$(cut -f3 <<<"$row")"; PROMPT_SHA="$(cut -f4 <<<"$row")"
  [ "$(shasum -a 256 < "$PROMPT_FILE" | awk '{print $1}')" = "$PROMPT_SHA" ] \
    || { echo "error: $PROMPT_FILE does not match its preregistered sha256" >&2; exit 1; }
  RUNS_BASE="$ROOT/runs"; RUN_PREFIX=run
fi
export IMAGE MODEL
load_token
agent_flags

mkdir -p "$RUNS_BASE"
# Claim the next free number atomically (mkdir fails if another run took it).
n=1
until mkdir "$(printf '%s/%s-%02d' "$RUNS_BASE" "$RUN_PREFIX" "$n")" 2>/dev/null; do n=$((n + 1)); done
RUN_DIR="$(printf '%s/%s-%02d' "$RUNS_BASE" "$RUN_PREFIX" "$n")"
mkdir -p "$RUN_DIR/record"
echo "run directory: $RUN_DIR (condition $COND, image $IMAGE, model $MODEL)"

PROBE_OUT="$RUN_DIR/probe" "$ROOT/scripts/probe.sh" || { echo "error: probe failed; not starting the session (probe output kept in $RUN_DIR/probe)" >&2; mv "$RUN_DIR" "$RUN_DIR.probe-failed"; exit 1; }

# First message: file content verbatim, minus the single newline that terminates the file.
PROMPT="$(cat "$PROMPT_FILE"; printf x)"; PROMPT="${PROMPT%x}"; PROMPT="${PROMPT%$'\n'}"
cp "$PROMPT_FILE" "$RUN_DIR/record/first-prompt.txt"
cp "$ROOT/config/operator-prompt.txt" "$RUN_DIR/record/operator-prompt.txt"

NETNAME="$(new_name)"; NAME="$(new_name)"; OPNET="$(new_name)"
net_up "$NETNAME" "$RUN_DIR/record/network.log"
net_up "$OPNET" "$RUN_DIR/record/operator-network.log"
agent_run_opts "$NETNAME"
CMD=(docker run -it --name "$NAME" "${RUN_OPTS[@]}" "$IMAGE" claude "${CLAUDE_FLAGS[@]}" -- "$PROMPT")
# The blind operator: separate container and network namespace, no tools, own system prompt.
OPCMD=(docker run --rm -i --network "container:$OPNET" --user "$IN_USER" -e CLAUDE_CODE_OAUTH_TOKEN)
for kv in "${AGENT_ENV[@]}"; do OPCMD+=(-e "$kv"); done
OPCMD+=(devenv:latest claude -p --model "$OPERATOR_MODEL" --tools "" --strict-mcp-config
        --no-session-persistence --output-format json)
OPCMD_JSON="$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${OPCMD[@]}")"

{
  echo "condition=$COND"
  echo "sequence_index=${SEQ_INDEX:-}"
  echo "container=$NAME"
  echo "netns_container=$NETNAME"
  echo "operator_netns_container=$OPNET"
  echo "net_mode=$NET_MODE"
  echo "model_flag=$MODEL"
  echo "operator_model=$OPERATOR_MODEL"
  echo "protocol_reply=$PROTOCOL_REPLY"
  echo "protocol_fixed=$PROTOCOL_FIXED"
  echo "protocol_max_replies=$PROTOCOL_MAX_REPLIES"
  echo "timeout_min=$PROTOCOL_TIMEOUT_MIN"
  echo "prompt_file=${PROMPT_FILE#$ROOT/}"
  echo "off_protocol=${OFF_PROTOCOL:-0}"
  echo "prompt_file_sha256=$PROMPT_SHA"
  echo "prompt_sent_sha256=$(printf '%s' "$PROMPT" | shasum -a 256 | awk '{print $1}')"
  echo "operator_prompt_sha256=$(shasum -a 256 < "$ROOT/config/operator-prompt.txt" | awk '{print $1}')"
  echo "harness_commit=$(git -C "$ROOT" rev-parse HEAD)$(git -C "$ROOT" diff --quiet HEAD -- . ':!runs' || echo '+dirty')"
  echo "start=$(now)"
} > "$RUN_DIR/record/run.env"
quote_cmd "${CMD[@]:0:${#CMD[@]}-1}" > "$RUN_DIR/record/launch-command.txt"
echo "  <contents of first-prompt.txt>" >> "$RUN_DIR/record/launch-command.txt"
quote_cmd "${OPCMD[@]}" > "$RUN_DIR/record/operator-command.txt"
echo "  --system-prompt <contents of operator-prompt.txt>   (stdin: the agent's last message)" >> "$RUN_DIR/record/operator-command.txt"

( sleep $((PROTOCOL_TIMEOUT_MIN * 60)); echo "timeout=$(now)" >> "$RUN_DIR/record/run.env"; docker stop -t 10 "$NAME" >/dev/null 2>&1 ) &
WATCHDOG=$!

set +e
python3 -I "$ROOT/scripts/drive/driver.py" --container "$NAME" --log-dir "$RUN_DIR/record" \
  --operator-cmd "$OPCMD_JSON" --operator-prompt "$ROOT/config/operator-prompt.txt" \
  --reply "$PROTOCOL_REPLY" --fixed "$PROTOCOL_FIXED" --max-replies "$PROTOCOL_MAX_REPLIES" \
  ${MIRROR:+--mirror} -- "${CMD[@]}"
rc=$?
set -e
kill "$WATCHDOG" 2>/dev/null || true
net_down "$OPNET"
{
  echo "end=$(now)"
  echo "driver_exit=$rc"
  python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); [print(f"{k}={v}") for k,v in d.items()]' \
    "$RUN_DIR/record/driver-summary.json" 2>/dev/null || echo "driver_summary=missing"
} >> "$RUN_DIR/record/run.env"
if ! grep -q '^fixed_sent=True$' "$RUN_DIR/record/run.env"; then
  echo "WARNING: the fixed message was NOT sent in this run (see record/operator.jsonl)" | tee -a "$RUN_DIR/record/run.env" >&2
fi

"$ROOT/scripts/collect.sh" "$RUN_DIR"
