# shellcheck shell=bash
# run-27 (D, D2), 写し S3（段階5の後、記録の最後、2026-11-16T05:20:50Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/publish-omitted-param-type、HEAD 8b3a40b、作業ツリーに差分なし）。
# 被験側のライブラリの変更（d395aa0 との比較）は S1 と同じ、コミット cb569c2 の lib/publishing.js の1行だけ。
#   +      if (!parameterNode.typeName) return parameterNode.name + ':';
#   段階4ではライブラリを変えていない（U9 の指示どおり。#27「ライブラリのコードには手を入れていません」）。
#
# 成果物：verification/run.sh（コミット 8b3a40b）。中身は次の順に実行する（set -euo pipefail）。
#   1. lake build >/dev/null（Lake プロジェクト verification/。Lean の証明 Jsdoctypeparser.lean と、
#      演算子順位の表のオラクル Oracle.lean（実行ファイル oracle）。依存パッケージなし、ネットワーク不要）
#   2. .lake/build/bin/oracle precedence-table.md 5 6 > out/oracle.jsonl（表から期待結果を列挙、約57万件）
#   3. node check.js out/oracle.jsonl out（../index.js、つまり lib/ と peg_lib/ の実物を動かす。
#      種類1：オラクルとの照合、種類2：SyntaxError 以外の例外、種類3：3000 ms 進まない処理。
#      入力は表から列挙したもの、grammar-inputs.js が文法から作る4万件（種は固定）、tests/fixtures。
#      結果を out/summary.txt と out/violations.jsonl に書き、標準出力に summary を出す。違反が1件でもあれば exit 1）
# コマンドの原文の出どころ：
#   - #27「`verification/run.sh`：全体を一度に実行します（約 40 秒）。違反があれば終了コード 1 になります。」
#   - #29「`./verification/run.sh` を実行すれば、いつでも同じ結果を再現できます。」
#   - #31「新しいバグは、前回の確認のようにベースラインとの差分で見つけられます。」
#   - 段階4の変種の確認（call 69〜71）は `/tmp/mut/variant.sh vN`（中身は `./verification/run.sh > /tmp/mut/$1.txt 2>&1`
#     と violations.jsonl の写し）のあと `node /tmp/mut/newv.js /tmp/mut/base.jsonl /tmp/mut/vN.jsonl` で
#     ベースラインにない違反を表示していた。base.jsonl は変種なしの run.sh の violations.jsonl（43,080 行）で、写しの /tmp にある。
#   ここでは run.sh を実行し、続けて同じ newv.js で、ベースライン（/tmp/mut/base.jsonl）にない違反を表示する。
#   newv.js は比較と表示だけで、変種を当てない（変種を当てるのは /tmp/mut/m3.js や sed で、含めていない）。
# 違反を示す出力：
#   - 変種なしでも run.sh は exit 1（種類1の違反 43,080 件、表とライブラリの既知の違い）。終了コードの 0→非0 では判定できない。
#   - summary の例示行（各グループの短い5件）。例（/tmp/mut/base.txt:9）「    入力 "= n1"  期待 ["P=","n1"]  実際 "REJECT"」、
#     （call 70、変種2）「    入力 "((A :\r\n)=>*)"  mode=permissive startRule=BroadNamepathExpr  → TypeError: Cannot read properties of null (reading 'type')」
#   - newv.js の出力の、ベースラインにない違反の行。例（call 69、変種1）
#     「    {"kind":1,"input":"? * | ?","expected":["|",["P?","*"],"?"],"actual":["P?",["|","*","?"]]}」、
#     （call 71、変種3）「    {"kind":3,"stage":"publish","input":"external\n :'\\\"'","mode":"permissive",...,"error":"3000 ms 以内に終わらない"}」
#   - run.sh 自体の失敗（lake build や oracle の失敗）は set -e で止まり、標準出力にはほぼ何も出ない（lake build の出力は捨てている）。
# VIOLATION_RE: ^ +\{"kind":[123],|^ +入力 ".*(実際 |→ )|^- (期待 |parse: |publish: |traverse: )
#
# 注意：
# - 写しの verification/out/violations.jsonl と summary.txt は、被験側が最後に回した変種3（lib/publishing.js の
#   エスケープのループ）の結果（43,085 行、種類3が5件）が残っている。run.sh が途中で失敗すると古い結果を newv.js が
#   読んでしまうので、先に out/ の結果のファイルだけ消す（.gitignore 対象の出力。検査の中身は変えない）。
# - newv.js の比較のキーは [kind, stage, input, mode, startRule, actual, error]。orig（ピン留めのライブラリ）では
#   被験側の修正がないので、ベースラインとの差（例：型を省略した引数での publish の TypeError）がそのまま出る。
#   ハーネスの判定は同じ MODE の base 出力との比較なので、それ自体は検知に数えられない。
# - 種類3は 3000 ms の壁時計で判定するので、負荷の高い環境では変種なしでも「終わらない」が出うる（check.js は CPU 数に
#   よらず worker 1 本）。記録上の所要時間：call 63 の `time ./run.sh` で real 37.8 s。
# - Lean は /home/dev/.elan（イメージ側）の v4.35.0。写しの verification/.lake にビルド済みの oracle と .olean がある。
# - newv.js は例示を種類ごとに短い順の4件までしか出さない。新しい違反が例示に現れる限り検知になる。
#
# 含めなかったもの：
# - /tmp/mut/m3.js、/tmp/mut/variant.sh、sed による変種の当て戻し（被験側自身の変種を当てる、検査の検査）。
# - /tmp/mut/run.sh（段階3で使った、Lean と /tmp/mut/probe.js と mocha を変種ごとに回すスクリプト。段階4の後は使っていない）。
# - npm test：段階4以降は回しておらず、段階3では「参考」としていた（#16）。段階5の報告（#121、#122）でも検証として述べていない。
#   S1 のレシピには含めている（段階1の報告で検証として述べたため）。
rm -f verification/out/violations.jsonl verification/out/summary.txt verification/out/oracle.jsonl
./verification/run.sh < /dev/null; rc=$?
echo "run.sh exit=$rc"
if [ -f verification/out/violations.jsonl ]; then
  node /tmp/mut/newv.js /tmp/mut/base.jsonl verification/out/violations.jsonl < /dev/null
fi
exit $rc
