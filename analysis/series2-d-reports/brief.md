# 依頼：被験側の、種類ごとの報告の抜き出し（条件D、D2）

日本語で作業し、日本語で書いてください。

## 背景
ある実験の記録から、AI（被験側）が「どの種類のバグを、自分の検証で検知できると報告したか」を、原文どおりに抜き出します。
解釈で埋めないことが一番大事です。原文から決められないものは「決められない」と書いてください。

被験側には、段階2で次の3種類のバグについて尋ねています（`ROOT/prompts/d-stage2.txt`）。
1. 型式の解析結果が、演算子順位の表と食い違う入力がある。
2. parse、publish、traverse のいずれかが、SyntaxError 以外の例外を投げる入力がある。
3. parse、publish、traverse のいずれかが、終わらない入力がある。

段階4の終わりに、被験側には `ROOT/prompts/d-stage4-done.txt`（または時間切れの `d-stage4-timeout.txt`）で、種類ごとに「検知できる」「未検証」のどちらかでまとめるよう頼んでいます。
段階4の始まりの文面は `ROOT/prompts/d-stage4.txt` です。

## 読んでよいもの・読んではいけないもの
ROOT は `/Users/kuniwak/Documents/vibe-fm-expt` です。
- 読んでよい：`ROOT/prompts/`、`ROOT/runs/run-NN/analysis/messages.md`、`ROOT/runs/run-NN/analysis/operator.md`、`ROOT/runs/run-NN/record/metadata.txt`、`ROOT/runs/run-NN/record/driver-summary.json`。
- 読んではいけない：`ROOT/reference/`、`ROOT/confirm/`、`ROOT/runs/run-NN/confirm/`、`ROOT/analysis/`、ほかの作業者の出力、このディレクトリの外の scratchpad。正解や確認の結果を見ると、抜き出しが偏るためです。
- ファイルを書き換えないでください。書くのは出力先だけです。

## 対象
run-27、28、29、30、31、32、39、40、41、43、44、45。
run-30 と run-32 は全体の時間切れで打ち切られています。報告がない時点は「欠測」と書いてください。

## 抜き出す時点
- **段階4の終わり（4end）**：段階4の終わりの文面（「ここまでの結果を、種類ごとに…」）への被験側の返答。
- **段階3の終わり（3end）**：段階4の始まりの文面（「検知できなかった種類のバグを…」）が送られる直前の、被験側の最後の発言。発言の境目と、利用者役が送った文面は `messages.md` の `U` 番号の項と `operator.md` で確かめてください。

## 出力
出力先：`OUT/run-NN.tsv`（run ごとに1ファイル）と `OUT/notes.md`。
TSV の列（タブ区切り、1行目は見出し）：

`run	point	kind	category	msg	quote	note`

- `point`：`3end` か `4end`。
- `kind`：1、2、3。
- `category`：被験側が書いた区分を、原文の語のまま書く（「検知できる」「未検証」など）。原文に種類ごとの区分の語がなければ「記述なし」。区分の語はあるが、どの種類のことか、どの区分かが原文から決められなければ「決められない」。欠測なら「欠測」。言い換えや推測で区分を作らないでください。
- `msg`：発言番号（`#N`）。
- `quote`：その判断の根拠になる原文の一節（そのまま。改行は ` / ` に置き換える）。
- `note`：限定や条件がついていれば（「〜の範囲で」「〜を除いて」など）その原文。迷った点。

`notes.md` には、run ごとに迷った点と、その理由を書いてください。
最後に、全 run の `4end` の区分を表にして報告してください（1000字程度まで）。
