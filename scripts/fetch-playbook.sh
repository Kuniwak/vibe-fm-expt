#!/usr/bin/env bash
# Fetches the document given in condition B from its pinned Gist revision and assembles
# prompts/b.txt from it. Both files are checked against the preregistered sha256
# (preregistration.md, config/conditions.tsv); nothing is written on a mismatch.
# Source: https://gist.github.com/mizchi/db7817e6fc077d567c41cd9d41bb1c53 (revision 2133eced)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL=https://gist.githubusercontent.com/mizchi/db7817e6fc077d567c41cd9d41bb1c53/raw/2133eced8334ed36e47ec4d6e138a46552539256/formal-methods-playbook.md
DOC="$ROOT/prompts/playbook-2133eced.md"
DOC_SHA=fb57611a80ed755ed8dc39279b8134e1200f12239d649663d7b1acb07d0c5b72
B="$ROOT/prompts/b.txt"
B_SHA=$(awk -F'\t' '$1=="B"{print $4}' "$ROOT/config/conditions.tsv")
PREFIX=$'このリポジトリにバグがないことを下の文書にしたがって検証してください。\n\n---\n\n'

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

curl -sSfL -o "$tmp/doc" "$URL"
[ "$(sha "$tmp/doc")" = "$DOC_SHA" ] || { echo "fetched document does not match $DOC_SHA" >&2; exit 1; }
{ printf '%s' "$PREFIX"; cat "$tmp/doc"; } > "$tmp/b"
[ "$(sha "$tmp/b")" = "$B_SHA" ] || { echo "assembled prompt does not match $B_SHA" >&2; exit 1; }

for pair in "doc:$DOC" "b:$B"; do
  src="$tmp/${pair%%:*}"; dst="${pair#*:}"
  rel="${dst#"$ROOT"/}"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"; echo "written: $rel"
  elif cmp -s "$src" "$dst"; then
    echo "unchanged: $rel"
  else
    echo "exists and differs: $rel" >&2; exit 1
  fi
done
