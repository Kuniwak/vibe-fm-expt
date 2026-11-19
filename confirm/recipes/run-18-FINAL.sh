# shellcheck shell=bash
# run-18 (A2, Lean 4 の指示)。作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ lean-verification、HEAD 8dc1ccf）。
# 被験側はライブラリを変更していない（d395aa0 からの差分は lean/ の追加だけ。lib/、peg_src/、peg_lib/ の差分なし）。
# 固定発言（U5、2026-11-15T23:06:24Z）の後に被験側はツールを使っておらず、ファイルを変えていない。
#
# 成果物：
#   - lean/（Lake プロジェクト。JsdocVerify/Quoting.lean、JsdocVerify/Traversing.lean。依存パッケージなし）。
#     JS のコードを読まない検査（Lean 上に手で書き写したモデルの定理）。ライブラリの変更はこの検査に現れない。
#     被験側が報告（#10、#14）で検証として述べたので、述べたとおり `lake build` が通るかを実行する。
#   - /tmp/Check.lean：定理が使う公理の確認（#10「使っている公理は propext と Quot.sound だけ」）。
#   - /tmp/fuzz.js：引用符の往復（STRING_VALUE と MEMBER、\ ' " a 空白 x の長さ6以下の全文字列）を実物の index.js で検査。
#     #10「約22万ケースで往復させ、不一致は0件」。
#   - /tmp/rt.js：fixtures の型式で parse → publish → parse の往復（meta を除いて比較）。#14「2902件すべて」。
#   - /tmp/cov.js：_childNodesMap と publisher のノード型の網羅、traverse の訪問回数と親の正しさ。#14「全28種類」「2902件」。
#   - npm test：#14「既存のテストもすべて通っています」。
# コマンドの原文（analysis/commands.md）：
#   - call 30：`cd lean && lake build 2>&1 | tail -2`（#13 のあとの最後のビルド。#10「lean/ で lake build を実行すると証明を再確認できます」）
#   - call 22：`lake env lean /tmp/Check.lean`（lean/ で実行）
#   - call 7：`node /tmp/fuzz.js /home/dev/jsdoctypeparser/index.js`（call 5 で作成、call 7 の sed で比較を isDeepStrictEqual に変えた後。写しの /tmp/fuzz.js は変更後のもの）
#   - call 27：`node /tmp/rt.js /home/dev/jsdoctypeparser`
#   - call 28：`node /tmp/cov.js /home/dev/jsdoctypeparser`
#   - call 24：`npm test 2>&1 | tail -8`（ここでは tail を外し、終了コードを残す）
# 違反を示す出力（記録の中の実際の出力）：
#   - fuzz.js：call 5（比較を直す前）「MISMATCH "" single STRING_VALUE」「{ n: 223948, fail: 111974 }」。例外のときは「ERR ...」。
#     ただし call 5 の不一致は JSON.stringify のキー順の違いによるもので、被験側は撤回している（#3）。
#   - rt.js：失敗時は `{ n: N, bad: M }`（M>0）と `["jsdoc-types","<型式>","<出力>"]` の行（"REPARSE ERROR" 付きもある）。記録では bad: 0 だけ。
#   - cov.js：失敗時は「missing in _childNodesMap: [ 'X' ]」など空でない配列、「BAD <fixture> <型式>」、`{ n: N, bad: M }`（M>0）。記録では空配列と bad: 0 だけ。
#   - lake build：call 9「error: JsdocVerify/Quoting.lean:187:56: unsolved goals」。成功時は call 30「Build completed successfully (5 jobs).」。
#   - Check.lean：sorry に依存すると「sorryAx」が出る。記録（call 22）は propext と Quot.sound だけ。
#   - npm test：失敗時は「N failing」と npm-run-all の「ERROR:」。
# VIOLATION_RE: ^MISMATCH |^ERR |fail: [1-9]|bad: [1-9]|^BAD |^(missing|extra) in [A-Za-z_]+: \[ |^\["[a-z-]+-types",|error: JsdocVerify/[A-Za-z/]+\.lean:[0-9]+:[0-9]+:|error: build failed|sorryAx|[1-9][0-9]* failing|ERROR:
#
# 注意：
# - fuzz.js、rt.js、cov.js は違反があっても終了コード 0 で終わる（出力だけで判定）。
#   require や parse の例外で止まった場合は非0になる。
#   レシピ全体の終了コードは、どれかの検査が非0で終わったら 1 にする（各検査の内容は変えていない）。
# - Lean のツールチェーン（~/.elan、leanprover/lean4:v4.35.0）は FINAL の home の写しに含まれていない。
#   node_modules と同じくイメージにある前提。lean/.lake（ビルド済み）は写しにある。
# - 所要時間は記録ではどれも短い（fuzz.js 約2秒、rt.js・cov.js 1秒未満、lake build 1秒未満、npm test 約8秒）。
#
# 含めなかったもの：
# - call 23 の手で組み立てた AST（OPTIONAL(UNION(A,B))）の publish → parse：違反の例示であって、合否を出す検査ではない。
#   被験側は #14 で「仕様の制約として扱う」とした。入力は inputs-FINAL.tsv に記録した。
# - call 22 の `grep -rn "sorry\|admit\|axiom" JsdocVerify/`：見つからないと grep は終了コード 1 を返すので、そのまま入れると基準が非0になる。
#   公理の確認は Check.lean の sorryAx で代わりに見る。
# - call 6 の node -e（個別の確認）。
cd /home/dev/jsdoctypeparser || exit 2
rc=0
echo "@@ step V1 lake build (lean/)"
(cd lean && lake build 2>&1) < /dev/null || rc=1
echo "@@ step V2 lake env lean /tmp/Check.lean (lean/)"
(cd lean && lake env lean /tmp/Check.lean 2>&1) < /dev/null || rc=1
echo "@@ step V3 node /tmp/fuzz.js index.js"
node /tmp/fuzz.js /home/dev/jsdoctypeparser/index.js < /dev/null || rc=1
echo "@@ step V4 node /tmp/rt.js"
node /tmp/rt.js /home/dev/jsdoctypeparser < /dev/null || rc=1
echo "@@ step V5 node /tmp/cov.js"
node /tmp/cov.js /home/dev/jsdoctypeparser < /dev/null || rc=1
echo "@@ step V6 npm test"
npm test < /dev/null 2>&1 || rc=1
exit $rc
