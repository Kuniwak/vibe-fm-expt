# shellcheck shell=bash
# run-25 (A, A2). 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、git status は clean）。
# 被験側はライブラリを変更していない（lib/、peg_src/、peg_lib/ の差分なし）。リポジトリにファイルを加えていない。
# 固定発言（U2、02:48:52Z）の後、被験側はツールを使っておらず、ファイルを変えていない（#5 は文章のみ）。
#
# 成果物：/tmp/verify/ の検査スクリプト（写しの /tmp にだけある）。
#   - check.js：トークン列を長さ MAXLEN まで全部並べ、4モード × 各開始ルールで P1（parse の全域性）、P2（publish の全域性）、
#     P3（parse(publish(ast)) の再パース成功と AST の一致、meta は除く）、P4（traverse の正しさ）を調べる。
#     引数：<index.js のパス> <MAXLEN> <'|' 区切りのトークン>。違反は「== <性質>: N violations」と、1件ずつの JSON 行で出す。
#     写しの check.js は call 5 の2つの sed（canon で meta を除く、slice(0, 100000)）を当てた後の最終版。
#   - filter.js：check.js の出力から既知の違反（前置修飾子のノードを後置の ?/! が包むもの）を除き、残りの (入力, 出力) を並べる。
#     filter.js 自身も /home/dev/jsdoctypeparser を require する。
#   - rand.js：check.js の列挙部分を乱数（長さ5〜10、seed 12345）に置き換えた rand_gen.js を生成する。
# 最終報告（#4）で検証として述べたもの：
#   V1「40種のトークンを並べた長さ3以下の全入力：約118万回の parse」
#      コマンドの原文：call 5 `node check.js /home/dev/jsdoctypeparser/index.js 3 > out3.txt; head -1 out3.txt; grep '^==' out3.txt; ...`
#      と、同じ call の `node check.js /home/dev/jsdoctypeparser/index.js 3 | grep '^{"s"' | node -e '<(入力, 出力) の対をまとめる>'`。
#      ここでは check.js を1回だけ実行して out3.txt に書き、その両方の後処理を out3.txt に当てる。所要時間：約17秒（call 4 の time）。
#   V2「29種のトークンを並べた長さ4以下の全入力：約1,319万回の parse」
#      コマンドの原文：call 8 `T="a|.|<|>|[]|(|)|{|}|,|:|?|!|=|...|||&|=>|function|new|'x'|~|#|typeof|keyof|module:|import|1| " && node check.js /home/dev/jsdoctypeparser/index.js 4 "$T" > out4.txt; head -1 out4.txt; grep "^==" out4.txt; node filter.js < out4.txt`
#      所要時間：約3分（call 8 は 02:43:10Z 開始、結果 02:46:03Z）。
#   V3「長さ5〜10のランダムな入力：720万回の parse」
#      コマンドの原文：call 11 `node rand.js && T="a|b|.|<|>|[]|(|)|{|}|,|:|?|!|=|...|||&|=>|function|new|this|'x'|~|#|typeof|keyof|module:|external:|event:|import|readonly|1| " && node rand_gen.js /home/dev/jsdoctypeparser/index.js 0 "$T" 400000 > outr.txt; head -1 outr.txt; grep "^==" outr.txt; node filter.js < outr.txt | grep -v '"keyof' | head -40`
#      所要時間：約1分45秒（call 11 は 02:46:25Z 開始、結果 02:48:11Z）。
#   V4 既存の npm test。#4「既存の `npm test` は335件すべて通過し、カバレッジも100%です」。コマンドの原文：call 3 `npm test 2>&1 | tail -30`。
#      pretest で lint と build（peg_src/ から peg_lib/ を作り直す）、test で nyc（カバレッジ100%を要求）＋mocha と tsc。
#      build が peg_lib/ を作り直すので、最後に置いた（peg_lib/ だけを変える変種は V4 の中で消える）。
#
# 違反を示す出力（記録の中の実際の例）：
#   V1（call 4）「== P3-reparse: 224 violations」「{"s":"?a?","mode":"permissive","startRule":"TopTypeExpr","out":"??a","e":"SyntaxError: ..."}」
#      （call 5）「["?a?","??a"]    permissive/TopTypeExpr,jsdoc/TopTypeExpr,...」
#   V2（call 8）「== P3-ast: 32 violations」「other violation inputs: 18」「["keyof a?","keyof ?a"]    permissive/TopTypeExpr REPARSE-FAIL,...」
#   V3（call 11）違反なし：「{"tokens":34,"maxlen":3,"parseCalls":7200000,"accepted":25506}」「other violation inputs: 0」
#   V4 の失敗の出力は記録にない。mocha の「N failing」「  1) ...」と nyc の「ERROR: Coverage for ...」を想定して加えた。
#   ライブラリは未修正なので、基準の出力にもすでに P3 の違反の行がある。新しい種類（数字を除いた形）の行だけが検知になる。
#   「== P3-reparse: # violations」のような件数の行は、件数が変わっても数字を除くと同じ形なので、新しい性質の違反（P1、P2、P4 など）だけが検知になる。
#   check.js の JSON 行（{"s":...}）はエラーメッセージ（期待されたトークンの一覧）を含み、文法の変更で同じ入力でも形が変わる。
#   そのため VIOLATION_RE には含めず、(入力, 出力) の対の行（["...","..."]）を当てる。
# VIOLATION_RE: ^== P[0-9A-Za-z-]+: [0-9]+ violations|^\["|other violation inputs: [1-9]|[1-9][0-9]* failing|^ +[0-9]+\) |ERROR:
#
# 注意：
# - check.js、filter.js、rand_gen.js はどれも違反があっても終了コード 0 で終わる。V1〜V3 の検知は出力の行だけに頼る。
# - V1〜V3 の出力ファイル（out3.txt、out4.txt、outr.txt）は、被験側と同じく /tmp/verify に上書きする。
# - check.js は index.js（→ lib/ と peg_lib/）を読む。peg_src/ の変種はビルド後でないと届かない（inside.sh が再ビルドする）。
# - call 5 の後処理の node -e は「slice(0,60)」で最初の60対だけを出す。被験側のとおりにした。
# - V4 は timeout 600 で包んだ（被験側の call 3 は約7秒）。npm test の build が長くかかった例が別の run にあるため。
#
# 含めなかったもの：
# - call 4 の `time node check.js ... 3 2>&1 | tail -80`：canon が meta も比べていた版で、call 5 の sed の後の V1 と同じ検査。
# - call 6、9、10 の node -e：個別の入力（?a?、??!、!??、keyof a? など）の確認。違反の説明のためで、検査ではない。

cd /home/dev/jsdoctypeparser || exit 2
rc=0

echo "@@ step V1 node /tmp/verify/check.js index.js 3 (40 tokens)"
(cd /tmp/verify && node check.js /home/dev/jsdoctypeparser/index.js 3 > out3.txt < /dev/null; head -1 out3.txt; grep '^==' out3.txt; grep '^{"s"' out3.txt | node -e '
const ls=require("fs").readFileSync(0,"utf8").trim().split("\n").map(JSON.parse);
const m=new Map();for(const f of ls){const k=JSON.stringify([f.s,f.out]);m.set(k,(m.get(k)||[]).concat(f.mode+"/"+f.startRule+(f.a?" AST-DIFF":"")));}
for(const[k,v] of [...m].slice(0,60))console.log(k,"  ",v.join(","));console.log("unique inputs:",m.size)')

echo "@@ step V2 node /tmp/verify/check.js index.js 4 (29 tokens) + node filter.js"
(cd /tmp/verify && T="a|.|<|>|[]|(|)|{|}|,|:|?|!|=|...|||&|=>|function|new|'x'|~|#|typeof|keyof|module:|import|1| " && node check.js /home/dev/jsdoctypeparser/index.js 4 "$T" > out4.txt < /dev/null; head -1 out4.txt; grep "^==" out4.txt; node filter.js < out4.txt)

echo "@@ step V3 node /tmp/verify/rand.js + node rand_gen.js index.js 0 (34 tokens) 400000 + node filter.js"
(cd /tmp/verify && node rand.js < /dev/null && T="a|b|.|<|>|[]|(|)|{|}|,|:|?|!|=|...|||&|=>|function|new|this|'x'|~|#|typeof|keyof|module:|external:|event:|import|readonly|1| " && node rand_gen.js /home/dev/jsdoctypeparser/index.js 0 "$T" 400000 > outr.txt < /dev/null; head -1 outr.txt; grep "^==" outr.txt; node filter.js < outr.txt | grep -v '"keyof' | head -40)

echo "@@ step V4 npm test"
timeout 600 npm test < /dev/null 2>&1 || rc=1

exit $rc
