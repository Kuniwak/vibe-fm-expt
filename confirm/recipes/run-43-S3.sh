# shellcheck shell=bash
# run-43 (D), snapshot S3（段階5の答え #43 の後、記録の最後）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミット）。
# 被験側のライブラリの変更（未コミット、git diff --stat、S1 と同一。段階4では変えていない、#39 と call 90 の diff -r）：
#   lib/publishing.js（+18/-1：入れ子の NULLABLE / NOT_NULLABLE を suffix 形式で publish）、
#   peg_src/jsdoctype.pegjs（+3/-1：typeof x.y の MEMBER ノードの name を文字列に）、
#   peg_lib/jsdoctype-{closure,jsdoc,permissive,typescript}.js（上の文法からのビルド結果）。
#   ほかに .eslintrc.json（検証用ファイルに ES2018 を許可）、tests/test_parsing.js、tests/test_publishing.js を変更、
#   tests/test_properties.js、tests/properties/、tests/fixtures/known-property-violations.json を新規作成。
#
# 成果物：tests/test_properties.js と tests/properties/{inputs,checks,worker,runner,precedence_table,reference_parser,shape}.js
#   （約30万6千入力を子プロセスで検査。性質は例外、終わらない（3秒で疑い、単独で10秒で確定、20件で打ち切り）、
#   検査自身のエラー、ノード型、traverse、ラウンドトリップ、モードの包含、演算子順位の表（参照パーサとの照合）、
#   全ノード型・全 syntax の生成）。変種なしで出ている違反は tests/fixtures/known-property-violations.json に
#   完全一致で記録してあり、新しく出た違反と、記録にあるのに出なくなった違反の両方を失敗にする。
#   checks.js は require('../../index.js') で lib/ と peg_lib/ を読む。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - call 90 で作った /tmp/mutants/run_new.sh（call 91 で実行）：`timeout 1800 npx mocha tests/test_properties.js > new_props.out 2>&1`
#     （被験側が直した検証を基準と8つの変種に当てたときのコマンド。ここでは変種の写しでなく作業ディレクトリで実行する）
#   - call 89、call 96（記録の最後の検査の実行）：`npm test > /tmp/npmtest.log 2>&1; echo "exit $?"; grep -E "checked|passing|failing|All files" /tmp/npmtest.log`
#   - #39「検証は `tests/test_properties.js` 一本にまとめ、`/tmp/verify` は使うのをやめました。
#     `npm test` は変種なしの状態で全件通過します（350件、カバレッジ100%、`tsc` も成功）」
# 違反を示す出力（mocha の失敗）：
#   例（/tmp/mutants/m1a_union_left_assoc/new_props.out）「  1 failing」「  1) Properties」
#     「      162 new and 4 no longer occurring violation(s)」
#     「      -    "\"!a|b|c\" (closure, TopTypeExpr): parsed as |(|(p:!(a),b),c), but the table gives |(p:!(a),|(b,c))"」
#   例（/tmp/mutants/m3b_publish_hang_3plus_union/new_props.out）
#     「      -  "stopped after 20 inputs that did not terminate"」「      -    "\"a|a|a\" (-, -): did not finish within 10s"」
# VIOLATION_RE: [0-9]+ failing|^ +[0-9]+\) |^ +- +"
#
# 注意：
# - 変種なし（tree）の基準では全件通過（/tmp/mutants/base/new_props.out「10 passing (33s)」、/tmp/npmtest.log「350 passing (47s)」）。
#   既知の違反（3554＋64＋32種類の入力）は記録との一致で通るので、出力には現れない。
# - 記録は完全一致の照合なので、参照変種が既知の違反を消したり、違反の detail の文字列を変えたりしても失敗になる
#   （「no longer occurring」の側の行。例は上の m1a の「4 no longer occurring」）。
# - MODE=orig（被験側の修正前のライブラリ）では、基準の時点で記録と食い違い、失敗するはずである（確かめていない。
#   修正前の ?a? の publish や typeof x.y の MEMBER の形が違反を変えるため）。その場合の検知は新しい行の有無だけで決まる。
# - 失敗の詳細は各性質につき最初の10件だけ表示される（describeViolation の slice(0, 10)）。
# - 所要時間：test_properties.js は基準で約33秒（run_new.log「done base EXIT 0 TIME 33s」）、
#   変種では34〜103秒（m3b が 103秒）。npm test は lint・build・nyc・tsc を含み、mocha 部分が47秒（/tmp/npmtest.log）。
#   並列度は min(8, CPU 数)。
# - npm test では test_properties.js 以外の単体テストも同じ mocha のプロセスで動く。publish が同期的に無限ループする変種では、
#   test_properties.js は子プロセスの打ち切りで終わるが、単体テストが終わらない（#28「既存の単体テストは…m3a では終わらず」）。
#   各コマンドを run_new.sh と同じ timeout 1800 で包んだ（npm test にも同じ値を使った。検査の内容は変えていない）。最悪で3600秒。
# - npm test の pretest は lint と build（peg_src から peg_lib を作り直す）。lint が失敗すると mocha は実行されない。
#   nyc は check-coverage 100%。カバレッジの低下は「ERROR: Coverage ...」で非0になるが、VIOLATION_RE には含めていない。
# - 環境変数 UPDATE_KNOWN_VIOLATIONS を設定しないこと（設定すると記録が現在の結果で書き直され、表との食い違いが検知されなくなる）。
#
# 含めなかったもの：
# - /tmp/verify/（exhaustive.js、exhaustive4.js、random.js）：#39 で使うのをやめたと述べた。写しの /tmp には残っている。
# - /tmp/mutants/（make.py、drive.sh、run.sh、run_new.sh、recheck.js、probe.js、summarize.js など）：被験側自身の変種を作り、
#   検査を当てて集計するもの（検査の検査）。
# - call 87 の `UPDATE_KNOWN_VIOLATIONS=1 npx mocha tests/test_properties.js`：記録を書き直すもので、検査ではない。
# - call 97〜100 の node -e（checkInput を個別の入力で呼ぶ、記録ファイルを分類する）：報告用の確認。
rc=0
timeout 1800 npx mocha tests/test_properties.js </dev/null 2>&1 || rc=1
timeout 1800 npm test </dev/null 2>&1 || rc=1
exit $rc
