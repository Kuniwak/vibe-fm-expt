#!/usr/bin/env bash
# Checks that every prompt file in config/conditions.tsv has the preregistered sha256.
# The condition-B prompt is fetched first (scripts/fetch-playbook.sh), which checks it as well.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/fetch-playbook.sh"
status=0
while IFS=$'\t' read -r cond _ file want; do
  have=$(shasum -a 256 "$ROOT/$file" | cut -d' ' -f1)
  if [ "$have" = "$want" ]; then echo "ok        $cond  $file"; else echo "MISMATCH  $cond  $file  $have (expected $want)"; status=1; fi
done < <(grep -v '^#' "$ROOT/config/conditions.tsv")
exit "$status"
