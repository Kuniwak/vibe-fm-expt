# run-23 表1：実際に試したこと

対象リポジトリは `home/dev/jsdoctypeparser` である。
時刻はすべて 2026-11-16 の UTC で、`tool-calls.md` の呼び出し時刻である。
1回の呼び出しで複数の検査を実行したものは、`T15 (1)`、`T15 (2)` のように分けた。

## 実コードの版

- R0：元のまま。T52 より前の実行はすべてこれである。
- R1：T50（`peg_src/jsdoctype.pegjs` の `QualifiedMemberName`）と T52（`lib/publishing.js` の `NULLABLE`、`NOT_NULLABLE`、`NAMED_PARAMETER`）の編集を含む。T52 の `npm run build` で `peg_lib/` に反映された。
- R2：R1 に T62（`TypeNameExprJsDocFlavored` に `!KeyQueryExpr`）の編集を加えたもの。T63 の `npm run build` で反映された。

## verification/enumerate.js の判定（表から参照する）

各モードで `impl.parse(s, {mode})` が例外を投げた入力は、そのモードでは何も判定しない（`return`）。
C1 で例外が出た入力は C2 と C3 を判定しない。

- C1 PublishTotal：`impl.publish(ast)` が例外を投げたら `record('PublishTotal', mode, s, e.message)`。
- C2 RoundTrip：`impl.parse(out, {mode})` が例外を投げたら記録し、そうでなければ `if (normalize(ast2) !== normalize(ast))` で記録する。
- C3 PublishFixed：`if (out2 !== out)`。
- C4 TraverseAll：`if (!nesting || missed.length || entered.length !== reach.length)`。
- C5 ModeSubset：mode が `permissive` 以外のとき `if (!p || JSON.stringify(p) !== JSON.stringify(ast))`。`p` は同じ入力の permissive での parse 結果である。
- C6 NameIsString：`if (/MEMBER$/.test(n.type) && typeof n.name !== 'string')`。

比較の緩め方は次のとおりである。

- K1（C2、C3 の再 parse、`--causes`）：`normalize` が `if (k === 'syntax' && SUFFIX_TO_PREFIX[v]) return SUFFIX_TO_PREFIX[v];` で `SUFFIX_QUESTION_MARK`、`SUFFIX_BANG`、`SUFFIX_DOTS` を `PREFIX_*` に置き換えてから JSON 文字列で比べる。
- K2（C4、C6）：`reachableNodes` は `if (k !== 'meta') walk(v[k]);` で `meta` の下をたどらない。
- K3（`--check` の ModeSubset、T65 の版）：`[...found.ModeSubset.witnesses.values()].filter(w => !DIALECT_CONFLICT.test(w.s))` で、骨格ごとの最短例のうち `/\?\[\]|keyof/` に合うものを失敗に数えない。
- K4（`--check` の ModeSubset、T66 と T67 の版）：`if (inv === 'ModeSubset' && !DIALECT_CONFLICT.test(s))` で集めた全件のうち、`/\?\[\]|keyof/` に合うものを失敗に数えない。

モードごとの判定は次のとおりである。

- 引数なし：件数と例を表示するだけで、終了コードは0である。
- `--check`：`const verdict = found[inv] ? 'VIOLATE' : 'OK';` を `EXPECTED` と比べ、食い違えば終了コード1を返す。
- `--broken`：4つの壊した版のそれぞれで `const caught = got && (!base[inv] || got.count > base[inv].count);` を判定し、1つでも偽なら終了コード1を返す。壊した版は `publisher drops PARENTHESIS`（RoundTrip）、`publisher no quote escaping`（RoundTrip）、`traverse skips children`（TraverseAll）、`mode parser diverges`（ModeSubset）である。
- `--causes`：`if (roundTrips(ast, mode)) continue;` で往復が通らない入力について、往復が通らない最小の部分木を `describe` のキーで数える。`roundTrips` は `normalize(parse(publish(node), {mode})) === normalize(node)` である。

`EXPECTED` は版によって変わる。

- T10 の版：PublishTotal、RoundTrip、PublishFixed、TraverseAll、NameIsString が `'VIOLATE'`、ModeSubset が `'OK'`。
- T35 の版：ModeSubset を `'VIOLATE'` に変えた。
- T54 と T55 の版：PublishTotal、PublishFixed、TraverseAll、NameIsString が `'OK'`、RoundTrip と ModeSubset が `'VIOLATE'`。さらに `--check` で RoundTrip があるとき、`causes()` のキーのうち `/^KEY_QUERY > /` に合わないものがあれば失敗にする。
- T65 以降の版：RoundTrip を `'OK'` に変え、T55 の追加判定を K3（T66 から K4）に置き換えた。

入力の範囲は次のとおりである。

- I1（T10 から T35 の版）：`EXTRA` 13件、`ATOMS` 19件、`UNARY` 26種、`BINARY` 2種（`|`、`&`）。生成は `EXTRA`、`ATOMS`、`UNARY` を `ATOMS` に1回かけたもの（深さ1）、`UNARY` を深さ1にかけたもの（深さ2）、`BINARY` で `ATOMS` 同士、深さ1と `ATOMS` の両順、`UNARY` を `BINARY(atom, 'B')` にかけたもの、の順で、`Set` で重複を除く。モードは `permissive`、`jsdoc`、`closure`、`typescript` の4つ。出力では `inputs: 51835 x 4 modes`。
- I2（T36 以降の版）：I1 の `ATOMS` に `"'s\\'q'"` を加えて20件にしたもの。出力では `inputs: 56684 x 4 modes`。

## verification/escape_z3.py の判定（表から参照する）

`sol.check()` が `sat` なら VIOLATE、`unsat` なら OK、それ以外は UNKNOWN とする。
引用はそれぞれ単一引用符と二重引用符の2通りで解く。

- Z1（T17 から T23 の版、Z3 の文字列理論）：
  - EncodeLexes：`sol.add(printable(s), Not(lexable(encode(s, q, broken), q)))`。
  - DecodeEncode：`sol.add(printable(s), decode(encode(s, q, broken), q, broken) != s)`（T23 の版では `decode(encode(s, q, n, broken), q, 2 * n, broken) != s`）。
  - EncodeDecode：`sol.add(lexable(s, q), encode(decode(s, q, broken), q, broken) != s)`。
  - 入力は `Length(s) <= max_len` で、`printable` は文字コード32から126と `\n` の列である。`MAX_LEN` は T17 で12、T23 で8。各 `solve` に `sol.set('timeout', 60000)`。
- Z2（T28 以降の版、`Array Int BV8` と長さ）：
  - EncodeLexes：`sol.add(Not(lexable(encode(s, q, broken), q)))`。
  - DecodeEncode：`sol.add(Not(equal(decode(encode(s, q, broken), q, broken), s)))`。
  - EncodeDecode：`sol.add(lexable(s, q), Not(equal(encode(decode(s, q, broken), q, broken), s)))`。
  - UnescapeOrderFree（T46 から）：`sol.add(lexable(s, q), Not(equal(decode(s, q, broken), decode(s, q, 'swapped-unescape'))))`。
  - 入力は `s.len >= 0, s.len <= bound` の各バイトが任意の列で、`s.at(i) != BitVecVal(0, 8)` で NUL だけを除く。`MAX_LEN` は T28 で10、T33 から5。タイムアウトの設定はない。
  - `--check` は `verdict == expected` を比べる。`EXPECTED` は T28 で `{'EncodeLexes': 'OK', 'DecodeEncode': 'OK', 'EncodeDecode': 'VIOLATE'}`、T46 で `'UnescapeOrderFree': 'OK'` を加えた。
  - `--broken` は `caught = all(v == 'VIOLATE' for v, _ in res)`。対象は T28 で `no-backslash-escape`（EncodeLexes、DecodeEncode）と `swapped-unescape`（DecodeEncode）、T46 で `swapped-unescape` を `no-quote-unescape`（DecodeEncode、UnescapeOrderFree）に置き換えた。
  - 反例が出たときは `replay` が `node -e` で実コード（permissive）に通し、結果を表示する。

## 表

| 番号 | 時刻 | 種類 | 対象 | 判定している条件 | 入力の範囲 | 比較の緩め方 | 記録された結果 | 備考 |
|---|---|---|---|---|---|---|---|---|
| T6 | 01:33:33 | 手で試した入力 | 実コード R0 | なし（出力を見ただけ）。<br>スクリプトは `JSON.stringify(parse(out)) === JSON.stringify(ast) ? 'same' : 'DIFF ' + ...` を表示する。 | 手で書いた12件（`'!Foo?'`、`'?Foo!'`、`'typeof a.b'`、`'(x:) => X'`、`'?Foo[]'`、`'string[]='`、`'Foo...'`、`"'a\\nb'"`、`"'a\\\\nb'"`、`'Foo?='`、`'keyof(A)'`、`'new () => X'`）。<br>モードは parse の既定値 `permissive`。 | なし | `"!Foo?" -> "?!Foo" REPARSE ERR`、`"?Foo!" -> "!?Foo" REPARSE ERR`、`"typeof a.b" -> "typeof a.{ type: 'NAME', name: 'b' }" REPARSE ERR`、`"(x:) => X" PUBLISH THROW Cannot read properties of null (reading 'type')`。<br>`"?Foo[]"` と `"string[]="` は PARSE ERR。<br>`"Foo..." -> "...Foo" DIFF`、`"Foo?=" -> "?Foo=" DIFF`。<br>残る4件は same。 | スクリプトは `/tmp/probe.js`（T6 で作成）。 |
| T11 | 01:34:47 | 全列挙 | 実コード R0 | C1 から C6（引数なし） | I1 | K1、K2 | `[VIOLATE] PublishTotal (4 cases)`、`RoundTrip (7900 cases)`、`PublishFixed (4 cases)`、`TraverseAll (7270 cases)`、`ModeSubset (51 cases)`、`NameIsString (7411 cases)`。<br>例：`"(a:) => X"` で `Cannot read properties of null`、`"?*?"` で `publish -> "??*" is rejected`、`"??!"` で `"!??" -> "?!?"`、`"typeof a.b"` で `not visited: NAME` と `MEMBER.name is object`、jsdoc の `"?[]"` で `AST differs`。 | スクリプトは T10 の版。<br>`head -120` を通している。 |
| T12 | 01:35:29 | 全列挙 | 実コード R0 | C1 から C6（引数なし） | I1 | K1、K2 | 件数は T11 と同じ。<br>例を骨格ごとにまとめた表示で、RoundTrip に `"keyof a?" [permissive,typescript] publish -> "keyof ?a" is rejected` などがあり、`... 739 more skeletons`。<br>ModeSubset は jsdoc の `"?[]"`、`"?[][]"`（`permissive rejects`）など。 | スクリプトは T12 までの版（例のまとめ方だけを変えた）。 |
| T14 | 01:36:02 | 全列挙 | 実コード R0 | `--causes`（`roundTrips`） | I1 | K1。<br>部分木の候補から `NON_EXPR`（`RECORD_ENTRY`、`NAMED_PARAMETER`、`FILE_PATH`）を除く。 | 34の原因。<br>`7411  MEMBER > NAME,NAME "typeof a.b" -> "a.{ type: 'NAME', name: 'b' }"`、`126  KEY_QUERY > NULLABLE "keyof a?" -> "keyof ?a"`、`64  NULLABLE(SUFFIX_QUESTION_MARK) > NOT_NULLABLE "!??" -> "?!?"`、`OPTIONAL(SUFFIX_KEY_QUESTION_MARK) > ...` と `VARIADIC(PREFIX_DOTS) > NAMED_PARAMETER{...}` の行が多数。 | スクリプトは T14 までの版。 |
| T15 (1) | 01:36:26 | 全列挙 | 実コード R0 | `--causes`（`roundTrips`） | I1 | K1。<br>候補から `NON_EXPR` に加え、`n.meta.syntax === 'SUFFIX_KEY_QUESTION_MARK'` のものと、`n.type === 'VARIADIC' && n.value.type === 'NAMED_PARAMETER'` のものを除く。 | 10の原因。<br>`7411 MEMBER > NAME,NAME`、`126 KEY_QUERY > NULLABLE`、`124 KEY_QUERY > NOT_NULLABLE`、`68 KEY_QUERY > UNION`、`68 KEY_QUERY > INTERSECTION`、`64 NULLABLE(SUFFIX_QUESTION_MARK) > NOT_NULLABLE`、`62 NULLABLE(SUFFIX_QUESTION_MARK) > NULLABLE`、`62 NOT_NULLABLE(SUFFIX_BANG) > NULLABLE`、`60 NOT_NULLABLE(SUFFIX_BANG) > NOT_NULLABLE`、`4 KEY_QUERY > OPTIONAL`。 | スクリプトは T15 までの版。 |
| T15 (2) | 01:36:26 | 手で試した入力 | 実コード R0 | なし（出力を見ただけ） | 手で書いた14件（`'?[]'`、`'?[][]'`、`'function(): keyof ?'`、`'keyof ?'` など）を4モードで parse し、AST の先頭90文字を表示する。 | なし | `"?[]"` は jsdoc で `GENERIC`（`Array`）、closure で REJECT、permissive と typescript で `NULLABLE` の `TUPLE`。<br>`"?[][]"` は jsdoc 以外で REJECT。<br>`"keyof ?"` は4モードとも `NULLABLE` の `NAME "keyof"`。<br>`"?Foo[]"`、`"Foo?[]"`、`"string[]="`、`"!Foo[]"`、`"Foo[]?"` は4モードとも REJECT。 | スクリプトは `/tmp/ms.js`（T15 で作成）。 |
| T18 | 01:37:16 | ソルバー | モデル | Z1（引数なしと `--broken` の2回） | Z1 | なし | 2回とも `ImportError: cannot import name 'ReplaceAll' from 'z3'`。 | 検査は始まっていない。<br>スクリプトは T17 と T18 の版。 |
| T20 (1) | 01:37:24 | ソルバー | モデル | Z1（引数なし） | Z1、`MAX_LEN = 12` | なし | 6つとも `[UNKNOWN]`（EncodeLexes、DecodeEncode、EncodeDecode のそれぞれ2つの引用符）。 | スクリプトは T20 までの版（`Z3_mk_seq_replace_all` を使う）。 |
| T20 (2) | 01:37:24 | ソルバー | モデル | Z1 の `--broken`。<br>`caught = all(solve(claim, q, broken, MAX_LEN)[0] == 'VIOLATE' for q in "'\"")`。 | Z1、`MAX_LEN = 12` | なし | `MISSED no-backslash-escape (DecodeEncode)`、`MISSED swapped-unescape (DecodeEncode)`。 | 実行時間は `real 0m0.061s` と出ている。<br>この短さの理由は確かめていない。 |
| T21 | 01:37:49 | ソルバー | モデル | `e.decode(e.encode(s,"'"),"'")!=s` と、`e.replace_all(s,'a','b')==StringVal('bb')` の2つの充足可能性 | `Length(s)<=12`。<br>`printable` の制約はない。 | なし | `unknown smt tactic failed to show goal to be sat/unsat (incomplete (theory seq))`、`sat`。 | escape_z3.py の T20 までの版を import している。 |
| T22 | 01:37:58 | ソルバー | モデル | `e.decode(e.encode(s,"'"),"'")!=s` | `Length(s)<=6`、タイムアウト 30000。<br>設定を3通り試す。 | なし | `{} unknown ...(incomplete (theory seq))`。<br>`{'smt.string_solver': 'z3str3'}` と `{'smt.seq.max_unfolding': 100000}` はどちらも `unknown invalid parameter for smt.string_solver, valid options are 'seq', 'auto'`。 | 3つ目の行が2つ目と同じ文言である理由は確かめていない。 |
| T23 | 01:38:36 | ソルバー | モデル | Z1（T23 の版、引数なし） | Z1、`MAX_LEN = 8` | なし | 6つとも `[UNKNOWN]`。<br>`real 6m22.098s`。 | スクリプトは T23 までの版（`replace_all` を `SubString` で位置ごとに展開）。 |
| T29 | 01:45:59 | ソルバー | モデル | Z2（`--check` のあと `--broken`） | Z2、`MAX_LEN = 10` | なし | 記録なし。 | 600秒で背景に移り、T31 で停止した。<br>出力は読まれていない。<br>スクリプトは T28 の版。 |
| T32 | 01:56:07 | ソルバー | モデル | Z2 の EncodeLexes、DecodeEncode、EncodeDecode | `n` を3、4、5、6 とし、単一引用符だけで解く。<br>`n` ごとに `timeout 120`。 | なし | n=3、4、5 で EncodeLexes と DecodeEncode は `OK`、EncodeDecode は `VIOLATE`（例 `'\\@ '`、`"\\\x80\\'"`、`'\\@\\\\'`）。<br>n=5 の DecodeEncode は30.3秒。<br>`n=6 timeout`。 | スクリプトは T28 の版。 |
| T33 | 01:59:04 | 全列挙 | 実コード R0 | `escape_enum.js --check`。<br>DecodeEncode：`if (back !== s && !witnesses.DecodeEncode)`。`back` は `parse(publish({type: 'STRING_VALUE', string: s, quoteStyle})).string`（例外なら `null`）。<br>EncodeDecode：`if (ast.type === 'STRING_VALUE' && publish(ast) !== q + s + q && !witnesses.EncodeDecode)`。<br>`EXPECTED = {DecodeEncode: 'OK', EncodeDecode: 'VIOLATE'}`。 | `ALPHABET = ['\\', "'", '"', 'n']` の長さ0から9のすべての列。<br>単一引用符と二重引用符。<br>モードは既定の permissive。 | なし。<br>EncodeDecode は `parse(q + s + q)` が例外の列を飛ばす（`continue`）。 | `[OK] DecodeEncode (|s|<=9)`。<br>`[VIOLATE] EncodeDecode (|s|<=9) witness {"source":"\"\\'\"","decoded":"\\'","republished":"\"\\\\'\""}`。 | 各条件で最初の反例1つだけを残す。<br>この呼び出しの前半で escape_z3.py の `MAX_LEN` を5に変えている。 |
| T34 (1) | 01:59:26 | ソルバー | モデル（反例は実コード R0 で再実行） | Z2（`--check`） | Z2、`MAX_LEN = 5` | なし | T43 で読んだ出力：EncodeLexes と DecodeEncode は2つの引用符とも `[OK] ... as expected`。<br>EncodeDecode は2つとも `[VIOLATE] ... as expected`（`witness " \\ \\\\" -> real code: {"source":"' \\ \\\\'","decoded":" \\ \\","republished":"' \\\\ \\\\'"}` など）。<br>`exit=0`。 | 背景で実行した。<br>スクリプトは T28 と T33 の版。 |
| T34 (2) | 01:59:26 | ソルバー | モデル | Z2 の `--broken`（T28 の対象） | Z2、`MAX_LEN = 5` | なし | `CAUGHT no-backslash-escape (EncodeLexes)`、`CAUGHT no-backslash-escape (DecodeEncode)`、`MISSED swapped-unescape (DecodeEncode) e.g. null`、`exit=1`。 | 背景で実行し、出力は T43 で読んだ。 |
| T35 (1) | 01:59:27 | 全列挙 | 実コード R0 | C1 から C6（`--check`、T35 の `EXPECTED`） | I1 | K1、K2 | 6条件とも `[VIOLATE] ... as expected`（件数は T11 と同じ）。<br>`exit=0`。 | スクリプトは T35 までの版。 |
| T35 (2) | 01:59:27 | 全列挙 | 実コード R0 | `--broken` | I1 | K1、K2 | `CAUGHT publisher drops PARENTHESIS`、`MISSED publisher no quote escaping (RoundTrip)`、`CAUGHT traverse skips children`、`CAUGHT mode parser diverges`、`exit=1`。 | `traverse skips children` の壊した版は、コードでは `n.type !== 'NAME'` の節を飛ばす。<br>コメントは GENERIC と書いているが、コードを採った。 |
| T37 (1) | 02:00:17 | 全列挙 | 実コード R0 | C1 から C6（`--check`、T35 の `EXPECTED`） | I2 | K1、K2 | `inputs: 56684 x 4 modes`。<br>PublishTotal 4、RoundTrip 8306、PublishFixed 4、TraverseAll 7640、ModeSubset 53、NameIsString 7781、すべて `as expected`。<br>`exit=0`。 | スクリプトは T36 までの版。<br>出力は `grep` で絞っている。 |
| T37 (2) | 02:00:17 | 全列挙 | 実コード R0 | `--broken` | I2 | K1、K2 | 4つとも `CAUGHT`、`exit=0`。 | |
| T37 (3) | 02:00:17 | 全列挙 | 実コード R0 | `--causes` | I2 | K1、T15 の候補の除外 | `7781 MEMBER > NAME,NAME`、`132 KEY_QUERY > NULLABLE`、`130 KEY_QUERY > NOT_NULLABLE`、`72 KEY_QUERY > UNION`、`72 KEY_QUERY > INTERSECTION`、`68`、`66`、`66`、`64`（4つの `NULLABLE`、`NOT_NULLABLE` の組）、`4 KEY_QUERY > OPTIONAL`。 | `head -12` を通している。 |
| T38 | 02:01:22 | 既存テスト | 実コード R0 | `tests/test_*` の各 `it` の `expect`（mocha）。<br>個々の条件は引用しない。 | 既存のテストファイルのまま。 | なし | `335 passing (6s)`。 | `tail -5` を通している。<br>同じ呼び出しの eslint は行にしていない。 |
| T40 | 02:01:34 | 全列挙 | 実コード R0 | C1 から C6（`--check`、T35 の `EXPECTED`） | I2 | K1、K2 | 出力は `/dev/null` に捨てている。<br>`CHECK_OK`（終了コード0）。 | スクリプトは T40 までの版（T39 の `eslint --fix` と T40 の正規表現の書き換えを含む）。 |
| T43 | 02:02:45 | なし | | | | | | T34 の出力を読んだだけなので、結果は T34 の行に書いた。 |
| T44 | 02:03:01 | ソルバー | モデル | `s.add(*pre, e.lexable(b,q), Not(e.equal(e.decode(b,q), e.decode(b,q,'swapped-unescape'))))` | `n` を4、5、6 とし、2つの引用符で解く。 | なし | 6つとも `unsat`。 | escape_z3.py の T28 と T33 の版を import している。 |
| T46 (1) | 02:03:17 | ソルバー | モデル（反例は実コード R0 で再実行） | Z2（`--check`、UnescapeOrderFree を含む） | Z2、`MAX_LEN = 5` | なし | EncodeLexes、DecodeEncode、UnescapeOrderFree は2つの引用符とも `[OK] ... as expected`。<br>EncodeDecode は2つとも `[VIOLATE] ... as expected`。 | スクリプトは T46 までの版。 |
| T46 (2) | 02:03:17 | ソルバー | モデル | Z2 の `--broken`（T46 の対象） | Z2、`MAX_LEN = 5` | なし | `CAUGHT no-backslash-escape (EncodeLexes)`、`CAUGHT no-backslash-escape (DecodeEncode)`、`CAUGHT no-quote-unescape (DecodeEncode)`、`CAUGHT no-quote-unescape (UnescapeOrderFree)`、`exit=0`。 | |
| T47 (1) | 02:05:04 | 全列挙 | 実コード R0 | `run.sh` の `enumerate.js --check`（T35 の `EXPECTED`） | I2 | K1、K2 | 表示なし（`grep` で `EXPECTED`、`MISSED`、`CAUGHT`、`exit` の行だけを出している）。<br>`run.sh` 全体で `exit=0`。 | `run.sh`（T41 の版）は `set -e` なので、`exit=0` は各コマンドが0を返したことを示す。 |
| T47 (2) | 02:05:04 | 全列挙 | 実コード R0 | `enumerate.js --broken` | I2 | K1、K2 | 4つとも `CAUGHT`。 | |
| T47 (3) | 02:05:04 | 全列挙 | 実コード R0 | `escape_enum.js --check` | T33 と同じ | T33 と同じ | 表示なし。 | 終了コードは `set -e` から0と読める。 |
| T47 (4) | 02:05:04 | ソルバー | モデル | Z2（`--check`） | Z2、`MAX_LEN = 5` | なし | 表示なし。 | 終了コードは `set -e` から0と読める。 |
| T47 (5) | 02:05:04 | ソルバー | モデル | Z2 の `--broken`（T46 の対象） | Z2、`MAX_LEN = 5` | なし | 4つとも `CAUGHT`。 | |
| T52 | 02:09:35 | 手で試した入力 | 実コード R1 | なし（出力を見ただけ）。<br>表示は T6 と同じ。 | T6 と同じ12件。 | なし | `"!Foo?" -> "!Foo?" same`、`"?Foo!" -> "?Foo!" same`、`"typeof a.b" -> "typeof a.b" same`、`"(x:) => X" -> "(x:) => X" same`。<br>`"?Foo[]"` と `"string[]="` は PARSE ERR、`"Foo..."` と `"Foo?="` は DIFF のまま。 | `/tmp/probe.js` を再実行した。 |
| T53 (1) | 02:09:40 | 全列挙 | 実コード R1 | C1 から C6（引数なし） | I2 | K1、K2 | `[OK] PublishTotal`、`[VIOLATE] RoundTrip (418 cases)`（例はすべて `keyof` を含む、`"keyof a?" ... publish -> "keyof ?a" is rejected` など）、`[OK] PublishFixed`、`[OK] TraverseAll`、`[VIOLATE] ModeSubset (53 cases)`、`[OK] NameIsString`。 | スクリプトは T40 までの版。 |
| T53 (2) | 02:09:40 | 全列挙 | 実コード R1 | `--causes` | I2 | K1、T15 の候補の除外 | `132 KEY_QUERY > NULLABLE`、`130 KEY_QUERY > NOT_NULLABLE`、`76 KEY_QUERY > UNION`、`76 KEY_QUERY > INTERSECTION`、`4 KEY_QUERY > OPTIONAL`。 | |
| T55 | 02:10:06 | 全列挙 | 実コード R1 | C1 から C6（`--check`、T54 と T55 の `EXPECTED` と原因の判定） | I2 | K1、K2 | PublishTotal、PublishFixed、TraverseAll、NameIsString は `[OK] ... as expected`。<br>RoundTrip 418、ModeSubset 53 は `[VIOLATE] ... as expected`。<br>`RoundTrip causes outside the known set: none`、`exit=0`。 | スクリプトは T55 までの版。 |
| T57 | 02:10:32 | 既存テスト | 実コード R1 | `npm test`（`pretest` の lint と build、`nyc` の下の mocha、`tsc`）の `expect`。 | 既存のテストに、T57 で `tests/test_publishing.js` に加えたテストを含む。 | なし | `339 passing (5s)`。<br>カバレッジは全ファイル100。 | 同じ呼び出しの Python は `AssertionError` で止まり、`tests/test_parsing.js` への追加は入っていない。<br>`tail -25` を通している。 |
| T58 | 02:10:46 | 既存テスト | 実コード R1 | `npm test` の `expect` | T57 の追加に、T58 で `tests/test_parsing.js` に加えた1件を含む。 | なし | `340 passing (4s)`、カバレッジは全ファイル100。 | 出力は `grep` で絞っている。 |
| T60 (1) | 02:11:10 | 全列挙 | 実コード R1 | `run.sh` の `enumerate.js --check`（T55 の版） | I2 | K1、K2 | `[OK] PublishTotal as expected`、`[VIOLATE] RoundTrip (418 cases) as expected`、`[OK] PublishFixed`、`[OK] TraverseAll`、`[VIOLATE] ModeSubset (53 cases) as expected`、`[OK] NameIsString`、`RoundTrip causes outside the known set: none`。 | `npm run verify` で実行した。<br>全体で `exit=0`。 |
| T60 (2) | 02:11:10 | 全列挙 | 実コード R1 | `enumerate.js --broken` | I2 | K1、K2 | 4つとも `CAUGHT`。 | |
| T60 (3) | 02:11:10 | 全列挙 | 実コード R1 | `escape_enum.js --check` | T33 と同じ | T33 と同じ | `[OK] DecodeEncode (|s|<=9)`、`[VIOLATE] EncodeDecode (|s|<=9)`（反例は T33 と同じ）。 | |
| T60 (4) | 02:11:10 | ソルバー | モデル（反例は実コード R1 で再実行） | Z2（`--check`） | Z2、`MAX_LEN = 5` | なし | EncodeLexes、DecodeEncode、UnescapeOrderFree は `[OK] ... as expected`、EncodeDecode は `[VIOLATE] ... as expected`（2つの引用符とも）。 | `grep` の条件のため反例の行は表示されていない。 |
| T60 (5) | 02:11:10 | ソルバー | モデル | Z2 の `--broken`（T46 の対象） | Z2、`MAX_LEN = 5` | なし | 4つとも `CAUGHT`。 | |
| T63 (1) | 02:15:24 | 手で試した入力 | 実コード R2 | なし（出力を見ただけ） | 手で書いた10件（`'keyof a?'`、`'keyof ?'`、`'keyof ?a'`、`'keyof'`、`'keyof?'`、`'keyof.foo'`、`'keyof foo'`、`'keyof(foo)'`、`'keyof typeof foo'`、`'function(): keyof ?'`）を permissive と jsdoc で parse し、publish する。 | なし | permissive の `"keyof a?"` は `KEY_QUERY` の `NULLABLE` で `keyof ?a`、`"keyof ?"` は `KEY_QUERY` の `UNKNOWN`。<br>jsdoc の `"keyof ?"` は `NULLABLE` の `NAME "keyof"` で `?keyof`、`"keyof a?"`、`"keyof foo"` などは REJECT。 | `node -e` で実行した。 |
| T63 (2) | 02:15:24 | 既存テスト | 実コード R2 | `npm test` の `expect` | T58 と同じテスト | なし | `340 passing (4s)`、カバレッジは全ファイル100。 | |
| T64 (1) | 02:15:37 | 全列挙 | 実コード R2 | C1 から C6（引数なし） | I2 | K1、K2 | `[OK] PublishTotal`、`[OK] RoundTrip`、`[OK] PublishFixed`、`[OK] TraverseAll`、`[VIOLATE] ModeSubset (151 cases)`（`"keyof ?" [jsdoc,closure] AST differs`、`"?keyof ?" [jsdoc,closure] permissive rejects` などが加わった）、`[OK] NameIsString`。 | スクリプトは T55 までの版。 |
| T64 (2) | 02:15:37 | 全列挙 | 実コード R2 | `--causes` | I2 | K1、T15 の候補の除外 | 出力なし。 | 同じ呼び出しの `node -e` はコメントだけで、行にしていない。 |
| T65 | 02:16:08 | 全列挙 | 実コード R2 | C1 から C6（`--check`、T65 の `EXPECTED`） | I2 | K1、K2、K3 | ModeSubset 以外は `[OK] ... as expected`。<br>`[VIOLATE] ModeSubset (151 cases) as expected`。<br>`ModeSubset outside dialect conflicts: none`、`exit=0`。 | スクリプトは T65 までの版。 |
| T67 (1) | 02:16:29 | 全列挙 | 実コード R2 | C1 から C6（`--check`、T65 の `EXPECTED`） | I2 | K1、K2、K4 | `ModeSubset outside dialect conflicts: none`。 | `tail -2` を通している。<br>終了コードは表示されていない。<br>スクリプトは T67 までの版。<br>T66 の呼び出しでは eslint が失敗し、検査は実行されていない。 |
| T67 (2) | 02:16:29 | 全列挙 | 実コード R2 | `--broken` | I2 | K1、K2 | 4つとも `CAUGHT`。 | 終了コードは表示されていない。 |
| T70 | 02:17:28 | 既存テスト | 実コード R2 | `npm test` の `expect` | T58 までの追加に、T68 と T70 で加えたテストを含む。 | なし | `344 passing (4s)`、カバレッジは全ファイル100。 | |
| T71 (1) | 02:17:44 | 全列挙 | 実コード R2 | `run.sh` の `enumerate.js --check`（T67 の版） | I2 | K1、K2、K4 | `ModeSubset outside dialect conflicts: none`。 | `npm run verify` で実行し、全体で `exit=0`。<br>出力は `grep` で絞っている。 |
| T71 (2) | 02:17:44 | 全列挙 | 実コード R2 | `enumerate.js --broken` | I2 | K1、K2 | `CAUGHT` の行数は (2) と (5) を合わせて `8`。 | `grep -c` の件数だけを表示している。 |
| T71 (3) | 02:17:44 | 全列挙 | 実コード R2 | `escape_enum.js --check` | T33 と同じ | T33 と同じ | 表示なし。 | 終了コードは `set -e` から0と読める。 |
| T71 (4) | 02:17:44 | ソルバー | モデル | Z2（`--check`） | Z2、`MAX_LEN = 5` | なし | `EXPECTED` の行は表示されていない。 | 終了コードは `set -e` から0と読める。 |
| T71 (5) | 02:17:44 | ソルバー | モデル | Z2 の `--broken`（T46 の対象） | Z2、`MAX_LEN = 5` | なし | `MISSED` の行は表示されていない。 | |
| T74 (1) | 02:21:29 | 全列挙 | 実コード R2 | `run.sh --node-only` の `enumerate.js --check`（T67 の版） | I2 | K1、K2、K4 | 表示なし（`tail -4`）。 | `npm run verify:node` で実行し、全体で `exit=0`。<br>`run.sh` は T74 の版。 |
| T74 (2) | 02:21:29 | 全列挙 | 実コード R2 | `enumerate.js --broken` | I2 | K1、K2 | `CAUGHT traverse skips children (TraverseAll)`、`CAUGHT mode parser diverges (ModeSubset)`。 | `tail -4` のため前の2行は見えていない。 |
| T74 (3) | 02:21:29 | 全列挙 | 実コード R2 | `escape_enum.js --check` | T33 と同じ | T33 と同じ | `[OK] DecodeEncode (|s|<=9)`、`[VIOLATE] EncodeDecode (|s|<=9)`（反例は T33 と同じ）。 | `--node-only` のため Z3 の部分は実行されていない。 |

## 行にしなかった呼び出し

- T3 と T19 は道具の版の確認である。
- T8 は4つの方言の parser を作り直し、`cmp -s` で `peg_lib/` と比べたもので、ビルドとファイルの比較なので行にしなかった。出力は4つとも `same`。
- T38、T39、T40、T47 などの eslint は、ライブラリの振る舞いを判定しないので行にしなかった。
- T79 の `npx -y node@10 --version` は `Exit code 143` で終わり、検査は実行されていない。

## スクリプトごとの一覧

| 名前 | 書いた T 番号 | 書き換えた T 番号 |
|---|---|---|
| `/tmp/probe.js` | T6 | なし |
| `/tmp/ms.js` | T15 | なし |
| `verification/enumerate.js` | T10 | T12、T14、T15、T35（`sed`）、T36（`sed`）、T39（`eslint --fix`）、T40（`sed`）、T54、T55、T65、T66、T67。<br>T66 の `sed 's|^  RoundTrip: .OK.,$|&|'` は内容を変えない置き換えである。 |
| `verification/escape_z3.py` | T17 | T18、T20、T23、T28（全体を書き直し）、T33（`sed` で `MAX_LEN = 5`）、T46。<br>T24 の `Write` は失敗し、反映されていない。 |
| `verification/escape_enum.js` | T33 | なし |
| `verification/run.sh` | T41 | T74 |
| インラインの Python（`python3 -c`） | T21、T22、T32、T44 | なし |
| インラインの `node -e` | T63 | なし |
