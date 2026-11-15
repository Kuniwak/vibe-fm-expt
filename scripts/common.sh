# shellcheck shell=bash
# Shared launch definition. Sourced by run.sh, probe.sh, collect.sh, audit.sh.
# Anything that affects what the agent sees is defined here, once, so that
# `probe` and `run` launch the agent identically.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.docker/bin:$PATH"

IMAGE="${IMAGE:-devenv:latest}"
NET_IMAGE="${NET_IMAGE:-devenv-netguard:latest}"
IN_HOSTNAME="devbox"
IN_USER="dev"
# shellcheck disable=SC2034  # used by probe.sh
IN_HOME="/home/dev"
IN_WORKDIR="/home/dev/jsdoctypeparser"

# Pinned versions (must match image/Dockerfile). collect.sh writes these configured values into
# metadata.txt; they are not read back from the container.
# shellcheck disable=SC2034  # used by collect.sh
MATHLIB_TAG="v4.35.0"
# shellcheck disable=SC2034
MATHLIB_REV="56a005855ea17e0b0958f73ec801ae140b0a1679"
# shellcheck disable=SC2034
REPO_COMMIT="5166cc4ac8f1ccfac0d32ec4d2957c58642f2beb"

NET_MODE="${NET:-allowlist}"          # allowlist | open
MODEL="${MODEL:-}"                    # empty = Claude Code default
ALLOW_FILE="$ROOT/config/allow-domains.txt"

# Environment visible to the agent (besides the image defaults).
AGENT_ENV=(
  DISABLE_AUTOUPDATER=1
  DISABLE_TELEMETRY=1
  DISABLE_ERROR_REPORTING=1
  ENABLE_CLAUDEAI_MCP_SERVERS=false
)

# Claude Code flags. --strict-mcp-config with no --mcp-config => no MCP servers.
agent_flags() {
  CLAUDE_FLAGS=(--dangerously-skip-permissions --strict-mcp-config)
  if [ -n "$MODEL" ]; then CLAUDE_FLAGS+=(--model "$MODEL"); fi
}

load_token() {
  if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -f "$ROOT/.secrets/oauth-token" ]; then
    CLAUDE_CODE_OAUTH_TOKEN="$(tr -d '[:space:]' < "$ROOT/.secrets/oauth-token")"
  fi
  if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "error: set CLAUDE_CODE_OAUTH_TOKEN or write it to .secrets/oauth-token (see README)" >&2
    exit 1
  fi
  export CLAUDE_CODE_OAUTH_TOKEN
}

allow_domains() { grep -vE '^\s*(#|$)' "$ALLOW_FILE" | awk '{print $1}' | tr '\n' ' '; }

# Random neutral container names (names are not visible inside the container).
new_name() { echo "dv-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 10)"; }

# net_up NAME LOGFILE : start the namespace holder and apply egress rules.
net_up() {
  local name="$1" log="$2"
  docker run -d --name "$name" --hostname "$IN_HOSTNAME" \
    --cap-drop ALL --cap-add NET_ADMIN --cap-add NET_RAW \
    -e ALLOW_DOMAINS="$(allow_domains)" \
    "$NET_IMAGE" "$NET_MODE" >/dev/null
  local _
  for _ in $(seq 1 60); do
    if docker logs "$name" 2>&1 | grep -q '^READY$'; then
      docker logs "$name" > "$log" 2>&1
      return 0
    fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]; then break; fi
    sleep 1
  done
  docker logs "$name" >&2 || true
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "error: network setup failed" >&2
  return 1
}

net_down() { docker rm -f "$1" >/dev/null 2>&1 || true; }

# agent_run_opts NETNAME : docker run options shared by probe and run.
agent_run_opts() {
  RUN_OPTS=(--network "container:$1" --user "$IN_USER" -w "$IN_WORKDIR"
            --cap-drop ALL --security-opt no-new-privileges --init
            -e TERM=xterm-256color -e CLAUDE_CODE_OAUTH_TOKEN)
  local kv
  for kv in "${AGENT_ENV[@]}"; do RUN_OPTS+=(-e "$kv"); done
}

# Print a command line with shell quoting, the token never appears in it.
quote_cmd() { local a out=""; for a in "$@"; do out+="$(printf '%q' "$a") "; done; echo "${out% }"; }

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
