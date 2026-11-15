# 出典と第三者のソフトウェア

このハーネスが使う第三者の成果物と、その入手元、版、ライセンスの一覧である。
「含まれる場所」は、このリポジトリに含まれるか、ビルドしたイメージに含まれるか、実行時に取得するかを示す。

## 条件B で渡す文書

| 項目 | 内容 |
|---|---|
| 題名 | 実装コードから仕様を吸い出して Z3 / TLA+ でバグを払い出す — 実践プレイブック（`formal-methods-playbook.md`） |
| 著者 | mizchi |
| 入手元 | https://gist.github.com/mizchi/db7817e6fc077d567c41cd9d41bb1c53 |
| 版 | リビジョン `2133eced8334ed36e47ec4d6e138a46552539256`（sha256 `fb57611a80ed755ed8dc39279b8134e1200f12239d649663d7b1acb07d0c5b72`） |
| ライセンス | 明示なし |
| 含まれる場所 | `scripts/fetch-playbook.sh` が上の版を取得し、sha256 を照合して `prompts/playbook-2133eced.md` と `prompts/b.txt` を作る |

## 検証の対象

| 名前 | 版 | 入手元 | ライセンス | 含まれる場所 |
|---|---|---|---|---|
| jsdoctypeparser | コミット `5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb` | https://github.com/jsdoctypeparser/jsdoctypeparser | MIT | イメージ（`.git` と `tests/` を含む） |
| jsdoctypeparser の npm 依存 | `package-lock.json` のとおり（`npm ci`） | https://registry.npmjs.org/ | 各パッケージによる（MIT、ISC、BSD-2-Clause、BSD-3-Clause、Apache-2.0 など） | イメージ（`node_modules/`） |

## 作業用イメージ（`image/Dockerfile`）

| 名前 | 版 | 入手元 | ライセンス | 含まれる場所 |
|---|---|---|---|---|
| Ubuntu | 24.04（`sha256:2198e4c6…` に固定） | https://hub.docker.com/_/ubuntu | 各パッケージによる | イメージ |
| elan | v4.2.4 | https://github.com/leanprover/elan | リポジトリの LICENSE を参照 | イメージ |
| Lean 4 | v4.35.0 | https://github.com/leanprover/lean4 | Apache-2.0 | イメージ |
| Mathlib（ビルド済みキャッシュ） | v4.35.0（`56a005855ea17e0b0958f73ec801ae140b0a1679`） | https://github.com/leanprover-community/mathlib4 、キャッシュは https://cache.mathlib.org/ | Apache-2.0 | イメージ（`~/.cache/mathlib`） |
| Node.js | v24.22.3 | https://nodejs.org/ | MIT ほか（同梱の LICENSE を参照） | イメージ |
| Claude Code | 2.1.311 | https://www.npmjs.com/package/@anthropic-ai/claude-code | Anthropic の独自ライセンス（「© Anthropic PBC. All rights reserved.」、利用条件は https://code.claude.com/docs/en/legal-and-compliance ） | イメージ |
| Eclipse Temurin JRE | 21.0.9+10 | https://adoptium.net/ | GPL-2.0 with Classpath Exception（同梱の `legal/` を参照） | イメージ `devenv-b` のみ |
| TLA+ tools（`tla2tools.jar`） | v1.7.4 | https://github.com/tlaplus/tlaplus | MIT | イメージ `devenv-b` のみ |
| Z3 | 5.3.3 | https://github.com/Z3Prover/z3 | MIT | イメージ `devenv-b` のみ |
| z3-solver（Python） | 5.3.3.0 | https://pypi.org/project/z3-solver/ | MIT | イメージ `devenv-b` のみ |

## ネットワーク制御用イメージ（`netguard/Dockerfile`）

| 名前 | 版 | 入手元 | ライセンス | 含まれる場所 |
|---|---|---|---|---|
| Alpine Linux | 3.22（`sha256:49340b34…` に固定） | https://hub.docker.com/_/alpine | 各パッケージによる | イメージ |
| iptables、ip6tables、ipset | Alpine 3.22 のパッケージ | https://pkgs.alpinelinux.org/ | GPL-2.0 | イメージ |
| bind-tools | Alpine 3.22 のパッケージ | https://pkgs.alpinelinux.org/ | MPL-2.0 | イメージ |

## 実行時に使うもの

| 名前 | 用途 |
|---|---|
| Claude Code（ホスト側） | OAuth トークンの発行（`claude setup-token`）。判定役はイメージ `devenv` の中の Claude Code で動く |
| Docker | すべてのコンテナの実行 |
| expect、Python 3（ホスト側） | probe と対話の操作、抜き出し |
