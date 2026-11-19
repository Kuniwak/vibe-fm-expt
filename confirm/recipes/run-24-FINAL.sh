# shellcheck shell=bash
# run-24 (A, A2). 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0 のまま、変更は未コミット）。
# 被験側はライブラリを変更している（git diff、コミットなし）：
#   - lib/publishing.js：NULLABLE / NOT_NULLABLE / VARIADIC で meta.syntax が SUFFIX_* のとき後置で出力する（+10行）。
#   - peg_src/jsdoctype.pegjs：QualifiedMemberName の MEMBER ノードで name: tokens[3] を
#     name: tokens[3].name, quoteStyle: 'none', hasEventPrefix: false に変更。
#   - peg_lib/*.js：上の文法から npm run build で再生成したもの（4ファイル）。
#   ほかに tests/test_publishing.js（期待値3件の書き換えと4件の追加）、tests/test_roundtrip.js（新規）、
#   .gitignore（formal/.lake）、.npmignore（formal）、formal/（Lean プロジェクト、新規）。
# 固定発言（U2、02:39:48Z）の後、被験側はツールを使っておらず、ファイルを変えていない（#9 は文章のみ）。
#
# 成果物と、最終報告（#8）で検証として述べたもの：
#   V1 ランダム往復テスト（/tmp/fuzz/fuzz.js）。parse(s) の AST と parse(publish(parse(s))) を深い比較で比べる。
#      #8「修正後、各モードで数十万件規模のランダム入力を試しましたが、不一致は 0 件でした。」
#      コマンドの原文：call 20 `for seed in 13 21 99 1234; do node /tmp/fuzz/fuzz.js $PWD/index.js $seed 300000 | head -12; done`
#      （モード指定なし、NOMETA なし＝meta も比較）、
#      call 21 `for m in jsdoc closure typescript; do echo "== $m"; MODE=$m node fuzz.js /home/dev/jsdoctypeparser/index.js 5 200000 | head -8; done`
#      （cd /tmp/fuzz で実行）。写しの fuzz.js は call 21 の sed を当てた後の最終版で、MODE が未設定なら call 20 と同じ動作。
#      fuzz.js は index.js（→ lib/ と peg_lib/）を読む。違反があっても終了コードは 0（出力の行だけで判定）。
#      所要時間：call 20 の4シードとビルドで約40秒、call 21 の3モードと npm test で約25秒。
#   V2 既存テスト＋追加テスト（tests/test_roundtrip.js を含む）。#8「修正後は全テスト 343 件が成功します。lint と型チェックも通っています。」
#      コマンドの原文：call 47 `npm run lint 2>&1 | tail -5; npx mocha tests/test_* 2>&1 | grep -E "passing|failing|round trip" ; npm run typecheck 2>&1 | tail -2`
#      （call 21 では `npm test` も実行しているが、最後に「343 件」を確かめたのは call 47 の mocha）。
#      ここでは grep/tail で出力を絞らずに実行する（違反の行を残すため）。
#   V3 Lean の証明。#8「`cd formal && lake build` で検証できます」。コマンドの原文は #8 のこの記述（call 33/36/41-43 では
#      `timeout 600 lake build` / `timeout 900 lake build`）。最後の成功は call 43「Build completed successfully (3 jobs).」。
#      formal/JsdocTypeParserFormal.lean は Lean 上の手書きのモデルで、JS のファイルを読まない。ライブラリの変種では結果は変わらない。
#      写しには formal/.lake/build があるので、lake は再検査せずに「up to date」で終わる可能性がある。
#      Lean のツールチェーン（leanprover/lean4:v4.35.0）は /home/dev/.elan にあった（call 42 の trace）が、写しの home/dev には
#      .elan がない。イメージにあることを前提にする。
#
# 違反を示す出力（記録の中の実際の例）：
#   V1（修正前、call 5）「parsed 120617, failures 13169」「DIFF "a!" => "!a" 」
#      「ERR "!Foo!" => "!!Foo" Expected "'", "(", ...」
#      修正後（call 20）は「parsed 175760, failures 0」。
#   V2（call 22）「  3 failing」「  1) publish」、（call 47 の修正前のコードでの確認）「  4 failing」
#   V3（call 36）「error: JsdocTypeParserFormal.lean:385:8: Tactic `rewrite` failed: ...」「error: build failed」
#   lint（eslint）と typecheck（tsc）の失敗の出力は記録にない。eslint の「✖ N problems」と tsc の「error TS」を想定して加えた。
#   「failures 0」は数字を除くと「failures #」になり違反の行と区別できないので、1以上だけに当てる。
# VIOLATION_RE: failures [1-9]|^(DIFF|ERR) "|[1-9][0-9]* failing|^ +[0-9]+\) |error: build failed|^error: .*\.lean:[0-9]+:[0-9]+:|✖ [0-9]+ problems?|error TS[0-9]+
#
# 注意：
# - 終了コード：各ステップの失敗を rc に集め、最後に exit $rc。fuzz.js は違反があっても 0 で終わる。
# - fuzz.js の引数の index.js は peg_lib/ を読むので、peg_src/ の変種はビルド後でないと届かない（inside.sh が再ビルドする）。
# - fuzz.js の比較は parse の結果どうしの比較なので、parse が例外を投げる入力は数えない（continue）。
#
# 含めなかったもの：
# - call 47 後半の `git stash push lib/publishing.js peg_src peg_lib -q && npx mocha tests/test_roundtrip.js ...; git stash pop -q`：
#   修正前のコードで新しいテストが失敗することの確認。ツリーを書き換えるので、ハーネスの変種と衝突する。
# - /tmp/fuzz/check.lean（`lake env lean /tmp/fuzz/check.lean`、#print axioms）：#8 で「使っている公理は propext と Quot.sound だけ」と
#   述べた確認。違反を示す出力がなく、JS とも無関係。V3 に付けても判定は変わらないので省いた。
# - npm test（call 21）：pretest で lint と build、test で coverage と typecheck。V2 と内容が重なり、build がツリーを書き換える。

cd /home/dev/jsdoctypeparser || exit 2
rc=0

echo "@@ step V1a node /tmp/fuzz/fuzz.js (permissive, seeds 13 21 99 1234, 300000)"
for seed in 13 21 99 1234; do node /tmp/fuzz/fuzz.js "$PWD/index.js" "$seed" 300000 < /dev/null | head -12; done

echo "@@ step V1b MODE=jsdoc|closure|typescript node /tmp/fuzz/fuzz.js (seed 5, 200000)"
for m in jsdoc closure typescript; do echo "== $m"; (cd /tmp/fuzz && MODE=$m node fuzz.js /home/dev/jsdoctypeparser/index.js 5 200000 < /dev/null | head -8); done

echo "@@ step V2a npm run lint"
npm run lint < /dev/null 2>&1 || rc=1

echo "@@ step V2b npx mocha tests/test_*"
npx mocha 'tests/test_*' < /dev/null 2>&1 || rc=1

echo "@@ step V2c npm run typecheck"
npm run typecheck < /dev/null 2>&1 || rc=1

echo "@@ step V3 cd formal && lake build"
(cd formal && timeout 900 lake build < /dev/null 2>&1) || rc=1

exit $rc
