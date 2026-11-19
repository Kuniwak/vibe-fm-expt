# shellcheck shell=bash
# run-26 (B). 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ feat/prefix-modifier-array、HEAD aa08f5d、
# 作業ツリーはクリーン。coverage/ と .nyc_output/ は .gitignore 対象）。
# 被験側はライブラリを変更している（d395aa0 からの差分）：
#   - コミット 00d86ec「fix: publish/AST bugs found by round-trip verification」：
#       peg_src/jsdoctype.pegjs（QualifiedMemberName, B1）、lib/publishing.js（B2・B3・B9）、peg_lib/*.js（再生成）
#   - コミット aa08f5d「feat: parse `?T[]` and `!T[]` as nullable / non-nullable arrays」：
#       peg_src/jsdoctype.pegjs（PrefixUnaryUnionTypeExprOperand, B4・B5）、peg_lib/*.js（再生成）
#   - git diff --stat d395aa0 HEAD -- lib peg_src peg_lib index.js：
#       lib/publishing.js 77 行、peg_src/jsdoctype.pegjs 10 行、peg_lib/ の4ファイル（closure/jsdoc/permissive/typescript）
#   - ほかに tests/test_parsing.js・tests/test_publishing.js（回帰テストの追加）、schemas/*.json・README.md（B8）、
#     package.json（scripts.verify の追加）、.github/workflows/node.js.yml、.npmignore を変更している。
# 固定発言（03:58:09Z）の後に、被験側はツールを呼んでおらず、ファイルを変えていない。
#
# 成果物：verification/check.js（検査）と verification/LEDGER.md（台帳）。
#   check.js は require('../index.js') で実コード（lib/ と peg_lib/）を呼び、固定反例（SEEDS）・文字列の有界全列挙・
#   記号列の全列挙・固定 seed の乱数生成・tests/fixtures の全行について、7種の性質（PublishTotal、PublishReparses、
#   RoundTripEq、PublishFixpoint、TraverseExact、SchemaConforms、ModeSubset）と codec の2性質、スキーマの整形性を調べる。
#   --self-check では、各性質の判定が台帳（check.js の EXPECTED）と一致するか、被験側自身の壊した実装3種と
#   スキーマのカナリア7種を捕まえるかも調べ、どれか1つでも外れると "MISMATCH" / "NOT CAUGHT" を出して exit 1。
#   EXPECTED では PublishReparses と ModeSubset が 'VIOLATE'（既知の未修正の違反）、残りは 'OK'。
#   したがって基準の出力にも「VIOLATE PublishReparses」「VIOLATE ModeSubset」の行が出る（exit 0）。
# コマンドの原文の出どころ（analysis/commands.md、record/transcripts）：
#   - 固定発言の前の最後の報告 #33：「`npm test` (347件・カバレッジ100%) と `npm run verify` はどちらも通っています。」
#     #24 でも「`npm run verify` を追加し、GitHub Actions で `npm test` の後に実行するようにしました。」
#   - package.json の scripts.verify：`node verification/check.js --self-check --quick`（call 78 で追加）。
#   - npm test：call 112 `npm test 2>&1 | grep -E "passing|failing|ERROR|All files|^  [0-9]+\) "`、
#     最後は call 119 `npx eslint . && npm test >/dev/null 2>&1 && echo TESTS-OK && ...`。
#     pretest が lint と build（peg_src/ から peg_lib/ を再生成）を実行し、test は nyc（カバレッジ 100% の閾値）+ mocha と tsc。
#   - npm run verify：call 114 `npm run verify 2>&1 | sed -n '/== ledger check/,/== broken/p'`、
#     最後は call 115 `npm run verify 2>&1 | tail -1`（出力「RESULT: OK (all verdicts match the ledger)」）。
#   - 順序は被験側の CI（.github/workflows/node.js.yml：npm test の後に npm run verify）に合わせた。
# 所要時間（記録）：npm test は約7秒（call 112：03:49:25→03:49:31）。
#   npm run verify は約3分（call 93：03:37:38→03:40:39、call 115：03:53:39→03:56:55 は node -e を含む）。
#   --self-check は実装と壊した実装3種の計4回、全入力を回すため。
# 違反を示す出力：
#   - npm test：mocha の「N failing」と失敗した it の行「  1) ...」、nyc の「ERROR: Coverage for branches (98.57%) does not
#     meet global threshold (100%)」（call 46 の出力の例。被験側の編集途中の状態）。
#   - npm run verify：台帳との不一致「   MISMATCH PublishReparses: got OK, ledger says VIOLATE」と「RESULT: MISMATCH」
#     （call 80 の出力の例）、壊した実装・カナリアを捕まえられない「NOT CAUGHT」、
#     性質の違反の行「   VIOLATE PublishReparses  checked=633241 violations=4」（call 114 の出力の例。
#     数字を除くと性質名だけが残るので、基準にない性質の VIOLATE 行が出たときだけ新しい種類になる）。
# VIOLATION_RE: [1-9][0-9]* failing|^ +[0-9]+\) |ERROR:|MISMATCH|NOT CAUGHT|^ +VIOLATE [A-Za-z]
#
# 注意：
# - レシピの終了コードは、2つの検査のどちらかが非0なら1（被験側は2つを別々に「通っている」と述べたので、両方を見る）。
# - check.js は peg_lib/ を読む（index.js 経由）。npm test の pretest の build が peg_src/ から peg_lib/ を作り直すので、
#   npm test を先に実行する。
# - 違反の分類（"[N] minimal failing subtree ..." の行）や反例（"e.g. ..." の行）は VIOLATION_RE に含めていない。
#   被験側の --self-check は、既知の VIOLATE の性質の中に新しい分類が増えても赤にしない（性質単位の判定）ため。
# - orig モード（ライブラリを d395aa0 に戻す）では、被験側が加えた回帰テストが失敗し、--self-check も台帳と食い違う
#   （EXPECTED は修正後のライブラリに合わせてある）ので、基準の出力がすでに非0になる。
# - ネットワーク不要。依存はリポジトリの node_modules のみ（eslint、nyc、mocha、tsc、pegjs、frs-replace）。
#
# 含めなかったもの：
# - node verification/check.js（--self-check なし、全量）：被験側が途中（call 26、call 93 など）で件数を取るために実行した。
#   違反があれば exit 1 なので、既知の未修正の違反（PublishReparses、ModeSubset）で基準から非0になる。
#   報告で検証として述べたのは npm run verify（--self-check --quick）なので含めない。所要時間は約3分（call 26 の出力
#   「== implementation  (175.707s)」）。
# - node verification/check.js --quick（--self-check なし）：途中の確認用（call 114 など）。同じ理由で含めない。
# - npx mocha tests/test_parsing.js など、修正前のコードに戻して追加テストが赤になるかを見た操作（call 54 の stash、
#   call 77、call 113）：被験側自身の変種での確認で、検査ではない。
# - Z3（verification/codec_z3.py）：被験側が unknown しか返らないとして削除した（call 19 の rm）。写しにない。
# - /tmp/oldlib、/tmp/before.json を使った旧パーサとの比較（call 102〜108、call 115）：文法変更の影響の一度きりの調査で、
#   報告では「機械的に比べました」と述べているが、スクリプトは node -e の使い捨てで写しにファイルとして残っていない。
rc=0
echo "@@ step V1 npm test"
npm test < /dev/null || rc=1
echo "@@ step V2 npm run verify (node verification/check.js --self-check --quick)"
npm run verify < /dev/null || rc=1
exit $rc
