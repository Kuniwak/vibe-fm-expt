# shellcheck shell=bash
# run-19 (A2, 形式手法の指示)。作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/keyof-prefix-operand、HEAD 53b53ea）。
# 被験側はライブラリを変更している（d395aa0 からの2コミット）：
#   - 2315522：lib/publishing.js（? / ! の被演算子が ? / ! のときは接尾辞形式で出力）。tests/test_publishing.js、tests/test_roundtrip.js（新規）。
#   - 53b53ea：peg_src/jsdoctype.pegjs（SuffixUnaryUnionTypeExpr に !KeyQueryWithPrefixUnaryOperand を追加。
#     `keyof ?a` / `keyof !a` を読めるようにする）と、それから生成した peg_lib/ の4ファイル。
#     lib/publishing.js の keyof 用の回避策は削除。tests/test_parsing.js、tests/test_publishing.js、tests/test_roundtrip.js。
#   参照変種はこの変更後のツリーに当てることになる。
# 固定発言（U10、2026-11-16T00:34:10Z）の後に被験側はツールを使っておらず、ファイルを変えていない。
#
# 成果物（どれも写しの /tmp/verify にあり、リポジトリの外）：
#   - /tmp/verify/check.js：有界網羅検査。P0 parse が SyntaxError 以外を投げない、P1 publish が投げない、
#     P2 publish の出力が同じモードで再パースできる、P3 parse(publish(ast)) が元と一致（接尾辞→接頭辞の書き換えは同一視）、
#     P4 traverse が全ノードを1回ずつ訪問し enter/leave が入れ子。4モード。require(path.resolve('.')) で実物の index.js を読む。
#   - /tmp/verify/diff.js：修正前のライブラリの写し /tmp/verify/old（コミット 2315522 の時点の peg_lib/、lib/、index.js、package.json）と
#     現在のツリーで parse の結果を比べる。
#   - npm test（被験側が加えた tests/test_roundtrip.js を含む。pretest が lint と build を実行する）。
# 被験側の最後の報告 #19（#18 を要約）で検証として述べたもの：
#   「網羅検査（parse → publish → parse で同じ AST に戻るか、計約8,050万件）と、修正前後のパーサーの比較（約872万件）は、どちらも反例ゼロ」
#   「npm test は349件すべて成功」
# コマンドの原文（analysis/commands.md、record/transcripts）：
#   - call 40：`(node /tmp/verify/check.js . 4 300000 > /tmp/verify/r4.txt 2>&1 & TOKENS='[...15個...]' node /tmp/verify/check.js . 6 0 > /tmp/verify/r6.txt 2>&1 & TOKENS='[...13個...]' node /tmp/verify/check.js . 6 0 > /tmp/verify/r6b.txt 2>&1; wait); head -20 /tmp/verify/r4.txt /tmp/verify/r6.txt /tmp/verify/r6b.txt`
#     （ここでは head -20 の代わりに cat で全体を出す）
#   - call 33：`TOKENS='[...18個...]' node /tmp/verify/diff.js /tmp/verify/old . 5`
#   - call 39：`npm test 2>&1 | grep -E "passing|failing|All files|rror  "`（ここでは grep を外し、終了コードを残す）
# 所要時間（記録）：
#   - call 40 の3本の並列実行：00:11:56 → 00:32:51 で約21分。単独では check.js . 4 300000 が約3分43秒（call 5 の time）、
#     15トークン長さ6が約18分（call 18、23:22:07 → 23:40:22）。
#   - diff.js：約7分半（call 33、00:03:24 → 00:10:49）。
#   - npm test：約10秒。
#   合計で約30分。被験側と同じく check.js の3本は並列に実行する。
# 違反を示す出力（記録の中の実際の出力）：
#   - check.js（/tmp/verify/out4.txt、修正前のライブラリでの call 5 の出力）：
#       「### P2 publish output does not reparse|permissive」「- src="?a?" published="??a"」
#       「### P3 round-trip changes AST|permissive」「- src="??!" published="!??"」
#     call 20 では「### P2 publish output does not reparse|permissive (total 394)」の形（件数の表示を足した後の check.js。写しはこちら）。
#     反例がなければ「checked N (string,mode) pairs, M accepted」の1行だけ。終了コードは常に 0。
#   - diff.js：「newly accepted / permissive 100 [...]」は被験側が意図した変化（記録の基準の出力にもある）。
#     被験側が違反として見たのは「NEWLY REJECTED / <mode>」「AST CHANGED / <mode>」（#18「AST が変わったものや拒否されるようになったものは0件」）。
#   - npm test：call 38「2 failing」。npm-run-all の「ERROR:」。
# VIOLATION_RE: ^### P[0-4] |^- src=|^(NEWLY REJECTED|AST CHANGED) / |[1-9][0-9]* failing|ERROR:
#
# 注意：
# - check.js と diff.js は違反があっても終了コード 0 で終わる（出力だけで判定）。例外で止まると非0。
#   レシピ全体の終了コードは、どれかの検査が非0で終わったら 1 にする（各検査の内容は変えていない）。
# - check.js の出力は /tmp/verify/r4.txt、r6.txt、r6b.txt に書く（被験側のコマンドどおり。写しのファイルを上書きする）。
# - diff.js は /tmp/verify/old を「修正前」として使う。orig モード（ライブラリを固定のコミットに戻す）では、
#   old と現在の parse が同じになり newly accepted の行も出なくなる。比較は同じモードの基準の出力とするので問題はない。
#   old は文法の修正前の peg_lib/ を持つので、参照変種が old には当たらず、現在のツリーにだけ当たる。
# - check.js は `.`（作業ディレクトリ）の index.js と tests/fixtures を読む。index.js → lib/ → peg_lib/ なので、
#   peg_src/ の変種は build の後でないと現れない（inside.sh が peg_src の変種のときは build する。npm test の pretest も build する）。
#
# 含めなかったもの：
# - /tmp/verify/out4.txt などの古い出力ファイルの読み出し：検査ではない。
# - call 7、13、14、21、32 の node -e による個別の確認：合否を出す検査ではない。
# - call 26 の `npx mocha tests/test_roundtrip.js`（単独）と git stash による修正前の確認：npm test に含まれる、または被験側の変種（修正前に戻す）を当てるもの。
cd /home/dev/jsdoctypeparser || exit 2
rc=0
echo "@@ step V1 node /tmp/verify/check.js (3 runs in parallel: 39 tokens len 4 + 300000 random; 15 tokens len 6; 13 tokens len 6)"
(node /tmp/verify/check.js . 4 300000 > /tmp/verify/r4.txt 2>&1 & p1=$!
 TOKENS='["a","?","!","...","=","|","&","(",")","<",">",",","{","}","keyof "]' node /tmp/verify/check.js . 6 0 > /tmp/verify/r6.txt 2>&1 & p2=$!
 TOKENS='["a","?","!","...","=","|","(",")","<",">",",","keyof"," "]' node /tmp/verify/check.js . 6 0 > /tmp/verify/r6b.txt 2>&1; r3=$?
 wait $p1; r1=$?; wait $p2; r2=$?
 [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$r3" = 0 ]) < /dev/null || rc=1
echo "@@ step V1 output r4.txt"
cat /tmp/verify/r4.txt
echo "@@ step V1 output r6.txt"
cat /tmp/verify/r6.txt
echo "@@ step V1 output r6b.txt"
cat /tmp/verify/r6b.txt
echo "@@ step V2 node /tmp/verify/diff.js /tmp/verify/old . 5"
TOKENS='["a","?","!","...","=","|","&","(",")","<",">",",","{","}",":","keyof","typeof"," "]' node /tmp/verify/diff.js /tmp/verify/old . 5 < /dev/null 2>&1 || rc=1
echo "@@ step V3 npm test"
npm test < /dev/null 2>&1 || rc=1
exit $rc
