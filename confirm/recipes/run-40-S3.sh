# shellcheck shell=bash
# run-40 (D, D2) 写し S3（段階5の後、2026-11-17T15:14:04Z。打ち切りではない）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（ブランチ fix/formal-verification-findings、HEAD cb5b174）。
# 被験側のライブラリの変更は S1 と同じ（コミット 4ff69f4、段階3以降は変更なし。git status は verify/ だけ）：
#   - peg_src/jsdoctype.pegjs：QualifiedMemberName の MEMBER.name を tokens[3].name にし、quoteStyle/hasEventPrefix を追加
#   - lib/publishing.js：NULLABLE/NOT_NULLABLE で meta.syntax が後置なら後置で出力、NAMED_PARAMETER で typeName が null のとき空文字
#   - peg_lib/*.js：再生成したもの。tests/ にも回帰テストの追加と期待値3件の書き換えがある
# 参照変種はこの変更後のツリーに当てる。
#
# 成果物：段階4で直した verify/（未コミット：props.js、run.js、fuzz.js を書き換え、table.js、harness.js、
#   worker.js、compare.js、.eslintrc.json を追加）。
#   - props.js：check（種類0/2/3：往復、traverse の構造、モード間の包含、SyntaxError 以外の例外、500ms 超の遅さ、
#     スタック溢れ）と checkTable（種類1：表から作った演算子順位パーサ table.js をオラクルにして permissive の
#     受理・拒否と入れ子を比べる）。
#   - harness.js / worker.js：ワーカースレッドで検査し、1 操作が HANG_MS（既定 2000ms）進まなければ
#     P5-hang（種類3）として記録して次の入力へ進む。MAX_HANGS（既定 10）件で打ち切り「INCOMPLETE」と表示。
#   - run.js：長さ N 以下の全列挙（--table で表のトークン 23 種）。fuzz.js：フィクスチャ全件と変異ファジング。
#     どちらも --out=<file> で違反を 1 件 1 行の JSON で書き出す。
#   require('..') でリポジトリの index.js（lib/ と peg_lib/）を読む。
# コマンドの原文：/tmp/mut/run2.sh（写しの /tmp にある。commands.md call 87 で作成、#40 の call 93 で BASE と 7 つの変種を順に実行）。
#   被験側が段階4の最後に変種なし（BASE）と変種に対して実行した、直した検証の一式：
#     job run4 verify/run.js 4
#     for r in NamepathExpr BroadNamepathExpr ExternalNameExpr ModuleNameExpr; do job run3_$r verify/run.js 3 $r; done
#     job table5 verify/run.js --table 5
#     job fuzz7 verify/fuzz.js 400000 7
#     job fuzz42 verify/fuzz.js 400000 42
#   job は「( timeout $T node "$@" --out=out2/$name.jsonl > out2/$name.txt 2>&1; echo "exit=$? sec=..." >> out2/$name.txt ) &」、
#   T の既定は 1500。run2.sh は /tmp/mut/<変種> のコピー（git archive HEAD に verify/ を写したもの）で動かすが、
#   ここではハーネスが変種を当てた /home/dev/jsdoctypeparser で同じコマンドを動かす（make.py と npm run build は除いた。
#   それは被験側の変種を作る部分で、peg_src の再ビルドは inside.sh が行う）。
#   報告：#46「直した検証は verify/ にあり ... table.js、harness.js、worker.js、compare.js を追加し、props.js、
#   run.js、fuzz.js を書き換え」、種類1の件数は「23種類のトークンを並べた長さ5以下の全入力」（table5）。
#   #47 も同じ検証の結果を述べている。
# 所要時間：BASE の記録（/tmp/mut/BASE/out2/*.txt の exit= 行）で、7 本並列で最長 run4 221 秒、table5 204 秒、
#   fuzz 約 128 秒。変種では最長 252 秒（M2b の run4）。#38「1つあたり5分前後」。
# 違反を示す出力：
#   - 各ジョブの標準出力（out2/<name>.txt）：「[kind K] <性質> [<モード>]: <件数>」の行と、その下の 4 件の例
#     （4 スペースで始まる JSON 行）、打ち切り時の「INCOMPLETE: stopped after N non-terminating inputs」。
#     例（/tmp/mut/BASE/out2/table5.txt:7）「[kind 1] K1-nesting [permissive]: 1991」
#     例（/tmp/mut/M2a/out2/run4.txt）「[kind 2] P5-exception [permissive]: 1805」
#     例（/tmp/mut/M3a/out2/run4.txt）「INCOMPLETE: stopped after 10 non-terminating inputs」「[kind 3] P5-hang [permissive]: 10」
#     例（/tmp/mut/M3c/out2/run4.txt）「[kind 3] P6-unbounded-recursion [permissive]: 1464」
#   - 被験側は「新しい違反」を件数ではなく、--out の JSON 行を verify/compare.js で BASE と突き合わせて決めた
#     （キーは [prop, mode, op, s]、call 98〜100、#45）。M1a（| を左結合）と M1b（A|B= を拒否）は、要約の行では
#     件数が変わるだけ（K1-nesting 1991→2116 など）で、数字を除くと基準と同じ形になる。そこで最後に、
#     --out の JSON 行を compare.js と同じキーで「V [kind,prop,mode,op,s]」の 1 行ずつにして表示する
#     （検査の内容は変えず、出力の見せ方だけを足した）。M2b のように違反が百万件単位になると --out は
#     約 955MB になった（/tmp/mut/M2b/out2/all.jsonl）ので、同じ [kind,prop,mode,op] ごとに先に現れた 20000 件までに
#     限った。BASE の最大の群は K1-rejects-valid の 15209 件なので、基準の群はすべて全件が出る。
#   - ジョブの終了コードが 0 でない（timeout の 124、ワーカーの例外など）ときは「JOB-FAILED <name> exit=<n>」を出す
#     （run2.sh の「exit=$? sec=...」の行を、数字を除いても区別できる形にしたもの）。
# VIOLATION_RE: ^\[kind [0-9]+\] |^INCOMPLETE:|^ +\{"kind":[0-9]|^V \[|^JOB-FAILED
#
# 注意：
# - 変種なしの基準の出力にも違反が出る：[kind 0] P4-same-ast [jsdoc] 8 件、[kind 1] K1-accepts-invalid 18 件、
#   K1-nesting 1991 件、K1-rejects-valid 15209 件（BASE の記録）。被験側は K1 の一部をオラクル側の問題
#   （=> を対象外にできていない、被演算子の種類を区別しない）と述べている（#46）。
# - P5-slow（1 操作 500ms 超）と P5-hang（2000ms 進まない）は時間依存。7 本を並列に動かすので、負荷によっては
#   変種と無関係に出る可能性がある。被験側も 7 本並列で動かしている。
# - 終わらない入力が 10 件に達したジョブは INCOMPLETE で打ち切られ、残りの入力は検査されない（#46 の制限）。
# - traverse の無限再帰（スタック溢れ）は P6-unbounded-recursion（種類3）として出る。被験側の M3c の再確認は
#   fuzz の 2 本が終わる前に止められた（#46「未検証」）。
# - 変種の当たっていないモード（orig）でも verify/ はそのまま動く（verify/ はライブラリの外）。
#
# 含めなかったもの：
# - verify/compare.js：BASE と変種の --out を突き合わせる道具。ハーネス側の比較（summarize.py）が同じ役目を
#   持つので、上の「V ...」行の出力で代えた。
# - /tmp/mut/make.py、/tmp/mut/run.sh、/tmp/mut/run2.sh の make/build 部分、/tmp/mut/probe.js：被験側の変種を作り、
#   当てて確かめるためのもの（検査の検査）。
# - node verify/run.js --table 3 / --table 4 --out=/tmp/t3.jsonl / /tmp/t4.jsonl（call 83、94）：作業中の確認。
#   最後の検証は --table 5。
# - npx eslint（call 83、100）：検証スクリプトの lint で、ライブラリの検査ではない。
# - npm test：段階3以降は実行していない。最後の報告（#46、#47）でも検証として述べていない。
cd /home/dev/jsdoctypeparser || exit 2
OUT=/tmp/confirm-out2
rm -rf "$OUT" && mkdir -p "$OUT"
T=1500
start=$(date +%s)
job () { name=$1; shift; ( timeout $T node "$@" --out=$OUT/$name.jsonl > $OUT/$name.txt 2>&1; echo "exit=$? sec=$(( $(date +%s)-start ))" >> $OUT/$name.txt ) & }
job run4 verify/run.js 4
for r in NamepathExpr BroadNamepathExpr ExternalNameExpr ModuleNameExpr; do job run3_$r verify/run.js 3 $r; done
job table5 verify/run.js --table 5
job fuzz7 verify/fuzz.js 400000 7
job fuzz42 verify/fuzz.js 400000 42
wait
for f in "$OUT"/*.txt; do echo "== $(basename "$f")"; cat "$f"; done
for f in "$OUT"/*.txt; do
  e=$(sed -n 's/^exit=\([0-9]*\) sec=.*/\1/p' "$f" | tail -1)
  [ "$e" = 0 ] || echo "JOB-FAILED $(basename "$f" .txt) exit=$e"
done
echo "### violations, one per [kind, prop, mode, op, s] (the key of verify/compare.js), at most 20000 per [kind, prop, mode, op]"
node -e '
const fs = require("fs"); const readline = require("readline");
const files = process.argv.slice(1).filter((f) => fs.existsSync(f));
const CAP = 20000; const groups = new Map();
(async () => {
  for (const f of files) {
    const rl = readline.createInterface({input: fs.createReadStream(f), crlfDelay: Infinity});
    for await (const line of rl) {
      if (!line) continue;
      let x; try { x = JSON.parse(line); } catch (e) { console.log("BAD-JSONL " + f); continue; }
      const g = JSON.stringify([x.kind, x.prop, x.mode, x.op]);
      if (!groups.has(g)) groups.set(g, new Set());
      const s = groups.get(g);
      if (s.size < CAP) s.add(JSON.stringify([x.kind, x.prop, x.mode, x.op, x.s]));
    }
  }
  const out = [];
  for (const s of groups.values()) for (const k of s) out.push("V " + k);
  out.sort();
  process.stdout.write(out.join("\n") + (out.length ? "\n" : ""));
})();
' "$OUT"/run4.jsonl "$OUT"/run3_NamepathExpr.jsonl "$OUT"/run3_BroadNamepathExpr.jsonl "$OUT"/run3_ExternalNameExpr.jsonl "$OUT"/run3_ModuleNameExpr.jsonl "$OUT"/table5.jsonl "$OUT"/fuzz7.jsonl "$OUT"/fuzz42.jsonl
