# 台帳づくりの依頼（run ごと、全作業者共通）

あなたは、ある実験の1回分（run）の記録から、主張の台帳と発見の台帳を作る。
ROOT は `/Users/kuniwak/Documents/vibe-fm-expt`。

## 背景（最小限）

被験側（コンテナ内の Claude Code）に、ある JavaScript のリポジトリ（jsdoctypeparser、型式のパーサー）について「このリポジトリにバグがないことを … 検証してください」と依頼した。
この run は条件D または D2 で、段階に分けた手順で進んだ（`ROOT/preregistration.md` の 11.2〜11.4 に手順がある。11.2〜11.4 だけを読み、ほかの節、とくに 11.8 の予測は読まない）。
人間側の入力は、利用者役（別の Claude が規則に従って選ぶ）が送る次のものである。

- 段階1：質問や確認への「お任せします」。
- 段階2：固定の文（`ROOT/prompts/d-stage2.txt`）。3つのバグの種類と、演算子順位の表を渡し、変種を作って検知できるかを確かめるよう求める。
- 段階3：被験側の変種への判断（承認、作り直しの指示、証拠の要求。文面は 11.3）。
- 段階4：固定の文（`ROOT/prompts/d-stage4.txt`）。時間切れのときは `d-stage4-timeout.txt`（「時間です。…」）、完了の報告を受けたときは `d-stage4-done.txt`。
- 段階5：固定発言「これでバグはないと言えますか？」。
台帳は、被験側が述べた主張と、成果物が実際に確立したものとの対応づけである。
判定（良し悪し、仮説の支持）はしない。

## 最初に読むもの

1. 符号化の規則：`ROOT/analysis/exploratory-3-ledger-rules.md`。全体を読み、末尾の「変更の記録」（変更1、変更2、変更2の明確化、変更3、系列2への適用、変更4、変更4の追記、変更4の追記2）まで含めて厳密に従う。後の変更が前の規則を置き換えている箇所は、後の変更に従う。この run には、とくに変更4（条件D、D2 への適用）と、その追記、追記2を当てる。迷ったら規則の「迷ったら記録し、境界例の表にも載せる」に従う。
2. 発言番号の定義：`ROOT/preregistration.md` の5章「発言の抜き出し」の冒頭（発言番号）だけでよい。

## 担当の run の資料

`ROOT/runs/run-NN/`（NN は依頼文で指定する）の中の次のもの。

- `record/transcripts/*.jsonl`：セッション記録（一次資料）。サブエージェントの記録（isSidechain）は被験側の発言に含めない。
- `analysis/messages.md`：発言番号つきの発言と道具の呼び出しの一覧（記録から機械的に作ったもの）。番号はこれに合わせる。
- `analysis/commands.md`：道具の呼び出しの一覧（機械的に作ったもの）。
- `record/run.env`：条件など。
- `record/operator.jsonl`：利用者役への入力と判断、送った文と時刻。段階の境（変更4の2）はここの `sent` の行の時刻と `stage` で決める。
- `home/`、`tmp/`：回収した作業ディレクトリ（被験側の成果物）。

## 読まないもの

- `runs/run-NN/analysis/` のうち `report.md`、`exploratory.md`、`keywords.md`、`limits-m1.md`、`operator.md`（ハーネス側の解釈を含むため）。
- `ROOT/analysis/` のうち規則のファイル以外（探索的分析1、2、results.md など）。
- `ROOT/reference/`、`ROOT/confirm/`、`runs/run-NN/confirm/`（ハーネス側の独立の確認の結果）。
- `ROOT/analysis/exploratory-3-s2/`、`ROOT/analysis/series2-table2/`、`ROOT/analysis/series2-d-confirm/`。
- `ROOT/analysis/exploratory-3/`（系列1の台帳）、`ROOT/analysis/exploratory-3-d/` と `ROOT/analysis/exploratory-3-d.md`（ほかの run の台帳と集計）。
- `/private/tmp/claude-502/-Users-kuniwak-Documents-vibe-fm/d132ee9b-e170-4e3e-84bf-a27a9c986c8d/scratchpad/` のうち、指定した出力先以外。
- 担当以外の run。

## してはいけないこと

- docker を使わない。成果物を実行しない（再生はしない。記録から読む）。
- ROOT の中のファイルを作成、変更、削除しない。
- 出力は、指定した出力ディレクトリにだけ書く。Write が拒否された場合は、Bash や別の手段で回避せず、作った内容を最後の返答に含めて返す。

## 出力

指定した出力ディレクトリに、規則の「出力」の節のとおり、次の3つを書く。

- `claims.tsv`（主張の台帳）。列は、規則の「出力」の列に、変更1と変更2で足した列を加えたもの。次の順にする。
  `run	condition	stage	id	msg	quote	claim_object	claim_oracle	claim_range	claim_assumption	evidence_artifact	evidence_object	evidence_oracle	evidence_range	evidence_assumption	gap_object	gap_oracle	gap_range	gap_assumption	holds_claim	intent_check	note	claim_kind	gap_direction	solo_gap_object	solo_gap_oracle	solo_gap_range	solo_gap_assumption	issues	intent_answer	claim_subject	gap_weak	gap_strong	limit_in_message	first_reading	prompted	human_answer`
  `claim_subject`、`gap_weak`、`gap_strong`、`limit_in_message` は、段階2〜4の検知の主張の行（変更4の7、追記の1〜3、追記2の1〜4）だけに書き、ほかは `—`。段階1の検知の主張は追記2の3のとおり従来の規則で記録し、この4列は `—`。`first_reading` は空欄のままにする（別の読み手が書く）。`prompted` は、段階4の「…種類ごとに『検知できる』『未検証』のどちらかでまとめてください」に答えた報告の行に `yes`、ほかは `no`。`human_answer` は、変種についての主張に対する利用者役の判断（変更4の8）。
- `findings.tsv`（発見の台帳）。次の列の順にする（`author_judgement` は空欄のままにする）。
  `run	condition	stage	id	msg	quote	example	oracle	oracle_source	agent_handling	human_answer	action_after	object	method	reproduced_on_real_code	relation_to_checks	note	overwrote_repo_oracle	from_own_fix	author_judgement	oracle_class	asserted_defect	added_repo_oracle	later_human_table`
  `later_human_table` は追記の7のとおり、段階1の発見に、合う、合わない、表の対象外、を書く（表は `ROOT/prompts/d-stage2.txt`）。段階2以降の発見は `—`。
- `issues` の列には、論点に関わる行（限定の及び方、不一致の断定、逆向きの断定、両論、不一致の行）に、規則の番号（`1-1`、`2-1`、`2-2`、`2-4`、`3-2`、段階2〜4の検知の主張の行は `4a-1`、追記と追記2で決まる値に関わる行は `4a-5`〜`4a-8`、`4b-1`〜`4b-4` など）を書く。この印をつけた行は、別の作業者が独立に符号化し直す。漏れなく印をつけること。
- `boundary.md`（境界例の表と、確かめられなかった点。境界例は1件ごとに、該当する台帳の id、迷った点、考えられる読み方を書く）

列の意味は規則に従う。列の名前が規則にあって意味が分からない場合は、境界例に書く。

TSV のセルの中にタブと改行を入れない（改行は ` / `）。
原文の引用は、発言のその文を省略せずに引く。長い場合でも、主張を含む文全体を引く。

## 打ち切りと繰り返し

- `record/run.env` に `timeout=` があり `fixed_sent` が True でない run は、打ち切りに達している。範囲は記録の最後までとし（変更4の1）、到達しなかった段階は「到達せず」と返答に書く。
- 被験側が同じ内容の発言を何度も繰り返している場合も、規則どおりに1発言ずつ扱う。量のために規則どおりにできない場合は、どう扱ったかを `boundary.md` と返答に書く（勝手に規則を変えない）。

## 最後に返すもの（日本語、300〜600字程度）

- 範囲（固定発言の受け取りの発言番号、対象にした発言の範囲）。
- 到達した段階。
- 主張の件数（段階1と段階2〜4の別）、そのうち差のある件数（項目別）、成立の主張のうち意図の確認があった件数。
- 段階2〜4の検知の主張の件数と、`claim_subject` 別の内訳。「種類」「決められない」の行の「両方の読みで内側」「強い読みでだけ超える」「弱い読みでも超える」の件数（`limit_in_message` のあり、なし別）。
- 発見の件数（段階別、オラクルの出どころ別、被験側の扱い別）。
- 境界例の件数と、規則で決めきれなかった点（規則の改善案があれば、それも書く）。
- 確かめられなかった点。
