# run-26 表1：実際に試したこと

時刻は `tool-calls.md` の呼び出しの時刻（2026-11-16、UTC）である。
対象リポジトリは `/home/dev/jsdoctypeparser`（記録の最後の状態は `runs/run-26/home/dev/jsdoctypeparser`）。
実コードの版は、`lib/` と `peg_src/` を編集した T 番号で書く。
`peg_src/jsdoctype.pegjs` の編集は、ビルド（`npm test` の pretest または `npm run build`）で `peg_lib/` に入る。
`verification/check.js` の版は、表のあとの「check.js の版」に記号（版A〜版J）で示す。
check.js の判定条件と入力の範囲は、表のあとの「check.js の判定条件の引用」と「check.js の入力の範囲」に引用する。

| 番号 | 時刻 | 種類 | 対象 | 判定している条件 | 入力の範囲 | 比較の緩め方 | 記録された結果 | 備考 |
|---|---|---|---|---|---|---|---|---|
| T7 | 02:52:12 | 既存テスト | 実コード（元のまま） | `npm test`。<br>pretest は `"npm-run-all lint build"`、test は `"npm-run-all coverage typecheck"`、coverage は `"nyc npm run mocha"`（`mocha tests/test_*`）。<br>nyc の設定は `"check-coverage": true, "branches": 100, "lines": 100, "functions": 100, "statements": 100`。<br>typecheck は `tsc`。 | `tests/test_*` の全件 | なし | `335 passing (5s)`。<br>`All files` の行は 100 / 100 / 100 / 100。 | 出力は `tail -25` で末尾だけ。 |
| T8 | 02:52:15 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ）。<br>各入力で parse、publish、publish 結果の再 parse を行い、例外の有無を表示する。 | 9件：`typeof a.b`、`!X?`、`?X!`、`!X?=`、`(x:) => a`、`Foo\|function():Returned=`、`a & b \| c`、`a \| b & c`、`external:path/to/file`。<br>モードは指定なし。 | なし | `"typeof a.b" -> "typeof a.{ type: 'NAME', name: 'b' }" REPARSE-ERR ...`<br>`"!X?" -> "?!X" REPARSE-ERR`、`"?X!" -> "!?X" REPARSE-ERR`、`"!X?=" -> "?!X=" REPARSE-ERR`<br>`"(x:) => a" PUBLISH-THROW Cannot read properties of null (reading 'type')`<br>`"Foo\|function():Returned=" -> "Foo \| function(): Returned=" reparse ok`<br>`a & b \| c`、`a \| b & c`、`external:path/to/file` は `PARSE-ERR`。 | |
| T14 | 02:53:52 | ソルバー | モデル（`verification/codec_z3.py`、T13 の版） | `want == 'PROVED'` の性質は否定を与え `got = 'PROVED' if res == z3.unsat else ('VIOLATED' if res == z3.sat else 'UNKNOWN')`。<br>EncodeAccepted：`z3.Not(z3.InRe(encode(x, q), R))`。<br>DecodeInverse：`decode(encode(x, q), q) != x`。<br>DecodeNotInj（SAT を期待）：`z3.And(z3.InRe(r1, R), z3.InRe(r2, R), r1 != r2, decode(r1, q) == decode(r2, q))`。<br>終了コード：`sys.exit(0 if ok else 1)`。 | q は `'` と `"`。<br>まず長さの上限なし、`unknown` のとき `z3.Length(v) <= bound['n']`（n=10、DecodeNotInj は n=6）で再試行。<br>`--self-check` で壊した版2種（`encode_no_backslash`、`decode_no_backslash`）も実行。<br>モデルの式：`encode_ok` は `replace_all(replace_all(x, BS, BS + BS), q, BS + q)`、`decode_ok` は `replace_all(replace_all(r, BS + q, q), BS + BS, BS)`、`raw_lang` は `z3.Star(z3.Union(plain, escaped))`。 | なし | 判定に至らず例外：`z3.z3types.Z3Exception: b"Sort of function 're.diff' does not match the declared type. Given domain: String (RegEx String) "`、`Exit code 1`。 | モデルは手で書いた式で、実コードを呼ばない。<br>実コードとの対応は docstring に書かれているが、根拠にしていない。 |
| T15 | 02:53:54 | ソルバー | モデル（codec_z3.py、T13 に T15 の sed を加えた版） | T14 と同じ | T14 と同じ | なし | 例外：`z3.z3types.Z3Exception: b'Sort mismatch at argument #2 for function (declare-fun str.replace_all (String String String) String) supplied sort is (_ BitVec 1)'`、`Exit code 1`。 | sed は `z3.AllChar(z3.StringSort())` を `z3.AllChar(z3.ReSort(z3.StringSort()))` に置換。 |
| T17 | 02:54:05 | ソルバー | モデル（codec_z3.py、T15 の sed と T16 の編集まで） | T14 と同じ。<br>壊した版は `caught = any(want == 'PROVED' and got == 'VIOLATED' ...)` で判定。 | T14 と同じ | なし | 実装の版、壊した版2種とも、6性質すべて `UNKNOWN`（`bounded(len<=10)` または `bounded(len<=6)`）。<br>壊した版は2つとも `-> NOT CAUGHT (checker is not load-bearing!)`。<br>`RESULT: MISMATCH`、`Exit code 1`。 | codec_z3.py は T19 で削除された。 |
| T18 | 02:54:09 | ソルバー | モデル（その場の Python） | `s.add(e!=x, z3.Length(x)<=3)` の check、および `z3.SolverFor('QF_S')` に `e!=x` だけを与えた check。<br>e は `Z3_mk_seq_replace_all(x, a, b)`。 | x は長さ3以下、および上限なし | なし | 2回とも `unknown smt tactic failed to show goal to be sat/unsat (incomplete (theory seq))`。 | a と b はシェルと Python のエスケープを経た値で、実際の文字列は確かめていない。 |
| T21 | 02:56:25 | 全列挙、ランダム、その他（fixtures） | 実コード（元のまま）、check.js 版A | 「check.js の判定条件の引用」の A1〜A11。<br>`--self-check` なし。 | 「check.js の入力の範囲」、`--quick`（CODEC_LEN 5、TOKEN_LEN 3、RANDOM_N 20000）。 | RoundTripEq だけ `normalize` を通す（C1）。<br>meta の下はノードとして数えない（C2）。 | `accepted (input x mode): {"TOKENS":2705,"RANDOM":9826,"FIXTURES":620536}`<br>`OK CodecInverse checked=39060 violations=0`<br>`OK CodecRawStable checked=632 violations=0`<br>`VIOLATE PublishTotal checked=633067 violations=737`（`e.g. "permissive: (x:) => *"`）<br>`VIOLATE PublishReparses checked=632330 violations=4295`<br>`VIOLATE RoundTripEq checked=628035 violations=8`<br>`VIOLATE PublishFixpoint checked=628035 violations=4`<br>`VIOLATE TraverseExact checked=632330 violations=3897`（`NAME{name:string} visited 0 times`、`e.g. "closure: typeof b.c"`）<br>`VIOLATE SchemaConforms checked=863302 violations=204935`<br>`VIOLATE ModeSubset checked=457395 violations=15`<br>`VIOLATE SchemaWellFormed checked=29 violations=7` | 出力は `head -150`。 |
| T26 | 02:57:50 | 全列挙、ランダム、その他（fixtures） | 実コード（元のまま）、check.js 版B | A1〜A11（バケットの名付けに T22 の `localize` を使う） | full（CODEC_LEN 7、TOKEN_LEN 4、RANDOM_N 300000） | C1、C2 | `accepted (input x mode): {"TOKENS":24901,"RANDOM":100836,"FIXTURES":620518}`<br>`OK CodecInverse checked=976560 violations=0`<br>`OK CodecRawStable checked=11106 violations=0`<br>`VIOLATE PublishTotal checked=746255 violations=9243`<br>`VIOLATE PublishReparses checked=737012 violations=15084`（最大のバケット `[11903] minimal failing subtree MEMBER(NAME,NAME)`、`e.g. "closure: typeof b.c  =>  typeof b.{ type: 'NAME', name: 'c' }"`）<br>`VIOLATE RoundTripEq checked=721928 violations=83`（例 `"permissive: (x: ?=) => a.\"d\"![]  =>  (x: ?=) => !a.\"d\"[]"`、`"jsdoc: ??!  =>  !??"`）<br>`VIOLATE PublishFixpoint checked=721928 violations=40`（`e.g. "jsdoc: ??!  =>  !??  =>  ?!?"`）<br>`VIOLATE TraverseExact checked=737012 violations=12168`<br>`VIOLATE SchemaConforms checked=1374644 violations=450587`<br>`VIOLATE ModeSubset checked=515055 violations=128`（例 `"jsdoc: ?[][]"` は `jsdoc accepts, permissive rejects`）<br>`VIOLATE SchemaWellFormed checked=29 violations=7` | 出力は `grep -v` で `type not in` と `no schema` のバケット行を除き、`/tmp/full_run.txt` に保存。<br>SchemaConforms 以降は T27 の `sed` で表示（T27 は実行ではない）。 |
| T28 | 03:01:07 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | 8件（`?string[]`、`?[]`、`?[][]`、`!Foo[]`、`?Foo[][]`、`string?[]`、`keyof ?`、`Array.<?>[]`）× 4モード | なし | `?string[]`、`!Foo[]`、`?Foo[][]`、`string?[]` は4モードとも `ERR`。<br>`?[]` は permissive と typescript で `NULLABLE`（値は `TUPLE`）、jsdoc で `GENERIC`（`objects":[{"type":"UNKNOWN"}]`）、closure で `ERR`。<br>`?[][]` は jsdoc だけ `OK`。<br>`keyof ?` は4モードとも `OK ?keyof`、AST は `{"type":"NULLABLE","value":{"type":"NAME","name":"keyof"},"meta":{"syntax":"SUFFIX_QUESTION_MARK"}}`。 | |
| T31 | 03:02:05 | その他（fixtures の集計） | 実コード（元のまま） | なし（数を見ただけ）。<br>分類の式：受理かつ `/typeof\s+[\w$]+\s*\./.test(s)`、拒否かつ `/(^\|[(<,\|:]\s*)[?!][\w$.]+(<[^>]*>)?\[\]/.test(s)`、拒否かつ `/[&].*[\|]\|[\|].*[&]/.test(s) && !/[(]/.test(s)`。 | `tests/fixtures` の全行（`if(e.skip) continue`）、モード指定なし | なし | `typeofDotted: 1051`、`prefixArr: 0`、`unionInter: 52`、`total: 179323`、`acc: 170397`。 | |
| T32 | 03:02:17 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `Foo\|function():Returned=`、`Foo\|Bar=`、`Foo\|Bar?` | なし | `UNION right=OPTIONAL(FUNCTION)`、`UNION right=OPTIONAL(NAME)`、`UNION right=NULLABLE(NAME)`。 | |
| T34 | 03:02:27 | 全列挙、ランダム、その他（fixtures） | 実コード（元のまま）、check.js 版C | A1〜A11 と、自己検査 A12、A13 | `--self-check --quick`。<br>本体1回と、壊した版3種で同じ入力をもう1回ずつ。 | C1、C2、C3 | 9性質すべて `match`（PublishTotal から ModeSubset までは `got VIOLATE, ledger says VIOLATE`、Codec の2つは `got OK`）。<br>`CAUGHT publisher drops parentheses (RoundTripEq: 401 new bucket(s), e.g. "jsdoc: (a)  =>  a")`<br>`CAUGHT publisher does not escape strings (CodecInverse: 2 new bucket(s), e.g. "\"'\" => '''")`<br>`CAUGHT traverse skips generic params (TraverseExact: 27 new bucket(s), e.g. "jsdoc: A[][]")`<br>`RESULT: OK (all verdicts match the ledger)` | 出力は `== ledger check` 以降だけ。 |
| T35 | 03:05:38 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | 7件：`() => a[]`、`() => !a[]`、`() => a![]`、`function(): ?a[]`、`??!`、`keyof ?`、`function(this: keyof ?)` | なし | `"() => a![]"  ARROW(=>GENERIC<NOT_NULLABLE(NAME)>)  publish: "() => !a[]"  reparse: GENERIC<ARROW(=>NOT_NULLABLE(NAME))>`<br>`"??!"  NOT_NULLABLE(NULLABLE(UNKNOWN))  publish: "!??"  reparse: NULLABLE(NOT_NULLABLE(UNKNOWN))`<br>`"function(): ?a[]"  GENERIC<FUNCTION(=>NULLABLE(NAME))>` | 同じ呼び出しで eslint も実行（`'NODE_TYPES' is assigned a value but never used`）。eslint は行にしない。 |
| T36 | 03:05:41 | 全列挙、ランダム、その他（fixtures） | 実コード（元のまま）、check.js 版D | A1〜A11、終了コードは A10 | `--quick` | C1、C2 | 標準出力は捨てられ、`exit=1` だけ。 | 同じ呼び出しで eslint（`LINT-OK`）。 |
| T38 | 03:07:14 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `X??`、`X!!`、`!X?`、`?X!`、`function(a,)`、`A & B \| C` | なし | `X??`、`X!!`、`A & B \| C` は `PARSE-ERR`。<br>`"!X?" -> "?!X" REPARSE-ERR`、`"?X!" -> "!?X" REPARSE-ERR`。<br>`"function(a,)" -> "function(a)" ok`。 | |
| T39 | 03:07:18 | 手で試した入力 | 実コード（元のまま） | なし（出力を見ただけ） | `?X?`、`!X!` | なし | `"?X?" -> "??X" REPARSE-ERR`、`"!X!" -> "!!X" REPARSE-ERR`。 | |
| T46 | 03:08:37 | 既存テスト | 実コード（T42、T44 の編集まで。pretest のビルドで peg_lib に反映） | T7 と同じ | `tests/test_*`。<br>テストファイルは変わっていない（同じ呼び出しの Python が最初の `assert s.count(anchor)==1` で止まった）。 | なし | `335 passing (4s)`。<br>`ERROR: Coverage for branches (98.57%) does not meet global threshold (100%)`<br>`ERROR: Coverage for statements (99.15%) does not meet global threshold (100%)` | 出力は `grep -E "passing\|failing\|ERR\|error\|✗\|[0-9]+\)"` で絞られている。<br>テストが追加されていないことは T51 の grep の出力でも分かる。 |
| T50 | 03:08:58 | 既存テスト | 実コード（T42、T44 まで） | T7 と同じ | `tests/test_*`、T48、T49 で test_publishing.js に2件追加 | なし | `337 passing (4s)`、`All files` 100、`exit=0`。 | 出力は grep で絞られている。 |
| T54（1回目） | 03:09:20 | 既存テスト | 実コード（元のまま。`git stash push peg_src/jsdoctype.pegjs lib/publishing.js` のあと `npm run build`） | mocha の各 it の expect | `npx mocha tests/test_parsing.js tests/test_publishing.js`、テストは T48、T49、T53 の追加を含む | なし | `283 passing (50ms)`、`3 failing`。 | 新しいテストが元のコードで失敗するかを見た実行。 |
| T54（2回目） | 03:09:20 | 既存テスト | 実コード（T42、T44 まで。stash pop のあと npm test でビルド） | T7 と同じ | `tests/test_*`、T48、T49、T53 を含む | なし | `338 passing (4s)`、`All files` 100、`exit=0`。 | |
| T55 | 03:09:31 | 全列挙、ランダム、その他（fixtures） | 実コード（T42、T44 まで）、check.js 版D | A1〜A11 | full | C1、C2 | `OK CodecInverse checked=976560 violations=0`<br>`OK CodecRawStable checked=11106 violations=0`<br>`OK PublishTotal checked=746255 violations=0`<br>`VIOLATE PublishReparses checked=746255 violations=3143`<br>`VIOLATE RoundTripEq checked=743112 violations=109`<br>`VIOLATE PublishFixpoint checked=743112 violations=40`<br>`OK TraverseExact checked=746255 violations=0`<br>`VIOLATE SchemaConforms checked=1456916 violations=498853`<br>`VIOLATE ModeSubset checked=518799 violations=128`<br>`VIOLATE SchemaWellFormed checked=29 violations=7` | 出力は判定の行だけ。 |
| T56 | 03:12:41 | 全列挙、ランダム、その他（fixtures） | 実コード（T42、T44 まで）、check.js 版D | A1〜A11 | `--quick` | C1、C2 | RoundTripEq のバケット：`[4] $: NOT_NULLABLE became NULLABLE  <=  NOT_NULLABLE/SUFFIX_BANG(NULLABLE/PREFIX_QUESTION_MARK)`、`[8] $: ARROW became GENERIC  <=  GENERIC/SQUARE_BRACKET(NAME,NOT_NULLABLE/SUFFIX_BANG)`。 | 出力は RoundTripEq のバケット行だけ。 |
| T59 | 03:13:42 | 全列挙、ランダム、その他（fixtures） | 実コード（T42、T44 まで）、check.js 版E | A1〜A13 | `--self-check --quick` | C1、C2、C3 | 9性質すべて `match`（PublishTotal と TraverseExact は `got OK, ledger says OK`）。<br>壊した版3種は `CAUGHT`（RoundTripEq 449、CodecInverse 2、TraverseExact 28 の新しいバケット）。<br>`RESULT: OK (all verdicts match the ledger)` | 同じ呼び出しで LEDGER.md を書き換えている。 |
| T61 | 03:18:23 | 全列挙、ランダム、その他（fixtures） | 実コード（T42、T44 まで）、check.js 版E | A1〜A11 | `--quick` | C1、C2 | PublishReparses から TraverseExact までのバケット行：`[87] ... NULLABLE/SUFFIX_QUESTION_MARK(NOT_NULLABLE/PREFIX_BANG)`、`[86] ... NOT_NULLABLE/SUFFIX_BANG(NULLABLE/PREFIX_QUESTION_MARK)`、`[74]`、`[73]`、`[60] ... KEY_QUERY(NOT_NULLABLE/SUFFIX_BANG)`、`[42] ... KEY_QUERY(NULLABLE/SUFFIX_QUESTION_MARK)`、`[3] ... GENERIC/SQUARE_BRACKET(NAME,NULLABLE/SUFFIX_QUESTION_MARK)`、`[8] $: ARROW became GENERIC; ...`、`[4] $: NOT_NULLABLE became NULLABLE; ...`、`[4] not a fixpoint`。 | 判定の行と例の行は grep で除かれている。 |
| T66 | 03:19:41 | 手で試した入力 | 実コード（元のまま。`git stash` で作業ツリーの変更をすべて退避） | なし（出力を見ただけ） | `{type:"GENERIC",subject:{type:"NAME",name:"Array"},objects:[{type:"NAME",name:"MyClass"}]}`（meta なし） | なし | `THROWS: Cannot read properties of undefined (reading 'syntax')`。 | |
| T67 | 03:19:54 | 手で試した入力 | 実コード（T42、T44、T64、T67 まで） | なし（出力を見ただけ）。<br>各行に `JSON.stringify(parse(p))===JSON.stringify(a)?"same AST":"DIFF"` の結果を表示。 | meta なしの GENERIC と、13件の文字列（`!X?`、`?X!`、`?X?`、`!X!`、`??!`、`a![]`、...） | なし | `Array<MyClass>`。<br>`!X?`、`?X!`、`?X?`、`!X!`、`??!` は publish 結果が入力と同じ文字列で `same AST`。<br>`a![]` の parse で `SyntaxError: Expected "&", "...", "=", "\|", ... but "[" found.` が投げられ、`Exit code 1`。残り7件は実行されていない。 | |
| T68 | 03:19:59 | 手で試した入力 | 実コード（T67 まで） | なし（出力を見ただけ）。T67 と同じ比較を表示。 | 8件 | なし | `"() => a![]" -> "() => a![]" same AST`、`"keyof a!" -> "keyof a!" same AST`、`"keyof []?" -> "keyof []?" same AST`、`"Object!" -> "!Object" DIFF`、`"goog.ui.Component?" -> "?goog.ui.Component" DIFF`、`"!a?=" -> "!a?=" same AST`、`"keyof a!\|[]" -> "keyof !a \| []" REPARSE-ERR`、`"(x: ?=) => a.\"d\"![]"` は `same AST`。 | `DIFF` は `JSON.stringify` の比較で、meta の違いも含む。 |
| T69 | 03:20:10 | 全列挙、ランダム、その他（fixtures） | 実コード（T67 まで）、check.js 版E | A1〜A11 | full | C1、C2 | `VIOLATE PublishReparses checked=746255 violations=112`（`[81] ... KEY_QUERY(OPTIONAL/SUFFIX_EQUALS_SIGN)` `e.g. "permissive: keyof a ? =  =>  keyof ?a="`、`[15] ... KEY_QUERY(UNION)`、`[14] ... KEY_QUERY(INTERSECTION)`、`[2] ... GENERIC/SQUARE_BRACKET(NAME,OPTIONAL/SUFFIX_EQUALS_SIGN)`）<br>`OK RoundTripEq checked=746143 violations=0`<br>`OK PublishFixpoint checked=746143 violations=0`<br>`OK TraverseExact checked=746255 violations=0` | 出力は sed で PublishReparses から TraverseExact までに絞られている。 |
| T73 | 03:23:41 | 手で試した入力 | 実コード（T73 まで） | なし（出力を見ただけ） | meta なしの NULLABLE(NOT_NULLABLE(NAME)) と7件 | なし | `hand-built no meta: ?!X`、`"!X?" -> !X?`、`"?X!" -> ?X!`、`"??!" -> ??!`、`"keyof a ? =" -> keyof a?=`、`"() => Array.<a>!=[]" -> () => Array.<a>!=[]`、`"keyof a!" -> keyof a!`、`"Object!" -> !Object`。 | |
| T76 | 03:23:54 | 既存テスト | 実コード（T73 まで） | T7 と同じ | `tests/test_*`、T74、T75 の追加を含む | なし | `343 passing (4s)`、`All files` 100、`publishing.js` 100、`exit=0`。 | |
| T77 | 03:24:05 | 既存テスト | 実コード（`lib/publishing.js` だけ `git show HEAD:` の元の版。peg_lib は T42 の版のビルド） | mocha の各 it の expect | `npx mocha tests/test_publishing.js`（T74、T75 の追加を含む） | なし | `91 passing (17ms)`、`6 failing`（`1) publish` から `6) publish`）。 | 実行後に publishing.js は戻されている。 |
| T80（1回目） | 03:24:21 | 既存テスト | 実コード（T73 まで） | T7 と同じ | `tests/test_*` | なし | `npm test exit=0`。 | 出力は捨てられ、終了コードだけ。 |
| T80（2回目） | 03:24:21 | 全列挙、ランダム、その他（fixtures） | 実コード（T73 まで）、check.js 版F | A1〜A13 | `npm run verify`（`node verification/check.js --self-check --quick`） | C1、C2、C3 | `MISMATCH PublishReparses: got OK, ledger says VIOLATE`、ほかの8性質は `match`。<br>壊した版3種は `CAUGHT`（448、2、28）。<br>`RESULT: MISMATCH`、`verify exit=1`。 | `--quick` の入力では PublishReparses の違反が出なかった。 |
| T82 | 03:27:40 | 全列挙、ランダム、その他（fixtures） | 実コード（T73 まで）、check.js 版G | A1〜A13 | `npm run verify`、SEEDS 18件を追加 | C1、C2、C3 | 9性質すべて `match`（PublishReparses は `got VIOLATE`）。<br>壊した版3種は `CAUGHT`（448、2、28）。<br>`RESULT: OK (all verdicts match the ledger)`、`verify exit=0`。 | |
| T83 | 03:30:42 | 全列挙、ランダム、その他（fixtures） | 実コード（T73 まで）、check.js 版G | A1〜A11 | full | C1、C2 | `OK CodecInverse checked=976560 violations=0`<br>`OK CodecRawStable checked=11106 violations=0`<br>`OK PublishTotal checked=746265 violations=0`<br>`VIOLATE PublishReparses checked=746265 violations=29`（`[15] minimal failing subtree KEY_QUERY(UNION)`、`[14] minimal failing subtree KEY_QUERY(INTERSECTION)`）<br>`OK RoundTripEq checked=746236 violations=0`<br>`OK PublishFixpoint checked=746236 violations=0`<br>`OK TraverseExact checked=746265 violations=0`<br>`VIOLATE SchemaConforms checked=1456928 violations=498855` | 出力は先頭20行に絞られ、`type not in` と `no schema` の行は除かれている。ModeSubset と SchemaWellFormed は表示されていない。 |
| T88 | 03:35:34 | その他（AST の形の集計） | 実コード（T73 まで） | なし（出力を見ただけ） | 32件の文字列と、`tests/fixtures` の全行（`!e.skip`）× 4モード。parse で例外の入力は無視。 | meta は `"meta:"+v.syntax` として集計 | ノード型ごとのフィールドと値の種類の一覧。例：`NUMBER_VALUE number=string`、`ARROW params=array returns=node new=null\|string:new`、`EXTERNAL quoteStyle=string:double name=string`、`VARIADIC value=node meta=meta:ONLY_DOTS\|meta:PREFIX_DOTS\|meta:SUFFIX_DOTS`。 | |
| T89 | 03:36:07 | その他 | 実コード（`lib/NodeType.js`）と T89 で書き直した `schemas/NodeType.json` | `JSON.stringify(Object.keys(require("./lib/NodeType.js"))) === JSON.stringify(require("./schemas/NodeType.json").enum)` | 1件 | なし | `true`。 | 同じ呼び出しで schemas/ を Python で書き直している。 |
| T92 | 03:36:38 | 全列挙、ランダム、その他（fixtures） | 実コード（T73 まで、schemas は T89）、check.js 版H | A1〜A11、ただし SchemaConforms と SchemaWellFormed は B1、B2 | `--quick` | C1、C2 | `OK SchemaConforms checked=792954 violations=0`<br>`VIOLATE ModeSubset checked=457721 violations=16`（例 `"jsdoc: ?[]"`、`"jsdoc: ?[][]"`、`"jsdoc: keyof []"`）<br>`OK SchemaWellFormed checked=30 violations=0` | 出力は SchemaConforms 以降の先頭40行。同じ呼び出しで eslint。 |
| T93 | 03:37:38 | 全列挙、ランダム、その他（fixtures） | 実コード（T73 まで、schemas は T89）、check.js 版I | A1〜A13、B1〜B3 | `npm run verify` | C1、C2、C3 | 10性質すべて `match`（SchemaConforms と SchemaWellFormed は `got OK`）。<br>壊した版3種は `CAUGHT`（448、2、28）。<br>カナリア7種すべて `CAUGHT`（例 `MEMBER.name as a node (old B1 shape)  (MEMBER.name: schema says string, got object)`）。<br>`RESULT: OK (all verdicts match the ledger)`、`verify exit=0`。 | 同じ呼び出しで eslint（`LINT-OK`）。 |
| T96 | 03:41:05 | 既存テスト | 実コード（T73 まで） | T7 と同じ | `tests/test_*` | なし | `npm test exit=0`。 | 出力は捨てられ、終了コードだけ。 |
| T102 | 03:43:16 | その他（AST の記録） | 実コード（T73 まで、コミット 80131cd） | なし（件数を見ただけ） | `tests/fixtures` の全行（`!e.skip`）× 4モード。各結果を `JSON.stringify` か `"ERR"` で `/tmp/before.json` に保存。 | なし | `716660`。 | T107 の比較の基準。 |
| T107 | 03:43:59 | その他（fixtures の比較）、手で試した入力 | 実コード（T106 まで。`npm run build` でビルド） | fixtures：`if(b!==r)` で T102 の記録と比べ、`ERR->OK`、`OK->ERR`、`AST changed` に分ける。<br>手で試した入力：各行に `JSON.stringify(parse(p,{mode:m}))===JSON.stringify(a)?"rt-ok":"RT-DIFF"` を表示。 | fixtures の全行 × 4モード。<br>11件（`?string[]`、`!Foo[]`、`?Array<T>[]`、`?Foo[][]`、`() => ?a[]`、`function(): !a[]`、`?[]`、`?[][]`、`?T`、`?string[]=`、`{a: ?T[]}`）× 3モード（permissive、jsdoc、closure）。 | `JSON.stringify` の文字列の一致で比べる | `BUILD-OK`。`fixture diffs:` のあとに行がない。<br>`permissive ?string[] NULLABLE(GENERIC<NAME>) ?string[] rt-ok`、jsdoc も同じ、closure は `ERR`。<br>`jsdoc () => ?a[] ERR`。<br>`permissive ?[][] NULLABLE(GENERIC<TUPLE>)`、`jsdoc ?[][] GENERIC<GENERIC<UNKNOWN>>`。<br>closure は `?T` だけ受理、それ以外の10件は `ERR`。<br>`RT-DIFF` の行はない。 | 直前の T104 は同じ内容だが、ビルドが失敗して node は実行されていない。 |
| T108 | 03:44:30 | 全列挙 | 実コード2版（旧：コミット 80131cd の `lib/` と `peg_lib/` を `/tmp/oldlib` に取り出したもの、新：T106 まで） | `a===null&&b!==null?"newly":a!==null&&b===null?"lost":a!==b?"changed":null`（a、b は旧と新の parse 結果の `JSON.stringify`、例外なら null） | 17トークン（`"a","?","!","[]","=","\|","()","=>","function()",":","{a:","}","<a>","...","keyof","(",")"`）の長さ1〜5の全列を空白で連結 × 4モード | `JSON.stringify` の文字列の一致で比べる | `{ newly: 1274, changed: 32, lost: 0 }`。<br>例：`newly` に `'permissive: a \| ? a []'`、`'jsdoc: a \| ? ? []'`。`changed` に `'permissive: () => ? a []'`、`'typescript: () => ? [] []'`。 | |
| T112 | 03:49:25 | 既存テスト | 実コード（T106 まで） | T7 と同じ | `tests/test_*`、T111 で test_parsing.js に4件追加 | なし | `347 passing (4s)`、`All files` 100、`exit=0`。 | |
| T113 | 03:49:35 | 既存テスト | 実コード（peg_lib だけ 80131cd の版。lib/ は T73 まで） | mocha の各 it の expect | `npx mocha tests/test_parsing.js`（T111 の追加を含む） | なし | `195 passing (41ms)`、`3 failing`。 | 実行後に peg_lib は T106 のビルドに戻されている。 |
| T114 | 03:49:41 | 全列挙、ランダム、その他（fixtures） | 実コード（T106 まで）、check.js 版J | A1〜A13、B1〜B3 | `npm run verify` と、`--quick` の通常実行の2回。SEEDS 22件。 | C1、C2、C3 | verify：10性質すべて `match`。<br>`--quick`：`VIOLATE PublishReparses checked=633241 violations=4`（`[2] ... KEY_QUERY(UNION)` `e.g. "permissive: keyof a!\|[]  =>  keyof !a \| []"`、`[2] ... KEY_QUERY(INTERSECTION)`）、`OK RoundTripEq checked=633237 violations=0`、`VIOLATE ModeSubset checked=457813 violations=20`（`[5] jsdoc accepts, permissive rejects` `e.g. "jsdoc: ? ? []"`）、`OK SchemaWellFormed checked=30 violations=0`。 | verify の出力は `/== ledger check/,/== broken/` で切られ、壊した版とカナリアの結果は表示されていない。`--quick` の出力は `head -30`。 |
| T115（1回目） | 03:53:39 | 全列挙、ランダム、その他（fixtures） | 実コード（T106 まで）、check.js 版J | A1〜A13、B1〜B3 | `npm run verify` | C1、C2、C3 | `RESULT: OK (all verdicts match the ledger)`。 | 出力は `tail -1` の1行だけ。 |
| T115（2回目） | 03:53:39 | 手で試した入力 | 実コード2版（旧：/tmp/oldlib、新：T106 まで） | なし（出力を見ただけ） | `??[]`、`? ? []`、`?[][]`、`!?[]`、`?![]` × jsdoc、permissive | なし | jsdoc：`??[]`、`? ? []`、`!?[]` は旧 `ERR`、新は受理。permissive：同じ3件は新旧とも `ERR`。<br>`?[][]` は permissive で旧 `ERR`、新は `NULLABLE`。<br>`?![]` は両モードとも新旧 `ERR`。 | 出力は各 AST を70文字で切っている。 |
| T117 | 03:57:07 | 手で試した入力 | 実コード（T106 まで） | なし（出力を見ただけ） | `string?[]`、`string[]!`、`string[]?` | なし | 3件とも `ERR`。 | |
| T118 | 03:57:20 | 既存テスト | 実コード（T106 まで） | T7 と同じ | `tests/test_*` | なし | `TESTS-OK`。 | `npm test >/dev/null 2>&1 && echo TESTS-OK` で、出力は捨てられている。同じ呼び出しで eslint。 |

## 行にしなかった呼び出し

T9（z3 の版と tlc、java の有無）、T12（z3py の関数名の一覧）は道具の有無を見ただけなので行にしていない。
T104 は `npm run build` が `Rule "PrefixUnaryUnionTypeExprOperand" is not defined.`（T105 の出力）で失敗し、後ろの node は実行されていない。
eslint だけの実行（T85 など）は、ライブラリの振る舞いを判定していないので行にしていない。

## check.js の判定条件の引用

A 節は版A〜版G の判定である。
版H 以降は SchemaConforms と SchemaWellFormed が B 節に置き換わる。

- A1 入力の扱い：`const r = tryParse(s, mode);` `if (r.error) return false;`。モードが受理しない入力は検査しない。
- A2 PublishTotal：`p = publish(ast, pub);` が例外を投げたら `record(ledger, 'PublishTotal', false, e.message, tag + s);`。
- A3 PublishReparses：`const r2 = tryParse(p, mode);` `record(ledger, 'PublishReparses', !r2.error, ...)`。
- A4 RoundTripEq：`const eq = util.isDeepStrictEqual(normalize(ast), normalize(r2.ast));`（再 parse できた入力だけ）。
- A5 PublishFixpoint：`record(ledger, 'PublishFixpoint', p2 === p, 'not a fixpoint', ...)`。p2 は `publish(r2.ast, pub)`。
- A6 TraverseExact：`if (prop !== null \|\| parent !== null) fail('root has parent info');`、`!(parent[prop] === node \|\| (Array.isArray(parent[prop]) && parent[prop].includes(node)))` で `'wrong parent info for '`、`if (stack.pop() !== node) fail('enter/leave not nested');`、`if (c !== 1) fail(util.format('%s visited %d times', nodeShape(n), c));`、`if (!expected.includes(n)) fail('visited foreign node ' + n.type);`。expected は `reachableNodes(ast)`。
- A7 SchemaConforms（版A〜版G、permissive の入力だけ）：`if (!nodeTypeEnum.includes(node.type))`、`if (!name) { problems.push(node.type + ': no schema file');`、`if (!(k in node)) problems.push(node.type + '.' + k + ': required but missing');`、`if (typeof v !== s.type)`、`else if (s.enum && !s.enum.includes(v))`、meta の `if (ss.enum && !ss.enum.includes(v[kk]))`、`if (s.$ref === 'Node.json' && !(v && typeof v === 'object' && v.type))`。
- A8 ModeSubset（permissive 以外のモード）：`const ok = !rp.error && util.isDeepStrictEqual(rp.ast, ast);`。rp は同じ文字列の permissive での parse。
- A9 CodecInverse：`const ok = !r.error && util.isDeepStrictEqual(r.ast, ast);`。ast は手で組み立てたノード、r は `tryParse(publish(ast, pub), 'permissive')`。CodecRawStable：`const ok = !r2.error && util.isDeepStrictEqual(r.ast, r2.ast);`。
- A10 SchemaWellFormed（版A〜版G）：配列の要素が `x === null`、`$ref` の先が `!fs.existsSync(path.join(SCHEMA_DIR, v.$ref.split('#')[0] \|\| '__missing__'))`、`typeof v.type === 'string' && /\.json$/.test(v.type)`。
- A11 判定と終了コード：`v[p] = ledger.violations[p] ? 'VIOLATE' : 'OK';`。`--self-check` がなければ `process.exit(Object.keys(v).every((p) => v[p] === 'OK') ? 0 : 1);`。
- A12 自己検査の台帳：`const match = v[p] === EXPECTED[p];`。EXPECTED は版ごとに異なる（「check.js の版」を参照）。
- A13 自己検査の壊した版：publisher が括弧を落とす版（RoundTripEq で判定）、文字列をエスケープしない版（CodecInverse）、GENERIC の objects を飛ばす traverse（TraverseExact）。`const caught = fresh.length > 0;`。
- B1 SchemaConforms（版H〜版J）：`validate(node, loadSchema(name), node.type)`。validate は `$ref` をたどり、`oneOf` は `matched === 1`、`if (schema.type && jsonType(v) !== schema.type)`、`if (schema.enum && !schema.enum.includes(v))`、`required`、`properties` と `items` を再帰で検査する。加えて `if (!(k in declared)) problems.push(node.type + '.' + k + ': undeclared');`。
- B2 SchemaWellFormed（版H〜版J）：`SCHEMA_KEYWORDS` にない鍵は `'unsupported keyword '`、`SCHEMA_TYPES` にない type は `'invalid type '`、`if ('$ref' in s && !fs.existsSync(path.join(SCHEMA_DIR, s.$ref)))`、オブジェクトでない schema は `' is not a schema'`。
- B3 カナリア（版I〜版J）：7種の手作りノードについて `const probs = schemaProblems(node); ok = ok && probs.length > 0;`。

## 比較の緩め方の引用

- C1 RoundTripEq の `normalize`：`if (out.type === 'NULLABLE' \|\| out.type === 'NOT_NULLABLE') delete out.meta;` と `if (out.type === 'VARIADIC' && out.meta.syntax === 'SUFFIX_DOTS') { out.meta = {syntax: 'PREFIX_DOTS'}; }`。ModeSubset、CodecInverse、CodecRawStable は `normalize` を通さない。PublishFixpoint は文字列の `===`。
- C2 `reachableNodes` は `if (!v \|\| typeof v !== 'object' \|\| key === 'meta') return;` で meta の下を見ない。TraverseExact と SchemaConforms の対象はこの関数で集めたノードである。
- C3 壊した版は、本物の実装にない新しいバケットだけを数える：`const fresh = after.filter((b) => !before.includes(b));`。
- 違反は理由の文字列ごとのバケットにまとめ、例は最も短いものだけを残す：`if (witness.length < b.witness.length) b.witness = witness;`。

## check.js の入力の範囲

- 入力は `seen` で重複を除き（`if (seen.has(s)) continue;`）、各入力を `MODES = ['permissive', 'jsdoc', 'closure', 'typescript']` の4モードで検査する。
- CODEC：字母 `['a', '\\', '\'', '"', '\n']` の長さ0〜CODEC_LEN の全文字列 × 文脈5種（STRING_VALUE、MEMBER、RECORD_ENTRY、FILE_PATH、EXTERNAL）× `['single', 'double']`。生の側は長さ0〜CODEC_LEN-1 を `'` と `"` で囲み、permissive で parse する。`CODEC_LEN = QUICK ? 5 : 7`。
- TOKENS：33トークンの長さ1〜TOKEN_LEN の全列を空白で連結。`TOKEN_LEN = QUICK ? 3 : 4`。
- RANDOM：`mulberry32(0xC0FFEE)`、件数は `RANDOM_N = QUICK ? 20000 : 300000`、`gen(4)` で深さ4まで、`if (d === 0 \|\| rnd() < 0.3) return pick(LEAVES);`。LEAVES は26件、FORMS は41件。
- FIXTURES：`tests/fixtures` の全ファイルの全行で `if (!e.skip)`。
- SEEDS：版G で18件（`'typeof a.b'`、`'(x:) => a'`、`'!X?'` など）、版J で4件追加（`'?string[]', '!Foo[][]', 'function(): !a[]', '() => ?a[]'`）。
- `--self-check` のときは、本体のあとに壊した版3種で `runAll` を同じ入力でもう1回ずつ実行する。

## 備考（コードと出力からの観察）

- RANDOM の生成式は `.replace(/ /g, sp \|\| ' ')` で、sp が `''` のときも `' '` に置き換わる。
- 出力の `checked` は、全入力とモードの組のうち parse が受理したものの数である。
- `--quick` の verify（T80）では PublishReparses の違反が出ず、full（T83）では29件出た。

## スクリプトごとの一覧

| 名前 | 書いた T 番号 | 書き換えた T 番号 |
|---|---|---|
| `verification/codec_z3.py` | T13 | T15（sed）、T16。T19 で削除 |
| `verification/check.js` | T20 | T22、T23、T24、T25、T33、T36（sed）、T57（sed）、T78（sed）、T82（Python）、T92（Python）、T93（Python）、T114（Python） |
| `package.json` の `verify` スクリプト（`node verification/check.js --self-check --quick`） | T78 | なし |
| `tests/test_publishing.js`（既存のテストへの追加） | なし（既存） | T48、T49、T74、T75 |
| `tests/test_parsing.js`（既存のテストへの追加） | なし（既存） | T53、T111（T46 の Python は assert で止まり、書き込んでいない） |

## check.js の版

| 版 | 内容 | EXPECTED（自己検査の台帳） | 使った実行 |
|---|---|---|---|
| 版A | T20 | PublishTotal から ModeSubset まで `'VIOLATE'`、Codec の2つは `'OK'` | T21 |
| 版B | 版A に T22〜T25 | 版A と同じ | T26 |
| 版C | 版B に T33 | 版A と同じ | T34 |
| 版D | 版C に T36 の sed（未使用の `NODE_TYPES` を削除） | 版A と同じ | T36、T55、T56 |
| 版E | 版D に T57 | PublishTotal、TraverseExact を `'OK'` | T59、T61、T69 |
| 版F | 版E に T78 | さらに RoundTripEq、PublishFixpoint を `'OK'` | T80 |
| 版G | 版F に T82（SEEDS 18件） | 版F と同じ | T82、T83 |
| 版H | 版G に T92（スキーマの検査器を置き換え） | さらに SchemaConforms を `'OK'` | T92 |
| 版I | 版H に T93（カナリア7種） | さらに `SchemaWellFormed: 'OK'` を追加 | T93 |
| 版J | 版I に T114（SEEDS 4件を追加） | 版I と同じ | T114、T115 |
