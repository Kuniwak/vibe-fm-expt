# shellcheck shell=bash
# run-21 (A、A2)。作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、コミットなし）。
# 被験側はライブラリを変更していない（git status は `?? verification/` だけ。lib/、peg_src/、peg_lib/ の差分なし。
#   peg_lib/ は call 2 の npm test の再ビルドで書き直されたが、内容は HEAD と同じ）。
# 固定発言（U2、01:14:54Z）の後、被験側はツールを使っておらず、ファイルを変えていない（#7 は文章だけ）。
#
# 成果物（最後の報告 #6 で検証として述べたもの）：
#   - /tmp/fz/fuzz.js：実コード（index.js）での往復テスト。代表的な式 46 個 × 4 モードの
#     parse → publish → parse の一致と、引用符付き文字列のランダムな往復（20,000 回 × 2 種の引用符）。
#     #6「テストは代表的な式 46 個を 4 モードで試したものと、ランダムな引用符付き文字列の往復です」。
#   - verification/Escape.lean：エスケープと復元の Lean モデルと定理（lex_escape、decode_encode、roundtrip）。
#     JS のコードを読まない（モデルは手で書き写したもの）。#6「`sorry` は 0 件」「公理は propext と Quot.sound だけ」。
#   - /tmp/fz/diff.js と /tmp/fz/escape：Lean モデルを実行ファイルにしたもの（/tmp/fz/escape）と、
#     実際の JS（publish の STRING_VALUE、parse の文字列リテラル）を 30,000 ケースで比べる差分テスト。
#     #6「Lean のモデルを実行ファイルにし、実際の JS と 30,000 ケースで出力を比べました。不一致は 0 件です」。
# コマンドの原文（analysis/commands.md）：
#   - call 7：`cd /tmp && node /tmp/fz/fuzz.js /home/dev/jsdoctypeparser/index.js`
#   - call 16（最後の lean 実行。出力は空＝エラーなし）：`lean Escape.lean 2>&1 | grep -v '^Note\|^Hint\|linter\|^$' | head -60`
#     （作業ディレクトリは verification/。call 10 以降の cd なしの呼び出しは verification/ で実行されている）
#   - call 17：`cd /home/dev/jsdoctypeparser/verification; grep -c sorry Escape.lean; printf '#print axioms roundtrip\n#print axioms lex_escape\n' > /tmp/fz/ax.lean; cat Escape.lean /tmp/fz/ax.lean > /tmp/fz/EscapeAx.lean; lean /tmp/fz/EscapeAx.lean 2>&1 | grep -i axiom; lean -c /tmp/fz/Escape.c Escape.lean >/dev/null 2>&1; leanc -o /tmp/fz/escape /tmp/fz/Escape.c 2>&1 | tail -3; ls -la /tmp/fz/escape`
#   - call 18：`cd /tmp && node /tmp/fz/diff.js /home/dev/jsdoctypeparser/index.js /tmp/fz/escape`
#   レシピでは、パイプの grep/head による絞り込みを外し、出力をそのまま出す（判定に使う行が隠れないように）。
#
# 違反を示す出力：
#   - fuzz.js：失敗のあったタグごとに「<タグ> <件数> <例の JSON>」の行を出す。
#     例（call 7）「struct-closure 3 [["typeof A.B","typeof A.{ type: 'NAME', name: 'B' }","Expected [ \\t], ...」
#     「struct-jsdoc 2 [["A?","?A","Expected values to be strictly deep-equal:"],["A!","!A",...]]」
#     基準の状態でもこの4行（struct-closure/typescript/permissive/jsdoc）が出る。数字を除いた形には例の JSON も
#     含まれるので、変種で新しい失敗が増えたり例が変わったりすると新しい種類の行になる。
#     ランダム部分のタグ（member、string、external、module、record、*-raw）は記録では失敗 0 件（行が出ない）。
#   - lean：「Escape.lean:<行>:<列>: error...」（例：call 13「Escape.lean:69:78: error: unsolved goals」）。
#     ただし Lean のモデルは JS を読まないので、ライブラリの変種では変わらない。
#   - diff.js：最後に「cases 30000 mismatches <n>」、不一致があれば最初の5件を「{"c":...」の JSON 行で出す。
#     記録（call 18）は「cases 30000 mismatches 0」。
# VIOLATION_RE: ^(struct-[a-z]+|member|string|external|module|record|member-raw|string-raw|record-raw) [0-9]+ \[|Escape(Ax)?\.lean:[0-9]+:[0-9]+: error|mismatches [1-9]|^\{"c":
#
# 注意：
# - fuzz.js と diff.js は Math.random を使い、シードを固定していない。実行ごとに入力が変わる。
#   fuzz.js の構造部分（46 個の式）は固定。
# - fuzz.js は publish(ast) を try の外で呼んでいるので、publish が例外を投げると止まり、非0で終わる。
#   diff.js も parse/publish の例外で止まる。終了コードは各検査の非0を集めてレシピの終了コードにする。
# - fuzz.js と diff.js は require に /home/dev/jsdoctypeparser/index.js を渡す（lib/ と peg_lib/ を読む）。
#   peg_src/ だけを変える変種は、inside.sh の再ビルドの後にだけ現れる。
# - /tmp/fz/escape は FINAL の写しにある。レシピは call 17 と同じく Escape.lean から作り直す
#   （leanc が失敗した場合は写しの /tmp/fz/escape がそのまま使われる）。
# - lean、leanc は /home/dev/.elan/bin（イメージの PATH に含まれる）。ネットワーク不要。
# - 所要時間はどれも短い（記録の時刻では fuzz.js 約4秒、lean 数秒、diff.js 約1秒）。
#
# 含めなかったもの：
# - npm test：被験側は call 2 で `npm test 2>&1 | tail -8` を実行したが、最後の報告 #6 では検証として述べていない
#   （「既存のテスト（カバレッジ 100%）」は固定発言の後の #7 にだけ現れる）。
# - call 8 の `node -e '...parse("typeof A.B",{mode:"typescript"})...'`：見つけたバグの確認で、検証としては述べていない。
# - call 10〜16 の途中の lean 実行：証明の修正中のもの。最後の状態（call 16、call 17）だけを含めた。

export PATH="/home/dev/.elan/bin:$PATH"
rc=0

echo "@@ step V1 node /tmp/fz/fuzz.js (round-trip fuzz)"
(cd /tmp && node /tmp/fz/fuzz.js /home/dev/jsdoctypeparser/index.js) || rc=1

echo "@@ step V2 lean Escape.lean"
(cd /home/dev/jsdoctypeparser/verification && lean Escape.lean 2>&1); r=$?
[ "$r" = 0 ] || rc=1

echo "@@ step V3 grep -c sorry / lean #print axioms / lean -c + leanc"
(
  cd /home/dev/jsdoctypeparser/verification || exit 2
  grep -c sorry Escape.lean
  printf '#print axioms roundtrip\n#print axioms lex_escape\n' > /tmp/fz/ax.lean
  cat Escape.lean /tmp/fz/ax.lean > /tmp/fz/EscapeAx.lean
  lean /tmp/fz/EscapeAx.lean 2>&1 | grep -i axiom
  lean -c /tmp/fz/Escape.c Escape.lean >/dev/null 2>&1
  leanc -o /tmp/fz/escape /tmp/fz/Escape.c 2>&1 | tail -3
  ls -la /tmp/fz/escape
)

echo "@@ step V4 node /tmp/fz/diff.js (Lean model vs JS)"
(cd /tmp && node /tmp/fz/diff.js /home/dev/jsdoctypeparser/index.js /tmp/fz/escape) || rc=1

exit $rc
