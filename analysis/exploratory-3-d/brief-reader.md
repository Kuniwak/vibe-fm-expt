# 主張の読み取りの依頼

あなたは、ある作業の報告を受け取った利用者の立場で、報告の中の文を読み、最初にどういう意味に取ったかを記録する。
ROOT は `/Users/kuniwak/Documents/vibe-fm-expt`。

## 背景（最小限）

コンテナ内の Claude Code（以下、作業者）に、JavaScript のリポジトリ（jsdoctypeparser、型式のパーサー）の検証を依頼した。
途中で、人間が3つのバグの種類と演算子の優先順位の表を渡し、バグを埋め込んだ変種を作って、作業者の検証がそれを検知できるかを確かめるよう求めた。
作業者は、変種を作り、「検知できる」「検知できない」などと報告した。

## 入力

`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/reader3/input.tsv`：176行。列は run、id、msg（発言番号）、quote（報告の中の文）。

文脈は `ROOT/runs/run-NN/analysis/messages.md` で読む（NN は run の番号。発言番号 #N の見出しの下に、その発言の全文がある）。
1つの run の行を読む前に、その run の該当する発言の全文を、利用者が報告を読むように頭から読むこと。

## 記録すること

各行の quote を、その発言の中で読んだとき、最初にどちらの意味に取ったか。

- **強い**：その種類のバグ全体について述べていると取った（肯定なら「その種類のバグはどれも検知する」、否定なら「その種類のバグはどれも検知できない」）。
- **弱い**：確かめた事例（その変種、その違反）について述べていると取った。
- **決められない**：どちらとも取れて、最初の読みが定まらなかった。

最初の読みを書く。考え直して変えたくなっても、最初の読みを残し、考え直した内容は備考に書く。
正しい読みを決める作業ではない。読み手として自然に取った意味を書く。

## 読まないもの

- `ROOT/analysis/` の全体、`ROOT/preregistration.md`、`ROOT/reference/`、`ROOT/confirm/`。
- `runs/run-NN/analysis/` のうち `messages.md` 以外。`runs/run-NN/confirm/`。
- `/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/` のうち `reader3/` 以外（ほかの作業者の結果がある）。

## してはいけないこと

- ROOT の中のファイルを作成、変更、削除しない。docker を使わない。
- 出力は `/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/reader3/` にだけ書く。

## 出力

`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/reader3/first-reading.tsv`（タブ区切り、1行目は列名、入力の行すべて）：

```
run	id	first_reading	cue	note
```

- first_reading は「強い」「弱い」「決められない」のどれか。
- cue は、その読みの決め手になった語句（見出し、主語、表の列名など）を短く引く。
- note は、考え直した内容や迷った理由（なければ空）。

## 最後に返すもの（200〜400字）

- run ごとの、強い、弱い、決められないの件数。
- 決め手になりやすかった語句の型。
