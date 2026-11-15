"""Evaluate probe output.

Usage: evaluate.py RAW TRANSCRIPTS_DIR BASELINE           -> report; exit 1 on anything unexpected
       evaluate.py RAW TRANSCRIPTS_DIR BASELINE --write   -> write BASELINE (product defaults only)

RAW: output of probe-inside.sh (filesystem + `claude -p /context` init and context data).
TRANSCRIPTS_DIR: ~/.claude/projects of the interactive probe session; the request actually
sent to the model there gives the interactive tools, skills, agents and system prompt.

Hard rules (independent of the baseline): no instruction/memory files loaded, no MCP
servers or MCP tools, no custom agents, no non-built-in skills or plugins.
Baseline: the exact product-default sets (tools, skills, plugins, agents, env names,
config files) for the pinned Claude Code version, so anything new shows up as a diff.
"""
import glob
import hashlib
import json
import os
import re
import sys


def sections(path):
    out, cur = {}, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("### "):
                cur = line[4:].strip()
                out[cur] = []
            elif cur is not None:
                out[cur].append(line)
    return out


def parse(path):
    s = sections(path)
    init, ctx = None, None
    for line in s.get("init", []):
        if not line.startswith("{"):
            continue
        d = json.loads(line)
        if d.get("type") == "system" and d.get("subtype") == "init":
            init = d
        if d.get("type") == "assistant" and "context_usage" in d:
            ctx = d["context_usage"]
    lines = lambda k: [x for x in s.get(k, []) if x.strip()]
    return {
        "init": init,
        "context": ctx,
        "context_text": "\n".join(s.get("init", [])),
        "env_names": lines("env-names"),
        "instruction_files": lines("instruction-files"),
        "managed_dirs": lines("managed-dirs"),
        "config_top": lines("claude-config-top"),
        "process": lines("process"),
        "plugins_installed": "\n".join(s.get("plugins-installed", [])).strip(),
        "marketplaces": "\n".join(s.get("marketplaces", [])).strip(),
        "claude_json": "\n".join(s.get("claude-json", [])).strip(),
        "user_settings": "\n".join(s.get("user-settings", [])).strip(),
        "whoami": lines("whoami"),
        "stderr": lines("stderr"),
    }


def interactive(tdir):
    """Parse the interactive session transcript (the one that sent a model request)."""
    for path in sorted(glob.glob(os.path.join(tdir, "**", "*.jsonl"), recursive=True)):
        rows = [json.loads(x) for x in open(path, encoding="utf-8") if x.strip()]
        shapes = [r for r in rows if r.get("type") == "api-request-shape"]
        if not shapes:
            continue
        shape = shapes[0]["shape"]
        atts = [r["attachment"] for r in rows if isinstance(r.get("attachment"), dict)]
        res = {"path": path, "tools": sorted(t.get("name") for t in shape.get("tools", [])),
               "system": "".join(x.get("text", "") for x in shape.get("system", [])),
               "attachment_types": sorted({a.get("type") for a in atts}),
               "deferred": [], "skills": [], "agents": [], "mcp_pending": [], "mcp_failed": [],
               "attachments": atts}
        for a in atts:
            if a.get("type") == "deferred_tools_delta":
                res["deferred"] += a.get("addedNames", [])
                res["mcp_pending"] += a.get("pendingMcpServers", [])
                res["mcp_failed"] += a.get("failedMcpServers", [])
            elif a.get("type") == "skill_listing":
                res["skills"] += re.findall(r"^- ([^:\n]+):", a.get("content", ""), re.M)
            elif a.get("type") == "agent_listing_delta":
                res["agents"] += a.get("addedTypes", [])
        for k in ("deferred", "skills", "agents"):
            res[k] = sorted(set(res[k]))
        return res
    return None


def observed(p, it):
    i, c = p["init"], p["context"]
    return {
        "claude_code_version": i.get("claude_code_version"),
        "tools": sorted(i.get("tools", [])),
        "slash_commands": sorted(i.get("slash_commands", [])),
        "skills": sorted(i.get("skills", [])),
        "context_skills": sorted(f'{x["name"]} ({x.get("source")})' for x in c.get("skills", [])),
        "plugins": sorted(f'{x["source"]} [{x["path"]}]' for x in i.get("plugins", [])),
        "agents": sorted(i.get("agents", [])),
        "env_names": sorted(p["env_names"]),
        "instruction_files": sorted(p["instruction_files"]),
        "config_top": sorted(p["config_top"]),
        "interactive_tools": it["tools"],
        "interactive_deferred_tools": it["deferred"],
        "interactive_skills": it["skills"],
        "interactive_agents": it["agents"],
        "interactive_attachment_types": it["attachment_types"],
    }


def main():
    raw, tdir, base_path = sys.argv[1], sys.argv[2], sys.argv[3]
    p = parse(raw)
    it = interactive(tdir)
    problems = []
    if p["init"] is None or p["context"] is None or it is None:
        print("PROBE FAILED: missing init/context data or interactive transcript")
        print("\n".join(p["stderr"]))
        return 1
    obs = observed(p, it)
    i, c = p["init"], p["context"]

    # Hard rules.
    if c.get("memory_files"):
        problems.append(f"instruction/memory files loaded: {c['memory_files']}")
    if c.get("mcp_tools"):
        problems.append(f"MCP tools present: {c['mcp_tools']}")
    if i.get("mcp_servers"):
        problems.append(f"MCP servers present: {i['mcp_servers']}")
    mcp_named = [t for t in i.get("tools", []) if t.startswith("mcp__")]
    if mcp_named:
        problems.append(f"MCP-provided tools: {mcp_named}")
    if c.get("agents"):
        problems.append(f"custom agents loaded: {c['agents']}")
    nonbuiltin_skills = [x for x in c.get("skills", []) if x.get("source") != "built-in"]
    if nonbuiltin_skills:
        problems.append(f"non-built-in skills: {nonbuiltin_skills}")
    nonbuiltin_plugins = [x for x in i.get("plugins", []) if x.get("path") != "builtin"]
    if nonbuiltin_plugins:
        problems.append(f"non-built-in plugins: {nonbuiltin_plugins}")
    if i.get("plugin_errors"):
        problems.append(f"plugin errors: {i['plugin_errors']}")
    if not any("No such file" in x for x in p["managed_dirs"]):
        problems.append(f"managed settings directory exists: {p['managed_dirs']}")

    for t in it["tools"] + it["deferred"]:
        if t.startswith("mcp__"):
            problems.append(f"MCP tool in interactive session: {t}")
    if it["mcp_pending"] or it["mcp_failed"]:
        problems.append(f"MCP servers in interactive session: {it['mcp_pending'] + it['mcp_failed']}")
    for word in ("Artifact",):
        if word in it["system"] or any(word == t for t in it["tools"] + it["deferred"]):
            problems.append(f"'{word}' present in interactive tools/system prompt")
    if p["plugins_installed"] not in ("(none)", ""):
        problems.append(f"installed plugins: {p['plugins_installed']}")

    if len(sys.argv) > 4 and sys.argv[4] == "--write":
        if problems:
            print("REFUSING to write baseline; hard rules violated:")
            for x in problems:
                print(f"  - {x}")
            return 1
        with open(base_path, "w", encoding="utf-8") as f:
            json.dump(obs, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"baseline written: {base_path} (review it before use)")
        return 0

    # Baseline diff.
    if not os.path.exists(base_path):
        problems.append(f"no baseline for this model: {base_path} (see README: writing a baseline)")
        base = {}
    else:
        with open(base_path, encoding="utf-8") as f:
            base = json.load(f)
    for k, expected in base.items():
        got = obs.get(k)
        if isinstance(expected, list):
            extra = sorted(set(got) - set(expected))
            missing = sorted(set(expected) - set(got))
            if extra:
                problems.append(f"{k}: not in baseline: {extra}")
            if missing:
                print(f"note: {k}: in baseline but absent now: {missing}")
        elif got != expected:
            problems.append(f"{k}: expected {expected!r}, got {got!r}")

    # Report.
    print("== probe report")
    print(f"whoami: {' | '.join(p['whoami'])}")
    print(f"claude code: {i.get('claude_code_version')}   model: {i.get('model')}   "
          f"permissionMode: {i.get('permissionMode')}   apiKeySource: {i.get('apiKeySource')}")
    print(f"memory_paths (auto memory location): {i.get('memory_paths')}")
    print(f"instruction/memory files loaded: {c.get('memory_files') or 'none'}")
    print(f"MCP servers: {i.get('mcp_servers') or 'none'}   MCP tools: {c.get('mcp_tools') or 'none'}")
    print(f"custom agents: {c.get('agents') or 'none'}")
    print(f"plugins (built-in only allowed): {obs['plugins'] or 'none'}")
    print(f"skills (built-in only allowed): {', '.join(obs['context_skills']) or 'none'}")
    print(f"skills (init list): {', '.join(obs['skills'])}")
    print(f"agent types (built-in): {', '.join(obs['agents'])}")
    print(f"tools (-p): {', '.join(obs['tools'])}")
    print(f"interactive transcript: {it['path']}")
    print(f"interactive tools: {', '.join(it['tools'])}")
    print(f"interactive deferred tools: {', '.join(it['deferred'])}")
    print(f"interactive skills: {', '.join(it['skills'])}")
    print(f"interactive agent types: {', '.join(it['agents'])}")
    print(f"interactive attachment types: {', '.join(it['attachment_types'])}")
    print(f"interactive system prompt: {len(it['system'])} chars, sha256 "
          f"{hashlib.sha256(it['system'].encode()).hexdigest()[:16]}")
    print(f"installed plugins: {p['plugins_installed']}")
    print(f"plugin marketplaces (not loaded into context): {p['marketplaces']}")
    print(f"agent process: {' | '.join(p['process'])}")
    print(f"instruction-like files on filesystem: {obs['instruction_files'] or 'none'}")
    print(f"~/.claude entries: {obs['config_top']}")
    print(f"~/.claude.json (keys, MCP entries): {p['claude_json']}")
    print(f"~/.claude/settings.json: {' '.join(p['user_settings'].split())}")
    print(f"env names: {', '.join(obs['env_names'])}")
    print()
    if problems:
        print("RESULT: UNEXPECTED")
        for x in problems:
            print(f"  - {x}")
        return 1
    print("RESULT: OK (only product defaults; matches baseline)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
