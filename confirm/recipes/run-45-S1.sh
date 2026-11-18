# shellcheck shell=bash
# run-45 (D2), 写し S1（段階1の終わり、2026-11-18T01:32:50Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミットの変更あり）。
# 被験側のライブラリの変更（未コミット、lib/publishing.js のみ。peg_src/ と peg_lib/ は変更なし）：
#   - NULLABLE / NOT_NULLABLE：中身が NULLABLE / NOT_NULLABLE のときは外側を後置形（%s? / %s!）で出力
#     （isNullabilityNode を追加、NodeType から NULLABLE, NOT_NULLABLE を読み込む）。
#   - KEY_QUERY：中身が NULLABLE / NOT_NULLABLE のときは `keyof A?` の形で出力。
#   テストの変更：tests/test_publishing.js に回帰テスト9件と stripMeta、tests/test_roundtrip.js（新規、
#   トークン3個以下の全組み合わせで publish→parse の往復を確かめる）。
#
# 成果物（写しの /tmp にだけある）：
#   - /tmp/verify/check.js：38種のトークンを並べた長さ4以下の全文字列（と tests/fixtures の全行）を
#     4モードで parse し、P1（SyntaxError 以外の例外）、P2（publish が例外）、P3（往復で再パース不能／AST 不一致）、
#     P4（publish が冪等でない）、P5（traverse の訪問）を確かめ、{total, accepted, fails} を JSON で出力する。
#     違反がなければ "fails": {}。違反があっても終了コードは 0（ただし P4 の再 publish など try の外で
#     例外が出ると異常終了し非0）。
#   - /tmp/verify/esc.js：引用符付きの名前（\ ' " を含む）を8つの構文形で 30 万件×4モード、Math.random で
#     生成して往復を確かめる。1行目は「件数 受理数 違反入力数」、続いて違反の例を最大15行。
#     parse が SyntaxError 以外を投げると throw して異常終了（非0）。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - call 24（段階1の最後の検証）：
#       npm test >/dev/null 2>&1; echo "npm test exit=$?"; cd /tmp/verify; until [ -s time4.txt ]; ...;
#       node -e '...require("/tmp/verify/out4.json")...'; node esc.js /home/dev/jsdoctypeparser
#     ここで読んだ out4.json は call 23 の `node check.js /home/dev/jsdoctypeparser 4 > out4.json`。
#   - 報告 #5：「修正後、同じ検査をすべてやり直して反例はゼロです。`npm test`（lint、テスト345件、
#     カバレッジ100%、型チェック）も通っています。」「長さ4以下の約930万ケースで…5つの性質…すべてに違反なし」
#     「引用符付きの名前のエスケープ処理（120万ケース）も違反なし」。
#   レシピでは out4.json に書かずに標準出力へ出す（中身は同じ JSON）。npm test の出力は捨てずに出す。
# 違反を示す出力：
#   - check.js：fails のキーの行と、例の入力の行。例（call 11 の出力 out4.json、修正前）
#       「 "P3-published-not-reparseable|permissive": {」「   "s": "?A!",」
#     （call 11 の表示は加工後の {"s":"?A?","info":"??A"} だが、check.js の出力そのものは null,1 の字下げ JSON）
#   - esc.js：「"<入力>" <モード> unparseable: <出力>」または「… mismatch: …」の行（記録では違反0件で、
#     実例はない。esc.js の書式から決めた）。
#   - npm test：「N failing」（例：call 18 の `npx mocha tests/test_roundtrip.js` で「1 failing」）。
#     lint の失敗、nyc のカバレッジ不足（branches/lines/functions 100% が閾値）、tsc の失敗は
#     終了コードだけに現れる。
# VIOLATION_RE: "P[1-5]-[A-Za-z-]+\|(permissive|jsdoc|closure|typescript)"|^\s*"s": |" (permissive|typescript|jsdoc|closure) (unparseable|mismatch): |[1-9][0-9]* failing
#
# 注意：
# - check.js（長さ4）は記録で約3分12秒（call 11 の time4.txt：real 3m12.1s。写しの /tmp/verify/time4.txt も同じ）。
#   esc.js は記録で約20〜30秒（段階3の変種での実行、/tmp/mut/*.esc.status：secs=19〜29）。
#   npm test は記録に所要時間の表示がない（mocha 部分は「345 passing (8s)」。pretest で lint と build を行う）。
# - 終わらない入力（種類3）に対する時間制限は、この時点の検査にはない。check.js が止まると、
#   inside.sh の全体の制限（5400秒）まで戻らない。段階3で被験側は `timeout 900` をかけて実行したが、
#   S1 の時点の検査のコマンドにはないので、ここでも付けていない。
# - esc.js は Math.random で入力を作るので、実行ごとに入力が変わる。基準の出力に違反行があると、
#   変種なしでも違反行の「種類」（数字を除いた形）が実行ごとに違って見える。
# - check.js は例を1キーあたり400件まで（call 6 で 5→400 に変えた後の写し）。
# - bash の終了コードは最後のコマンドのものになるので、3つの検査のどれかが非0なら非0で終わるようにした。
#   検査の内容は変えていない。
#
# 含めなかったもの：
# - /tmp/verify/out3.json を作る `node check.js … 3`：長さ4の実行に含まれる。
# - 段階1の途中の `npx mocha tests/test_*`（call 2）、`npx mocha tests/test_roundtrip.js`（call 18、修正前の
#   コードに対する確認）：最後の検証は npm test で、これに含まれる。
rc=0
npm test < /dev/null 2>&1; r=$?; echo "npm test exit=$r"; [ "$r" = 0 ] || rc=1
node /tmp/verify/check.js /home/dev/jsdoctypeparser 4 < /dev/null; r=$?; echo "check.js exit=$r"; [ "$r" = 0 ] || rc=1
node /tmp/verify/esc.js /home/dev/jsdoctypeparser < /dev/null; r=$?; echo "esc.js exit=$r"; [ "$r" = 0 ] || rc=1
exit $rc
