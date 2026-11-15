#!/usr/bin/env bash
# Run the preregistered sequence (preregistration.md, 3. 手順): A, A2, B three times, 9 runs in all.
# Runs are executed in waves of PARALLEL consecutive sequence entries started together
# (amendment in preregistration.md, 7.). After each wave: audit and extraction, one run at a time.
# Usage: scripts/batch.sh [START_INDEX] [PARALLEL]   (START_INDEX is 1-based; default 1 and 3)
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
# shellcheck source=../config/protocol.env
source "$ROOT/config/protocol.env"
SEQ=(A A2 B A A2 B A A2 B)
start="${1:-1}"; parallel="${2:-3}"
mkdir -p "$ROOT/runs/logs"

run_dir_of() { grep -l "^sequence_index=$1\$" "$ROOT"/runs/run-[0-9][0-9]/record/run.env 2>/dev/null | head -1 | xargs -r dirname | xargs -r dirname; }
postprocess() {
  local run="$1"
  [ -d "$run/audit" ] || "$ROOT/scripts/audit.sh" "$run" > "$run/audit.log.txt" 2>&1 || echo "audit failed for $run (see $run/audit.log.txt)"
  [ -d "$run/analysis" ] || python3 -I "$ROOT/scripts/analysis/extract.py" "$run" || echo "extract failed for $run"
  grep -E '^(condition|sequence_index|start|end|timeout|replies_sent|fixed_sent|WARNING)' "$run/record/run.env"
}

# Wait for runs started earlier (e.g. by a previous sequential batch) to finish, then post-process them.
while pgrep -f 'scripts/run\.sh' >/dev/null; do sleep 30; done
for run in "$ROOT"/runs/run-[0-9][0-9]; do
  [ -f "$run/record/run.env" ] && grep -q '^end=' "$run/record/run.env" && { [ -d "$run/audit" ] && [ -d "$run/analysis" ] || postprocess "$run"; }
done

i="$start"
while [ "$i" -le "${#SEQ[@]}" ]; do
  wave=()
  for ((k = 0; k < parallel && i <= ${#SEQ[@]}; k++, i++)); do wave+=("$i"); done
  echo "=== wave: sequence ${wave[*]}  $(now)"
  pids=()
  for j in "${wave[@]}"; do
    c="${SEQ[$((j - 1))]}"
    echo "--- start sequence $j (condition $c)"
    SEQ_INDEX="$j" COND="$c" MODEL="$PROTOCOL_MODEL" "$ROOT/scripts/run.sh" > "$ROOT/runs/logs/seq-$j.log" 2>&1 &
    pids+=("$!")
    sleep 15
  done
  failed=0
  for p in "${pids[@]}"; do wait "$p" || failed=1; done
  for j in "${wave[@]}"; do
    run="$(run_dir_of "$j")"
    if [ -z "$run" ]; then echo "--- sequence $j: no run directory (see runs/logs/seq-$j.log)"; failed=1; continue; fi
    echo "--- sequence $j -> $run"
    postprocess "$run"
  done
  if [ "$failed" = 1 ]; then
    echo "=== a run in this wave did not complete; stopping. Resume the remaining entries with: scripts/batch.sh <index> $parallel"
    exit 1
  fi
done
echo "=== sequence finished $(now)"
