# shellcheck shell=bash
# run-12 (C2). 作業ディレクトリは /home/dev/jsdoctypeparser を想定する。
#
# 成果物：verification/smt.js（Z3。peg_src/jsdoctype.pegjs を直接読む）と
#         verification/bmc.js（実コードの有界網羅検査。peg_lib/*.js と lib/ を読む）。
# 被験側は README などの手順の文書を残していない。コマンドは次の原文に基づく。
#   - call 23: `time timeout 300 node verification/smt.js`（smt.js の最後の実行）
#   - call 25: `time node verification/bmc.js`（bmc.js の全性質の最後の実行。call 27 は P3 と X1 だけ）
#   - call 29: verification/mutants.js の evaluate()。変種を当てたコピーで
#     `npm run build --silent` を実行してから smt.js と bmc.js を実行する。
#     変種を当てたツリーで peg_lib を作り直す手順として、これだけを借りる。
#     （ビルドは node_modules 内の frs-replace と pegjs を使い、ネットワークは要らない。
#      ただし run-12 では7並列のビルドが完了しなかった。単独のビルドが通るかは確かめていない。）
#
# 含めないもの：
#   - verification/mutants.js：被験側の変種の検査の仕組み（自前の変種 M1〜M6 を一時コピーに当てて
#     smt.js と bmc.js を回す）。run-12 では完了せず（/tmp/mutants-run1.log は 0 バイト）、
#     audit の再実行も600秒で時間切れ（exit 124）。検査そのものは下の2つと同じなので含めない。
#   - Lean と TLA+ の成果物はない。
#
# 変種を当てない状態でも、bmc.js は X1 と P6b で FAILED を出し exit 1 になる（audit の再実行）。
#   X1  FAILED  counterexamples=8    （"(new:)=>new" などで publish が例外）
#   P6b FAILED  counterexamples=672  （"[...a,]" などが構文エラー）
# smt.js は変種なしで exit 0（P4/jsdoc は n/a、ほかは proved）。
# 検知の判定は、この基準と比べて新たに現れた FAILED/UNKNOWN/VACUOUS の行や反例で行う必要がある。
# bmc.js の実行時間は約2分（call 25 で real 1m52s）。
#
# VIOLATION_RE: ^\S+\s+(FAILED|UNKNOWN|VACUOUS)\b|Error
npm run build --silent
node verification/smt.js
node verification/bmc.js
