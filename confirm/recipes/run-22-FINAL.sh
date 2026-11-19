# shellcheck shell=bash
# run-22 (A、A2)。作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、コミットなし。変更は作業ツリーのみ）。
# 被験側はライブラリを変更している（U2「お任せします」の後、#3〜#8 で4件を修正）：
#   - peg_src/jsdoctype.pegjs：QualifiedMemberName の MEMBER を `name: tokens[3].name, quoteStyle: 'none', hasEventPrefix: false` に（call 10）。
#   - peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js：上の再ビルド（call 11 の npm run build、以後 npm test の pretest）。
#   - lib/publishing.js：NULLABLE / NOT_NULLABLE（子が前置の ?/! なら後置で出す、isPrefixNullability）、
#     KEY_QUERY（被演算子の中の ?/! を WeakSet syntaxPreservedNodes で元の後置のまま出す、traverse を require）、
#     NAMED_PARAMETER（typeName が null なら `name:`）（calls 11、14〜16、19、23）。
#   - tests/test_parsing.js（1件）、tests/test_publishing.js（8件）に回帰テストを追加。
#   参照変種はこの変更後のツリーに当てることになる。
# 固定発言（U3、01:31:07Z）の後、被験側はツールを使っておらず、ファイルを変えていない（#9 は文章だけ）。
#
# 成果物（最後の報告 #8 で検証として述べたもの）：
#   - /tmp/verify/check.js：トークン40種を最大3個並べた全組み合わせ（区切りなし・空白区切り）と、
#     長さ4〜11のランダム入力 N 件を4モードで parse し、P1（parse は AST かそのモードの SyntaxError）、
#     P2（publish が例外を出さない）、P3（parse(publish(ast)) が meta を除いて同じ AST）、
#     P4（traverse の訪問回数がノード数と一致）を調べる。require(引数のパス) → index.js → lib/ と peg_lib/。
#     #8「性質ベースの検証（約850万回）でも違反は0件です」（2,000,000 件のランダムで total 8506076）。
#   - npm test：#8「すべてのテスト（344件）が通りました」「lint、カバレッジ100%、`tsc` の型チェックもすべて通っています」。
#     pretest で lint と build（peg_src → peg_lib）、test で nyc + mocha（check-coverage、branches/lines 100）と tsc。
# コマンドの原文（analysis/commands.md、最後の検証は call 23）：
#   - call 23：`npm test 2>&1 | grep -E "passing|failing|All files|error"; node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 2000000`
#   - call 20：`node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 1000000`（#6「I'll run the full verification once more on the final code.」）
#   レシピは call 23 に沿う。npm test は grep の絞り込みを外し、出力をそのまま出す（失敗したテストの名前が隠れないように）。
#
# 違反を示す出力：
#   - check.js：最後に JSON を1つ出す。違反があれば failures の下に「"<性質>:<モード>": [」の鍵と、
#     例（最大5件）の "s"、"info" が並ぶ。違反がなければ `"failures": {}`。
#     例（call 3）「  "P3-reparse:permissive": [」「    "s": "typeof b.c",」
#     例（call 21 の直前、call 20）「  "P2:permissive": [」「    "info": "TypeError: Cannot read properties of null (reading 'type')"」
#     記録の最後（call 23）は `"failures": {}`（基準では違反行なしの見込み）。
#   - npm test：mocha の「N failing」と「  1) ...」、nyc の「ERROR: Coverage for ...」、tsc の「error TS2345: ...」
#     （例：call 18「lib/publishing.js(233,16): error TS2345: Argument of type 'AstNode' is not assignable ...」）、
#     eslint の「  <行>:<列>  error  ...」。
# VIOLATION_RE: ^ +"P[0-9][-a-z]*:[a-z]+": \[|[1-9][0-9]* failing|^ +[0-9]+\) |ERROR:|error TS[0-9]+|^ +[0-9]+:[0-9]+ +error +[^ ]
#
# 注意：
# - 時間：check.js の 2,000,000 件は記録で約3分（call 23 は npm test と合わせて 01:27:25 → 01:30:29）。
#   1,000,000 件の call 20 は約1分半、call 3（200,000 件）は約28秒。npm test は十数秒。
# - check.js は Math.random を使い、シードを固定していない。全組み合わせの部分（トークン3個以下）は固定、
#   ランダム部分は実行ごとに変わる。call 20 で初めて当たった `( module: ) => ! new` のように、
#   ランダム部分の違反は実行によって出たり出なかったりする。
# - check.js は違反があっても終了コード 0（JSON を出すだけ）。traverse などが例外を投げると非0で止まる。
#   npm test は失敗で非0。レシピは各検査の非0を集めて終了コードにする。
# - npm test の pretest が peg_lib/ を peg_src/ から作り直すので、check.js は作り直した後の peg_lib/ を読む。
# - check.js の "s" の行（具体的な入力）は VIOLATION_RE に含めていない（鍵の行で足りるため、また乱数で変わるため）。
#
# 含めなかったもの：
# - /tmp/verify/check2.js、check3.js：check.js の中で被験側が自分の回避策（publisher の差し替え、MEMBER の正規化）を
#   当てたもの（calls 7、8）。ライブラリの検査ではなく、修正前に「残りのバグの有無」を見るためのもの。
# - calls 4、9、13、21、22 の `node -e ...`（個々の入力の確認）と `git stash` での元のコードとの比較。
# - call 2 の `npm test 2>&1 | tail -30`（変更前の基準確認）。最後の npm test（call 23）に含まれる。
echo "@@ step V1 npm test (lint, build, nyc+mocha, tsc)"
rc=0
npm test < /dev/null 2>&1 || rc=1

echo "@@ step V2 node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 2000000"
node /tmp/verify/check.js /home/dev/jsdoctypeparser 3 2000000 < /dev/null 2>&1 || rc=1

exit $rc
