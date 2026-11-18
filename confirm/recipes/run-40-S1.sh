# shellcheck shell=bash
# run-40 (D, D2) 写し S1（段階1の終わり、2026-11-17T13:27:52Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/formal-verification-findings、HEAD cb5b174、作業ツリーはクリーン）。
# 被験側はライブラリを変更している（コミット 4ff69f4）：
#   - peg_src/jsdoctype.pegjs：QualifiedMemberName の MEMBER.name を tokens[3].name にし、quoteStyle/hasEventPrefix を追加
#   - lib/publishing.js：NULLABLE/NOT_NULLABLE で meta.syntax が後置なら後置で出力、NAMED_PARAMETER で typeName が null のとき空文字
#   - peg_lib/*.js：上の文法から再生成したもの
#   - tests/test_parsing.js、tests/test_publishing.js：回帰テスト追加と既存の期待値3件の書き換え
# 参照変種はこの変更後のツリーに当てる。
#
# 成果物：verify/props.js（性質 P1〜P5 の判定）、verify/run.js（37 トークンの長さ N 以下の全列挙）、
#   verify/fuzz.js（フィクスチャ全件 179,360 件と、シード付きの変異ファジング）。コミット cb5b174 に含まれる。
#   require('..') でリポジトリの index.js（lib/ と peg_lib/）を読む。peg_src/ だけを変える変種は再ビルド後に効く
#   （inside.sh が peg_src の変更時に npm run build する）。
# コマンドの原文：
#   - commands.md call 48（段階1で最後の検証の実行、#16「最終コードで形式検証をすべてやり直します」）：
#     (node verify/run.js 4 > /tmp/r4.txt & for r in NamepathExpr BroadNamepathExpr ExternalNameExpr ModuleNameExpr; do node verify/run.js 3 $r > /tmp/r3_$r.txt & done; node verify/fuzz.js 400000 7 > /tmp/rf7.txt & node verify/fuzz.js 400000 42 > /tmp/rf42.txt & wait); grep -v '^    ' /tmp/r4.txt /tmp/r3_*.txt /tmp/rf*.txt
#     （末尾の git status / git diff は検査ではないので除いた）
#   - commands.md call 47：npm test 2>&1 | grep -E "passing|failing|problem|ERROR|All files|error TS" | head
#     #17「npm test（lint・カバレッジ100%・型検査を含む）は342件すべて通っています」、#21 の Test plan にも
#     「npm test: 342 passing ...」と「node verify/run.js 4 and node verify/fuzz.js 400000」を並べている。
#   - 所要時間：call 48 は 13:21:38 開始、#17 が 13:24:46（並列で約3分）。npm test は数秒〜十数秒（call 47）。
# 違反を示す出力：
#   - run.js / fuzz.js は違反があっても終了コード 0。違反は「<性質> [<モード>]: <件数>」の行と、その下の
#     4〜5 件の例（4 スペースで始まる JSON 行）で示される。
#     例（/tmp/n4.txt、段階1の途中）「P2-reparse-fails [permissive]: 918」
#        「    {"prop":"P2-reparse-fails","mode":"permissive","s":"?A?","out":"??A",...}」
#     例（/tmp/fuzz1.txt）「P1-publish-throws [permissive]: 184 {"fuzz":184}」
#     例（call 48 の出力、変種なしでも出る）「/tmp/r4.txt:P4-same-ast [jsdoc]: 8」
#   - npm test は「N failing」と「ERROR: "coverage" exited with 3.」など（commands.md call 45 の出力に「3 failing」「ERROR: "coverage" exited with 3.」）。
#   被験側の grep は例の行を隠すので、あとで各出力ファイルを全部表示し、例の行も VIOLATION_RE に含めた。
# VIOLATION_RE: (^|:)P[0-9]b?-[a-z-]+ \[[a-z]+\]: [0-9]+|^ +\{"prop":"P[0-9]|[1-9][0-9]* failing|ERROR:|error TS
#
# 注意：
# - 変種なしの基準の出力にも「P4-same-ast [jsdoc]: 8」（?[] がモードで別の AST）が出る（被験側は仕様上の論点とした）。
# - P5-time は parse が 500ms を超えたら違反とする時間依存の判定。7 本を並列に動かすので、負荷によっては
#   変種と無関係に出る可能性がある。
# - この時点の検査には 1 入力ごとの制限時間がない。parse/publish/traverse が終わらない変種では
#   run.js/fuzz.js が終わらず、wait から先に進まない（ハーネス全体の 5400 秒で打ち切られ、何も出力されない）。
#   被験側も段階3でこれを確かめている（#33 種類3）。被験側のコマンドには timeout がないので、ここでも付けない。
# - npm test は pretest で lint と build（peg_lib/ を peg_src/ から作り直す）を行う。peg_lib/ だけを変える変種を
#   消してしまうので、被験側の順序（npm test が先）と逆に、形式検査のあとに置いた。
#   npm test の build は frs-replace/pegjs で長くかかることがあるため、timeout 600 で囲んだ（被験側は付けていない）。
# - 終了コードは npm test のもの（run.js/fuzz.js はつねに 0）。
# - orig モード（ライブラリを固定コミットに戻す）では、被験側が書き換えたテストの期待値（Object! など）と
#   追加したテストが失敗するので、npm test は基準の時点で非0になる。
#
# 含めなかったもの：
# - /tmp/jtp での仮修正版の検査（call 18〜23）：一時コピーに対するもので、最後の検証ではない。
# - node verify/fuzz.js 200000 1（call 14）：段階1の途中のもの。最後の検証では 400000 7 と 400000 42 に置き換わった。
# - node -e による個別の確認（call 10、16、24、38、40）：検査ではなく、反例の確認。
node verify/run.js 4 > /tmp/r4.txt & for r in NamepathExpr BroadNamepathExpr ExternalNameExpr ModuleNameExpr; do node verify/run.js 3 $r > /tmp/r3_$r.txt & done; node verify/fuzz.js 400000 7 > /tmp/rf7.txt & node verify/fuzz.js 400000 42 > /tmp/rf42.txt & wait
grep -v '^    ' /tmp/r4.txt /tmp/r3_*.txt /tmp/rf*.txt
echo '### full outputs (the subject read the example lines with grep -A, e.g. call 38)'
for f in /tmp/r4.txt /tmp/r3_*.txt /tmp/rf7.txt /tmp/rf42.txt; do echo "== $f"; cat "$f"; done
timeout 600 npm test < /dev/null 2>&1 | grep -E "passing|failing|problem|ERROR|All files|error TS"
exit "${PIPESTATUS[0]}"
