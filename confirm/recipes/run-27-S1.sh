# shellcheck shell=bash
# run-27 (D, D2), 写し S1（段階1の終わり、2026-11-16T04:11:18Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/publish-omitted-param-type、HEAD 1ab12d3）。
# 被験側はライブラリを変更している（コミット cb569c2「fix: `publish` no longer throws on arrow parameters
# with omitted types」）。lib/ の差分（d395aa0 との比較）は次の1行だけ。peg_src/、peg_lib/ の差分はない。
#   lib/publishing.js NAMED_PARAMETER:
#   +      if (!parameterNode.typeName) return parameterNode.name + ':';
# 同じコミットで tests/test_publishing.js に回帰テスト1件を加えている。
#
# 成果物：verification/Jsdoctypeparser.lean（Lean 4 の定理。import なし、ライブラリの JS を読まない手写しのモデル）。
#   被験側は段階3（#16）で「Lean のファイルは何も import しておらず、ライブラリの JS を一切読まない」と述べている。
#   したがってこの検査はライブラリの変更で結果が変わらないはずだが、報告で検証として述べたので含める。
# コマンドの原文の出どころ（analysis/messages.md と transcript の call 番号）：
#   1. #5「確認コマンド: `lean verification/Jsdoctypeparser.lean`」。#11 の Test plan「`lean verification/Jsdoctypeparser.lean` (no errors, no `sorry`)」。
#      #13「`lean verification/Jsdoctypeparser.lean` がエラーなしで通り」。
#   2. #5「補強として、エスケープの往復性は実際の `parse`/`publish` で 40,000 件ランダムに試し、すべて一致しました。」
#      コマンドは call 20 の `node -e "..."`（原文どおり。原文では前に `cd /home/dev/jsdoctypeparser &&`、
#      後ろに `&& npm test 2>&1 | tail -5` が付いていた）。乱数の種は固定されていない（Math.random）。
#      出力例（call 20）「roundtrip checks 40000 mismatches 0」。不一致があると「MISMATCH "<文字列>" single」の行が出る。
#   3. #7「`npm test` は通っています（336 件パス、型チェックもパス、ESLint も問題なし）」、#11 の Test plan「`npm test` (336 passing, typecheck OK)」。
#      最後の実行は call 24 の `npm test >/dev/null 2>&1; echo test=$?`（出力 test=0）。ここでは出力を捨てずに実行する。
#      pretest で lint（eslint .）と build（peg_src から peg_lib を再生成）が走る。test は nyc mocha tests/test_* と tsc。
# 違反を示す出力：
#   - Lean のエラー。例（開発中の出力、transcript）「Jsdoctypeparser.lean:71:6: error: unsolved goals」
#   - 往復性の不一致「MISMATCH ...」「roundtrip checks 40000 mismatches N」（N>0）。記録に N>0 の実例はない。
#   - mocha の「N failing」、tsc の「error TS....」、eslint の「N problems」。記録に失敗の実例はない（成功例「336 passing (4s)」）。
# VIOLATION_RE: : error:|^MISMATCH |mismatches [1-9]|[1-9][0-9]* failing|error TS[0-9]+|[0-9]+ problems? \(
#
# 注意：
# - Lean は /home/dev/.elan（イメージ側。PATH=/home/dev/.elan/bin:... がイメージの Env にある）の v4.35.0 を使う。写しには .elan はない。
# - npm test の pretest の eslint は、参照変種のコードの書き方（スタイル）だけでも失敗しうる。その場合も終了コードは非0になる。
# - 所要時間：Lean は記録上数秒、往復性は数秒、npm test は数十秒（記録に正確な時間はない）。
#
# 含めなかったもの：
# - /tmp/axioms.lean（call 19、#print axioms で公理への依存を表示するだけ。ライブラリの検査ではない）。
# - call 9 の node -e（`(x:) => string` などで publish が落ちることの確認。バグの再現であって、報告で検証として述べたものではない）。
lean verification/Jsdoctypeparser.lean < /dev/null; rc1=$?
node -e "
const {parse,publish}=require('./index.js');
const alpha=['a','\\\\',\"'\",'\"','b'];let bad=0,n=0;
for(let i=0;i<20000;i++){let s='';const L=Math.random()*8|0;for(let j=0;j<L;j++)s+=alpha[Math.random()*alpha.length|0];
 for(const q of ['single','double']){const ast={type:'MEMBER',owner:{type:'NAME',name:'Foo'},name:s,quoteStyle:q,hasEventPrefix:false};
  n++; const back=parse(publish(ast)); if(back.name!==s){bad++; if(bad<3)console.log('MISMATCH',JSON.stringify(s),q);} }}
console.log('roundtrip checks',n,'mismatches',bad);
" < /dev/null; rc2=$?
npm test < /dev/null; rc3=$?
echo "lean=$rc1 roundtrip=$rc2 npm_test=$rc3"
[ "$rc1" = 0 ] && [ "$rc2" = 0 ] && [ "$rc3" = 0 ]
