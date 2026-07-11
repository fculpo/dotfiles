# Running Claude Code under nono

Three profiles + two shell functions. macOS. Validated 2026-07.

## Profiles

`claude-code-base.jsonc` — extends the built-in `claude-code` (so the **keychain**,
git config, runtimes, and workdir-rw are inherited). Everything except egress:

- `filesystem.read`: `~/.local/share/mise` (mise tools), `~/.config/gh`,
  `~/.config/glab-cli`
- `filesystem.write`: `~/workspace`
- `filesystem.allow`: `~/.npm` (npx), `~/.nono-share`
- `network.open_port`: `9222` (browser CDP), `5037` (adb), `8787` (headroom)
- `command_policies`: `{}` (NOT `null` — see gotchas)

`claude-code-hardened.jsonc` — base + the egress filter. **The default.**

- `network.network_profile`: `claude-code` (LLM APIs, registries, github/gitlab, docs)
- `network.allow_domain`: supabase + nono registry hosts

`claude-code-open.jsonc` — base, nothing added: no proxy runs, so **any host is
reachable**. Filesystem confinement and policy groups are unchanged.

Why base + two siblings, rather than `open` extending `hardened` and switching the
filter off? nono's merge rules make that impossible: array fields like `allow_domain`
are *appended* down the chain and a child can never remove an inherited entry, and
**any** non-empty `allow_domain` turns the default-deny proxy on. `network_profile`
is the one null-clearable field, but clearing it alone would leave the 4 inherited
`allow_domain` entries as the *entire* allowlist — stricter, not open. So the
unfiltered profile must never inherit the filter in the first place.

There is **no nono CLI flag** for "unrestricted network". The network flags are
`--block-net`, `--network-profile <name>`, `--allow-domain`, and the port flags —
all of which only ever *narrow* egress. Unfiltered means: pick a profile with no
`network_profile` and no `allow_domain`.

## Launch functions (`~/.zshrc`, chezmoi'd)

`nono-claude` (hardened, default) and `nono-claude-open` (unrestricted egress) share
one helper and differ only by profile:

```bash
_nono-claude() {
  # herdr socket grant (dynamic path) for the report_agent hook; see "herdr" below.
  local profile=$1; shift
  local -a herdr_grant proxy_grant
  [[ -n "$HERDR_SOCKET_PATH" ]] && herdr_grant=(--allow-unix-socket "$HERDR_SOCKET_PATH")
  [[ $profile == claude-code-hardened ]] && proxy_grant=(--trust-proxy-ca)
  HERDR_AGENT=claude nono run --allow-cwd "${proxy_grant[@]}" \
    --allow-unix-socket "$SSH_AUTH_SOCK" \
    "${herdr_grant[@]}" \
    --profile "$profile" -- \
    claude --dangerously-skip-permissions "$@"
}

nono-claude()      { _nono-claude claude-code-hardened "$@" }
nono-claude-open() { _nono-claude claude-code-open "$@" }
```

- `--trust-proxy-ca`: lets Go tools (`gh`) trust nono's TLS-intercepting proxy.
  Hardened only — under `claude-code-open` no proxy runs, so there is no CA to trust
  and TLS goes direct.
- `--allow-unix-socket "$SSH_AUTH_SOCK"`: ssh-agent for commit signing (dynamic
  launchd path, so it can't live in the profile).
- `HERDR_AGENT=claude` + the `$HERDR_SOCKET_PATH` grant: make herdr detect the
  session — see **herdr agent detection** below.
- `--dangerously-skip-permissions`: safe because **nono is the boundary**;
  containment = the profile's grants + the egress filter.

**Always `cd` into a project first** — never launch from `$HOME` (cwd would
overlap nono's state root `~/.local/state/nono` and be refused).

## herdr agent detection

nono keeps claude on an **inner pty**, so herdr's foreground-process detection
sees `nono` and never marks the pane as an agent. Making herdr detect it needs
**both** of these (verified on macOS 2026-07 — neither works alone):

1. **`HERDR_AGENT=claude`** on the `nono` command (in the launch function above).
   Makes herdr trust the pane is claude and stop overriding with process
   detection. Must be on the `nono` process herdr observes, so it is a command
   prefix — not a profile `set_var`.
2. **A `pane.report_agent` hook** at `~/.claude/hooks/herdr-nono-lifecycle.sh`
   (chezmoi-managed) that reports presence + state over herdr's socket. Needs the
   `$HERDR_SOCKET_PATH` grant in the launcher.

The gate `HERDR_CLAUDE_LIFECYCLE=1` (in this profile's `environment.set_vars`)
enables the hook **and** suppresses herdr's stock claude session hook for nono
(its `agent_session` would flip herdr back to process detection and break the
above). Trade-off: nono panes get live detection + state, but not herdr
session-**resume**.

**Not chezmoi-managed** (Claude Code writes to `settings.json`): add these hook
entries to `~/.claude/settings.json` by hand. Gate the stock herdr hook and add
ours on the five lifecycle events plus PostToolUse:

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

(herdr's docs present `HERDR_AGENT` as sufficient and warn against `report_agent`
hooks; that guidance did not hold for nono's inner-pty model on macOS.)

## Per-workflow

| Workflow | What it needs |
| --- | --- |
| **Commit signing** | git `gpg.format=ssh`, `user.signingkey` = inlined `ssh-ed25519 …`. Key-safe: ssh-agent socket only, no `~/.ssh` read. Verify locally with `gpg.ssh.allowedSignersFile`. |
| **gh / glab** | Inherited keychain (gh token) + `~/.config/glab-cli` (glab file token). Works via the alias (`--trust-proxy-ca`). |
| **Browser visual checks** | Host: `nono-gui-host.sh` (headed Chrome `--remote-debugging-port=9222`). Project `.mcp.json`: `playwright` as **stdio** with `--cdp-endpoint=http://localhost:9222` (NOT `type:http` — Claude's HTTP MCP client is broken, #45368). `open_port 9222` (profile). |
| **Android** | Host: emulator running + `adb start-server && adb connect localhost:5555`. `.mcp.json`: `mobile` = mobile-mcp stdio. `open_port 5037` (profile). |
| **iOS** | Host: `xcrun simctl boot …`. Screenshots via `simctl` work directly under nono (no extra grant). mobile-mcp only enumerates iOS if `idb-companion` is installed. |
| **Remote MCP (e.g. Supabase)** | Add the MCP host AND its OAuth host to `network.allow_domain` (e.g. `mcp.supabase.com` + `api.supabase.com`). Mismatched subdomain = "credentials rejected on reconnect". |

## Gotchas

- **Launch from a project dir**, not `$HOME` (state-root overlap).
- `nono profile init --full` writes `command_policies: null`, which its own parser
  rejects — change to `{}`. (The minimal extend-only profile avoids this.)
- **`ps` (setuid) fails** under nono; ccstatusline degrades gracefully, so the
  statusline still renders. No fix needed.
- **Claude's own OAuth needs the keychain** — that's why this profile *inherits*
  the keychain grant rather than denying it. Fully keychain-free requires
  `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`).
- **`~/.claude.json.tmp.<pid>` write** is denied (atomic config save) but
  non-fatal; grant `write_file` if settings stop persisting.
- Egress filtering (`network_profile`) is the real containment under
  `--dangerously-skip-permissions`; keep it on (or tighten to `minimal`).

## nono cheatsheet

```bash
nono why --profile claude-code-hardened --path <p> --op read   # why allowed/denied
nono run ... -v -- <cmd>                                        # show all grants + denials
nono profile show claude-code-hardened                         # resolved policy
# unblock loop: read the denial -> add --read/--allow/--open-port -> persist to profile
```
