# shellcheck shell=bash
# run-41 (D, D2) 写し S1（段階1の終わり、2026-11-17T15:39:11Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、ブランチは固定コミットのまま）。
# 被験側のライブラリの変更：なし（lib/、peg_src/、peg_lib/、index.js は HEAD と同じ。未追跡は formal/ だけ）。
#
# 成果物（段階1の報告 #14 で検証として述べたもの）：
#   1. formal/（Lean 4 の Lake プロジェクト、JsDocType/{Ast,Traverse,Quote}.lean）。
#      JS のコードは読まない（Lean に書き写したモデルについての定理）。#14「formal/、lake build が成功」。
#      あわせて /tmp/ax.lean で #print axioms を表示し、sorry/admit/axiom を grep した（call 28）。
#      #14「全定理に sorry はなく、使っている公理は Lean 標準の propext と Quot.sound だけ」。
#   2. /tmp/rt.js：手で選んだ33入力 × 4モードで parse → publish → parse の往復（call 3）。
#      #14「手で選んだ33入力について、4モードで解析・出力・再解析の往復を試し、不一致はありませんでした」。
#      parse の例外は黙って飛ばす（catch { continue; }）。publish の例外は捕まえない（node が異常終了する）。
#   3. /tmp/model_check.js：publisher の網羅、引用符付き名前の往復（Math.random の2万個）、
#      実際の AST での traverse の親情報（call 29〜34 で入力を差し替えた最終版）。
#      #14「ランダムな文字列 2 万個で…」「traverse が渡す親情報…」「パブリッシャーが全ノード種別に対応…」。
#   4. 既存テスト `npm test`（call 35、36。「335 passing」）。#14「既存テストは 335 件すべて通過しています」。
# コマンドの原文：
#   - Lean：call 29 ほかの `lake build 2>&1 | tail -1`（formal/ で）、call 28 の `lake env lean /tmp/ax.lean` と
#     `grep -rn 'sorry\|admit\|axiom ' JsDocType JsDocType.lean`。
#   - rt.js：call 3 の `node /tmp/rt.js "$PWD/index.js"`。
#   - model_check.js：call 34 の `node /tmp/model_check.js /home/dev/jsdoctypeparser`。
#   - npm test：call 35、36 の `npm test 2>&1 | grep -E '[0-9]+ (passing|failing|pending)'`（ここでは grep で絞らない）。
#   - timeout の値は、被験側が段階3で「いまの検証（変更なし）」を実行するために書いた /tmp/verif/run.sh（call 40）に
#     合わせた（lake build 300秒、rt.js と model_check.js 120秒、テスト 300秒）。この run.sh は S1 の写しにはない。
# 違反を示す出力：
#   - rt.js：「[mode] 入力 -> 出力 : REPARSE ERROR」「… : AST MISMATCH」（記録では一度も出ていない。call 3 の出力は「done」だけ）。
#   - model_check.js：「publisher covers NodeType: false」「quote roundtrip failures: N」（N≠0）、
#     「traverse parent failures: N」（N≠0）、「parse error …」「mismatch …」。
#     基準の出力（call 34）：「publisher covers NodeType: true」「quote roundtrip failures: 0」「traverse parent failures: 0」。
#   - npm test：「N failing」（段階3の call 47 で変種に対し「4 failing」など）。
#   - Lean：「error: …」「error: build failed」（call 20 の失敗中のビルドで出た形）、#print axioms の「sorryAx」、
#     grep の「JsDocType/…:行:」。
# VIOLATION_RE: : (REPARSE ERROR|AST MISMATCH)$|^publisher covers NodeType: false|^quote roundtrip failures: [1-9]|^traverse parent failures: [1-9]|^parse error |^mismatch |[1-9][0-9]* failing|^error: |sorryAx|^JsDocType[^ ]*:[0-9]+:
#
# 注意：
# - どの検査も、違反を出しても終了コード0で終わる（rt.js、model_check.js は数を表示するだけ）。例外で止まったときと
#   npm test の失敗、timeout（124）のときだけ非0になる。下では各検査の終了コードの OR をレシピの終了コードにした。
#   段階3（call 47）で被験側は、変種 k2a のとき model_check.js が TypeError で異常終了したこと（exit=1）を
#   「検出」と数えている。
# - model_check.js の引用符の往復は Math.random を使うので、実行ごとに入力が違う。
# - rt.js と model_check.js は、終わらない変種では止まらない（call 47：k3b で両方とも120秒で打ち切り）。
# - npm test は pretest で lint と build（peg_src → peg_lib）を走らせる。lint は formal/ も対象になるが、S1 の formal/ に JS はない。
# - lake は ~/.elan/bin にある（call 1 の `which lean lake elan`：/home/dev/.elan/bin/…）。PATH に足した。
#   formal/.lake/build は写しにあり、依存パッケージはない（lake-manifest.json の packages は空）。
# - Lean の定理は JS を読まないので、ライブラリの変種では結果が変わらない（被験側も #20 で同じことを述べた）。
#
# 含めなかったもの：
# - /tmp/t.lean、/tmp/new.lean：証明を書く途中の試し（call 21、23）。検査ではない。
# - call 5、call 33 の node -e：手で入力を確かめただけ。報告で検証として述べていない。
export PATH="/home/dev/.elan/bin:$HOME/.elan/bin:$PATH"
rc=0
(cd formal && timeout 300 lake build 2>&1 | tail -1; exit "${PIPESTATUS[0]}") || rc=1
(cd formal && lake env lean /tmp/ax.lean 2>&1) || rc=1
(cd formal && grep -rn 'sorry\|admit\|axiom ' JsDocType JsDocType.lean)
timeout 120 node /tmp/rt.js "$PWD/index.js" < /dev/null 2>&1 || rc=1
timeout 120 node /tmp/model_check.js /home/dev/jsdoctypeparser < /dev/null 2>&1 || rc=1
timeout 300 npm test < /dev/null 2>&1 || rc=1
exit $rc
