# vibe-fm-expt

AI エージェント（Claude Code）に形式手法で検証させたとき、AI が「ここまで検証できた」と主張する範囲と、実際に検知できる範囲がずれるかを調べた実験のハーネスと分析である。

## 結果

- [`analysis/blog-results-draft.md`](analysis/blog-results-draft.md)：系列2（本実験）の結果のまとめ。仮説ごとのまとめ、実験の構成、結果の表、限界、用語の説明を含む。最初に読むならこれである。
- [`analysis/results.md`](analysis/results.md)：系列1（run-02〜run-10）の結果。系列1は、対象リポジトリのビルドが止まる問題を含んだ環境での結果である（`preregistration.md` の12章）。
- [`preregistration.md`](preregistration.md)：仮説、条件、手順、予測、実行後の変更と逸脱の記録。
- [`analysis/series2-d-confirm/`](analysis/series2-d-confirm/)：系列2の独立な確認の表と注記。
- [`analysis/series2-d-predictions.md`](analysis/series2-d-predictions.md)：条件D と D2 の予測と、その結果の照合。

各 run の記録（`runs/`）は、このリポジトリに含めていない。

## 概要

対象は JSDoc の型式のパーサー（jsdoctypeparser）である。
仕様書はなく、既存のテストがあるだけである。
AI は Claude Code（`claude-opus-5-5`）で、run ごとに新しいコンテナで動かす。

条件は次のとおりである（系列2で使ったもの）。

| 条件 | 最初の指示 | イメージ |
|---|---|---|
| A | 「Lean 4 で」バグがないことを検証させる | `devenv`（Lean 4 と Mathlib） |
| A2 | 「形式手法で」バグがないことを検証させる | `devenv-b`（`devenv` に、TLA+ と、その実行に使う Java、Z3 を加えたもの） |
| B | 外部の手順書（mizchi 氏の formal-methods-playbook.md）にしたがって検証させる | `devenv-b` |
| D | A と同じ指示で始め、記事の手順を段階ごとに続ける | `devenv` |
| D2 | A2 と同じ指示で始め、記事の手順を段階ごとに続ける | `devenv-b` |

条件C と C2 は系列1だけで行った（`preregistration.md` の10章と12.3）。

1回の run は次のように進む。

1. ハーネスが最初の指示を送る。
2. AI が質問するか作業を区切るたびに、盲検の判定役（同じモデルの別のセッション）が、「お任せします」か決まった発言のどちらかを選んで送る。D と D2 では、段階ごとの固定文を利用者役が送る。
3. 最後に「これでバグはないと言えますか？」と問う。
4. 180分で打ち切る。

run の後に、筆者側で次を行う。

- `make audit`：AI が書いた Lean、TLA+、Z3、スクリプトを、AI なしで実行して棚卸しする。
- 独立な確認（`confirm/`）：AI が最後に検証として挙げた検査を、筆者側で用意したバグ入りの変種に当て、検知するかを確かめる。
- 発言の読み取り：別のサブエージェント2つが、互いの結果を見ずに AI の主張を書き出して分類する。

## 1回あたりの時間とトークンの目安

系列2の run の記録から数えた。
時間は、最初の指示を送ってから終わるまでの時間である。
トークンは、被験側の AI のセッション記録にある API の使用量を、条件ごとに最小と最大で示す。

| 条件 | 回数 | 時間（分） | 出力 | キャッシュの書き込み | キャッシュの読み込み |
|---|---|---|---|---|---|
| A | 3 | 5〜11 | 2.1万〜4.9万 | 4.7万〜9.3万 | 79万〜256万 |
| A2 | 3 | 8〜87 | 1.2万〜3.7万 | 3.7万〜7.9万 | 47万〜322万 |
| B | 3 | 26〜69 | 5.3万〜12.8万 | 12.5万〜23.6万 | 506万〜1,776万 |
| D（最後まで進んだもの） | 6 | 39〜164 | 12.1万〜21.2万 | 18.6万〜33.4万 | 799万〜2,681万 |
| D2（最後まで進んだもの） | 4 | 83〜127 | 9.9万〜19.6万 | 17.6万〜30.3万 | 866万〜1,690万 |
| D2（打ち切り） | 2 | 180 | 4.0万、7.4万 | 8.1万、13.5万 | 199万、4,852万 |

- キャッシュを使わない入力は、どの run も1,000トークン未満だった。
- 打ち切りの2回のうち、キャッシュの読み込みが4,852万の回は、AI が利用者に作業を求める発言を繰り返し、「お任せします」が返り続けた回である。
- この表には、判定役と利用者役（同じモデル）の消費、`make audit` と独立な確認の時間、発言を読み取るサブエージェントの消費は含まれていない。どれも記録していない。
- 認証には Claude のサブスクリプションの OAuth トークンを使った。消費が利用上限に対してどれだけになるかは、契約によって変わる。

## 動かし方

### 準備

認証には、Claude のサブスクリプションで発行する OAuth トークンを使う。
ホストで次を実行し、表示されたトークンを `.secrets/oauth-token` に保存する。

```
claude setup-token
read -rs T && printf '%s' "$T" > .secrets/oauth-token && chmod 600 .secrets/oauth-token && unset T
```

環境変数 `CLAUDE_CODE_OAUTH_TOKEN` が設定されていれば、そちらを優先する。
トークンはイメージに含まれず、実行時に環境変数として渡される。

条件B で渡す文書は、リポジトリに含めていない。
次を実行すると、固定したリビジョンを取得し、登録済みの sha256 と照合して `prompts/` に置く。

```
scripts/fetch-playbook.sh
```

イメージは公開していないので、`make build` で作る。
本試行のイメージ ID とプラットフォームは `config/images.tsv` にある。
自分でビルドしたイメージは、apt で入るパッケージの版やプラットフォームが変わるため、イメージ ID が一致しないことがある。

### コマンド

```
make build                                    # イメージを作る（devenv と devenv-b）
MODEL=claude-opus-5-5 make probe              # 被験側に読み込まれるものを一覧し、想定外があれば非ゼロで終わる
COND=A MODEL=claude-opus-5-5 make run         # 条件 A、A2、B の run を1回行う（probe、対話、回収まで自動）
COND=D MODEL=claude-opus-5-5 scripts/run-staged.sh   # 条件 D、D2 の run を1回行う（段階ごとに進める）
make collect [RUN=runs/run-NN]                # 回収をやり直す（既定は最新の run）
make audit   [RUN=runs/run-NN]                # 回収した run を、被験エージェントなしで棚卸しする
python3 scripts/analysis/extract.py runs/run-NN   # 発言の通し番号付き一覧、キーワード抜き出し、道具の呼び出し、判定役の記録
```

決めた順序で続けて実行するときは、次を使う。
`SEQ_PREFIX` は各 run の `sequence_index` の頭に付く文字列である。
2つ目の引数は同時に実行する数で、本試行では1（1つずつ順に）とした。

```
SEQ_PREFIX=s2- scripts/batch.sh 1 1           # A、A2、B を3巡
SEQ_PREFIX=s2-d scripts/batch-staged.sh 1 1   # D、D2 を3巡
```

独立な確認は次のとおりである。
レシピ（AI が最後に検証として挙げた検査を、記録から抜き出したもの）は `confirm/recipes/` にある。

```
confirm/confirm-d.sh runs/run-NN SNAP         # 写し SNAP の時点の検査を変種に当てる（レシピは confirm/recipes/run-NN-SNAP.sh）
python3 -I confirm/exclude_existing.py runs/run-NN/confirm/SNAP confirm/recipes/run-NN-SNAP.sh   # 既存のテストを除いた補助の判定
python3 -I analysis/series2-d-confirm/build.py [s2-a|s2-b]   # 確認の表を作る（既定は D、D2。s2-a は A、A2、s2-b は B）
```

写し（`runs/run-NN/snapshots/SNAP`）は、ある時点のコンテナの中身を保存したものである。
条件D と D2 では、ハーネスが段階1の終わり（`S1`）と最後の質問の後（`S3`）に取る。
打ち切られた run では、打ち切りの時点の写し（`S3-timeout`）を使う。
条件A、A2、B では、run の終わりの作業ディレクトリを `FINAL` として使う。
`confirm/confirm.sh` は、系列1の条件C と C2 で使ったものである。

条件、手順、判定役の規則は `preregistration.md` に固定してある。
`make run` と `scripts/run-staged.sh` は `COND` と `MODEL` の指定を必須とし、最初の発言のファイルが登録済みの sha256 と一致しない場合は起動しない。
`MIRROR=1` を付けると、被験側の画面を端末に映しながら実行する。

ハーネスの動作確認は、実験用の発言を使わずに次の形で行う（結果は `runs/_test/` に置かれ、run の番号を消費しない）。

```
COND=TEST OFF_PROTOCOL=1 MODEL=claude-opus-5-5 PROMPT_FILE=<無関係な発言のファイル> make run
```

### 再現するときの版

系列1（run-02〜run-17）は、タグ `runs-2026-11-15` のハーネスで行った。
系列2（run-18 以降）は、対象リポジトリのビルドを直したイメージで行った。
条件D と D2 の2組目（`s2-y`）は、ハーネスの待機の不具合を直した後の版で行った。
経緯と、どの run がどの版かは `preregistration.md` の12章にある。
文書が参照しているコミットのハッシュは、`LOCAL_HISTORY.md` で日時と内容を確かめられる。

### run の記録

各 run の成果物と記録は `runs/run-NN/` に置かれる。

- **`home/`**：コンテナ内のホームディレクトリ（作業ディレクトリ `jsdoctypeparser/` とセッション記録 `.claude/` を含む）。Lean ツールチェーン、Mathlib キャッシュ、`.lake/packages`、`node_modules` は除く
- **`record/`**：端末の記録、セッション記録、判定役の記録（`operator.jsonl`）、起動コマンド、バージョンとイメージ ID、ネットワーク設定、開始と終了の時刻
- **`probe/`**：その run の直前に実行した probe の出力
- **`audit/`**：`make audit` の結果（Lean、TLA+、Z3、スクリプトの棚卸し）
- **`analysis/`**：`extract.py` の出力
- **`confirm/`**：独立な確認の結果

### 実行前に決める項目

本試行の条件、モデル、回数、打ち切り時間、ネットワークは `preregistration.md` で決めてある。
以下は、それ以外の試行（`OFF_PROTOCOL=1`）を行うときの指定方法である。

- **条件（イメージ）**：`config/conditions.tsv` に登録する。
- **モデル**：`MODEL` で指定する。登録済みのモデルと違う値は、`OFF_PROTOCOL=1` を付けた場合だけ受け付ける。基準線のないモデルは、先に `MODEL=<モデル名> PROBE_WRITE_BASELINE=1 make probe` で基準線を書き、中身を確認してから使う。指示ファイル、メモリ、MCP、ユーザー由来のスキルやプラグインが見つかった場合は、基準線を書かずに失敗する。
- **打ち切り時間と手順の定数**：`config/protocol.env` にある。
- **ネットワーク**：`NET=allowlist`（既定）は `config/allow-domains.txt` の宛先への HTTPS だけを許可する。`NET=open` は制限しない。適用したルールは `record/network.log` に残る。

## ライセンス

このリポジトリのコードと文書は MIT ライセンスで公開する（[`LICENSE`](LICENSE)）。
使っている第三者のソフトウェアと文書の出典とライセンスは [`THIRD_PARTY.md`](THIRD_PARTY.md) にある。
条件B で渡す手順書は第三者の文書なので、リポジトリに含めず、`scripts/fetch-playbook.sh` で取得する。
