#!/bin/sh
# Reports Claude Code lifecycle state to herdr via pane.report_agent, for claude
# running under nono. nono keeps claude on an inner pty, so herdr's process
# detection sees `nono`. The launcher sets HERDR_AGENT=claude (so herdr trusts
# the pane as claude and does not override with process detection); this hook
# then supplies the actual presence + state. BOTH are required -- neither works
# alone under nono. Gated on HERDR_CLAUDE_LIFECYCLE=1 (injected by the
# claude-code-hardened nono profile) so direct / claude-sandbox sessions are
# untouched. Uses a distinct source so it does not collide with the stock hook.
#
# Registered in ~/.claude/settings.json (NOT chezmoi-managed -- Claude Code writes
# to that file) on SessionStart/UserPromptSubmit/Stop/SessionEnd/Notification,
# plus PostToolUse with matcher AskUserQuestion|ExitPlanMode: answering an
# interactive tool is a tool result, not a prompt, so without it the pane would
# stay "blocked" until Stop. See ~/.config/nono/README.md for the exact entries.
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
