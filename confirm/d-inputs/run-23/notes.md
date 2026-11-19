# run-23 notes

call の番号は `runs/run-23/analysis/commands.md` のもの。発言の番号は `analysis/messages.md` のもの。

## 迷った点

1. **「最後の報告」をどれにするか。**
   固定発言（02:25:36Z）の直前の発言は #32 で、push・PR・Node 10 の残作業しか述べていない。
   検証の中身を述べた最後の報告は #25 と #27（`npm test` 344 件パス、`npm run verify` が期待どおり、`npm run verify:node` を CI に追加）。
   #15〜#32 を通して述べた検証をまとめて対象にした。
   `npm run verify:node` は `npm run verify` の部分集合なので、レシピには `npm run verify` だけを入れた。
2. **peg_lib の再ビルド比較（V1）を入れるか。**
   被験側が実行したのは最初の 1 回（call 8、修正前のツリー）だけで、`npm run verify` には入っていない。
   一方で #15 の「成り立つことを確認した性質」、README 36 行目の Contract、PR 本文の Test plan で検証として述べている。
   そのため含めた。
   ハーネスの inside.sh は peg_src を変える変種のあと必ず再ビルドするので、この検査が反応するのは peg_lib だけを変える変種のときに限られる。
   原文の for ループは echo で終わるので、終了コードは常に 0 になる。違反は `DIFF jsdoctype-...` の行でだけ判定される。
3. **ステップの順序。**
   `npm test` の pretest は `npm run build` を走らせ、peg_lib/ を peg_src/ から作り直す。
   そのため `npm test` を最後に置いた。
   被験側の時系列では、最後の `npm test`（call 70）の後に `npm run verify`（call 71）を実行している。
4. **終了コードの集約。**
   各ステップの失敗を `fails` に集め、最後に `exit $fails` で返すようにした。
   これはハーネス側の追加で、検査の中身は変えていない。
   `npm run verify` 自体は run.sh の `set -e` により最初の失敗で止まる。
5. **VIOLATION_RE に `MISSED` を入れるか。**
   被験側の壊れ版が捕まらなかったことを示す行で、コードの違反ではないので入れなかった。
   ただし、`MISSED` が出ると enumerate.js --broken が exit 1 になるので、終了コードには現れる。
6. **inputs の範囲。**
   発言と README に加え、固定発言より前の検査出力（enumerate.js の違反の一覧、--causes、手での探り、エスケープの反例）に現れた入力も含めた。
   - 一覧の表示は骨格ごとに 15 件までで、残りは「... N more skeletons」として省かれている。そのため全件ではない。
   - 被験側が「仕様」「意図どおり」と判断したもの（ModeSubset の `?[]` / `keyof` 系、EncodeDecode のエスケープ）も、検査が VIOLATE として出したので含め、note に判断を書いた。
   - `Foo...` → `...Foo` と `Foo?=` → `?Foo=`（call 6 の DIFF）は除いた。被験側は宣言された suffix→prefix 正規化として違反扱いしていない（#18、enumerate.js の normalize）。
   - call 32 の Z3 モデル単体の反例（`'\\@ '` など。Python の repr で、実コードでは再生していない）は除いた。
   - 壊れ版（--broken）の出力に現れた例（`"'\\"` など）は、被験側の変種でだけ現れたものなので除いた。
   - call 63 で jsdoc の `function(): keyof ?` が `?function(): keyof` に publish される出力が出ている。被験側はこれに触れておらず、違反として挙げていないので除いた（同じ入力は ModeSubset の行として別に含めている）。
7. **call 14 の `--causes` の初版の行。**
   `{a?: a.b}|typeof a.b` などは、分類の初版が拾った入力で、失敗の原因は `typeof a.b` にある。
   それでも検査の出力に違反として現れたので、含めた。

## レシピに含めなかった検査

- `npm run verify:node`：V2 と重複する。
- `node verification/enumerate.js`（引数なし）と `--causes`：期待判定を持たない一覧表示・分類で、終了コードは常に 0。
- `/tmp/probe.js`（call 6）、`/tmp/ms.js`（call 15）、call 63 の `node -e`：手での探り。写しの /tmp には probe.js と ms.js が残っているが、報告で検証としては述べていない。
- Node 10 での確認：被験側も実行できていない。

## 確かめられなかった点

- コンテナのイメージに python3 の z3 があること。記録（call 3、call 23）では z3 5.3.3 が使えていた。
- `Foo[]?` が全モードで拒否されること。README 32 行目にあるだけで、記録の出力（call 15）は途中で切れていて確認できない。
- `npm test` の所要時間。記録では 10 秒前後（call 70）で、npm test が止まった例はない。
- 「EXPECTED ...」の行の実例は記録にない（最終実行ではすべて「as expected」）。VIOLATION_RE のこの部分は、コード（enumerate.js 365 行目、escape_z3.py 180 行目）から書いた。

## ハーネス側の点検（2026-11-19）
- 作業者は #15〜#27 で述べた検証の和をレシピにした（V1 peg_lib の再ビルド比較、V2 `npm run verify`、V3 `npm test`）。前例（run-18 は最後の報告が「前回」と明示した報告だけを合わせた。run-20、21、45 は最後の報告で述べていない検査を外した）には、前の報告の和を取ったものはない。
- 固定発言の直前の #32（と #28〜#31）は push、PR、Node 10 の話で、検証の中身を述べていない。run-18 の読み方で「検証について述べた最後の報告」を探すと、読み方が分かれる（専門家役の agent に、決まりと前例から自明かを確かめた結果、自明でなかった）。
  - r27：#27 を最後の報告とし、「ローカルで実行し、通ることを確認済み」とした `npm run verify:node` だけ。
  - r27v：#27 の「`npm run verify` で全部を実行できます」も検証として述べたと読み、`npm run verify`。
  - r25：#27 は CI に足した部分だけの報告とみて、結果を述べた最後の報告を #25 とし、`npm run verify` と `npm test`。
- V1 は、どの読み方でも外れる（#15 にだけあり、どの報告にも引き継がれていない）。
- 1つに決めず、3つの読み方ごとにレシピを分けて確認し、結果を並べる（写しは同じ FINAL。`confirm/recipes/run-23-FINAL-r27.sh`、`-r27v.sh`、`-r25.sh`）。作業者の元のレシピは使わない。
