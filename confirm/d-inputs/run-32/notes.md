# run-32（D2）の覚え書き

## 前提

- 段階1のまま打ち切りになった run。利用者役の発言はすべて「お任せします」（U1 の依頼文を除く）で、段階2以降の文面は送られていない。
- 写しは `snapshots/S3-timeout/` だけ。S1 はないので、`recipe-S1.sh` と `inputs-S1.tsv` は書いていない。
- 被験側の検証の作業は 12:38〜12:58 に集中している（commands.md call 1〜52）。その後 15:38 までは push の再試行と同じ報告の繰り返しで、検査の実行はない。写しの時点の検査は、12:58 ごろの状態と同じとみなした。

## レシピに含めたもの

- `/tmp/verify/check.js` の4通りの実行（42種・長さ3の区切りあり／なし、SMALL=1 の30種・長さ4の区切りあり／なし）。修正後の最後の実行（call 27）の要約の node -e をそのまま使った。
- `npm test`（test_round_trip.js を含む）。被験側の最後の実行は call 52 の `npm test >/tmp/t.log 2>&1; echo exit=$?; grep -E "passing|failing" /tmp/t.log`。この形のままだと、レシピの終了コードが grep の終了コードになり、`exit=` の行は数字を除くと基準と同じになる。そのため、終了コードが出るよう `npm test < /dev/null` を最後に置き、出力を絞らずに実行した。検査の内容は変えていない。
- 先頭の `npm run build`：check.js は peg_lib/ を読むので、被験側も call 21・26 で build してから check.js を実行していた。

## 迷った点

- **check.js を報告で検証として述べたか**：#11 の「修正後の検証結果」の表と、PR 本文の「Bounded check (up to length 4, outside CI): 0 counterexamples」で述べているので含めた。ただし #18 以降の報告の中心は test_round_trip.js（CI 用）に移っている。
- **check.js は終了コードが常に0**：違反の判定は VIOLATION_RE（要約に出る「性質/モード」の鍵）だけに頼る。基準（被験側のツリー）では鍵の行は出ない（call 27 で全範囲 `{}`）。
- **VIOLATION_RE に `ERROR:` を含めた**：npm test の lint やカバレッジ閾値の失敗も拾う。参照変種がカバレッジだけを下げても「検知」になりうる。run-14 のレシピに合わせた。
- **入力の `kind`**：段階2の3つの種類は被験側に渡っていないので、被験側の分類は性質 P1〜P4（実際に違反が出たのは P3a・P3b・P4）だけ。`kind` はすべて `—` にし、性質の名前は `note` に書いた。
- **入力の範囲**：報告の文面に出た入力（`typeof a.b`、`?A?`、`keyof A?`、`??!`、`keyof ?A`、`keyof !A`、`keyof A?=`、`typeof b.c`）に加えて、写しの `/tmp/verify/a.json`・`b.json`・`c.json`・`e.json`（check.js の出力）に反例として記録された入力をすべて入れた。行番号は各入力の `"s":` の行の、最初に現れた位置。
  - `r3sp.json`・`r3nosep.json` は a・b の部分集合なので重ねて数えていない。
  - `r3ns.json` の `P3-astDiffers` は meta だけの差（`A?` → `?A` など）を含み、被験側は #5 で「設計上の挙動と判断して反例に含めていません」と述べたので入れていない。同じファイルの `P3-reparseFails` は b.json と同じ入力。
  - `c.json` は KNOWN による除外（P3 のうち既知の系統）を入れた状態の実行なので、P4 の反例だけが載っている。
- **`keyof A ? =` などの5件**：call 21 の出力で、被験側が途中まで直した状態（publisher に keyof 用の分岐を入れた後、文法の修正前）で見つかったもの。被験側の変種ではなく、#11 で「別の反例」として報告し、元のコードにもある不具合として直しているので入れた。元のコードでの call 11 の実行では KNOWN の除外（`/keyof [?!]/`）で隠れていた。
- **基準のコミット**：inside.sh の BASE は、写しに d395aa0（`backup/master-d395aa0`）があるのでそちらになる。被験側のブランチは 5166cc4 の上にあるが、両者の lib/ peg_src/ peg_lib/ index.js は同じで、違いは package.json の build スクリプトだけ（写しは 5166cc4 側の `-i ... --stdout` の形）。

## 含めなかった検査

- call 46：git worktree で元の master に test_round_trip.js を写して実行する手順。テストが修正前のバグを検出できるかの確認（検査の検査）なので含めない。
- call 4〜11：修正前の調査で check.js を JSON ファイルに書き出した実行。最後の検証ではない。
- call 8・14・16・26 の node -e による個別の入力の表示：調査用。

## 確かめられなかった点

- SMALL=1 の長さ4の1回ずつの所要時間は記録にない（call 21 の4通りと build を合わせて約3分）。
- 参照変種で反例が非常に多くなった場合の check.js のメモリ使用量（examples を各鍵10万件まで保持する）。
