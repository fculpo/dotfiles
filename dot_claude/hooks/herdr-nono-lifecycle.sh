#!/bin/sh
# Reports Claude Code lifecycle state to herdr via pane.report_agent, for claude
# running under nono in the user's CURRENT pane. nono keeps claude on an inner
# pty, so herdr's process detection sees `nono`, never labels the pane, and the
# screen manifest never runs (HERDR_AGENT is Linux-only) -- so this hook pushes
# state instead. The launcher (_nono-claude in ~/.zshrc) sets
# HERDR_CLAUDE_LIFECYCLE=1 when inside herdr, which gates this hook so direct /
# non-nono sessions are untouched. Uses a distinct source so it does not
# collide with the stock session hook.
#
# Registered in ~/.claude/settings.json (NOT chezmoi-managed -- Claude Code writes
# to that file) on SessionStart/UserPromptSubmit/Stop/SessionEnd/Notification,
# plus PostToolUse with matcher AskUserQuestion|ExitPlanMode: answering an
# interactive tool is a tool result, not a prompt, so without it the pane would
# stay "blocked" until Stop. The stock herdr session hook is GATED OFF under
# nono (same settings.json): its herdr:claude agent_session switches the pane to
# Claude's official integration policy, and herdr then silently drops
# report_agent from every other source (verified herdr 0.7.4, 2026-07). This
# hook sends the session id/transcript inside its own report_agent instead.
# See ~/.config/nono/README.md.
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

# SessionEnd -> release: claude runs in the user's own pane, so when it exits
# the pane must return to plain-shell display. Releases are harmless on a
# session-gated pane (verified: same/fresh sources report fine afterwards), so
# the spurious SessionEnds from /clear or nested `claude -p` runs just cause a
# brief flicker that the next hook event corrects.
if event == "SessionEnd":
    method = "pane.release_agent"
    params = {"pane_id": pane_id, "source": source, "agent": "claude", "seq": seq}
else:
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
