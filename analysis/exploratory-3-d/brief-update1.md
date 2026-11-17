# 台帳の更新の依頼（変更4の追記）

規則に「変更4の追記」が加わった（`ROOT/analysis/exploratory-3-ledger-rules.md` の末尾。ROOT は `/Users/kuniwak/Documents/vibe-fm-expt`）。
まずそれを全部読み、担当の run の台帳を更新する。依頼文（brief.md）の制約（読まないもの、してはいけないこと、出力先）はそのまま有効である。

## 手順

1. 更新前のファイルを `claims-v1.tsv`、`findings-v1.tsv`、`boundary-v1.md` として同じディレクトリに複製する。
2. `claims.tsv` の列 `target_gap_a`、`target_gap_b` を、`gap_weak`、`gap_strong`、`limit_in_message`、`first_reading` の4列に置き換える（位置は元の2列の場所、この順）。
   - 検知の主張の行（`claim_kind = 検知力`。肯定も否定も、実在の違反を根拠にしたものも）すべてに、追記の1〜3で `gap_weak`、`gap_strong`、`limit_in_message` を書く。値は差の5語彙（超えた、両論、なし、証拠なし、不明）。
   - `first_reading` は空欄のままにする（別の読み手が書く）。
   - 検知の主張でない行は4列とも `—`。
   - 検知の主張の行で、旧4の7のために `gap_object` などに入れていた値は、追記の4のとおり見直す。
3. 追記の5：段階2以降で性質が人間の表か種類である成立の主張は、`intent_check` を「人間が与えた」にする。
4. 追記の6、8：発見の断定（`asserted_defect`）を見直す。人間の表とリポジトリ内のオラクルが逆で断定がある発見は、`note` に2つの値を書く。
5. `findings.tsv` の末尾に列 `later_human_table` を足す。段階1の発見に、合う、合わない、表の対象外、を書く（表は `ROOT/prompts/d-stage2.txt`）。段階2以降の発見は `—`。
6. `issues` の列：検知の主張の行は `4-7` の代わりに `4a-1` と書く。変えた値に関わる行にも、該当する追記の番号（`4a-5`、`4a-6`、`4a-7`、`4a-8`）を足す。
7. `boundary.md` に、追記で解決した境界例はそう書き、新しく迷った点を足す。

## 返すもの（日本語、200〜400字）

- 検知の主張の行の数と、「両方の読みで内側」「強い読みでだけ超える」「弱い読みでも超える」の件数（`limit_in_message` のあり、なし別）。
- `intent_check` を変えた行の数、断定を変えた発見（id と理由）、`later_human_table` の内訳。
- 新しく迷った点。
