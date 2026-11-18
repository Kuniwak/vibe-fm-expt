# shellcheck shell=bash
# run-43 (D), snapshot S1（段階1の終わり、#12 の報告の時点）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミット）。
# 被験側のライブラリの変更（未コミット、git diff --stat）：
#   lib/publishing.js（+18/-1：入れ子の NULLABLE / NOT_NULLABLE を suffix 形式で publish、call 11）、
#   peg_src/jsdoctype.pegjs（+3/-1：typeof x.y の MEMBER ノードの name を文字列に、call 19）、
#   peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js（上の文法からのビルド結果）。
#   ほかに tests/test_parsing.js、tests/test_publishing.js に単体テストを追加し、tests/test_properties.js を新規作成。
#
# 成果物：
#   (a) tests/test_properties.js（リポジトリ内。29トークンを長さ3まで並べた全入力を4モード×全開始規則で parse し、
#       例外・不正なノード型・traverse の訪問漏れ・ラウンドトリップを検査。`keyof` を含む入力はラウンドトリップから除外。
#       既知の問題3件は it.skip）。require('../index.js') 経由で lib/ と peg_lib/ を読む。
#   (b) /tmp/verify/（写しの /tmp にだけある）：props.js（性質 P1〜P5）、exhaustive.js（41トークン長さ3の網羅）、
#       exhaustive4.js（25トークン長さ4の網羅）、random.js（文法に沿ったランダム生成、シード指定）。
#       第1引数のディレクトリを require する。違反は JSON の "violations" に出し、違反があっても終了コードは 0
#       （検査スクリプト自身が落ちたときだけ非0）。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - call 31：`npx eslint tests/test_properties.js && time npx mocha tests/test_properties.js 2>&1 | tail -20`
#   - call 26（段階1の /tmp/verify の最後の実行。6本を & で並列に実行）：
#       `for i in 1 2 3 4; do (node random.js /home/dev/jsdoctypeparser 150000 $i > r$i.json) & done`
#       `(node exhaustive.js /home/dev/jsdoctypeparser 3 > n3b.json) &`  `(node exhaustive4.js /home/dev/jsdoctypeparser > n4b.json) &`
#     （cd /tmp/verify の後）。ここでは JSON をファイルでなく標準出力に出し、順に実行する。
#   - call 33：`npm test 2>&1 | grep -E "passing|pending|failing|All files|error"`（段階1の最後に実行した検査）
#   - #9「検証スクリプトは `/tmp/verify/`（`props.js`、`exhaustive.js`、`exhaustive4.js`、`random.js`）にあります」
#     #12「`npm test`（lint・ビルド・カバレッジ・型検査）は344件通過、3件 pending」「追加したもの：`tests/test_properties.js`」
#     #28（段階3）「ここでいう「いまの検証」は、…`tests/test_properties.js`…と、`/tmp/verify` の6本（長さ3の網羅、長さ4の網羅、ランダム生成4シード）」
# 違反を示す出力：
#   - mocha の失敗。例（/tmp/mutants/m2a_parse_crash_empty_tuple/props.out、被験側の変種で S1 版の test_properties.js を実行したもの）
#     「  1 failing」「  1) Properties (bounded exhaustive)」
#     「      -  "\"[\" (permissive, TopTypeExpr): TypeError: Cannot read properties of null (reading 'type')"」
#     例（call 32、修正前のライブラリに戻して実行）「    1) should reparse a published AST to the same AST」「  1 failing」
#   - /tmp/verify の JSON の違反。例（/tmp/verify/n3b.json、変種なし）
#     「   "prop": "P3-roundtrip-reparse",」「     "s": "keyof a ?",」
#   - /tmp/verify の検査スクリプト自身の異常終了。例（/tmp/mutants/m2a_parse_crash_empty_tuple/v_n3.json）
#     「TypeError: Cannot read properties of undefined (reading 'ok')」（props.js:68）
# VIOLATION_RE: [0-9]+ failing|^ +[0-9]+\) |^ +- +"|"prop": "P[0-9]|^ +"s": |^[A-Za-z]*Error:
#
# 注意：
# - 変種なし（tree）の基準の時点で、/tmp/verify は違反を出す（keyof の再パース失敗、?[] のモード間の食い違い、
#   function(): X?[] のラウンドトリップ）。数字を除いた形で比べるので、基準と同じ "prop"/"s" の行は検知に数えない。
#   出力は各分類の最初の5例だけなので、新しい違反が既存の分類に加わっても、その5例に入らなければ行として現れない。
# - MODE=orig（被験側の修正前のライブラリ）では、基準の時点で test_properties.js のラウンドトリップが失敗する
#   （call 32「AssertionError: expected [ Array(280) ] to deeply equal []」）。npm test も call 12/19/23/25 で追加した
#   単体テストが失敗するはずである（確かめていない）。
# - 所要時間：test_properties.js は約14秒（call 31「real 0m14.116s」）。npm test は lint・build・nyc・tsc を含み、S1 の時点の所要時間は記録から読み取れなかった
#   （S3 の npm test では mocha 部分が「350 passing (47s)」、/tmp/npmtest.log）。
#   /tmp/verify は段階3の基準で n3 48秒、n4 113秒、r1〜r4 各32〜34秒（/tmp/mutants/base/v_*.status。並列実行時の値）。
# - 終わらない入力に対する入力ごとの制限時間は、被験側の検査にない（#28「入力ごとの時間制限はどの検証にもありません」）。
#   publish が同期的に無限ループする変種では mocha も node も終わらない（#28 の m3a）。各コマンドを timeout 600 で包んだ。
#   600秒は被験側が自分の変種に同じ検査を当てたときの値（/tmp/mutants/run.sh の `T=${T:-600}`、`timeout $T npx mocha ...`、
#   `timeout $T node exhaustive.js "$D" 3` など）。検査の内容は変えていない。最悪で 600×8＝4800秒。
# - npm test の pretest は lint と build（peg_src から peg_lib を作り直す）。lint が失敗すると mocha は実行されない。
# - nyc は check-coverage 100%（package.json）。カバレッジが下がると「ERROR: Coverage for ...」で非0になるが、
#   その行は VIOLATION_RE に含めていない（終了コードには反映される）。
# - /tmp/verify の props.js は permissive の parse が SyntaxError 以外を投げると p.ok で落ちる（被験側が #28 で述べた不具合）。
#
# 含めなかったもの：
# - 被験側の変種（/tmp/mutants/、段階3以降に作成）は S1 の時点では存在しない。
# - call 32 の `git stash push ... && npx mocha ... ; git stash pop`：修正前のライブラリに戻して検査を当てたもの（検査の検査）。
# - call 6 と call 14 の /tmp/verify の実行：call 26 と同じスクリプトの、ライブラリ修正前の実行。
# - call 7、15、18、27 などの node -e：個別の入力を手で確かめたもので、検査として報告していない。
rc=0
timeout 600 npx mocha tests/test_properties.js </dev/null 2>&1 || rc=1
(cd /tmp/verify && timeout 600 node exhaustive.js /home/dev/jsdoctypeparser 3) </dev/null 2>&1 || rc=1
(cd /tmp/verify && timeout 600 node exhaustive4.js /home/dev/jsdoctypeparser) </dev/null 2>&1 || rc=1
for i in 1 2 3 4; do
  (cd /tmp/verify && timeout 600 node random.js /home/dev/jsdoctypeparser 150000 $i) </dev/null 2>&1 || rc=1
done
timeout 600 npm test </dev/null 2>&1 || rc=1
exit $rc
