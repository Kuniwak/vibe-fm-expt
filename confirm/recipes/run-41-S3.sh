# shellcheck shell=bash
# run-41 (D, D2) 写し S3（段階5の後、2026-11-17T16:12:36Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0）。
# 被験側のライブラリの変更：なし（lib/、peg_src/、peg_lib/、index.js は HEAD と同じ。未追跡は formal/ だけ）。
#   被験側の変種は /tmp/mut/<名前>/ の写しに当てたもので、リポジトリ本体には入っていない（#20、call 49 の git status）。
#
# 成果物（段階4で作り直し、#31・#34 で「検証」として述べたもの）：
#   1. formal/check/run.js（worker.js、oracle.js、precedence-table.md を使う）。
#      ライブラリ（既定はこのリポジトリ、index.js → lib/ と peg_lib/）を worker スレッドで実行し、
#      K1（演算子順位の表との食い違い、permissive）、K2（SyntaxError 以外の例外）、K3（3秒進まない）、CRASH、
#      TRAV（traverse の親情報・訪問）、RT（往復）、QUOTE（引用符付き名前）、COVER（publisher の網羅）を数える。
#      違反が1件でもあれば終了コード1。乱数は種を固定（rng(1)〜rng(5)）しているので、入力は毎回同じ。
#   2. formal/ の Lean（lake build）。#31「Lean の証明（V1）は今回も JS とつながっていないので、どの変種でも結果は変わりません」、
#      #34 も検証の一部として述べている。最後のビルドは call 68 の `cd formal && lake build 2>&1 | tail -1`。
# コマンドの原文：
#   - call 62、66：`node formal/check/run.js /tmp/mut/base --out /tmp/verif/new_base.json 2>&1 | tail -80`
#     （/tmp/mut/base はリポジトリの写し）。call 67：変種ごとに `node formal/check/run.js /tmp/mut/$m --out …`。
#   - formal/README.md：「node formal/check/run.js [library-root] [--out violations.json] runs the library itself
#     (default: this repository)」。ここでは library-root を省き、このリポジトリそのものを対象にする。
#   - 被験側は変種ごとの違反を `node formal/check/diff.js base.json mutant.json` で比べた（キーは cat, op, mode, input, detail）。
#     ハーネス側の比較に合わせるため、下では --out の JSON を1違反1行（「VIOLATION<TAB>cat<TAB>op<TAB>mode<TAB>input<TAB>detail」）
#     で表示する。これは出力の書き直しで、検査の内容は変えていない。不要ならこの node -e の行を外してよい
#     （その場合、run.js の要約に出る例の行（各分類6件まで、短い入力から）だけが判定に使われる）。
# 違反を示す出力：
#   - run.js の要約の例の行。例（call 66 の出力、変種なし）：
#       「    [parse/permissive] "= ?"  ->  SyntaxError, table accepts as ["P=","?"]」
#       「    [traverse/permissive] "typeof core.Dict"  ->  visited 3 nodes, expected 4 in pre-order」
#     例（call 67、変種 k3c）：「    [traverse/permissive/fixture] "Array.<{length}>"  ->  no progress for 3000 ms」（diff.js の形）。
#   - 上の VIOLATION 行。
#   - Lean：「error: …」「error: build failed」（call 20）。
#   要約の「K1     5961」のような件数の行は、数字を除くとどれも同じ形になるので入れていない。
# VIOLATION_RE: ^ +\[[a-z]*/[a-z-]+\] |^VIOLATION\t|^error:
#
# 注意：
# - 変種なしでも違反がある（call 66：K1 5961、K2 748、TRAV 42）。終了コードは基準の時点で1なので、終了コードの変化では検知できない。
# - 所要時間：変種なしで約15秒（call 66「time 15.3 s」、call 62 は real 16.1s）。終わらない変種では worker を25回まで再起動して打ち切る
#   （call 67：k3a/k3b/k3c で約136秒、「ABORTED after 25 restarts」。8つを並列に走らせた時の値）。
#   打ち切った場合、それ以降の入力は実行されない。
# - K3 は「3秒間進まない」で判定する（HANG_MS=3000）。機械が混んでいると、変種なしでも K3 が出る可能性がある（記録では出ていない）。
# - worker の resourceLimits は maxOldGenerationSizeMb 768。
# - run.js は peg_lib/ を読む。peg_src/ の変種は build（inside.sh が行う）の後でないと現れない。
# - lake は ~/.elan/bin にある（call 1）。PATH に足した。Lean の結果は JS の変種では変わらない。
#
# 含めなかったもの：
# - formal/check/diff.js：2回の実行の差を出す道具。ハーネス側の比較がその代わりになる。
# - /tmp/verif/run.sh（旧 V1〜V3 と既存の mocha）：段階3で S1 の検証をそのまま実行するために書いたもの。
#   段階4で run.js に置き換えられ、旧 V2・V3 は run.js に取り込まれた（#21、#31）。
# - /tmp/verif/mkcopy.sh、/tmp/mut/ を作る call 42〜45 のスクリプト、/tmp/verif/witness.js：被験側の変種を作る・発現を確かめるもの。
# - 既存テスト（npm test / mocha）：段階3の表で「参考: 既存テスト」とした（#20）だけで、段階4以降の報告では検証として述べていない。
#   なお S3 では formal/check/*.js が lint の対象に入る（npm test の pretest）。
# - call 63〜65、70、71 の node -e：違反の集計・分類だけ。
export PATH="/home/dev/.elan/bin:$HOME/.elan/bin:$PATH"
OUT=/tmp/confirm-run41-S3-violations.json
rm -f "$OUT"
node formal/check/run.js --out "$OUT" < /dev/null 2>&1; rc=$?
[ -f "$OUT" ] && node -e '
const v = require(process.argv[1]);
if (v.aborted) console.log("run aborted after too many restarts");
for (const x of v.violations) console.log(["VIOLATION", x.cat, x.op, x.mode, JSON.stringify(x.input), x.detail].join("\t"));
' "$OUT"
(cd formal && timeout 300 lake build 2>&1 | tail -1; exit "${PIPESTATUS[0]}") || rc=1
exit $rc
