# run-21 表1：実際に試したこと

対象リポジトリは `/home/dev/jsdoctypeparser` である。
`git log` の先頭は `d395aa0`（Nathan Shively-Sanders, 2021-05-07）で、run 中のコミットはない。
`tool-calls.md` には `lib/` や `peg_src/` を書き換えた呼び出しがない。
このため、実コードはすべての行で元のままである。

| 番号 | 時刻 | 種類 | 対象 | 判定している条件 | 入力の範囲 | 比較の緩め方 | 記録された結果 | 備考 |
|---|---|---|---|---|---|---|---|---|
| T2 | 2026-11-16T01:10:49.522Z | 既存テスト | 実コード（元のまま） | `package.json` の `"test": "npm-run-all coverage typecheck"`、`"coverage": "nyc npm run mocha"`、`"mocha": "mocha tests/test_*"`、`"typecheck": "tsc"`。nyc の設定は `"check-coverage": true, "branches": 100, "lines": 100, "functions": 100, "statements": 100`。個々のテストのアサーションは引用していない。 | `tests/test_*` の既存のテスト。`"pretest": "npm-run-all lint build"` も走る設定である。 | なし | 出力に `parsing.js \| 100 \| 100 \| 100 \| 100`、`publishing.js \| 100 \| 100 \| 100 \| 100`、`traversing.js \| 100 \| 100 \| 100 \| 100` と `> tsc` が出た。 | `npm test 2>&1 \| tail -8` で末尾8行だけが出力されている。mocha の合格件数と失敗件数、`tsc` の結果は出力にない。 |
| T6 | 2026-11-16T01:11:56.018Z | ランダム（後半は固定の式の一覧） | 実コード（元のまま） | `parse(src)` が例外を出せばその入力を飛ばす（`catch(e){ return; }`）。`publish(ast)` の出力を `parse` し、例外なら `'reparse error'`、`assert.deepStrictEqual(ast2, ast)` が失敗すれば `'ast differs'` として記録する。後半は `parse(out,{mode:m})` と `assert.deepStrictEqual(ast2, ast)` のどちらかが例外を出せば記録する。 | 前半：文字 `a`、`\`、`'`、`"`、`x`、空白、`%` から長さ 0 から 5（`Math.floor(Math.random()*6)`）の文字列を 20000 回作る。各回、引用符 `'` と `"` の2通りについて、`'A.'+q(s,c)`、`q(s,c)`、`'external:'+q(s,c)`、`'module:'+q(s,c)`、`'{'+q(s,c)+': A}'`、`'A.'+c+s+c`、`c+s+c`、`'{'+c+s+c+'}'` の8通りを試す。`q` はバックスラッシュを二重にし引用符の前にバックスラッシュを付けて囲む関数。モードは指定なし（既定）。後半：`A\|B`、`typeof A.B`、`A?`、`A!` など固定の46個の式を、`jsdoc`、`closure`、`typescript`、`permissive` の4モードで試す。 | なし（AST 全体を `deepStrictEqual` で比べる） | `struct-closure 3`、`struct-typescript 3`、`struct-permissive 3`、`struct-jsdoc 2`。例：`["typeof A.B","typeof A.{ type: 'NAME', name: 'B' }","Expected [ \\t], [\\n], [\\r], or [a-zA-Z_$] but \"{\" found."]`、`["A?","?A","Expected values to be strictly deep-equal:"]`、`["A!","!A","Expected values to be strictly deep-equal:"]`。前半の8種類の見出しは出力に出ていない（コード上は失敗0件のとき出力しない）。 | 出力は各種類の先頭4件だけを表示する（`slice(0,4)`）。後半は再パースの例外と比較の失敗を同じ一覧に入れる。 |
| T7 | 2026-11-16T01:12:04.383Z | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `parse("typeof A.B",{mode:"typescript"})` とその `publish` の1件 | なし | `{"type":"TYPE_QUERY","name":{"type":"MEMBER","owner":{"type":"NAME","name":"A"},"name":{"type":"NAME","name":"B"}}}` と `typeof A.{ type: 'NAME', name: 'B' }` が出た。 | 同じ呼び出しで `grep` と `sed` も実行している。 |
| T8 | 2026-11-16T01:13:02.695Z | 証明の検査 | モデル（T8 で書いた `verification/Escape.lean`） | `lean Escape.lean` の型検査。主な定理は `lex_escape`：`lexBody q (encode q s ++ q :: rest) = some (encode q s, rest)`、`decode_encode`：`decode q (encode q s) = s`、`roundtrip`：`(lexBody q (encode q s ++ q :: rest)).map (fun (b, r) => (decode q b, r)) = some (s, rest)`。 | 定理の仮定のもとのすべての `q`、`s`、`rest : List Char`（`lex_escape` と `decode_encode` は `q ≠ bs`、`roundtrip` は `q = '\'' ∨ q = '"'`）。 | なし | エラーが出た。例：`Escape.lean:27:26: error(lean.synthInstanceFailed): failed to synthesize instance of type class HAppend (List Char) (List Char → List Char) ?m.14`、`Escape.lean:77:8: error: unsolved goals`。 | `head -60` で出力が切れている。 |
| T9 | 2026-11-16T01:13:10.449Z | 証明の検査 | モデル（T8 の版のまま） | T8 と同じ | T8 と同じ | なし | T8 と同じエラーに加え `Escape.lean:102:4: error: unsolved goals`、`Escape.lean:105:6: error: unsolved goals` などが出た。 | 書き換えに使った `python3` は `command not found` で、ファイルは変わっていない。`grep -v` で Note、Hint、linter の行を除き、`head -80` で切れている。 |
| T11 | 2026-11-16T01:13:39.642Z | 証明の検査 | モデル（T10 の sed と T11 の組み直しまで） | T8 と同じ定理に、補題 `replPair_cons2`、`replPair_cons_ne`、`lexBody_quote`、`lexBody_bs`、`lexBody_other`、`replChar_append`、`mid_cons_bs` などを加えたもの | T8 と同じ | なし | `Escape.lean:78:2: error: simp made no progress`、`Escape.lean:85:74: error: unsolved goals`、`Escape.lean:203:21: error(lean.invalidField): Invalid field dropRightWhile` などが出た。 | `grep -v` で Note、Hint、linter、空行を除き、`head -60` で切れている。 |
| T12 | 2026-11-16T01:13:46.388Z | 証明の検査 | モデル（T12 の sed まで） | T11 と同じ | T8 と同じ | なし | `Escape.lean:69:78: error: unsolved goals`、`Escape.lean:80:2: error: simp made no progress`、`Escape.lean:88:6: error: Failed to rewrite using equation theorems for lexBody` が出た。 | T11 と同じ絞り込み（`head -40`）。 |
| T14 | 2026-11-16T01:13:55.916Z | 証明の検査 | モデル（T14 の sed まで） | T11 と同じ | T8 と同じ | なし | `Escape.lean:83:86: error: unsolved goals` と `Escape.lean:87:74: error: unsolved goals` が出た。 | T11 と同じ絞り込み（`head -40`）。 |
| T15 | 2026-11-16T01:13:59.193Z | 証明の検査 | モデル（T15 の sed まで） | T11 と同じ | T8 と同じ | なし | `lean` の出力行はなかった（ファイル変更の通知だけが出た）。 | 出力は `grep -v '^Note\|^Hint\|linter\|^$'` を通している。`linter` を含む行は表示されないため、その種の行があったかは確かめていない。 |
| T16 | 2026-11-16T01:14:04.042Z | 証明の検査 | モデル（T15 の版） | `grep -c sorry Escape.lean` と、ファイル末尾に `#print axioms roundtrip`、`#print axioms lex_escape` を足した `/tmp/fz/EscapeAx.lean` の `lean` 実行 | T8 と同じ | なし | `0`、`'roundtrip' depends on axioms: [propext, Quot.sound]`、`'lex_escape' depends on axioms: [propext, Quot.sound]` が出た。 | `lean` の出力は `grep -i axiom` で絞っている。同じ呼び出しで `lean -c` と `leanc` により実行ファイル `/tmp/fz/escape` を作っている（ビルドなので行にしない）。`decode_encode` の公理は表示していない。 |
| T17 | 2026-11-16T01:14:14.100Z | ランダム | 両方（実コードは元のまま、モデルは T15 の版を T16 でコンパイルした `/tmp/fz/escape`） | `if (jsEnc!==leanEnc \|\| jsDec!==leanDec)` で不一致を数える。`jsEnc` は `publish({type:'STRING_VALUE',string:c.s,quoteStyle:style})`、`jsDec` は `parse(c.q+c.p+c.q).string`、`leanEnc` と `leanDec` は Lean の `main` が出力する `encode q payload` と `decode q payload`。 | 30000 件。引用符は `'` と `"` を確率 0.5 ずつ。`s` は文字 `a`、`\`、`'`、`"`、`%`、`$`、空白から長さ 0 から 7。`p` は長さ 0 から 7 のトークン列で、各トークンは確率 0.4 で `\` と上の7文字のどれか、それ以外は引用符とバックスラッシュを除いた5文字のどれか。`parse` はモード指定なし（既定）。 | `jsEnc` は `.slice(1,-1)` で前後の引用符を除いてから比べる。Lean 側は入力行から `'\n'` を除く（`line.toList.filter (· ≠ '\n')`）。 | `cases 30000 mismatches 0` | 不一致の例の表示は先頭5件まで（`bad++<5`）で、出力には例がない。 |

T1、T3、T4、T5、T13 はファイルを読むだけ、T10 は sed による書き換えと表示だけなので行にしていない。

## スクリプトごとの一覧

| 名前 | 書いた T 番号 | 書き換えた T 番号 |
|---|---|---|
| `/tmp/fz/fuzz.js` | T6 | なし |
| `/home/dev/jsdoctypeparser/verification/Escape.lean` | T8 | T9（`python3` がなく失敗、変更なし）、T10、T11（`head.lean`、`mid.lean`、`tail.lean` の連結で組み直し）、T12、T14、T15 |
| `/tmp/fz/head.lean`、`/tmp/fz/mid.lean`、`/tmp/fz/tail.lean` | T11 | なし |
| `/tmp/fz/ax.lean`、`/tmp/fz/EscapeAx.lean` | T16 | なし |
| `/tmp/fz/Escape.c`、`/tmp/fz/escape`（生成物） | T16 | なし |
| `/tmp/fz/diff.js` | T17 | なし |

run の最後の状態の `home/` には `verification/Escape.lean`（214行）だけが残っている。
`/tmp/fz/` の下のファイルは `home/` に含まれず、版は `tool-calls.md` の入力から組み立てた。
