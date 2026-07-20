#!/bin/sh
# Reports Claude Code lifecycle state to herdr via pane.report_agent, for claude
# running under nono. nono keeps claude on an inner pty, so herdr's process
# detection sees `nono` and never labels the pane. herdr accepts report_agent
# ONLY for panes created via `herdr agent start` under a name that is NOT a
# known agent (the exact name "claude" triggers Claude's screen-only policy and
# reports are silently dropped -- verified herdr 0.7.4, 2026-07). The launcher
# (_nono-claude in ~/.zshrc) starts such a pane with a unique claude-<dir>-<n>
# name and injects HERDR_CLAUDE_LIFECYCLE=1 via `agent start --env`, which
# gates this hook so direct / non-nono sessions are untouched. Uses a distinct
# source so it does not collide with the stock session hook.
#
# Registered in ~/.claude/settings.json (NOT chezmoi-managed -- Claude Code writes
# to that file) on SessionStart/UserPromptSubmit/Stop/Notification, plus
# PostToolUse with matcher AskUserQuestion|ExitPlanMode: answering an
# interactive tool is a tool result, not a prompt, so without it the pane would
# stay "blocked" until Stop. The stock herdr session hook is GATED OFF under
# nono (same settings.json): its herdr:claude agent_session switches the pane to
# Claude's official integration policy, which silently drops report_agent from
# any other source. This hook sends the session id/transcript inside its own
# report_agent instead. See ~/.config/nono/README.md.
set -eu

hook_input_file="$(mktemp "${TMPDIR:-/tmp}/herdr-nono-lifecycle.XXXXXX")" || exit 0
trap 'rm -f "$hook_input_file"' EXIT HUP INT TERM
cat >"$hook_input_file" 2>/dev/null || true

[ "${HERDR_CLAUDE_LIFECYCLE:-}" = "1" ] || exit 0
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

HERDR_HOOK_INPUT_FILE="$hook_input_file" python3 - <<'PY'
import json
import os
import random
import socket
import time

pane_id = os.environ.get("HERDR_PANE_ID")
socket_path = os.environ.get("HERDR_SOCKET_PATH")
if not pane_id or not socket_path:
    raise SystemExit(0)

hook_input = {}
try:
    with open(os.environ["HERDR_HOOK_INPUT_FILE"], encoding="utf-8") as handle:
        content = handle.read()
    if content.strip():
        hook_input = json.loads(content)
except Exception:
    hook_input = {}

event = str(hook_input.get("hook_event_name") or "")
if hook_input.get("agent_id") or event == "SubagentStop":
    raise SystemExit(0)

source = "herdr:claude-nono"
seq = time.time_ns()
request_id = f"{source}:{seq}:{random.randrange(1_000_000):06d}"

states = {
    "SessionStart": "idle",
    "UserPromptSubmit": "working",
    "Stop": "idle",
    "Notification": "blocked",
    "PostToolUse": "working",
}

# No pane.release_agent, ever: SessionEnd also fires on /clear and on nested
# `claude -p` runs inside the pane, and a release poisons the pane's state
# authority (later reports are silently dropped). The agent-start pane closes
# with the process, and herdr clears state on pane close, so release is
# unnecessary.
state = states.get(event)
if state is None:
    raise SystemExit(0)
method = "pane.report_agent"
params = {
    "pane_id": pane_id,
    "source": source,
    "agent": "claude",
    "state": state,
    "seq": seq,
}
session_id = hook_input.get("session_id")
if isinstance(session_id, str) and session_id:
    params["agent_session_id"] = session_id
transcript_path = hook_input.get("transcript_path")
if isinstance(transcript_path, str) and transcript_path:
    params["agent_session_path"] = transcript_path

request = {"id": request_id, "method": method, "params": params}
try:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(0.5)
    client.connect(socket_path)
    client.sendall((json.dumps(request) + "\n").encode())
    try:
        client.recv(4096)
    except Exception:
        pass
    client.close()
except Exception:
    pass
PY
