#!/usr/bin/env bash

# Wires the Serena hooks into ~/.claude/settings.json, which chezmoi does not
# manage: Claude Code, herdr and serena all write to that file at runtime, so a
# managed copy would revert their edits on every apply.
#
# `serena setup claude-code` only registers the MCP server -- the hooks are a
# separate manual step, and without them Claude Code ignores Serena's tools in
# favour of Read/Grep/Bash. serena-prefer-symbols.py covers the case Serena's
# own `remind` hook cannot see: grep run through Bash.
#
# Runs once per machine, and again whenever this script changes. It only adds
# what is missing -- removing a hook by hand afterwards is respected.

set -eu

settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

# python3 rather than jq: jq is installed via mise, which may not be populated
# yet on a fresh machine. python3 ships with macOS.
python3 - "$settings" <<'PY'
import json
import os
import sys

path = sys.argv[1]
wanted = [
    ("PreToolUse", "", "serena-hooks remind --client=claude-code"),
    ("PreToolUse", "mcp__serena__*", "serena-hooks auto-approve --client=claude-code"),
    ("PreToolUse", "Bash", "python3 %s/hooks/serena-prefer-symbols.py" % os.path.dirname(path)),
    ("SessionStart", "*", "serena-hooks activate --client=claude-code"),
    ("SessionEnd", "", "serena-hooks cleanup --client=claude-code"),
]

try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}

hooks = settings.setdefault("hooks", {})
added = []
for event, matcher, command in wanted:
    groups = hooks.setdefault(event, [])
    if any(h.get("command") == command for g in groups for h in g.get("hooks", [])):
        continue
    groups.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})
    added.append(command)

allow = settings.setdefault("permissions", {}).setdefault("allow", [])
if "mcp__serena__*" not in allow:
    allow.append("mcp__serena__*")
    added.append("permissions.allow mcp__serena__*")

if not added:
    print("claude hooks: already wired")
    sys.exit(0)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
os.chmod(path, 0o600)
print("claude hooks: added %d\n  %s" % (len(added), "\n  ".join(added)))
PY
