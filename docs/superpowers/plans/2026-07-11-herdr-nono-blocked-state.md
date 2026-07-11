# herdr/nono Stale Blocked State Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Report `working` to herdr the moment the user answers an interactive tool (`AskUserQuestion`, `ExitPlanMode`) under nono, so the pane no longer shows a stale `blocked` state for the rest of the turn.

**Architecture:** One new entry (`PostToolUse` → `working`) in the state table of the existing lifecycle hook script, plus a narrowly-matched `PostToolUse` registration in `~/.claude/settings.json`, plus a README recipe update. `Stop` → `idle` remains the safety net for anything the matcher misses.

**Tech Stack:** POSIX sh + embedded python3 (hook script), JSON (Claude Code settings), chezmoi (dotfile deployment).

**Spec:** `docs/superpowers/specs/2026-07-11-herdr-nono-blocked-state-design.md`

## Global Constraints

- This repo is the live chezmoi source at `/Users/fabien/.local/share/chezmoi`. Work directly in it (no worktree): testing requires `chezmoi apply` to `$HOME`, which reads this exact source path.
- `~/.claude/settings.json` is NOT chezmoi-managed (Claude Code writes to it). Edit it in place; there is nothing to commit for that file.
- The deployed hook is `~/.claude/hooks/herdr-nono-lifecycle.sh` (mode 644, invoked via `sh`). Chezmoi source: `dot_claude/hooks/herdr-nono-lifecycle.sh`. After editing the source, `chezmoi apply` before testing; tests must run against the deployed file.
- The test harness is throwaway tooling: it lives in the session scratchpad, not in the repo. Do not commit it.
- No emojis or em-dashes in any file content or commit message.

---

### Task 1: Hook script -- map `PostToolUse` to `working`

**Files:**
- Modify: `dot_claude/hooks/herdr-nono-lifecycle.sh` (chezmoi source; lines 11-13 comment, lines 55-60 states map)
- Test: `<scratchpad>/test_lifecycle_hook.py` (throwaway harness, not committed)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: deployed `~/.claude/hooks/herdr-nono-lifecycle.sh` that, given a `PostToolUse` hook payload on stdin (and env `HERDR_CLAUDE_LIFECYCLE=1`, `HERDR_ENV=1`, `HERDR_PANE_ID`, `HERDR_SOCKET_PATH`), sends `{"method": "pane.report_agent", "params": {..., "state": "working"}}` over the Unix socket. Task 2 registers this event in settings.json.

- [ ] **Step 1: Write the failing test harness**

Write `<scratchpad>/test_lifecycle_hook.py` (replace `<scratchpad>` with the session scratchpad directory):

```python
#!/usr/bin/env python3
"""One-shot harness for herdr-nono-lifecycle.sh: fake herdr socket, fake hook payloads."""
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading

SCRIPT = os.path.expanduser("~/.claude/hooks/herdr-nono-lifecycle.sh")


def run_case(name, env_extra, payload, expect):
    tmpdir = tempfile.mkdtemp()
    sock_path = os.path.join(tmpdir, "herdr.sock")
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(sock_path)
    server.listen(1)
    server.settimeout(2)
    received = []

    def accept():
        try:
            conn, _ = server.accept()
            received.append(conn.recv(65536).decode())
            conn.sendall(b'{"id":"x","result":{}}\n')
            conn.close()
        except OSError:
            pass

    thread = threading.Thread(target=accept)
    thread.start()
    env = dict(
        os.environ,
        HERDR_CLAUDE_LIFECYCLE="1",
        HERDR_ENV="1",
        HERDR_PANE_ID="pane-test",
        HERDR_SOCKET_PATH=sock_path,
    )
    env.update(env_extra)
    subprocess.run(["sh", SCRIPT], input=json.dumps(payload).encode(), env=env, timeout=10)
    thread.join()
    server.close()

    if expect is None:
        ok = not received
        detail = received[0].strip() if received else "no report (as expected)"
    elif received:
        req = json.loads(received[0])
        ok = (
            req.get("method") == expect[0]
            and req.get("params", {}).get("state") == expect[1]
            and req.get("params", {}).get("pane_id") == "pane-test"
        )
        detail = received[0].strip()
    else:
        ok, detail = False, "no report received"
    print(("PASS" if ok else "FAIL"), name, "--", detail)
    return ok


results = [
    run_case(
        "PostToolUse -> working",
        {},
        {
            "hook_event_name": "PostToolUse",
            "tool_name": "AskUserQuestion",
            "session_id": "s1",
            "transcript_path": "/tmp/t.jsonl",
        },
        ("pane.report_agent", "working"),
    ),
    run_case(
        "Notification -> blocked",
        {},
        {"hook_event_name": "Notification", "message": "needs input", "session_id": "s1"},
        ("pane.report_agent", "blocked"),
    ),
    run_case(
        "subagent payload skipped",
        {},
        {"hook_event_name": "PostToolUse", "tool_name": "AskUserQuestion", "agent_id": "sub1"},
        None,
    ),
    run_case(
        "lifecycle gate off -> no report",
        {"HERDR_CLAUDE_LIFECYCLE": "0"},
        {"hook_event_name": "PostToolUse", "tool_name": "AskUserQuestion"},
        None,
    ),
]
sys.exit(0 if all(results) else 1)
```

- [ ] **Step 2: Run harness to verify the target case fails**

Run: `python3 <scratchpad>/test_lifecycle_hook.py`
Expected: `FAIL PostToolUse -> working -- no report received` (the script has no `PostToolUse` mapping yet, so it exits silently); the other three cases PASS. Exit code 1. Each no-report case takes ~2s (listener timeout), so total runtime under 10s is normal.

- [ ] **Step 3: Add the state mapping and update the header comment**

In `dot_claude/hooks/herdr-nono-lifecycle.sh`, change the states map:

```python
states = {
    "SessionStart": "idle",
    "UserPromptSubmit": "working",
    "Stop": "idle",
    "Notification": "blocked",
    "PostToolUse": "working",
}
```

And change the comment lines 11-13 from:

```sh
# Registered in ~/.claude/settings.json (NOT chezmoi-managed -- Claude Code writes
# to that file) on SessionStart/UserPromptSubmit/Stop/SessionEnd/Notification;
# see ~/.config/nono/README.md for the exact entries.
```

to:

```sh
# Registered in ~/.claude/settings.json (NOT chezmoi-managed -- Claude Code writes
# to that file) on SessionStart/UserPromptSubmit/Stop/SessionEnd/Notification,
# plus PostToolUse with matcher AskUserQuestion|ExitPlanMode: answering an
# interactive tool is a tool result, not a prompt, so without it the pane would
# stay "blocked" until Stop. See ~/.config/nono/README.md for the exact entries.
```

- [ ] **Step 4: Deploy with chezmoi**

Run: `chezmoi apply ~/.claude/hooks/herdr-nono-lifecycle.sh`
Expected: no output, exit 0. Verify: `grep -n 'PostToolUse' ~/.claude/hooks/herdr-nono-lifecycle.sh` shows the new map entry.
Fallback if chezmoi is blocked by sandboxing: `cp /Users/fabien/.local/share/chezmoi/dot_claude/hooks/herdr-nono-lifecycle.sh ~/.claude/hooks/herdr-nono-lifecycle.sh` (target has no template/private attributes, so a plain copy is equivalent), then run `chezmoi status` later to confirm no drift.

- [ ] **Step 5: Run harness to verify all cases pass**

Run: `python3 <scratchpad>/test_lifecycle_hook.py`
Expected: 4 x PASS, exit code 0. The first case's detail line must show `"state": "working"` and `"method": "pane.report_agent"`.

- [ ] **Step 6: Commit**

```bash
cd /Users/fabien/.local/share/chezmoi
git add dot_claude/hooks/herdr-nono-lifecycle.sh
git commit -m "herdr-nono hook: report working on PostToolUse

Answering AskUserQuestion/ExitPlanMode is a tool result, not a prompt
submission, so no event fired between Notification (blocked) and Stop
and herdr showed a stale blocked state for the rest of the turn."
```

---

### Task 2: Register PostToolUse in settings.json and document it

**Files:**
- Modify: `~/.claude/settings.json` (outside the repo; nothing to commit for it)
- Modify: `dot_config/nono/README.md:98-104` (the settings.json recipe block)

**Interfaces:**
- Consumes: deployed `~/.claude/hooks/herdr-nono-lifecycle.sh` from Task 1 (must already handle `PostToolUse`).
- Produces: live hook registration so Claude Code invokes the script on `PostToolUse` for `AskUserQuestion|ExitPlanMode`; README recipe that reproduces it.

- [ ] **Step 1: Add the PostToolUse hook entry to settings.json**

Run this python (idempotent, safe to re-run):

```bash
python3 - <<'PY'
import json
import pathlib

path = pathlib.Path.home() / ".claude" / "settings.json"
data = json.loads(path.read_text())
cmd = "sh '/Users/fabien/.claude/hooks/herdr-nono-lifecycle.sh'"
post = data.setdefault("hooks", {}).setdefault("PostToolUse", [])
if not any(
    h.get("command") == cmd
    for entry in post
    for h in entry.get("hooks", [])
):
    post.append({
        "matcher": "AskUserQuestion|ExitPlanMode",
        "hooks": [{"type": "command", "command": cmd, "timeout": 10}],
    })
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("added")
else:
    print("already present")
PY
```

Expected output: `added`

- [ ] **Step 2: Verify the registration**

Run: `python3 -c "import json,pathlib; d=json.load(open(pathlib.Path.home()/'.claude/settings.json')); print(json.dumps(d['hooks']['PostToolUse'], indent=1))"`
Expected: exactly one entry with `"matcher": "AskUserQuestion|ExitPlanMode"` whose command is `sh '/Users/fabien/.claude/hooks/herdr-nono-lifecycle.sh'` and timeout 10. Also confirm the file is still valid JSON and the pre-existing `PreToolUse`/`SessionStart`/etc. blocks are untouched (`git`-style eyeball via the printed JSON plus `python3 -m json.tool ~/.claude/settings.json > /dev/null && echo valid`).

- [ ] **Step 3: Update the README recipe**

In `dot_config/nono/README.md`, change the block (currently lines 98-104):

```jsonc
// SessionStart "*" matcher — gate the stock hook, add ours:
{ "command": "[ \"${HERDR_CLAUDE_LIFECYCLE:-}\" = 1 ] || bash '~/.claude/hooks/herdr-agent-state.sh' session", "type": "command", "timeout": 10 },
{ "command": "sh '~/.claude/hooks/herdr-nono-lifecycle.sh'", "type": "command", "timeout": 10 }
// plus a matcher:"*" -> sh '~/.claude/hooks/herdr-nono-lifecycle.sh' under each of:
//   UserPromptSubmit, Stop, SessionEnd, Notification
```

to:

```jsonc
// SessionStart "*" matcher — gate the stock hook, add ours:
{ "command": "[ \"${HERDR_CLAUDE_LIFECYCLE:-}\" = 1 ] || bash '~/.claude/hooks/herdr-agent-state.sh' session", "type": "command", "timeout": 10 },
{ "command": "sh '~/.claude/hooks/herdr-nono-lifecycle.sh'", "type": "command", "timeout": 10 }
// plus a matcher:"*" -> sh '~/.claude/hooks/herdr-nono-lifecycle.sh' under each of:
//   UserPromptSubmit, Stop, SessionEnd, Notification
// plus a matcher:"AskUserQuestion|ExitPlanMode" -> same command under PostToolUse:
//   answering an interactive tool is a tool result (no UserPromptSubmit fires),
//   so this is what flips herdr's "blocked" back to "working" mid-turn.
```

Note: this README already uses em-dash characters in its existing prose; the "no em-dashes" rule applies to new sentences you author, and the added lines above contain none. Do not reformat the surrounding lines.

- [ ] **Step 4: Update the paragraph above the recipe**

In the same README, the sentence at lines 94-96:

```markdown
**Not chezmoi-managed** (Claude Code writes to `settings.json`): add these hook
entries to `~/.claude/settings.json` by hand. Gate the stock herdr hook and add
ours on the five lifecycle events:
```

change `on the five lifecycle events:` to `on the five lifecycle events plus PostToolUse:`

- [ ] **Step 5: Commit**

```bash
cd /Users/fabien/.local/share/chezmoi
git add dot_config/nono/README.md
git commit -m "nono README: document PostToolUse herdr hook entry"
```

---

### Task 3: End-to-end verification note (manual, next nono session)

**Files:** none.

**Interfaces:**
- Consumes: Tasks 1-2 fully applied.
- Produces: confidence the fix works live.

- [ ] **Step 1: Live check (user-driven, cannot be done from this session)**

In the next `nono-claude` session inside a herdr pane: ask Claude something that triggers `AskUserQuestion` (or enter plan mode and approve the plan). Watch the herdr pane status: it must show `blocked` while the question is open and flip to `working` immediately after answering, then `idle` at end of turn. If it stays `blocked`, run `herdr api snapshot` and check the pane's agent state source/seq to see which report was last.

---

## Self-Review Notes

- Spec coverage: spec section 1 (script) = Task 1; section 2 (settings.json) = Task 2 steps 1-2; section 3 (README) = Task 2 steps 3-4; "Testing" simulated cases = Task 1 harness (all four cases present); live sanity check = Task 3.
- No placeholders: every code step contains the full content.
- Type consistency: the settings command string `sh '/Users/fabien/.claude/hooks/herdr-nono-lifecycle.sh'` matches the existing entries in settings.json exactly (verified against the live file); the states-map key `PostToolUse` matches the hook event name Claude Code sends.
