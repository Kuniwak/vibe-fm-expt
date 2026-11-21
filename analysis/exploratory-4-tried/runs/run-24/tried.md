# run-24 表1：実際に試したこと

根拠は `runs/run-24/analysis/tool-calls.md`、`runs/run-24/home/` の最後の状態、対象リポジトリ `home/dev/jsdoctypeparser` の `git log` だけである。
`git log` の先頭は `d395aa0` で、run の中のコミットはない。
`/tmp/fuzz/` のファイルは `home/` に残っていないため、その中身は `tool-calls.md` の `Write` と `cat <<EOF` と `sed` の入力から組み立てた。
`formal/JsdocTypeParserFormal.lean` の最後の状態は、T31、T34、T35、T37、T39、T40、T41、T42 の入力から組み立てた版と、定理の並びと `conv => lhs; rw [wf]`、`; rfl` の位置で一致した。
1回の呼び出しで複数の検査を実行したものは、検査ごとに行を分け、番号の後ろに括弧で区別を付けた。

## 表

| 番号 | 時刻 | 種類 | 対象 | 判定している条件 | 入力の範囲 | 比較の緩め方 | 記録された結果 | 備考 |
|---|---|---|---|---|---|---|---|---|
| T3(1) | 2026-11-16T02:29:31.290Z | 既存テスト | 実コード（元のまま） | 既存の mocha テストの各 `expect`（`npx mocha tests`） | `tests` の既存テスト | なし | `335 passing (4s)` | 出力は `tail -8` で末尾だけ。 |
| T3(2) | 2026-11-16T02:29:31.290Z | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `parse('Array<string\|number>=')` の1件と、その `publish` | なし | AST は `OPTIONAL` の下に `GENERIC`、`meta.syntax` は `SUFFIX_EQUALS_SIGN`。`publish` は `Array<string \| number>=` | |
| T4 | 2026-11-16T02:29:51.190Z | ランダム | 実コード（元のまま） | `try { p = publish(a); b = parse(p); } catch (e) { err = e.message; }` のあと `if (err \|\| !util.isDeepStrictEqual(strip(a), strip(b)))` を失敗とする | 線形合同法 `seed = (seed * 1103515245 + 12345) & 0x7fffffff`、種 7、200000 件生成。深さ `Math.floor(rnd() * 4) + 1`（1から4）。葉は名前20語（`'a', 'Foo', 'string', ... 'Array', 'a.b', 'a-b'`）と `'*', '?', '1', '-1.5', '0x1F', '"s"', "'q'", '"a\\"b"', "'a\\'b'", '...'`。構文は33通り（和、交差、括弧、前置と後置の `?` `!`、後置 `=`、前置 `...`、`[]`、`<>`、`.<>`、レコード、タプル、`function` 4形、アロー3形、`module:`、`external:`、`.` `#` `~` のメンバー、`typeof`、`keyof`、`keyof(...)`、`import(...)`）。リストとレコードの要素数は0から2。最初の `parse` に失敗した入力は `catch (e) { continue; }` で除く。`parse` はモードを指定しない | `const strip = n => JSON.parse(JSON.stringify(n));`（JSON 化で表せない値を落としてから比べる） | `parsed 120617, failures 13169`。例：`DIFF "a!" => "!a"`、`ERR "!Foo!" => "!!Foo"`、`ERR "typeof a.b" => "typeof a.{ type: 'NAME', name: 'b' }"` | 表示は失敗入力のうち異なるものを最大400件ためて、短い順に60件。 |
| T5 | 2026-11-16T02:30:01.305Z | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `'a!'`、`'typeof a.b'`、`'...a?'`、`'!Foo!'` の4件の `parse` | なし | `typeof a.b` の `MEMBER` の `name` が `{"type":"NAME","name":"b"}`。`!Foo!` は `PREFIX_BANG` の上に `SUFFIX_BANG` | |
| T6 | 2026-11-16T02:30:08.525Z | ランダム | 実コード（元のまま） | T4 と同じ | T4 の生成に `` () => `${t()}...` `` を加えた34通り。種 11、300000 件 | `NOMETA=1` で `JSON.stringify(n, (k, v) => process.env.NOMETA && k === "meta" && v && /NULLABLE\|BANG\|QUESTION/.test(v.syntax) && !/KEY/.test(v.syntax) ? undefined : v)`。`meta.syntax` に `NULLABLE`、`BANG`、`QUESTION` のどれかを含み `KEY` を含まない `meta` を除く | `parsed 175761, failures 9493`。例：`DIFF "a..." => "...a"`、`ERR "?\"s\"!" => "!?\"s\""`、`DIFF "function(): keyof x$![]" => "function(): keyof !x$[]"` | |
| T7 | 2026-11-16T02:30:24.612Z | ランダム | 実コード（元のまま） | T4 と同じ | T6 と同じ生成。種 13、300000 件 | T6 の正規表現を `/NULLABLE\|BANG\|QUESTION\|DOTS/` に変えた（`DOTS` を含む `meta` も除く）。さらに出力から `grep -v "typeof [^\|&]*\.[^<]*{ type"` に当たる行を表示から除いた | `parsed 175760, failures 2739`。例：`ERR "!Foo!" => "!!Foo"`、`ERR "(!Array?)" => "(?!Array)"`、`DIFF "function(!event, module): Array![]" => "function(!event, module): !Array[]"` | `grep -v` は表示だけを除き、件数の行には含まれる。表示は `head -50`。 |
| T10 | 2026-11-16T02:30:44.428Z | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `parse('a.b')` の1件 | なし | `{"type":"MEMBER","owner":{"type":"NAME","name":"a"},"name":"b","quoteStyle":"none","hasEventPrefix":false}` | |
| T11(種13) | 2026-11-16T02:30:51.624Z | ランダム | 実コード（元のまま） | T4 と同じ | T6 と同じ生成。種 13、300000 件。`NOMETA` は設定していない | `JSON.parse(JSON.stringify(...))` だけ（`NOMETA` がないので `meta` は除かない） | `parsed 175760, failures 24279`。例：`DIFF "a!" => "!a"`、`DIFF "a..." => "...a"` | 同じ呼び出しの `python3` が `python3: command not found` で失敗しており、ソースは書き換わっていない。`npm run build` のあとに実行。表示は `head -15`。 |
| T11(種21) | 2026-11-16T02:30:51.624Z | ランダム | 実コード（元のまま） | T4 と同じ | 種 21、ほかは T11(種13) と同じ | T11(種13) と同じ | `parsed 175771, failures 24283` | 同上。 |
| T11(種99) | 2026-11-16T02:30:51.624Z | ランダム | 実コード（元のまま） | T4 と同じ | 種 99、ほかは T11(種13) と同じ | T11(種13) と同じ | `parsed 175758, failures 24274` | 同上。 |
| T19(種13) | 2026-11-16T02:31:33.288Z | ランダム | 実コード（T14 から T18 の編集までを含む） | T4 と同じ | T6 と同じ生成。種 13、300000 件。`NOMETA` は設定していない | `JSON.parse(JSON.stringify(...))` だけ | `parsed 175760, failures 0` | `npm run build` のあとに実行。 |
| T19(種21) | 2026-11-16T02:31:33.288Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | 種 21 | 同上 | `parsed 175771, failures 0` | |
| T19(種99) | 2026-11-16T02:31:33.288Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | 種 99 | 同上 | `parsed 175758, failures 0` | |
| T19(種1234) | 2026-11-16T02:31:33.288Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | 種 1234 | 同上 | `parsed 175739, failures 0` | |
| T20(jsdoc) | 2026-11-16T02:32:15.860Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | T6 と同じ生成。`parse = s => lib.parse(s, mode ? {mode} : undefined)` で `MODE=jsdoc`。種 5、200000 件 | `JSON.parse(JSON.stringify(...))` だけ | `parsed 70201, failures 0` | |
| T20(closure) | 2026-11-16T02:32:15.860Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | `MODE=closure`、種 5、200000 件 | 同上 | `parsed 67529, failures 0` | |
| T20(typescript) | 2026-11-16T02:32:15.860Z | ランダム | 実コード（T14 から T18 まで） | T4 と同じ | `MODE=typescript`、種 5、200000 件 | 同上 | `parsed 98607, failures 0` | |
| T20(npm test) | 2026-11-16T02:32:15.860Z | 既存テスト | 実コード（T14 から T18 まで） | `npm test`（`pretest` の lint と build、`nyc npm run mocha`、`tsc`）。既存テストの各 `expect` | `tests/test_*` の既存テスト | なし | 失敗の印として `1) should return a module type with a postfix nullable type operator`、`2) should return a nullable type with a nullable type operator on the tail`、`3) should return a non-nullable type with a nullable type operator on the tail` | 出力は `grep -E` で絞り `head -20` で切れており、件数の行は出ていない。 |
| T21 | 2026-11-16T02:32:39.843Z | 既存テスト | 実コード（T14 から T18 まで） | 既存テストの各 `expect`。失敗した3件は `expect(publish(node)).to.equal('?module:foo/bar')`、`.to.equal('?goog.ui.Component')`、`.to.equal('!Object')` | `tests/test_*` | なし | `332 passing`、`3 failing`。`expected 'module:foo/bar?' to equal '?module:foo/bar'`、`expected 'goog.ui.Component?' to equal '?goog.ui.Component'`、`expected 'Object!' to equal '!Object'` | |
| T23 | 2026-11-16T02:32:56.754Z | 既存テスト | 実コード（T14 から T18 まで）。テストは T23 で書き換えた版 | 既存テストの各 `expect`。T23 で 417、478、490 行目の期待値を `'module:foo/bar?'`、`'goog.ui.Component?'`、`'Object!'` に変え、`parse('number...')` を `'number...'`、`parse('!Object!')` を `'!Object!'`、`parse('keyof Array![]')` を `'keyof Array![]'`、`parse('typeof x.y.z')` を `'typeof x.y.z'` と比べる4件を加えた | `tests/test_*` | なし | `339 passing (4s)` | 失敗の行は `grep -E "passing\|failing"` の出力に出ていない。 |
| T24(lint) | 2026-11-16T02:33:03.593Z | その他 | 実コード（T14 から T18 まで） | `eslint --report-unused-disable-directives .` | リポジトリ全体 | なし | 見出しの行だけで、エラーの行は出ていない | 静的な検査で、振る舞いは判定しない。`tail -3`。 |
| T24(typecheck) | 2026-11-16T02:33:03.593Z | その他 | 実コード（T14 から T18 まで） | `tsc` | `tsconfig.json` の範囲 | なし | 見出しの行だけで、エラーの行は出ていない | 同上。 |
| T28 | 2026-11-16T02:35:40.997Z | 手で試した入力 | 実コード（T14 から T18 まで） | なし（出力を見ただけ） | `'((a))'`、`'(a)'`、`'!(a)'`、`'(a)!'`、`'((a)\|b)'`、`'(!a)?'` の6件の `parse` | なし | 6件とも AST が出た。例：`(!a)? {"type":"NULLABLE","value":{"type":"PARENTHESIS",...},"meta":{"syntax":"SUFFIX_QUESTION_MARK"}}` | |
| T32 | 2026-11-16T02:36:30.202Z | 証明の検査 | モデル（T31 の版） | `lake build` が通るか。定理は `P_sound : ∀ f c ts a r, P f c ts = some (a, r) → wf c a = true ∧ print a ++ r = ts`、`parse_sound`（`parse ts = some a` から `wf .PE a = true ∧ print a = ts`）、`parse_print_parse`（`parse ts = some a` から `parse (print a) = some a`）、`old_publisher_bug`（`decide`） | 字句は `Tok`（`id n`、`q`、`bang`、`bar`、`lp`、`rp`）、AST は `Ty`（`name`、`unary op pre t`、`union`、`paren`）。文法は型名、括弧、前置と後置の `?` `!`、`\|` だけ。`P` は燃料付き、`parse` の燃料は `9 * ts.length + 8`。`P_sound` などはすべての字句列。`old_publisher_bug` は `[.bang, .id 0, .bang]` の1件 | 空白、字句解析、引用符、`meta` は前置と後置の区別のほかは表さない（モデル化の範囲） | `Build completed successfully (3 jobs).` | |
| T33 | 2026-11-16T02:36:35.204Z | 証明の検査 | モデル（T31 の版） | `#print axioms` で使う公理を表示 | `parse_sound`、`parse_print_parse`、`old_publisher_bug` | なし | `parse_sound` と `parse_print_parse` は `[propext, Quot.sound]`、`old_publisher_bug` は `[propext]` | |
| T34 | 2026-11-16T02:37:28.741Z | 証明の検査 | モデル（T31 に T34 で `complete.lean` を足した版） | `lake build` が通るか。足した定理は `P_complete`、`parse_complete (a : Ty) (h : wf .PE a = true) : parse (print a) = some a`、`parse_iff : parse ts = some a ↔ wf .PE a = true ∧ print a = ts` など | T32 と同じモデル。`parse_complete` は `wf .PE a = true` を満たすすべての `a` | T32 と同じ | `error: JsdocTypeParserFormal.lean:367:20: Unknown constant `Nat.strong_induction_on``、`error: build failed` | |
| T35 | 2026-11-16T02:37:32.008Z | 証明の検査 | モデル（T34 の版を T35 の `sed` で `Nat.strongRecOn` にした版） | `lake build` が通るか | T34 と同じ | T32 と同じ | 385 行目 `Tactic `rewrite` failed`、393 行目と 423 行目 `Application type mismatch` | 出力は `head -80` で切れている。 |
| T40 | 2026-11-16T02:38:20.145Z | 証明の検査 | モデル（T35 の版に T37 の Edit、T39 の `edit.js`、T40 の `edit2.js` を当てた版） | `lake build` が通るか | T34 と同じ | T32 と同じ | 348 行目から 352 行目（`wf_PU`、`wf_SU`、`wf_SO`、`wf_U`、`wf_UO`）で `unsolved goals` | 出力は `grep -v "^  "` と `head -40` で切れている。 |
| T41 | 2026-11-16T02:38:27.361Z | 証明の検査 | モデル（T40 の版の `wf_` 補題を `conv => lhs; rw [wf]` にした版） | `lake build` が通るか | T34 と同じ | T32 と同じ | 429 行目 `unsolved goals`（`case ind.SO.inl`）、487 行目 `Tactic `rewrite` failed` | 出力は `head -60` で切れている。 |
| T42 | 2026-11-16T02:38:34.237Z | 証明の検査 | モデル（T41 の版に T42 の `sed` で `; rfl` と `simp only [Un_fail ...]` を当てた版。最後の状態） | `lake build` が通るか | T34 と同じ | T32 と同じ | `Build completed successfully (3 jobs).` | |
| T43(axioms) | 2026-11-16T02:38:38.547Z | 証明の検査 | モデル（T42 の版） | `#print axioms` で使う公理を表示 | `parse_sound`、`parse_print_parse`、`old_publisher_bug`、`parse_complete`、`parse_iff` | なし | `parse_complete` と `parse_iff` は `[propext, Quot.sound]`。ほかは T33 と同じ | 同じ呼び出しの `grep -n "sorry\|admit\|axiom "` は何も出していない。 |
| T43(build) | 2026-11-16T02:38:38.547Z | 証明の検査 | モデル（T42 の版） | `lake build` の出力の `warning` を含む行の数 | 同上 | なし | `0` | |
| T46(lint) | 2026-11-16T02:38:58.591Z | その他 | 実コード（T14 から T18 まで） | `eslint --report-unused-disable-directives .` | リポジトリ全体（T45 の `tests/test_roundtrip.js` を含む） | なし | 見出しの行だけで、エラーの行は出ていない | 静的な検査で、振る舞いは判定しない。 |
| T46(mocha) | 2026-11-16T02:38:58.591Z | 既存テスト | 実コード（T14 から T18 まで）。テストは T23 の版と T45 の `test_roundtrip.js` | 既存テストの各 `expect` と、T45 の `expect(parse(published, {mode}), ...).to.deep.equal(node)` および `expect(accepted).to.be.above(1000)` | 既存テストと T45 のテスト。T45 は種 42 の同じ線形合同法、モード `permissive`、`jsdoc`、`closure`、`typescript` ごとに 20000 件生成、深さ1から4、T6 の34通りに `` `typeof ${pick(names)}.${pick(names)}` `` を加えた35通り。最初の `parse` に失敗した入力は除く | なし（`meta` を除かない。JSON 化もしない） | `parse/publish round trip`、`343 passing (7s)` | 失敗の行は `grep -E "passing\|failing\|round trip"` の出力に出ていない。 |
| T46(typecheck) | 2026-11-16T02:38:58.591Z | その他 | 実コード（T14 から T18 まで） | `tsc` | `tsconfig.json` の範囲 | なし | `> tsc` だけで、エラーの行は出ていない | 静的な検査。 |
| T46(stash) | 2026-11-16T02:38:58.591Z | ランダム | 実コード（`git stash push lib/publishing.js peg_src peg_lib` で元のままに戻した版） | T46(mocha) の T45 の `expect` と同じ | `tests/test_roundtrip.js` だけ。範囲は T46(mocha) の T45 と同じ | なし | `0 passing (14ms)`、`4 failing` | 失敗の中身は `grep` で絞られて出ていない。実行後に `git stash pop` している。 |

## スクリプトごとの一覧

| 名前 | 書いた T 番号 | 書き換えた T 番号 |
|---|---|---|
| `/tmp/fuzz/fuzz.js` | T4 | T6（`sed`：後置 `...` の生成を追加、`strip` を `NOMETA` 付きに変更）、T7（`sed`：正規表現に `DOTS` を追加）、T20（`sed`：`MODE` でモードを指定） |
| `/tmp/fuzz/check.lean` | T33 | T43（`#print axioms parse_complete` と `parse_iff` を追記） |
| `/tmp/fuzz/complete.lean` | T34 | なし（T34 で `formal/JsdocTypeParserFormal.lean` に連結） |
| `/tmp/fuzz/base.lean` | T34 | なし |
| `/tmp/fuzz/edit.js` | T39 | なし（証明ファイルを書き換えるためのもの） |
| `/tmp/fuzz/edit2.js` | T40 | なし（同上） |
| `formal/JsdocTypeParserFormal.lean` | T31 | T34（連結）、T35（`sed`）、T37（Edit）、T39（`edit.js`）、T40（`edit2.js`）、T41（`sed`）、T42（`sed`） |
| `formal/lean-toolchain`、`formal/lakefile.toml` | T30 | なし |
| `tests/test_roundtrip.js` | T45 | なし |
| `tests/test_publishing.js`（既存） | 既存 | T23（`sed` と `node` で期待値3件を変更、4件を追加） |
| `peg_src/jsdoctype.pegjs`（実コード） | 既存 | T14（Edit）。T11 の `python3` による書き換えは失敗して当たっていない |
| `lib/publishing.js`（実コード） | 既存 | T15、T16、T17、T18（Edit）。T11 の `python3` による書き換えは失敗して当たっていない |

`peg_lib/` は T11、T19 の `npm run build` と T20 の `npm test` の `pretest` で `peg_src` から作り直されている。
