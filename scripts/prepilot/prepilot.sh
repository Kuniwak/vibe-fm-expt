#!/usr/bin/env bash
# Compressed harness check before a pilot (preregistration.md 12.5): unit tests, then two short
# sessions with unrelated prompts and a stand-in user role. Never counts as a run (runs/_test).
#   dialog : multi- and single-select dialogs, stages 1-5, fixed message (neutral texts)
#   timeout: the user role always replies; the overall limit (shortened to 3 min) stops the session
# Usage: scripts/prepilot/prepilot.sh [dialog] [timeout]   (default: both). Exit 0 only if all checks pass.
set -u
cd "$(dirname "$0")/../.." || exit 1
export PATH="$HOME/.docker/bin:$PATH"
D=scripts/prepilot
fail=0
check() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

echo "== unit tests"
python3 -I -W ignore -m unittest discover -s scripts/drive/tests 2>&1 | tail -1
python3 -I -W ignore -m unittest discover -s scripts/drive/tests >/dev/null 2>&1 || fail=1

session() {  # name prompt mock-mode timeout-unit-secs
  local before after
  before=$(ls -d runs/_test/test-* 2>/dev/null | sort | tail -1)
  COND=TEST OFF_PROTOCOL=1 MODEL=claude-opus-5-5 PROMPT_FILE="$D/$2" TEST_STAGE_DIR="$D/stage" \
    TEST_STAGE4_MINUTES=2 TEST_TIMEOUT_UNIT_SECS="$4" MOCK_ROLE="$3" \
    OPCMD_OVERRIDE="[\"python3\", \"-I\", \"$PWD/$D/mock_role.py\"]" \
    scripts/run-staged.sh > "runs/_test/prepilot-$1.log" 2>&1
  after=$(ls -d runs/_test/test-* | sort | tail -1)
  [ "$after" != "$before" ] || { echo "  FAIL no session directory"; fail=1; return 1; }
  R="$after/record"; echo "  ($after)"
}

mkdir -p runs/_test
for s in "${@:-dialog timeout}"; do for name in $s; do
  echo "== $name"
  case $name in
    dialog)
      session dialog prompt-dialog.txt complete 60 || continue
      check "driver exit 0"            "grep -q '^driver_exit=0$' $R/run.env"
      check "summary written"          "! grep -q '^driver_summary=missing' $R/run.env"
      check "fixed message sent"       "grep -q '^fixed_sent=True$' $R/run.env"
      check "two dialogs answered"     "[ \$(grep -c '\"event\": \"dialog\"' $R/operator.jsonl) -ge 2 ]"
      check "no dialog left open"      "! grep -q 'dialog_still_open\|operator_error' $R/operator.jsonl"
      check "answers reached agent"    "[ \$(cat $R/transcripts/*.jsonl | grep -o '\"answers\"' | wc -l) -ge 2 ]"
      ;;
    timeout)
      session timeout prompt-ask.txt reply 1 || continue
      check "time limit reached"       "grep -q '^timeout=' $R/run.env"
      check "S3-timeout copied"        "grep -q '^snapshot_s3_timeout=.*(ok)' $R/run.env"
      check "driver exit 0"            "grep -q '^driver_exit=0$' $R/run.env"
      check "summary written"          "! grep -q '^driver_summary=missing' $R/run.env"
      check "pty_closed recorded"      "grep -q '\"event\": \"pty_closed\"' $R/operator.jsonl"
      check "no traceback"             "! grep -q Traceback runs/_test/prepilot-timeout.log"
      ;;
    *) echo "unknown: $name"; fail=1 ;;
  esac
done; done
echo "== leftovers"
check "no watchdog sleep left"   "! pgrep -f 'sleep 10800' >/dev/null && ! pgrep -xf 'sleep 180' >/dev/null"
check "no container left"        "[ -z \"\$(docker ps -q --filter name=dv-)\" ]"
exit $fail
