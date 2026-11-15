#!/usr/bin/env bash
# Runs via `docker exec` in the live probe session (same image, user, env and network as a run).
set -uo pipefail
FLAGS=(--dangerously-skip-permissions --strict-mcp-config)
[ -n "${PROBE_MODEL:-}" ] && FLAGS+=(--model "$PROBE_MODEL")
echo "### whoami"; id; echo "hostname=$(hostname)"; echo "cwd=$(pwd)"
echo "### env-names"; tr '\0' '\n' < /proc/1/environ | cut -d= -f1 | sort
echo "### process"
# shellcheck disable=SC2009  # full command lines are compared with the baseline
ps -eo args= | grep -E '^claude( |$)' | grep -v -- ' -p ' | cut -c1-300
echo "### instruction-files"
find / -xdev \( -path /proc -o -path /sys \) -prune -o \
  \( -name CLAUDE.md -o -name CLAUDE.local.md -o -name AGENTS.md -o -name .mcp.json \
     -o -name managed-settings.json -o -name managed-mcp.json -o -name settings.local.json \
     -o -name MEMORY.md -o -name SKILL.md -o -path '*/.claude' -o -path '*/.claude-plugin' \) -print 2>/dev/null \
  | grep -v '^/home/dev/.claude/plugins/marketplaces/' | sort
echo "### managed-dirs"; ls -la /etc/claude-code 2>&1
echo "### claude-config-top"
# shellcheck disable=SC2012  # names only, compared with the baseline
ls -A "$HOME/.claude" | sort
echo "### claude-cache"; (cd "$HOME/.claude" && find cache -maxdepth 3 2>/dev/null | sort | head -50)
echo "### plugins-installed"; cat "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null || echo "(none)"
echo "### marketplaces"; cat "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null | tr -d '\n' | cut -c1-400; echo
echo "### claude-json"; node -e 'const j=require(process.env.HOME+"/.claude.json");console.log(JSON.stringify({keys:Object.keys(j).sort(),mcpServers:j.mcpServers||{},projects:Object.fromEntries(Object.entries(j.projects||{}).map(([k,v])=>[k,{mcpServers:v.mcpServers||{},enabledMcpjsonServers:v.enabledMcpjsonServers||[]}]))}))'
echo "### user-settings"; cat "$HOME/.claude/settings.json"; echo
echo "### init"
cd /tmp && mkdir -p probe-p && cd probe-p || exit 1
(cd /home/dev/jsdoctypeparser && claude "${FLAGS[@]}" -p --output-format stream-json --verbose "/context" < /dev/null 2>/tmp/stream.err)
echo "exit=$?"
echo "### stderr"; cat /tmp/stream.err
echo "### end"
