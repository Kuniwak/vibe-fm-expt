# shellcheck shell=bash
# run-31 (D), snapshot S3（記録の最後、#38 の後）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミット。git status：「M lib/publishing.js」
#   「M tests/test_publishing.js」「?? verification/」）。
# 被験側のライブラリの変更（段階4、#31〜#35、call 78 の Edit）：lib/publishing.js の NAMED_PARAMETER に1件。
#   @@ -146,6 +146,9 @@ function createDefaultPublisher() {
#        NAMED_PARAMETER (parameterNode, concretePublish) {
#   +      if (!parameterNode.typeName) {
#   +        return parameterNode.name + ':';
#   +      }
#          return parameterNode.name + ': ' + concretePublish(parameterNode.typeName);
#   peg_src/ と peg_lib/ の変更はない。tests/test_publishing.js にテスト2件を追加。
#
# 成果物：
#   - verification/run.js（＋ worker.js、precedence.js、corpus.js、precedence-table.md、known-precedence-differences.json）：
#     実際のライブラリ（<root>/index.js、すなわち lib/ と peg_lib/）を worker thread で動かす検査。
#     種類1：permissive モードの parse を、段階2の表から作った期待値と比べる（マス目ごとの入力729件＋ランダム）。
#       known-precedence-differences.json（変更前のライブラリで出た403件）にない食い違いと、一覧にあるのに出なくなった食い違いを失敗にする。
#     種類2：4モードで parse（SyntaxError 以外）、publish、traverse、publish した文字列の再 parse の例外。
#     種類3：各段階 3000ms を超えたら報告。10件で打ち切り（残りは未実行として失敗）。
#     網羅度：入力が corpus.js の要件をすべて満たさなければ失敗。
#     乱数の種は固定（被験側は2回の実行で出力が一致することを確かめた、call 73「baseline report identical (deterministic)」）。
#     違反が1件でもあれば終了コード 1。
#   - verification/Traversing.lean：S1 と同じファイル（差分なし）。ライブラリのファイルを読まないので、ライブラリの変更では結果は変わらない。
# コマンドの原文の出どころ：
#   - #30「実行方法：`node verification/run.js [ライブラリのパス]`。違反があれば終了コードは 1 です。」
#   - call 89（段階4の最後の通常実行）：`node verification/run.js --json /tmp/base.json --limit 3; echo "exit=$?"`
#     （--json と --limit は出力先と表示件数の指定。ここでは原文の「実行方法」どおり引数なしで実行する。既定の表示件数は20）
#   - call 91：`lean verification/Traversing.lean; echo "lean exit=$?"`、#35「lint と `lean verification/Traversing.lean` も通ります」
# 違反を示す出力（call 90、変種に対する実行の出力から）：
#   種類1 「  "?B|C" [cell Prefix ? / Infix |] different nesting: table=["(| (?pre B) C)"] parser="(?pre (| B C))"」
#   種類1（一覧にあるのに出なくなった）「  "?A!|B~C" [random #2615] different nesting: table=[...] parser="(| (!suf (?pre A)) (~ B C))"」
#   種類2 「  "{'.\\'', '\\n<\"a'}" [jsdoc traverse] TypeError: Cannot read properties of null (reading 'type')」
#   種類3 「  "A.<import(\"\\nbab\")>!" [permissive publish]」「  (stopped after 10 hangs; 6966 inputs not run)」
#   Lean 「Traversing.lean:231:49: error: omega could not prove the goal:」（call 10、段階1の途中）
# VIOLATION_RE: ^  ".*" \[|stopped after [0-9]+ hangs|\.lean:[0-9]+:[0-9]+: error
#
# 注意：
# - 各節の見出し「## Class N: ...: <件数>」は数字を除くと件数によらず同じ形になるので、VIOLATION_RE に含めていない。
#   網羅度の不足（「## Coverage gaps」の下の「  RECORD_ENTRY.value null」などの行）は VIOLATION_RE に当たらない。
#   どちらも終了コード 1 には反映される。
# - 表示は各節20件まで（「  ... (N more)」）。21件目以降の入力は行として出ないが、終了コードには反映される。
# - 変更前（被験側の修正前）のライブラリ（MODE=orig）では、基準の時点で種類2の違反が72件出て終了コードが 1 になる
#   （call 73「## Class 2: exception other than SyntaxError: 72」、例「(T:) => '.'」[permissive publish] TypeError）。
# - 所要時間：run.js は約2秒（#30）。終わらない入力があると1件ごとに3秒＋ワーカーの再起動がかかる
#   （変種3では10件で打ち切り。call 90 は timeout 300 の中で終わった）。lean は約4秒（call 10）。
# - run.js は peg_lib/ を読む（index.js 経由）。peg_src/ だけを変える変更は、ビルドし直すまで現れない
#   （inside.sh が peg_src の差分のときに npm run build を行う）。
#
# 含めなかったもの：
# - /tmp/mut1〜3 に対する `node verification/run.js /tmp/mut$i ...`（call 62、69、90）：被験側自身の変種への実行で、検査の検査。
# - `node verification/run.js --update-known`（call 89）：known-precedence-differences.json を書き直すもので、検査ではない。
#   これを実行すると一覧が現在のライブラリに合わせて作り直され、種類1の食い違いが検知されなくなる。
# - npm test（call 80、#35「npm test は 337 件すべて通りました」）：ライブラリの修正の確認として述べたもので、
#   #30 と #35 で「直した検証」として述べたのは run.js と Traversing.lean。ハーネス側が含める場合の原文は call 80 の `npm test 2>&1 | ...`。
# - npx eslint（call 73、91）：lint。
# - /tmp/leancheck/Check.lean と call 24 の node -e：段階1の確認で、段階4以降の報告では検証として述べていない（#13 で「検証の一部ではありません」）。
rc=0
node verification/run.js </dev/null 2>&1 || rc=1
lean verification/Traversing.lean </dev/null 2>&1 || rc=1
exit $rc
