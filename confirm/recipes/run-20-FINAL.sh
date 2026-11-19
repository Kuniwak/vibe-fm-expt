# shellcheck shell=bash
# run-20 (B). 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ verify/spec-extraction、HEAD 3b4ea33、
# 親は d395aa0）。作業ツリーはコミット済みで、未コミットの変更はない（.nyc_output/ と coverage/ は npm test の生成物）。
# 被験側のライブラリの変更：なし（3b4ea33 の差分は verify/check.js、verify/escape.js、verify/LEDGER.md、
#   package.json に "verify" スクリプトを1行、.github/workflows/node.js.yml に1行。lib/、peg_src/、peg_lib/ は d395aa0 のまま）。
# 固定発言（U4、01:00:47Z）の後、被験側はツールを呼んでおらず、ファイルを変えていない（#20 は文章だけ）。
#
# 成果物：
#   - verify/check.js：fixtures の実コーパス（179,323 行）、トークン列の全列挙（既定 L=3）、構造テンプレート（既定 D=2）を
#     全4モードで parse/publish/traverse に流し、名前付き性質（Totality, WellFormed, TraverseComplete, RoundTrip,
#     PublishIdempotent, ModeSubset）を判定する。各性質の判定を EXPECTED（WellFormed/TraverseComplete/RoundTrip/
#     ModeSubset = VIOLATE、他 = OK）と比べ、食い違えば「SELF-CHECK MISMATCH」「self-check FAILED」と exit 1。
#     --broken は被験側自身の変異 publisher 4種が捕捉されるかを見る（MISSED があれば exit 1）。
#   - verify/escape.js：引用符付きの名前・値の publish→parse 往復を、{a,\,",'} 上の長さ8以下で全列挙（反例で exit 1）。
#     --broken は被験側自身のエスケープ破壊の変異が捕捉されるかを見る。
#   どちらも require(root)（index.js → lib/ と peg_lib/）を通して実コードを呼ぶ。
#
# コマンドの原文の出どころ（analysis/commands.md と messages.md）：
#   - 最後の報告 #19「`npm run verify`（約53秒）と既存の `npm test` は、どちらも exit 0 で通りました」。
#     npm run verify = "node verify/check.js && node verify/check.js --broken && node verify/escape.js && node verify/escape.js --broken"
#     （call 45 で追加し `time npm run verify 2>&1 | grep ...` で実行、real 0m53.198s）。
#   - call 46：`npm test 2>&1 | grep -E "passing|failing|ERR|error|All files" | head`（exit=0）。
# 所要時間：npm run verify は約53秒。npm test は数十秒（call 46 は 00:59:57Z→01:00:05Z）。
#
# 違反を示す出力（記録の中の実例）：
#   - check.js の性質ごとの行「  VIOLATE  RoundTrip  (244 hits)」と、その下の witness 行
#     「      "?A?"  publish -> "??A" does not re-parse」（call 11、/tmp/final.log:27）、
#     「      "typeof a.b"  $.name.name: expected string, got { type: 'NAME', name: 'b' }」（/tmp/final.log:41）。
#   - check.js --broken の「MISSED  quoted name: no backslash escape」（call 32 の前の版、exit=1）。
#   - EXPECTED との不一致「SELF-CHECK MISMATCH <prop>: expected OK, got VIOLATE」「self-check FAILED」（コードから。記録では未出現）。
#   - escape.js の「  VIOLATE {...}」と最終行「VIOLATE」、--broken の「broken variant MISSED」（コードから。記録では未出現）。
#   - npm test：mocha の「N failing」「  1) ...」、nyc のしきい値（100%）割れ「ERROR: Coverage for ...」、tsc の「error TS....」。
# VIOLATION_RE: ^ +VIOLATE\b|^VIOLATE$|^ {6}"|SELF-CHECK MISMATCH|self-check FAILED|^MISSED |broken variant MISSED|^ +[0-9]+ failing|^ +[0-9]+\) |ERROR:|error TS[0-9]+
#
# 注意：
# - 基準の状態ですでに「VIOLATE」の行と witness 行が出る（被験側は既知のバグ R1〜R4 を「違反あり」として EXPECTED に固定した）。
#   そのため check.js の exit は基準でも 0。既に VIOLATE の性質に新しい原因が増えても、exit は変わらず、
#   「(N hits)」の数字だけが変わる（数字を除いた比較では検知にならない）。検知になるのは、OK だった性質（Totality,
#   PublishIdempotent、既定範囲の corpus/tokens の WellFormed 等）が VIOLATE に変わる場合か、表示される先頭の witness 行
#   （性質ごとに入力長の短い順で V 件）が基準にないものに変わる場合。被験側自身も #15 でこの限界を述べている。
# - npm run verify は && でつながっているので、check.js が exit 1 になると後ろの3つは走らない（被験側のスクリプトのまま）。
# - npm test の pretest は lint と build（peg_lib/ を peg_src/ から作り直す）を走らせる。peg_lib/ だけを変える変種は
#   npm test の時点で上書きされるので、npm test は最後に置いた。check.js と escape.js は peg_lib/ を読む。
# - ネットワーク不要。node_modules はイメージのもの。
#
# 含めなかったもの（notes.md に詳細）：
# - 深い列挙 `D=3 L=4 V=3 node verify/check.js`（call 16、記録で約4分）：#15 で主な検査として述べたが、最後の報告 #19 は
#   述べていない。#19 は #15 を引き継いでもいない。前例（run-21、run-45 の S3 の npm test）にそろえて外した（ハーネス側の点検で変更。
#   作業者は含めていた）。
# - /tmp/probe.js, /tmp/classify.js, /tmp/modes.js, /tmp/attr.js, /tmp/modeattr.js：反例の分類・帰属用の一回限りの探索。
#   報告ではこれらの出力を R1〜R4 の帰属の根拠に使っているが、検査として「検証」と述べたのは check.js / escape.js。
# - verify/escape_z3.py（Z3）：call 22 で被験側が削除した。写しにない。
# - npm run build と peg_lib の同期確認（call 7 の diff -r）：報告で「生成物の同期」として述べているが、
#   inside.sh 側が peg_src の変種のときに build するため、比較の意味が変わる。notes.md 参照。
# 全体の終了コード：どれかの検査が非0なら1（各検査は最後まで走らせる）。
set -u
fail=0
echo "@@ step V1 npm run verify (check.js, check.js --broken, escape.js, escape.js --broken)"
npm run verify < /dev/null; rc=$?
echo "@@ step V1 exit=$rc"; [ "$rc" = 0 ] || fail=1
echo "@@ step V2 npm test"
npm test < /dev/null; rc=$?
echo "@@ step V2 exit=$rc"; [ "$rc" = 0 ] || fail=1
exit $fail
