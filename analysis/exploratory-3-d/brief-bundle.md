# 発見の束ねの依頼（条件D、D2、run-27〜run-32）

ROOT は `/Users/kuniwak/Documents/vibe-fm-expt`。
被験側（コンテナ内の Claude Code）が JavaScript の型式パーサー jsdoctypeparser を検証した6回分（条件D、D2）の記録から、run ごとに「発見の台帳」ができている。
条件D、D2 は段階に分けた手順で進んだ（`ROOT/preregistration.md` の 11.2〜11.4。ほかの節、とくに 11.8 の予測は読まない）。段階2で、人間が3つのバグの種類と演算子順位の表（`ROOT/prompts/d-stage2.txt`）を渡している。
あなたは、発見を run をまたいで束ね、欠陥の断定の差を表にする。
判定（良し悪し、仮説の支持）はしない。

## 最初に読むもの

- 規則：`ROOT/analysis/exploratory-3-ledger-rules.md`。全体を読み、末尾の変更の記録（変更1〜3、系列2への適用、変更4、変更4の追記、変更4の追記2）まで従う。とくに変更2の1、変更3の1〜3、変更4の4、5、9〜11、追記の6〜8。
- 書式の手本：`ROOT/analysis/exploratory-3-s2/findings-bundled.tsv` と `ROOT/analysis/exploratory-3-s2/assertions.tsv`（系列2の A 系の束 V1〜V27）。対応づけのために中身も読む。

## 入力

`ROOT/analysis/exploratory-3-d/runs/run-NN/` の `findings.tsv`（元の作業者）と `findings-indep.tsv`（独立の作業者。oracle_class、asserted_defect、later_human_table）。
内容を確かめる必要があれば、`ROOT/runs/run-NN/analysis/messages.md` と `record/transcripts/*.jsonl` を読んでよい。

## 束ね方の追加

- 段階1の発見と段階2〜4の発見は、同じ入力の形でも、束の中で段階の列（`stage`）を分けて示す。集計は段階1と段階2〜4に分ける。
- 段階1は A 系と並べる枠なので、A 系の束（V1〜V27）と同じ入力の形なら `s2a_bundle` の列に対応を書く。

## 読まないもの

- `ROOT/analysis/series2-table2/`、`ROOT/analysis/series2-d-confirm/`、`ROOT/reference/`、`ROOT/confirm/`、`ROOT/runs/run-NN/confirm/`、`ROOT/runs/run-33` 以降。
- `runs/run-NN/analysis/` のうち `messages.md`、`commands.md` 以外。
- scratchpad の、指定した出力先以外。

## してはいけないこと

- docker を使わない。成果物を実行しない。ROOT の中を作成、変更、削除しない。
- 出力は指定した出力ディレクトリにだけ書く。Write が拒否されたら回避せず、返答に含める。一時ファイルも出力ディレクトリの中に置く。

## 出力

出力ディレクトリ：`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/bundle3/`

1. `findings-bundled.tsv`：系列2の A 系と同じ列に、最後に `stage`（その束に含まれる発見の段階。例 `1`、`3`、`1;3`）、`s2a_bundle`（A 系の同じ入力の形の束。なければ `—`）、`later_human_table`、`indep_disagreement`（元と独立で値が食い違った行の id と両方の値）を足す。束の id は W1、W2…。`author_judgement` は空欄。
2. `assertions.tsv`：系列2の A 系と同じ列に `stage` を足す。束ごと、run ごとに、固定発言より前に欠陥と断定した行だけ。`gap_oracle` は変更2の1、変更3の2、変更4の5、追記の6、7で決める。2つの値になるもの、独立の作業者の値で結果が変わるものは、`note` に両方を書く（どちらにも寄せない）。
3. `notes.md`：束ねで迷った点と、A 系の束との対応で迷った点。

## 最後に返すもの（300〜500字）

- 束の数と、各束の run の数（段階1、段階2〜4 別）。
- 断定のうち `gap_oracle` が「超えた」のもの（束、run、段階）。2つの値になったもの。
- 元と独立の食い違いで、結果が変わるもの。
- 迷った点。
