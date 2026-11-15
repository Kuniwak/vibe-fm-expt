# shellcheck shell=bash
# run-11 (C, c1). 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ verify-lean-and-fixes、HEAD 7631d2d）。
# 被験側はライブラリを変更している（コミット c0c8565：lib/publishing.js と peg_src/jsdoctype.pegjs）。
# 参照変種はこの変更後のツリーに当てる（10.4）。
#
# 成果物：verify/verify.sh（Lake プロジェクト verify/ の Lean 定理 verify/JsdocVerify/Spec.lean）。
#   verify.sh は node gen/gen.js で peg_src/jsdoctype.pegjs と lib/*.js を Lean 用の JSON に変換し
#   （verify/JsdocVerify/Source.lean を生成）、lake build JsdocVerify で native_decide の定理を評価する。
#   ソースを変えると定理の真偽が変わるので、実コードと結びつく実行可能な検査として扱う。
# コマンドの原文：call 72 と call 76 の `verify/verify.sh 2>&1 | tail -1`。
#   verify/README.md の Usage「./verify.sh  # regenerate Source.lean and check every theorem」。
#   被験側の mutants.js も「detected = verify.sh の終了コードが 0 でない」で判定している。
# 違反を示す出力：lake build の失敗。
#   例（call 52）「error: JsdocVerify/Spec.lean:48:67: Tactic `native_decide` evaluated that the proposition」「error: build failed」
# VIOLATION_RE: error: JsdocVerify/Spec\.lean:[0-9]+:[0-9]+:|error: build failed
#
# 注意：
# - gen.js は対応外の JS 構文や正規表現に出会うと例外で止まる（「Error: unsupported ...」、exit 1）。
#   この場合は定理の失敗ではなく変換の失敗なので、上の VIOLATION_RE には含めていない。
#   終了コードだけで判定すると、これも「違反」に数えられる点に注意。
# - verify.sh が読むのは peg_src/ と lib/ だけで、ビルド済みの peg_lib/ は読まない。
#   参照変種が peg_lib/ だけを変える場合、この検査には現れない。
# - lake build は依存パッケージなし（lake-manifest.json の packages は空）、ネットワーク不要。
#   gen.js はリポジトリの node_modules の pegjs と espree を使う。
#
# 含めなかったもの：
# - node verify/gen/diff.js：Lean 上のモデルと実コードの一致を見る差分テスト。
#   変種は両方に同じく効くので、バグの検査ではない（被験側も「模型が実物と一致しているか」の確認と述べた、#11）。
# - node verify/gen/mutants.js：被験側自身の変種を当てて元に戻すスクリプト。参照変種の検査ではない。
#   置換前の文字列が見つからないと例外で止まる。
# - npm test：既存のテストに被験側が4件を加えたもの（call 68）。被験側は最後に `npm test </dev/null` を実行した（call 80）が、
#   最終報告 #28 で6種類の検証として述べたのは Lean の検証で、npm test は「the existing tests」と別に述べている。
#   ハーネス側が含めるかを判断する場合のコマンドの原文は call 80 の `npm test </dev/null`。
verify/verify.sh
