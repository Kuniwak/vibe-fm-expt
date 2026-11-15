# shellcheck shell=bash
# run-16 (C2). 実行手順の案（被験側の最終的な検査を、被験側の手順どおりに実行する）。
# 作業ディレクトリ: /home/dev/jsdoctypeparser（被験側が残した verify/ を含む最終ツリー）。
#
# 成果物: verify/model_check.js（実コードの index.js を require し、決めた範囲の入力を全列挙して
#   PUBLISH, TRAVERSE, TYPEOF, RECORDKEY, TUPLE を検査する。被験側の呼び名は「有界網羅検査」）。
# コマンドの出どころ: #4「実行方法」の「node verify/model_check.js      # 検査」。
#   被験側が最終版を引数なしで実行したのは call 19（node verify/model_check.js; echo exit=$?）。
#   call 20 は lint 修正のみで、その後の版で audit の再実行（audit/scripts-rerun.txt）は exit=0、5性質とも PASS。
# 出力の形: 性質ごとに "PASS <名前>" / "FAIL <名前>" / "KNOWN <名前>" の行と、その下の "  counterexample: {...}" の行。
#   違反があると exit 1。KNOWN_MEMBER_NAME_NODE と KNOWN_SUFFIX_MODIFIER は変種なしでも出る既存の反例で、
#   --strict を付けない限り終了コードに影響しない（被験側の手順は --strict を付けない）。
#   KNOWN_* への振り分けは AST の特徴による（MEMBER.name がノード、または後置の ?/! を含む）ため、
#   変種の症状がそうした AST にだけ出る場合は FAIL ではなく KNOWN の見出しの反例数（"... and N more"）が変わる。
# VIOLATION_RE: ^FAIL [A-Z_]+
#
# 含めないもの:
# - verify/mutation_check.js（#4「node verify/mutation_check.js   # 変種による確認」、call 23）: 被験側自身の6変種を
#   リポジトリの写しに文字列置換で埋め込み、model_check.js の強さを確かめるもの。作業ツリーの検査ではないので含めない。
#   （置換前の文字列がちょうど1回現れないと例外で止まる。）
# - Lean、TLA+、Z3 の成果物: なし。
# - peg_lib/ の生成（npm run build）: 被験側は call 21 で実行したが、検査ではない。確認の環境側でビルドする前提とする。
node verify/model_check.js
