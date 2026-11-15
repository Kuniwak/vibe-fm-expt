# 使い方

## 準備

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

使っている第三者のソフトウェアと文書の出典は `THIRD_PARTY.md` にある。

## コマンド

```
make build                                    # イメージを作る
MODEL=claude-opus-5-5 make probe              # 被験側に読み込まれるものを一覧し、想定外があれば非ゼロで終わる
COND=A MODEL=claude-opus-5-5 make run         # 条件 A の run を1回行う（probe、対話、回収まで自動）
make collect [RUN=runs/run-NN]                # 回収をやり直す（既定は最新の run）
make audit   [RUN=runs/run-NN]                # 回収した run を、被験エージェントなしで棚卸しする
python3 scripts/analysis/extract.py runs/run-NN   # 発言の通し番号付き一覧、キーワード抜き出し、道具の呼び出し、判定役の記録
```

条件、手順、判定役の規則は `preregistration.md` に固定してある。
`make run` は `COND` と `MODEL` の指定を必須とし、最初の発言のファイルが登録済みの sha256 と一致しない場合は起動しない。
対話は盲検の判定役が自動で行い、被験側の発言が区切れるたびに「お任せします」か固定発言のどちらかを送る。
`MIRROR=1` を付けると、被験側の画面を端末に映しながら実行する。

ハーネスの動作確認は、実験用の発言を使わずに次の形で行う（結果は `runs/_test/` に置かれ、run の番号を消費しない）。

```
COND=TEST OFF_PROTOCOL=1 MODEL=claude-opus-5-5 PROMPT_FILE=<無関係な発言のファイル> make run
```

各 run の成果物と記録は `runs/run-NN/` に置かれる。

- **`home/`**：コンテナ内のホームディレクトリ（作業ディレクトリ `jsdoctypeparser/` とセッション記録 `.claude/` を含む）。Lean ツールチェーン、Mathlib キャッシュ、`.lake/packages`、`node_modules` は除く
- **`record/`**：端末の記録、セッション記録、判定役の記録（`operator.jsonl`）、起動コマンド、バージョンとイメージ ID、ネットワーク設定、開始と終了の時刻
- **`probe/`**：その run の直前に実行した probe の出力
- **`audit/`**：`make audit` の結果（Lean、TLA+、Z3、スクリプトの棚卸し）
- **`analysis/`**：`extract.py` の出力

## 実行前に決める項目

本試行の条件、モデル、回数、打ち切り時間、ネットワークは `preregistration.md` で決めてある。
以下は、それ以外の試行（`OFF_PROTOCOL=1`）を行うときの指定方法である。

- **条件（イメージ）**：`config/conditions.tsv` に登録する。`devenv` は Lean 4 と Mathlib だけ、`devenv-b` はそれに TLA+ と Z3 を加えたイメージである。
- **モデル**：`MODEL` で指定する。登録済みのモデルと違う値は、`OFF_PROTOCOL=1` を付けた場合だけ受け付ける。基準線のないモデルは、先に `MODEL=<モデル名> PROBE_WRITE_BASELINE=1 make probe` で基準線を書き、中身を確認してから使う。指示ファイル、メモリ、MCP、ユーザー由来のスキルやプラグインが見つかった場合は、基準線を書かずに失敗する。
- **打ち切り時間と手順の定数**：`config/protocol.env` にある。
- **ネットワーク**：`NET=allowlist`（既定）は `config/allow-domains.txt` の宛先への HTTPS だけを許可する。`NET=open` は制限しない。適用したルールは `record/network.log` に残る。
