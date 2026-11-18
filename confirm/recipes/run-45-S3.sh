# shellcheck shell=bash
# run-45 (D2), 写し S3（段階5の後、2026-11-18T03:23:38Z）。
# 作業ディレクトリ /home/dev/jsdoctypeparser（HEAD d395aa0、未コミットの変更あり）。
# 被験側のライブラリの変更：S1 と同じ（lib/publishing.js のみ。NULLABLE / NOT_NULLABLE の入れ子を後置形で出力、
#   KEY_QUERY の中身が nullable のとき `keyof A?` の形で出力）。段階2以降、リポジトリ本体は変わっていない
#   （S1 と S3 の jsdoctypeparser の木は .git 等を除いて同一。被験側の変種は /tmp/mut/<名前> のコピーにだけある）。
#
# 成果物（写しの /tmp にだけある）：/tmp/verify2/
#   - run.js：検証の本体。入力集合 A（旧網羅検査の38トークン、長さ4まで）、B（表の記号24種、長さ5まで）、
#     C（tests/fixtures の全行）、D（引用符付きの名前、固定シードの乱数で30万件）を4モードで確かめる。
#     性質 P1〜P5（S1 の check.js と同じ）、P6（parse/publish/traverse/表の照合が 10 秒以内に終わらない。
#     ワーカーを止めて違反として記録し、その入力を飛ばして再開）、T1（B のみ permissive で、演算子順位表の
#     受理・拒否と入れ子の形にライブラリが一致する）。
#     <出力ディレクトリ>/failures.tsv に違反を1行ずつ（kind, mode, 入力, info のタブ区切り）、summary.json に集計を書き、
#     標準出力には集計（種類ごとの件数）だけを出す。終了コードはワーカーの例外のときだけ 2、それ以外は 0。
#   - oracle.js / table.js / table.md：表に従う独立のパーサ（オラクル）と、段階2の表の写し。run.js が読む。
#   - report.js：failures.tsv を（比較元と差を取って）分類して表示する補助。
# コマンドの原文の出どころ（analysis/commands.md）：
#   - call 53 / 58 / 64：`cd /tmp/verify2 && time node run.js /home/dev/jsdoctypeparser out/baseline 2>&1 | tail -16`
#     （call 64 が最後の変種なしの実行。それ以前の out は `rm -rf out` で消している）。
#   - 変種での判定（call 65, 68, 70）：`node run.js /tmp/mut/$m out/$m` の後、
#     `node report.js out/$m/failures.tsv out/baseline/failures.tsv`（比較元にない違反だけを数える）。
#   - 報告 #22「新しい検証で変えた点」、#23 の検証の範囲の説明。#22 の判定はすべてこの run.js による。
#   レシピでは被験側の out/baseline を上書きしないよう、出力先を out/recipe にする。
#   被験側が変種での判定に使ったのは「基準の failures.tsv にない行」なので、集計の後に failures.tsv の全行を出す
#   （ハーネス側が基準の出力と比べられるようにするため。集計の行だけでは、変種なしでもすでにある種類
#   〔T1-nesting-differs など〕の件数の増減が「新しい種類」として現れない）。
# 違反を示す出力：
#   - 集計の行：例（out/t2_exc.log）「  "P1-non-SyntaxError-exception|permissive": 44660,」
#   - failures.tsv の行：例（out/baseline/failures.tsv）
#       「T1-table-accepts-library-rejects	permissive	"=A?"	{"table":"OPTIONAL(NULLABLE(A))","library":"reject"}」
#     例（out/t3_hang/failures.tsv）「P6-timeout	permissive	"{A}"	"publish が 10000ms 以内に終わらない (入力集合 A)"」
# VIOLATION_RE: (^|")(P[1-6]|T1)-[A-Za-z-]+(\t|\|)
#
# 注意：
# - 1回の実行に時間がかかる。記録では変種なしで real 7m42s（call 64、8ワーカー＝nproc 8）、変種で 472〜475 秒
#   （out/t1_nest.log ほか）。ワーカー数は os.cpus().length なので、CPU が少ないと延びる。
# - 終わらない変種では、止まる入力ごとに 10 秒待ってワーカーを作り直す。被験側の t3_hang（`{A}` などで
#   publish が止まる変種）での実行は、02:56Z ごろ開始から写しの時点（03:23Z）まで終わらず、P6-timeout が
#   607 行記録された段階だった（/tmp/verify2/out/t3_hang/failures.tsv）。同種の変種では inside.sh の
#   全体の制限（5400秒）で打ち切られ、集計は出ないが、それまでに書かれた failures.tsv の行はレシピからは
#   出せない（cat は run.js の終了後）。このため、打ち切りのときは終了コード 124 だけが手がかりになる。
# - failures.tsv の行の順序はワーカーの完了順で決まり、実行ごとに変わり得る（判定は集合で比べるので影響しない）。
#   変種なしで約2万行（写しの out/baseline/failures.tsv は 20228 行、2.6MB）。例外が大量に出る変種では
#   20MB を超える（被験側の t2_exc で 24MB）。
# - 入力集合 D は固定シード（mulberry32）なので、S1 の esc.js と違い実行ごとに同じ入力になる。
#
# 含めなかったもの：
# - /tmp/verify/check.js と /tmp/verify/esc.js（S1 の検査）：段階4で run.js に置き換えられ、#22・#23 では
#   検証として述べていない（run.js の入力集合 A と D が同じ範囲を含む）。
# - npm test：段階3では変種ごとに「参考として別欄」（#15）で、段階4以降の報告 #22・#23 では検証として述べていない。
# - /tmp/mut/ の変種と、それを作るコマンド（call 30〜34）、変種での実行（call 59, 65）：被験側自身の変種で、検査の検査。
# - report.js：run.js の出力の表示を整えるだけで、違反の判定はしない。
cd /tmp/verify2 || exit 2
rm -rf out/recipe
node run.js /home/dev/jsdoctypeparser out/recipe < /dev/null 2>&1; rc=$?
echo "run.js exit=$rc"
cat out/recipe/failures.tsv
exit $rc
