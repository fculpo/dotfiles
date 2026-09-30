# Herdr: local conventions

These override the defaults in SKILL.md where they differ.

## Scope

- Subagents (Claude Code's Agent tool) stay the default for delegation, research and parallel work. Use Herdr to watch or drive *other sessions*, and to create a pane, tab, workspace or worktree only when the user asks for one.
- The user decides the workflow. When it is unclear which session is meant, where a new one should go, or what to send, ask.

## Finding a session

- Sessions the user started by hand have no name. Identify them with `herdr agent list`: `terminal_title_stripped` is Claude's session title, plus `cwd` and `workspace_id` (labels from `herdr workspace list`). Target them by `pane_id`.
- When more than one session matches, list the candidates (title, cwd, status) and ask.
- Never rename a hand-started session. Only agents you dispatch get names.
- Re-resolve pane ids from `herdr agent list` before acting after a long gap; `pane move` changes them.

## Following

Always allowed:

- State: `herdr agent get <target>`.
- Output: `herdr agent read <target> --source recent-unwrapped --lines 120`. If that looks truncated (short Claude sessions), use `--source visible`.
- Wait: `herdr agent wait <target> --timeout <ms>` (settles on idle, done or blocked).

Background watching (a background command running `herdr agent wait` or `herdr agent prompt ... --wait`) is for sessions you dispatched. Watch a hand-started session in the background only when asked.

## Driving

Without asking:

- Prompt a session the user named in the current request (the request is the consent) when it is idle or done.
- Prompt sessions you dispatched.

Ask first:

- The target is `working`: a prompt would queue behind its current turn. Offer to wait instead.
- The target is `blocked` on an approval, question or folder-trust dialog. Show what `herdr agent read` shows; never answer the dialog yourself.
- Any interrupt: `send-keys esc`, `ctrl+c`.
- Closing panes, tabs or workspaces, or `herdr worktree remove`.
- Prompting a session the user did not name.

Never run `herdr server stop`.

## Starting a session

Use `herdr-dispatch` (in `~/.local/bin`) rather than `herdr agent start`: it picks the nono launcher, handles placement, and names the agent. (`herdr agent start --kind claude` is also sandboxed here, because the shell's `claude` function routes to nono, but it always uses the default launcher. `--kind codex` is not routed; never use it.)

```bash
herdr-dispatch <name> [--launcher FN] [--pane ID | --worktree BRANCH | --direction right|down] \
  [--cwd DIR] [--prompt TEXT] [--focus] [--timeout SECONDS] [-- LAUNCHER_ARGS...]
```

- Placement: use what the user asked for. Otherwise propose one and wait for OK:
  - read-only work (review, investigation): a sibling pane, the default (`herdr-dispatch <name>`);
  - code-writing work: `--worktree <branch>`, a git worktree at `<repo>/.worktrees/<branch>` in its own workspace, so two agents never share a checkout;
  - a new tab or workspace: create it with `herdr tab create` / `herdr workspace create --no-focus`, then pass `--pane` with `.result.root_pane.pane_id`.
- Launcher: this machine's default (`$HERDR_CLAUDE_LAUNCHER`, else `nono-claude-open`). Use another (`nono-claude`, `nono-claude-open`, `nono-codex`, ...) only when the user says so.
- Names: `[a-z][a-z0-9_-]{0,31}`, unique among live agents; describe the task (`review-auth`, `fix-ci`).
- The first task goes in `--prompt`. For a long brief, write it to a file and prompt "Read <path> and do it".
- It prints `{"name","pane_id","workspace_id","kind","status"}`. Exit 3 means the agent is blocked at startup (e.g. Claude's folder-trust dialog in an untrusted repo): show the user and let them decide.
- Never start one in `$HOME`; nono refuses it and the script does too.
- `worktree create` also opens a workspace for the parent repo if none is open.
