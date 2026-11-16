# shellcheck shell=bash
# run-31 (D), snapshot S1（段階1の終わり、#10 の報告の時点）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミット。git status は「?? verification/」のみ）。
# 被験側のライブラリの変更（lib/、peg_src/、peg_lib/ の差分）：なし。
#
# 成果物：verification/Traversing.lean（lib/traversing.js の traverse を手で Lean に書き写したモデルと、
#   その性質 collect_eq / traverse_correct / traverse_enter_count / traverse_leave_count / traverse_no_crash の証明）。
#   このファイルはリポジトリのファイルを何も読み込まない（import も外部ファイルの読み込みもない）。
#   したがって、ライブラリを変えても結果は変わらない（被験側も #13 でそう述べ、変種3つで lean が通ることを確かめた）。
# 補助：/tmp/leancheck/Check.lean（Traversing.lean の写しに #print axioms と #eval を足したもの、call 24 で作成）。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - call 23（段階1の最後の lean の実行）：`lean Traversing.lean 2>&1 | head -40; echo "exit=$?"`（cd verification の後）
#   - call 24：`lean /tmp/leancheck/Check.lean 2>&1` と、それに続く node -e（実際の JS の traverse の訪問順の出力）
#   - #10「`lean verification/Traversing.lean` を実行すると、エラーも警告もなく終わります」
#     「依存しているのは Lean 標準の公理（propext, Classical.choice, Quot.sound）だけ」（Check.lean の #print axioms）
#     「…を実際の JS で traverse した結果と、Lean モデルの実行結果を比べたところ、訪問順もプロパティ名も一致しました」（call 24 の node -e）
# 違反を示す出力：
#   - Lean の証明の失敗。例（call 10、段階1の途中）「Traversing.lean:231:49: error: omega could not prove the goal:」
#   - JS の traverse の例外（node -e が捕捉せずに落ちる）。例（#13、変種2で被験側が述べた結果）
#     「TypeError: Cannot read properties of null (reading 'type')」
# VIOLATION_RE: \.lean:[0-9]+:[0-9]+: error|^[A-Za-z]*Error:
#
# 注意：
# - /tmp/leancheck/Check.lean は、変更前でも #eval の行で失敗する
#   （call 24 の出力「/tmp/leancheck/Check.lean:403:41: error(lean.synthInstanceFailed): failed to synthesize instance of type class
#   Repr Std.Format」、lean の終了コードは非0）。#print axioms の出力と #eval の結果は出る。
#   このため、Check.lean の終了コードはこのレシピの終了コードに入れていない。そのエラー行は基準の出力にも出るので、
#   数字を除いた形で比べる VIOLATION_RE の判定には影響しない。
# - node -e の比較は、被験側が Lean の #eval の出力と目で突き合わせたもので、突き合わせ自体は機械化されていない。
#   訪問順やプロパティ名が変わっても、例外にならなければ「違反の行」は出ない（出力の差分としてだけ現れる）。
# - 所要時間：lean は約4秒（call 10 の time の出力「real 0m4.141s」）。
#
# 含めなかったもの：
# - 段階1の途中の lean の実行（call 10〜23）：同じファイルの途中の版に対するもので、最後の実行と同じ。
# - 段階1の終わりの時点で、被験側が違反として挙げた入力はない（#10「traverse についてはバグは見つかりませんでした」）。
rc=0
(cd verification && lean Traversing.lean) </dev/null 2>&1 || rc=1
lean /tmp/leancheck/Check.lean </dev/null 2>&1
node -e '
const {parse, traverse} = require("./index.js");
const ast = parse("function(this:T, A, ...B): (Array<C>|{a: D, b})");
const out=[];
const strip = n => n.type==="PARENTHESIS" ? n.value : n;
traverse(ast, (n,p)=>n.type!=="PARENTHESIS"&&out.push(`enter ${n.type} ${p}`), (n,p)=>n.type!=="PARENTHESIS"&&out.push(`leave ${n.type} ${p}`));
console.log(out.join("\n"));' </dev/null 2>&1 || rc=1
exit $rc
