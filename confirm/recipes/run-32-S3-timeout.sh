# shellcheck shell=bash
# run-32 (D2), snapshot S3-timeout. 段階1のまま打ち切り（段階2以降の発言は送られていない）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/roundtrip-bugs、HEAD 93d4342、作業ツリーは clean）。
# 被験側は上流の master 5166cc4 にブランチを載せ直した（commands.md call 52）。5166cc4 と元の d395aa0 の差は
# package.json の build:* スクリプト（frs-replace の入力を `< file` から `-i file --stdout` に変更）だけで、
# lib/ peg_src/ peg_lib/ index.js は同じ。d395aa0 は backup/master-d395aa0 ブランチとして写しに残っている。
# 被験側のライブラリの変更（コミット 5923a84、5166cc4 からの差分）:
#   - peg_src/jsdoctype.pegjs: QualifiedMemberName の MEMBER.name を tokens[3].name にし、
#     quoteStyle: 'none', hasEventPrefix: false を追加。KeyQueryWithPrefixUnaryOperand 規則を追加し、
#     SuffixNullableTypeExpr / SuffixNotNullableTypeExpr の先頭に否定先読み
#     `!KeyQueryWithPrefixUnaryOperand // no-jsdoc, no-closure` を追加。
#   - lib/publishing.js: publishNullability() を追加。NULLABLE / NOT_NULLABLE の中身がさらに
#     NULLABLE / NOT_NULLABLE のときは外側の演算子を後置で出す。
#   - peg_lib/*.js: 上の文法を再ビルドしたもの。
#   - tests/test_parsing.js, tests/test_publishing.js に回帰テスト8件、tests/test_round_trip.js を新規追加（コミット 93d4342）。
#
# 成果物:
#   (a) /tmp/verify/check.js（写しの /tmp にだけある）: 有界網羅検査。トークン列を長さ MAXLEN まで全部作り、
#       4モードで P1（構文エラー以外の例外なし）、P4（traverse が全ノードを1回ずつ訪問）、
#       P2（publish が例外を投げない）、P3a（publish の出力が再パースできる）、
#       P3b（再パースした AST が meta を除いて一致）を確かめ、JSON を出力する。終了コードは常に0。
#       call 21 で KNOWN による除外の行は sed で消してあり、写しの check.js は除外なしで数える。
#       require(repo) → index.js → lib/ + peg_lib/ を読むので、peg_src の変更は build 後にだけ届く。
#   (b) tests/test_round_trip.js: (a) と同じ性質（P2 は除く）を29トークン・長さ3で確かめる mocha テスト。npm test に含まれる。
# コマンドの原文の出どころ（analysis/commands.md）:
#   - call 21 / call 27: `npm run build >/dev/null 2>&1 && echo built && cd /tmp/verify && ...;
#       for a in "3 sp" "3 nosep"; do node check.js /home/dev/jsdoctypeparser $a | node -e "..."; done;
#       for a in "4 sp" "4 nosep"; do SMALL=1 node check.js /home/dev/jsdoctypeparser $a | node -e "..."; done`
#     （call 27 が修正後の最後の4通りの実行。下では call 27 の node -e の要約をそのまま使う）。
#   - 報告 #11「修正後の検証結果」の表（42種・長さ3、30種・長さ4、区切りあり・なし、反例0）と
#     PR 本文 #16 / /tmp/pr-body.md の「Bounded check (up to length 4, outside CI): 0 counterexamples」。
#   - call 52: `npm test >/tmp/t.log 2>&1; echo exit=$?; grep -E "passing|failing" /tmp/t.log`（最後の npm test、
#     345 passing、exit=0）。報告 #22・#27・#29 で、test_round_trip.js を含む npm test が通ったことを検証として述べた。
#     下では、終了コードがレシピの終了コードに出るよう、npm test を最後に置き、出力を絞らずに実行する。
# 違反を示す出力:
#   - check.js の要約（util.inspect の形）に性質/モードの鍵が出る。例（call 21 の出力、途中まで直した状態）:
#       "  'P3a-reparseFails/permissive': 18,"
#     例（call 11 の出力、元のコード）: "  'P4-traverse/permissive': 95,"
#     修正後（call 27）はどの範囲も "3 sp 75894 5879 metaOnly 380 {} []" で、鍵の行は出ない。
#   - npm test: test_round_trip.js の失敗。例（call 46、元のコードの master で実行した出力）:
#       "  2 failing"
#       -  "permissive: \"? A ?\": published \"??A\" is not re-parseable"
#     ほかに lint・カバレッジ閾値の失敗は "ERROR:" で出る（call 27 の出力: "ERROR: Coverage for lines (99.14%) does not meet global threshold (100%)"）。
# VIOLATION_RE: (P1-nonSyntaxError|P2-publishThrows|P3a-reparseFails|P3b-semanticDiff|P4-traverse)/(permissive|jsdoc|closure|typescript)|[1-9][0-9]* failing|ERROR:|is not re-parseable|changes the AST|did not visit every node|non-syntax error
#
# 注意:
# - 所要時間（記録）: check.js の長さ3は1回約7.5秒（call 42 の time: real 0m7.630s / 0m7.462s）。
#   call 21 の build と4通りの実行は全体で約3分（12:45:35 → 12:48:46）なので、SMALL=1 の長さ4は1回1分前後。
#   npm test は約10秒（call 47・52 の "345 passing (10s)"）。
# - check.js は違反があっても終了コード0。違反の判定は上の VIOLATION_RE による。要約の node -e は、
#   check.js が例外で止まって JSON が出ない場合は JSON.parse の例外で止まる（そのときの行は VIOLATION_RE に当たらない）。
# - SMALL=1 の長さ4は約84万入力 × 4モード。参照変種によって反例が非常に多くなっても、要約は件数と先頭5件だけを出す。
# - npm test の pretest（lint と build）は peg_lib/ を peg_src/ から作り直す。下の npm run build も同じ。
#   したがって peg_lib/ だけを変える参照変種は、この検査には届かない。
# - 被験側は npm test に timeout を付けていない。stdin は /dev/null にした。
#
# 含めなかったもの:
# - 被験側が自分で埋め込んだ変種を当てるスクリプトはない（段階3に達していない）。
# - call 46 の、git worktree で元の master に test_round_trip.js を写して実行する手順:
#   「テストが修正前のバグを検出できるか」の確認（検査の検査）なので含めない。
# - call 8・14・26 などの node -e での個別の入力の表示: 調査のためのもので、報告で検証として述べていない。
# - check.js の結果を JSON ファイル（a.json など）に書く形の実行（call 4〜11）: 修正前の調査の段階のもの。
npm run build < /dev/null
cd /tmp/verify || exit 2
for a in "3 sp" "3 nosep"; do node check.js /home/dev/jsdoctypeparser $a < /dev/null | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const r=JSON.parse(s);console.log('$a',r.inputs,r.accepted,'metaOnly',r.metaOnly,r.summary, Object.values(r.examples).flat().slice(0,5))})"; done
for a in "4 sp" "4 nosep"; do SMALL=1 node check.js /home/dev/jsdoctypeparser $a < /dev/null | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const r=JSON.parse(s);console.log('small $a',r.inputs,r.accepted,'metaOnly',r.metaOnly,r.summary, Object.values(r.examples).flat().slice(0,5))})"; done
cd /home/dev/jsdoctypeparser || exit 2
npm test < /dev/null
