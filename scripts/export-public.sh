#!/usr/bin/env bash
# Copies the harness into a new directory as a fresh git repository (files staged, not committed)
# for publication. Third-party text fetched by scripts/fetch-playbook.sh, runs/ and .secrets/
# are left out. The local commit history is not carried over; LOCAL_HISTORY.md lists it
# (hash, date, subject) so that commit hashes cited in the documents can be looked up.
# Usage: scripts/export-public.sh OUT_DIR   (OUT_DIR must not exist)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?usage: export-public.sh OUT_DIR}"
[ ! -e "$OUT" ] || { echo "$OUT already exists" >&2; exit 1; }
EXCLUDE='^(prompts/playbook-2133eced\.md|prompts/b\.txt|runs/.*|\.secrets/.*)$'

cd "$ROOT"
mkdir -p "$OUT"
git ls-files -co --exclude-standard | grep -vE "$EXCLUDE" | while read -r f; do
  [ -e "$f" ] || continue
  mkdir -p "$OUT/$(dirname "$f")"; cp -p "$f" "$OUT/$f"
done

{
  echo "# ローカルの履歴"
  echo
  echo "公開したリポジトリは、作成時の内容を1つのコミットにしたものである。"
  echo "それ以前の履歴はローカルにだけあり、公開していない。"
  echo "文書中で参照しているコミットのハッシュは、下の一覧で日時と内容を確かめられる。"
  echo "日時はローカルの記録であり、第三者が検証できるものではない。"
  echo
  echo "| コミット | 日時 | 内容 |"
  echo "|---|---|---|"
  git log --reverse --date=iso-strict --format='| `%h` | %ad | %s |'
  echo
  echo "書き出し時点の HEAD：\`$(git rev-parse HEAD)\`$(git diff --quiet HEAD && [ -z "$(git ls-files -o --exclude-standard)" ] || echo '（未コミットの変更を含めて書き出した）')"
} > "$OUT/LOCAL_HISTORY.md"

if grep -rIlE --exclude=export-public.sh '[A-Za-z0-9._%+-]+@(gmail|yahoo|outlook|icloud)\.|sk-ant-[A-Za-z0-9]' "$OUT"; then
  echo "possible personal data or credentials in the files above; check before publishing" >&2; exit 1
fi
git -C "$OUT" init -q -b main
git -C "$OUT" add -A
echo "exported to $OUT (staged, not committed)"
git -C "$OUT" status --short | wc -l
