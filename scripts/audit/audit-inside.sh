#!/usr/bin/env bash
# Runs inside the audit container (no agent). The collected home is restored at /home/dev
# and the collected /tmp at /tmp, so scripts written with absolute paths run unchanged.
# Usage: audit-inside.sh OUT
# The audit items are fixed (preregistration.md); only concrete commands may adapt.
set -uo pipefail
OUT="$1"; TOOLS="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
ROOTS=(/home/dev /tmp)
PRUNE=(-name .lake -o -name .elan -o -name node_modules -o -name .cache -o -name .git -o -name .npm
       -o -name .claude -o -name claude-1000 -o -name cc-socks -o -name node-compile-cache -o -name audit-tools -o -name audit-out
       -o -path /tmp/states -o -name states)
list() { find "${ROOTS[@]}" \( "${PRUNE[@]}" \) -prune -o -type f \( "$@" \) -print 2>/dev/null | sort; }
section() { echo; echo "######## $*"; }

# ---------------------------------------------------------------- Lean
section "Lean"
list -name '*.lean' > "$OUT/lean-files.txt"
echo "lean files: $(wc -l < "$OUT/lean-files.txt")"
{
  for pat in sorry admit axiom; do
    printf '=== \\b%s\\b\n' "$pat"
    [ -s "$OUT/lean-files.txt" ] && xargs -d '\n' grep -nHwE "$pat" < "$OUT/lean-files.txt" || true
    echo
  done
  echo "=== axiom declarations"
  [ -s "$OUT/lean-files.txt" ] && xargs -d '\n' grep -nHE '^\s*(@\[[^]]*\]\s*)?((private|protected|noncomputable|unsafe|partial)\s+)*axiom\s' < "$OUT/lean-files.txt" || true
} > "$OUT/lean-search.txt"
cat "$OUT/lean-search.txt"

# Lake projects: build (full output), then axioms per theorem, module by module.
find "${ROOTS[@]}" \( "${PRUNE[@]}" \) -prune -o -type f \( -name lakefile.lean -o -name lakefile.toml \) -exec dirname {} + 2>/dev/null \
  | sort -u > "$OUT/lake-projects.txt"
i=0
while read -r P; do
  i=$((i + 1)); D="$OUT/lake-project-$i"; mkdir -p "$D"; echo "$P" > "$D/path.txt"
  echo "--- lake project $i: $P"
  (
    cd "$P" || exit
    cat lean-toolchain > "$D/lean-toolchain.txt" 2>/dev/null
    if grep -qs '"name": *"mathlib"' lake-manifest.json || grep -qsi mathlib lakefile.lean lakefile.toml; then
      lake exe cache get > "$D/cache-get.log" 2>&1; echo "exit=$?" >> "$D/cache-get.log"
    fi
    lake build > "$D/lake-build.log" 2>&1; echo "exit=$?" >> "$D/lake-build.log"
    echo "lake build: $(tail -1 "$D/lake-build.log") warnings=$(grep -c '^warning' "$D/lake-build.log") errors=$(grep -c '^error' "$D/lake-build.log")"
    : > "$D/axioms.txt"
    find . \( -name .lake -o -name .git \) -prune -o -type f -name '*.lean' ! -name lakefile.lean -print | sed 's|^\./||' | sort |
    while read -r f; do
      mod="${f%.lean}"; mod="${mod//\//.}"
      sed "s|@@MODULE@@|$mod|g" "$TOOLS/Axioms.lean.in" > /tmp/axioms-probe.lean
      echo "=== module $mod ($f)" >> "$D/axioms.txt"
      lake env lean /tmp/axioms-probe.lean >> "$D/axioms.txt" 2>&1 || echo "(axiom collection failed for $mod)" >> "$D/axioms.txt"
    done
    grep -E 'AXIOMS' "$D/axioms.txt"
  )
done < "$OUT/lake-projects.txt"

# Standalone Lean files (not inside a Lake project): compile, then axioms per theorem by
# appending a command that lists every theorem declared in the file itself.
: > "$OUT/lean-standalone.txt"
while read -r f; do
  inproj=0
  while read -r P; do case "$f" in "$P"/*) inproj=1;; esac; done < "$OUT/lake-projects.txt"
  [ $inproj = 1 ] && continue
  {
    echo "=== $f"
    echo "--- lean (as written)"
    (cd "$(dirname "$f")" && lean "$f" 2>&1); echo "exit=$?"
    echo "--- axioms per theorem"
    { echo "import Lean"; cat "$f"; echo; cat "$TOOLS/AxiomsLocal.lean.in"; } > /tmp/axioms-local.lean
    (cd "$(dirname "$f")" && lean /tmp/axioms-local.lean 2>&1 | grep -E 'AXIOMS|error') ; echo "exit=$?"
  } >> "$OUT/lean-standalone.txt"
done < "$OUT/lean-files.txt"
[ -s "$OUT/lean-standalone.txt" ] && cat "$OUT/lean-standalone.txt"

# ---------------------------------------------------------------- TLA+
section "TLA+"
list -name '*.tla' -o -name '*.cfg' > "$OUT/tla-files.txt"
echo "tla/cfg files: $(wc -l < "$OUT/tla-files.txt")"
: > "$OUT/tla-settings.txt"
while read -r f; do
  case "$f" in
    *.cfg)
      { echo "=== $f"; cat "$f"; echo; } >> "$OUT/tla-settings.txt" ;;
    *.tla)
      { echo "=== $f (CONSTANT/ASSUME/SYMMETRY lines)"; grep -nE '^\s*(CONSTANTS?|ASSUME|ASSUMPTION|AXIOM|SYMMETRY|VIEW)\b' "$f"; echo; } >> "$OUT/tla-settings.txt" ;;
  esac
done < "$OUT/tla-files.txt"
[ -s "$OUT/tla-settings.txt" ] && cat "$OUT/tla-settings.txt"
# Re-run TLC with default settings for every spec that has a same-named .cfg
# (the agent's own commands and flags are listed separately from the transcript).
: > "$OUT/tlc-rerun.txt"
grep '\.tla$' "$OUT/tla-files.txt" | while read -r t; do
  c="${t%.tla}.cfg"
  [ -f "$c" ] || { echo "=== $t: no same-named .cfg; not re-run" >> "$OUT/tlc-rerun.txt"; continue; }
  {
    echo "=== $t with $(basename "$c")"
    echo "\$ tlc -workers 1 -config $(basename "$c") $(basename "$t")"
    (cd "$(dirname "$t")" && timeout 1800 tlc -workers 1 -metadir /tmp/tlc-meta -config "$(basename "$c")" "$(basename "$t")" 2>&1); echo "exit=$?"
  } >> "$OUT/tlc-rerun.txt"
done
[ -s "$OUT/tlc-rerun.txt" ] && grep -E '^===|states generated|depth of the complete|Model checking completed|Error:|Invariant .* is violated|exit=' "$OUT/tlc-rerun.txt"

# ---------------------------------------------------------------- Z3
section "Z3"
{ list -name '*.smt2' -o -name '*.smt'; list -name '*.py' | xargs -r grep -lE '^\s*(from z3|import z3)'; } | sort -u > "$OUT/z3-files.txt"
echo "z3 files: $(wc -l < "$OUT/z3-files.txt")"
: > "$OUT/z3-rerun.txt"
while read -r f; do
  {
    echo "=== $f"
    case "$f" in
      *.py) echo "\$ timeout 600 python3 $f"; (cd "$(dirname "$f")" && timeout 600 python3 "$f" 2>&1); rc=$? ;;
      *)    echo "\$ timeout 600 z3 $f"; (cd "$(dirname "$f")" && timeout 600 z3 "$f" 2>&1); rc=$? ;;
    esac
    echo "exit=$rc$([ $rc = 124 ] && echo ' (timeout)')"
  } >> "$OUT/z3-rerun.txt"
done < "$OUT/z3-files.txt"
if [ -s "$OUT/z3-rerun.txt" ]; then
  grep -E '^===|exit=' "$OUT/z3-rerun.txt"
  echo "--- result tokens (sat/unsat/unknown) per file"
  awk '/^=== /{f=$2} /^(sat|unsat|unknown)$/{c[f" "$1]++} END{for(k in c) print c[k], k}' "$OUT/z3-rerun.txt" | sort -k2
fi

# ---------------------------------------------------------------- enumeration / tests
section "Scripts (enumeration, tests)"
list -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.py' -o -name '*.sh' \
  | grep -v '^/home/dev/jsdoctypeparser/\(lib\|bin\|peg_lib\|peg_src\|schemas\|tests\|index.js\|coverage\)' > "$OUT/script-candidates.txt"
# coverage/ is the nyc report written by `npm test`, not a script by the agent.
# Keep only files that are new or changed relative to the pinned commit (files the agent committed
# count as new); all of /tmp and the rest of home are kept.
# The pinned commit: the recreated one (preregistration.md, 12.) or, for series-1 runs, the upstream one.
BASE=d395aa070e17b600969e18139e43ace2fbe2f78f
git -C /home/dev/jsdoctypeparser cat-file -e "$BASE^{commit}" 2>/dev/null || BASE=5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb
: > "$OUT/scripts.txt"
while read -r f; do
  case "$f" in
    /home/dev/jsdoctypeparser/*)
      rel="${f#/home/dev/jsdoctypeparser/}"
      git -C /home/dev/jsdoctypeparser cat-file -e "$BASE:$rel" 2>/dev/null \
        && git -C /home/dev/jsdoctypeparser diff --quiet "$BASE" -- "$rel" && continue ;;
  esac
  echo "$f	$(node "$TOOLS/classify.js" "$f" 2>/dev/null || echo 'model or other')" >> "$OUT/scripts.txt"
done < "$OUT/script-candidates.txt"
cat "$OUT/scripts.txt"
: > "$OUT/scripts-rerun.txt"
cut -f1 "$OUT/scripts.txt" | grep -E '\.(js|mjs|cjs)$' | while read -r f; do
  { echo "=== $f"; echo "\$ timeout 600 node $f"; (cd "$(dirname "$f")" && timeout 600 node "$f" 2>&1 | tail -50); echo "exit=$?"; } >> "$OUT/scripts-rerun.txt"
done
[ -s "$OUT/scripts-rerun.txt" ] && cat "$OUT/scripts-rerun.txt"
echo
echo "audit done"
