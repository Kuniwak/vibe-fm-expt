# shellcheck shell=bash
# run-23 (B). 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/formal-verification-findings、HEAD 238fc1e、未コミットの変更なし）。
# 被験側はライブラリを変更している（基点 d395aa0 からのコミット 2791df9 と 10b5fe3）：
#   - lib/publishing.js：NAMED_PARAMETER の型の省略で `a:` を出す。NULLABLE / NOT_NULLABLE の被演算子が
#     NULLABLE / NOT_NULLABLE のときは後置形で出す（isPrefixUnary）。
#   - peg_src/jsdoctype.pegjs：QualifiedMemberName の name を tokens[3].name（文字列）に、quoteStyle / hasEventPrefix を追加。
#     TypeNameExprJsDocFlavored の前に `!KeyQueryExpr // no-jsdoc, no-closure` の先読みを追加。
#   - peg_lib/*.js：上の peg_src から再生成したもの（4ファイル）。
#   ほかに tests/（回帰テスト追加）、verification/、package.json（scripts.verify / verify:node）、.npmignore、
#   .github/workflows/node.js.yml（npm run verify:node を追加）を変えている。
# 固定発言（2026-11-16T02:25:36Z）の後、被験側はツールを呼んでおらず、ファイルを変えていない（最後のツール呼び出しは 02:24:05 の call 79）。
#
# 成果物：verification/（未追跡ではなくコミット ed09693 / 238fc1e に含まれる）
#   - enumerate.js：parse / publish / traverse の有界全列挙（56,684 入力 × 4 モード）。require('..') で実コード
#     （index.js -> lib/ + peg_lib/）を回す。--check は不変条件ごとの期待判定（EXPECTED）との一致を見て、
#     不一致なら「  EXPECTED OK」などを出して exit 1。--broken は被験側自身の壊れ版 4 件が捕まるかを見る。
#   - escape_enum.js：quote 付き名前のエスケープを実コードで全列挙（|s|<=9）。--check で期待と違えば exit 1。
#   - escape_z3.py：エスケープの Z3 モデル（|s|<=5）。判定はモデルだけで決まり、JS は反例の再生（replay）でしか読まない。
#   - run.sh：上の 5 コマンドを set -e で順に実行する入口（npm run verify = sh verification/run.sh）。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - V1：call 8 の peg_lib 再ビルド比較（#15「ビルド成果物: peg_lib/ は peg_src/ からの再ビルドとバイト単位で一致」、
#     verification/README.md 36 行目の Contract、/tmp/pr_body.md の Test plan「Rebuilt peg_lib/ matches peg_src/」）。
#   - V2：call 60 / call 71 の `npm run verify >/tmp/run.log 2>&1`（#20「npm run verify で全検証が回ります」、
#     #25「npm run verify も期待どおりです」、#27「ローカルでは npm run verify で全部を実行できます」）。
#   - V3：call 70 の `npm test 2>&1 | grep ...`（#25「npm test は 344 件すべてパス、カバレッジ 100%」）。
#     npm test は pretest で lint と build（peg_lib/ の再生成）を走らせ、nyc mocha と tsc を実行する。
# 所要時間（記録）：npm run verify は約 2 分 40 秒（call 47 の time：real 2m41s）。うち Node 部分は約 1 分
#   （call 74 の npm run verify:node：real 0m57s）。npm test は 10 秒前後（call 70）。V1 は 1 秒未満（call 8）。
# 順序：V3 の npm test は pretest の build で peg_lib/ を peg_src/ から作り直すので、最後に置いた
#   （peg_lib/ だけを変える変種が V1・V2 に届くように）。被験側の検査の中身は変えていない。
# 終了コード：各ステップの失敗を集めて、1 つでも非 0 ならレシピ全体を exit 1 にする（ハーネス側の追加）。
#   V1 は被験側の原文どおり echo で終わるため、常に 0 で終わる（違反は DIFF の行でだけ現れる）。
#
# 違反を示す出力：
#   - enumerate.js / escape_z3.py の --check の期待との不一致：「  EXPECTED OK」「  EXPECTED VIOLATE」
#     （verification/enumerate.js 365 行目、verification/escape_z3.py 180 行目。記録の中には不一致の実例はない。
#     記録の最終実行 /tmp/run.log ではすべて「as expected」）。
#   - enumerate.js --check の「ModeSubset outside dialect conflicts: <入力の並び>」（none 以外。enumerate.js 378 行目）。
#   - escape_enum.js の「[VIOLATE] DecodeEncode ...」（期待は OK。EncodeDecode の [VIOLATE] は期待どおりで基準にも出る）。
#   - npm test：mocha の「N failing」と失敗の一覧「  1) ...」、tsc の「error TS....」、eslint の「✖ N problems」。
#     例（call 38 の eslint）「✖ 3 problems (3 errors, 0 warnings)」。例（call 70）「344 passing (4s)」が正常時。
#   - V1：「DIFF jsdoctype-<方言>.js」（正常時は「same jsdoctype-jsdoc.js」など、call 8）。
# VIOLATION_RE: EXPECTED (OK|VIOLATE)|ModeSubset outside dialect conflicts: (?!none)|^\[VIOLATE\] DecodeEncode|[1-9][0-9]* failing|^ +[0-9]+\) |error TS[0-9]+|✖ [0-9]+ problems?|^DIFF jsdoctype-
#
# 注意：
# - run.sh は set -e なので、enumerate.js --check が失敗するとそれ以降（--broken、escape_enum.js、Z3）は実行されない。
#   被験側の入口のとおりにしてある。
# - enumerate.js --broken は被験側自身の壊れ版の捕捉を見る自己検査。参照変種で基準の違反数が増えると
#   「MISSED」になり exit 1 になりうる（記録の例、call 35「MISSED  publisher no quote escaping (RoundTrip)」）。
#   これはコードの違反ではなく検査自体の判定なので VIOLATION_RE には入れていない（終了コードには現れる）。
# - escape_z3.py の判定は Z3 のモデルだけで決まり、lib/ や peg_src/ の変更は判定に届かない（反例の再生の出力だけが変わる）。
#   python3 と z3（記録では z3 5.3.3）を使う。ネットワーク不要。
# - orig モード（ライブラリを基点に戻す）では、被験側が tests/ に足した回帰テストが失敗し、npm test の基準が非 0 になる。
#   enumerate.js --check も基準で「EXPECTED OK」を出す。そのため orig では終了コードの 0→非0 では検知できず、新しい種類の行だけで判定される。
# - 標準入力は /dev/null。記録では npm test が止まった例はない。
#
# 含めなかったもの：
# - npm run verify:node（run.sh --node-only）：V2 の npm run verify の部分集合（Z3 を省くだけ）なので重複。
# - node verification/enumerate.js（引数なし）と --causes：期待判定を持たない一覧表示・原因の分類で、途中の調査用。
#   違反の一覧は inputs-FINAL.tsv に写した。
# - /tmp/probe.js（call 6）、/tmp/ms.js（call 15）、call 63 の node -e：手で入力を試す探り。報告で検証としては述べていない。
# - CI の Node 10 での実行：被験側は実行できなかった（#31〜#32）。
#
# ハーネス側の点検（2026-11-19）：最後の報告の読み方が決まりと前例から1つに決まらないため、読み方ごとにレシピを分けた
# （confirm/d-inputs/run-23/notes.md の末尾）。V1 peg_lib の再ビルド比較は、どの読み方でも外す（#15 にだけあり、引き継がれていない）。
# この版の読み方：#25 を結果を述べた最後の報告とする（npm run verify と npm test）。npm test は peg_lib を作り直すので後に置く。
fails=0
cd /home/dev/jsdoctypeparser || exit 2
echo "@@ step V2 npm run verify (sh verification/run.sh: enumerate --check/--broken, escape_enum --check, escape_z3 --check/--broken)"
npm run verify < /dev/null 2>&1 || fails=1
echo "@@ step V3 npm test (lint, build, nyc mocha, tsc)"
npm test < /dev/null 2>&1 || fails=1
exit $fails
