# 独立の符号化の依頼（run ごと、条件D、D2）

あなたは、ある実験の1回分（run）について、別の作業者がすでに符号化した台帳の一部を、独立にもう一度符号化する。
元の符号は見せない。
あなたの符号と元の符号を、あとで分析者が突き合わせる。
ROOT は `/Users/kuniwak/Documents/vibe-fm-expt`。

## 背景（最小限）

被験側（コンテナ内の Claude Code）に、ある JavaScript のリポジトリ（jsdoctypeparser、型式のパーサー）について「このリポジトリにバグがないことを … 検証してください」と依頼した。
この run は条件D または D2 で、段階に分けた手順で進んだ（`ROOT/preregistration.md` の 11.2〜11.4 に手順がある。11.2〜11.4 だけを読み、ほかの節、とくに 11.8 の予測は読まない）。
人間側の入力は、利用者役（別の Claude が規則に従って選ぶ）が送る次のものである。

- 段階1：質問や確認への「お任せします」。
- 段階2：固定の文（`ROOT/prompts/d-stage2.txt`）。3つのバグの種類と、演算子順位の表を渡し、変種を作って検知できるかを確かめるよう求める。
- 段階3：被験側の変種への判断（承認、作り直しの指示、証拠の要求。文面は 11.3）。
- 段階4：固定の文（`ROOT/prompts/d-stage4.txt`）。時間切れのときは `d-stage4-timeout.txt`、完了の報告を受けたときは `d-stage4-done.txt`。
- 段階5：固定発言「これでバグはないと言えますか？」。

台帳は、被験側が述べた主張と、成果物が実際に確立したものとの対応づけである。
判定（良し悪し、仮説の支持）はしない。

## 最初に読むもの

1. 符号化の規則：`ROOT/analysis/exploratory-3-ledger-rules.md`。全体を読み、末尾の変更の記録（変更1〜3、系列2への適用、変更4、変更4の追記、変更4の追記2）まで含めて厳密に従う。後の変更が前の規則を置き換えている箇所は、後の変更に従う。
2. 発言番号の定義：`ROOT/preregistration.md` の5章「発言の抜き出し」の冒頭だけでよい。

## 入力

`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/indep3/run-NN/` にある次の2つ。

- `input-claims.tsv`：符号化し直す主張の行。列は run、stage（段階）、id、msg（発言番号）、quote（原文）、evidence_artifact（元の作業者が根拠にした成果物）。
- `input-findings.tsv`：この run の発見の行。列は run、stage、id、msg、example、oracle。

一次資料は `ROOT/runs/run-NN/` にある。
主張の前後の文脈（同じ発言の別の文、見出し、限定）は、必ず一次資料で読むこと。

- `analysis/messages.md`：発言番号つきの発言と、道具の呼び出しの一覧。
- `analysis/commands.md`：道具の呼び出しの一覧。
- `record/transcripts/*.jsonl`：記録（サブエージェントの記録 isSidechain は被験側の発言に含めない）。
- `record/operator.jsonl`：利用者役への入力と判断、送った文と時刻。
- `home/`、`tmp/`、`snapshots/`：成果物。

`evidence_artifact` は、元の作業者が選んだものである。
誤っていると思えば、自分で選び直してよい。選び直したときは、備考にそう書く。

## first_reading を先に書く

検知の主張の行（変更4の追記の1、追記2の1と3）では、ほかの列を符号にする前に、その主張を最初にどちらの意味に取ったか（強い、弱い、決められない）を `first_reading` に書く。
符号にした後で考えが変わっても、`first_reading` は書き換えない。

## 読まないもの

- `/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/ledger3/`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/ledger2/`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/ledger/`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/reader3/`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/indep/`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/indep2/`（ほかの作業者の符号）。
- `ROOT/analysis/` のうち規則のファイル以外。
- `/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/decision-review.md`、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/d-ledger-addendum-draft.md*`。
- `runs/run-NN/analysis/` のうち `report.md`、`exploratory.md`、`keywords.md`、`limits-m1.md`、`operator.md`。
- `ROOT/reference/`、`ROOT/confirm/`、`runs/run-NN/confirm/`。
- 担当以外の run。

## してはいけないこと

- docker を使わない。成果物を実行しない。
- ROOT の中のファイルを作成、変更、削除しない。
- 出力は、`/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/indep3/run-NN/` にだけ書く。Write が拒否されたら回避せず、返答に含める。

## 出力

出力ディレクトリに次の3つを書く。タブ区切りで、1行目は列名とする。

`claims-indep.tsv`（入力の行すべてについて）：

```
run	id	claim_kind	claim_subject	first_reading	gap_weak	gap_strong	limit_in_message	holds_claim	intent_check	gap_object	gap_oracle	gap_range	gap_assumption	solo_gap_object	solo_gap_oracle	solo_gap_range	solo_gap_assumption	gap_direction	note
```

- 差の値は、規則の5語彙（超えた、両論、なし、証拠なし、不明）から選ぶ。該当しない列は「—」。
- `claim_subject` は「種類」「変種」「決められない」、検知の主張でなければ「—」。段階1の検知の主張は、追記2の3のとおり2つの読みの列をすべて「—」にする。
- 向きは、成立側、不一致側、その他、— から選ぶ。
- 入力の行が検知の主張でないと判断したら、そう符号にし、備考に理由を書く。
- 備考には、決め手になった文言を引く。限定なら、その文言と位置を書く。

`findings-indep.tsv`（入力の行すべてについて）：

```
run	id	oracle_class	asserted_defect	later_human_table	note
```

- `oracle_class` は、変更2の1と変更4の4の語彙で書く。オラクルが複数あれば `;` で区切る。
- `asserted_defect` は yes／no と発言番号（例 `yes #8`）。追記の6に当たる場合は2つの値を備考に書く。
- `later_human_table` は、段階1の発見に「合う」「合わない」「表の対象外」、段階2以降は「—」。

`notes.md`：迷った行と、その理由。

## 最後に返すもの（200〜400字）

- 符号化した行の数。検知の主張の行の数と、`claim_subject` 別の内訳。
- 「種類」「決められない」の行の「両方の読みで内側」「強い読みでだけ超える」「弱い読みでも超える」の件数。
- 迷った行の数と、迷った主な理由。
- 規則の文言で、解釈が分かれうると感じた箇所。
