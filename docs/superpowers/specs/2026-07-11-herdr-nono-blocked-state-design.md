# herdr/nono lifecycle hook: clear stale `blocked` state on answered input

Date: 2026-07-11
Status: approved

## Problem

When Claude Code runs under nono (`nono-claude`), pane state is reported to
herdr by `~/.claude/hooks/herdr-nono-lifecycle.sh` via `pane.report_agent`.
The hook maps lifecycle events to states:

| Event            | State   |
| ---------------- | ------- |
| SessionStart     | idle    |
| UserPromptSubmit | working |
| Stop             | idle    |
| Notification     | blocked |
| SessionEnd       | release |

Under `--dangerously-skip-permissions` the only mid-turn blockers are
interactive tools (`AskUserQuestion`, `ExitPlanMode` plan approval). When one
fires, a `Notification` event reports `blocked`. Answering the dialog produces
a *tool result*, not a prompt submission: no `UserPromptSubmit` fires, and no
event at all reaches the hook until `Stop` at end of turn. herdr is
last-write-wins per source (confirmed via `herdr api schema`; no stickiness or
TTL on its side), so the pane shows `blocked` for the rest of the turn even
though Claude resumed working.

## Fix

Report `working` at the moment the user answers, via `PostToolUse` on the two
interactive tools. `PostToolUse` fires exactly when the answer completes the
tool; `PreToolUse` would fire when Claude *asks* (before the block) and add
nothing.

### 1. `dot_claude/hooks/herdr-nono-lifecycle.sh` (chezmoi-managed)

- Add `"PostToolUse": "working"` to the `states` map.
- Update the header comment's event list.
- No other logic changes: the existing `agent_id` guard already skips
  subagent tool events; payload parsing is event-agnostic.

### 2. `~/.claude/settings.json` (by hand, not chezmoi-managed)

Add a `PostToolUse` block with matcher `AskUserQuestion|ExitPlanMode`
invoking `sh '~/.claude/hooks/herdr-nono-lifecycle.sh'`, timeout 10. The
narrow matcher means the reporter only spawns when an interactive tool
completes, never on ordinary Bash/Read/Edit calls.

### 3. `dot_config/nono/README.md`

Update the "hook entries in settings.json" recipe to include the new
`PostToolUse` entry with its matcher, so the by-hand setup stays
reproducible.

## Safety net

`Stop` → idle still clears any resume path the matcher misses (e.g. a future
interactive tool), so the worst case regresses to today's behavior, never
worse.

## Testing

Simulated, without a live nono pane:

1. Start a throwaway Unix-socket listener (scratchpad) capturing one JSON line.
2. Export `HERDR_CLAUDE_LIFECYCLE=1 HERDR_ENV=1 HERDR_PANE_ID=test
   HERDR_SOCKET_PATH=<listener>`.
3. Pipe a fake `PostToolUse` payload (`tool_name: AskUserQuestion`) into the
   script; assert captured JSON is `pane.report_agent` with
   `state: "working"`.
4. Regression checks: `Notification` payload → `blocked`; payload with
   `agent_id` set → no report; missing gate env vars → no report.

Live sanity check in the next `nono-claude` session: trigger
`AskUserQuestion`, answer it, confirm herdr flips blocked → working.
