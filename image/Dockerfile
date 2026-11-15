# syntax=docker/dockerfile:1
# Workspace image. Layers are ordered from least to most frequently changed:
#   OS -> Lean toolchain -> Mathlib cache -> Node.js / Claude Code -> target repository -> user config
# Build context is this directory only; nothing else from the host is copied in.
# Targets: `a` = Lean 4 only (condition A), `b` = `a` plus TLA+ and Z3 (condition B).
# `b` only adds layers on top of `a`, so the `a` image is unchanged by it.

FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5 AS a

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils zstd procps less \
 && rm -rf /var/lib/apt/lists/* \
 && userdel -r ubuntu 2>/dev/null; \
    useradd -m -u 1000 -s /bin/bash dev

# ---- Lean toolchain (elan + Lean/Lake) --------------------------------------
ARG ELAN_VERSION=v4.2.4
ARG ELAN_SHA256_arm64=05febd124d84ebf994b2e7479922a5650b1e950c17ae3bd1ddd776b65bb72bf9
ARG ELAN_SHA256_amd64=42b94d4244e8353142c456ec0e4ca6528fd898a6c604d4059f494e706e431f63
ARG LEAN_TOOLCHAIN=leanprover/lean4:v4.35.0

USER dev
WORKDIR /home/dev
ENV PATH=/home/dev/.elan/bin:$PATH
RUN set -eu; \
    case "$TARGETARCH" in arm64) a=aarch64; s=$ELAN_SHA256_arm64;; amd64) a=x86_64; s=$ELAN_SHA256_amd64;; *) exit 1;; esac; \
    curl -sSfL -o /tmp/elan.tgz "https://github.com/leanprover/elan/releases/download/${ELAN_VERSION}/elan-${a}-unknown-linux-gnu.tar.gz"; \
    echo "$s  /tmp/elan.tgz" | sha256sum -c -; \
    tar -xzf /tmp/elan.tgz -C /tmp; \
    /tmp/elan-init -y --no-modify-path --default-toolchain none; \
    rm -f /tmp/elan.tgz /tmp/elan-init; \
    elan toolchain install "$LEAN_TOOLCHAIN"; \
    elan default "$LEAN_TOOLCHAIN"; \
    lean --version; lake --version

# ---- Mathlib build cache -----------------------------------------------------
# `lake new <name> math` pins Mathlib to the tag matching the default toolchain
# (v4.35.0) and its post-update hook runs `lake exe cache get`, which reads from
# the per-user cache ~/.cache/mathlib before downloading. Pre-filling that cache
# here means a new Mathlib project only unpacks files, without downloading or compiling.
ARG MATHLIB_REV=56a005855ea17e0b0958f73ec801ae140b0a1679
RUN set -eu; \
    mkdir -p /tmp/w && cd /tmp/w; \
    lake new warm math > /tmp/w/log 2>&1 || { tail -50 /tmp/w/log; exit 1; }; \
    grep -q "\"$MATHLIB_REV\"" warm/lake-manifest.json || { echo "unexpected Mathlib revision"; cat warm/lake-manifest.json; exit 1; }; \
    cd warm && printf 'import Mathlib\nexample : (2:Nat) + 2 = 4 := by norm_num\n' > Warm/Basic.lean; \
    lake build > /tmp/w/build.log 2>&1 || { tail -50 /tmp/w/build.log; exit 1; }; \
    if grep -q 'Built Mathlib\.' /tmp/w/build.log; then echo "Mathlib was compiled; cache did not apply"; exit 1; fi; \
    cd / && rm -rf /tmp/w; \
    du -sh /home/dev/.cache/mathlib

# ---- Node.js and Claude Code ------------------------------------------------
USER root
ARG NODE_VERSION=v24.22.3
ARG NODE_SHA256_arm64=6e51a2ada00f0011cc266f65d98922b403d7ad88f809ca2aa615a5fe1ce6e86c
ARG NODE_SHA256_amd64=4f2b175a6d53a5c617a80dba2676238a0688cef28c6da4eba35c7d844e66fcfb
RUN set -eu; \
    case "$TARGETARCH" in arm64) a=arm64; s=$NODE_SHA256_arm64;; amd64) a=x64; s=$NODE_SHA256_amd64;; *) exit 1;; esac; \
    curl -sSfL -o /tmp/node.tar.xz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${a}.tar.xz"; \
    echo "$s  /tmp/node.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; node --version

ARG CLAUDE_CODE_VERSION=2.1.311
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && npm cache clean --force \
 && rm -rf /root/.npm \
 && claude --version

# ---- Target repository -------------------------------------------------------
ARG REPO_URL=https://github.com/jsdoctypeparser/jsdoctypeparser.git
ARG REPO_COMMIT=5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb
# The pinned commit recreated with the build fix below (same tree except package.json,
# same parent, author, committer, dates and message), so the hash is deterministic.
ARG REPO_BASE=d395aa070e17b600969e18139e43ace2fbe2f78f
USER dev
COPY --chown=dev:dev skel/.gitconfig /home/dev/.gitconfig
RUN set -eu; \
    git clone --quiet "$REPO_URL" /home/dev/jsdoctypeparser; \
    cd /home/dev/jsdoctypeparser; \
    br=$(git symbolic-ref --short HEAD); \
    git checkout --quiet -B "$br" "$REPO_COMMIT"; \
    test "$(git rev-parse HEAD)" = "$REPO_COMMIT"; \
    # Build fix (preregistration.md, 12.): frs-replace reads stdin until EOF before anything
    # else, so `-i <file>` hangs whenever stdin is an open pipe. Feed the grammar on stdin
    # instead; the generated peg_lib files are byte-identical.
    sed -i "s# -i './peg_src/jsdoctype.pegjs' --stdout# < ./peg_src/jsdoctype.pegjs#" package.json; \
    test "$(grep -c '< ./peg_src/jsdoctype.pegjs' package.json)" = 3; \
    GIT_COMMITTER_NAME="$(git log -1 --format=%cn)" GIT_COMMITTER_EMAIL="$(git log -1 --format=%ce)" \
      GIT_COMMITTER_DATE="$(git log -1 --format=%cd --date=raw)" \
      git commit --quiet --amend --no-verify -C HEAD -- package.json; \
    test "$(git rev-parse HEAD)" = "$REPO_BASE"; \
    for t in $(git tag --points-at "$REPO_COMMIT"); do test "$(git cat-file -t "refs/tags/$t")" = commit; git update-ref "refs/tags/$t" "$REPO_BASE"; done; \
    # Drop refs that point past the pinned commit so later upstream history is not reachable;
    # origin/<default branch> and origin/HEAD are kept, pointing at the pinned commit.
    git for-each-ref --format='%(refname)' refs/remotes | xargs -r -n1 git update-ref -d; \
    git update-ref "refs/remotes/origin/$br" "$REPO_BASE"; \
    git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$br"; \
    git branch --quiet --set-upstream-to="origin/$br"; \
    for t in $(git tag); do git merge-base --is-ancestor "$t" HEAD || git tag -d "$t" >/dev/null; done; \
    git reflog expire --expire=now --all; git gc --quiet --prune=now; \
    test "$(git rev-parse HEAD)" = "$REPO_BASE"; \
    if git cat-file -e "$REPO_COMMIT" 2>/dev/null; then echo "original commit still reachable" >&2; exit 1; fi; \
    npm ci --no-audit --no-fund; \
    git status --short | head; \
    rm -rf /home/dev/.npm

# ---- Claude Code user-level state (first-run dialogs only) -------------------
COPY --chown=dev:dev skel/.claude.json /home/dev/.claude.json
COPY --chown=dev:dev skel/.claude/settings.json /home/dev/.claude/settings.json

WORKDIR /home/dev/jsdoctypeparser
CMD ["bash"]

# ==== Target b: TLA+ and Z3 on top of target a ===============================
FROM a AS b
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
ARG TARGETARCH

# Java runtime for the TLA+ tools (Eclipse Temurin JRE 21).
ARG JRE_TAG=jdk-21.0.9+10
ARG JRE_FILE_VERSION=21.0.9_10
ARG JRE_SHA256_arm64=1d041073c65e834bdb4da732485a54ff829859dcd1549e7992f15bd73341be29
ARG JRE_SHA256_amd64=aeab55d064a1a27a3744b0880b9b414077b4ed2b1790817eea3df60aec946431
RUN set -eu; \
    case "$TARGETARCH" in arm64) a=aarch64; s=$JRE_SHA256_arm64;; amd64) a=x64; s=$JRE_SHA256_amd64;; *) exit 1;; esac; \
    tag=$(printf '%s' "$JRE_TAG" | sed 's/+/%2B/'); \
    curl -sSfL -o /tmp/jre.tgz "https://github.com/adoptium/temurin21-binaries/releases/download/${tag}/OpenJDK21U-jre_${a}_linux_hotspot_${JRE_FILE_VERSION}.tar.gz"; \
    echo "$s  /tmp/jre.tgz" | sha256sum -c -; \
    mkdir -p /opt/java && tar -xzf /tmp/jre.tgz -C /opt/java --strip-components=1 --no-same-owner; \
    rm -f /tmp/jre.tgz; ln -s /opt/java/bin/java /usr/local/bin/java; java -version

# TLA+ tools (TLC, SANY, PlusCal translator, TLATeX), with the command names used by
# common packages of tla2tools.jar.
ARG TLA_VERSION=v1.7.4
ARG TLA_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
RUN set -eu; \
    mkdir -p /opt/tlaplus; \
    curl -sSfL -o /opt/tlaplus/tla2tools.jar "https://github.com/tlaplus/tlaplus/releases/download/${TLA_VERSION}/tla2tools.jar"; \
    echo "$TLA_SHA256  /opt/tlaplus/tla2tools.jar" | sha256sum -c -; \
    for pair in tlc:tlc2.TLC tla2sany:tla2sany.SANY pcal:pcal.trans tla2tex:tla2tex.TLA; do \
      name=${pair%%:*}; cls=${pair#*:}; \
      printf '#!/bin/sh\nexec java -XX:+UseParallelGC -cp /opt/tlaplus/tla2tools.jar %s "$@"\n' "$cls" > "/usr/local/bin/$name"; \
      chmod 755 "/usr/local/bin/$name"; \
    done; \
    printf -- '---- MODULE Check ----\n====\n' > /tmp/Check.tla; \
    (cd /tmp && tla2sany Check.tla); rm -f /tmp/Check.tla

# Z3: command-line solver and Python bindings (same version).
ARG Z3_VERSION=5.3.3
ARG Z3_SHA256_arm64=d4586e12af2609499e07d615ac578256125b19f396f0d6ca358fe7b22988bcec
ARG Z3_SHA256_amd64=d56f60b06f432f33de5810f7f1a384a339131f361e2d54d08ea83eea14326880
ARG Z3PY_SHA256_arm64=701619d4995695819e150e9fa10218b67a5a2241868f31dddccfe2d3fe15f986
ARG Z3PY_SHA256_amd64=0431023a82278dab706c02a320f63178ee0755fb8f10a5c980f0bfe3c84f6f96
RUN set -eu; \
    apt-get update && apt-get install -y --no-install-recommends unzip python3 python3-pip && rm -rf /var/lib/apt/lists/*; \
    case "$TARGETARCH" in \
      arm64) z=z3-${Z3_VERSION}-arm64-glibc-2.38; s=$Z3_SHA256_arm64; ws=$Z3PY_SHA256_arm64;; \
      amd64) z=z3-${Z3_VERSION}-x64-glibc-2.39; s=$Z3_SHA256_amd64; ws=$Z3PY_SHA256_amd64;; \
      *) exit 1;; esac; \
    curl -sSfL -o /tmp/z3.zip "https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/${z}.zip"; \
    echo "$s  /tmp/z3.zip" | sha256sum -c -; \
    unzip -q /tmp/z3.zip -d /tmp/z3 && mkdir -p /opt/z3 && cp -r /tmp/z3/${z}/* /opt/z3/; \
    ln -s /opt/z3/bin/z3 /usr/local/bin/z3; rm -rf /tmp/z3 /tmp/z3.zip; \
    echo "z3-solver==${Z3_VERSION}.0 --hash=sha256:${ws}" > /tmp/req.txt; \
    pip3 install --no-cache-dir --break-system-packages --require-hashes -r /tmp/req.txt; rm -f /tmp/req.txt; \
    z3 --version; python3 -c 'import z3; print("z3py", z3.get_version_string())'

USER dev
WORKDIR /home/dev/jsdoctypeparser
CMD ["bash"]
