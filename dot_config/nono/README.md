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
  # Inside herdr, launch the sandbox inside a herdr-labelled agent pane so herdr
  # reports it (see "herdr agent detection" below). The socket grant lets the
  # stock session hook inside the sandbox report identity/resume.
  local profile=$1; shift
  local -a herdr_grant proxy_grant ssh_grant
  [[ -n "$HERDR_SOCKET_PATH" ]] && herdr_grant=(--allow-unix-socket "$HERDR_SOCKET_PATH")
  [[ -n "$SSH_AUTH_SOCK" ]] && ssh_grant=(--allow-unix-socket "$SSH_AUTH_SOCK")
  [[ $profile == claude-code-hardened ]] && proxy_grant=(--trust-proxy-ca)
  # herdr agent start uses herdr's own PATH (no mise), so pass nono's abs path.
  local nono_bin; nono_bin=$(command -v nono) || return 1
  if [[ "${HERDR_ENV:-}" == 1 ]] && command -v herdr >/dev/null 2>&1; then
    local agent_name="claude-${PWD:t}-${RANDOM}"
    herdr agent start "$agent_name" --cwd "$PWD" --split right \
      --env HERDR_CLAUDE_LIFECYCLE=1 -- \
      "$nono_bin" run --allow-cwd "${proxy_grant[@]}" "${ssh_grant[@]}" "${herdr_grant[@]}" \
      --profile "$profile" -- claude --dangerously-skip-permissions "$@"
  else
    "$nono_bin" run --allow-cwd "${proxy_grant[@]}" "${ssh_grant[@]}" \
      --profile "$profile" -- claude --dangerously-skip-permissions "$@"
  fi
}

nono-claude()      { _nono-claude claude-code-hardened "$@" }
nono-claude-open() { _nono-claude claude-code-open "$@" }
```

- `--trust-proxy-ca`: lets Go tools (`gh`) trust nono's TLS-intercepting proxy.
  Hardened only — under `claude-code-open` no proxy runs, so there is no CA to trust
  and TLS goes direct.
- `--allow-unix-socket "$SSH_AUTH_SOCK"`: ssh-agent for commit signing (dynamic
  launchd path, so it can't live in the profile).
- `herdr agent start <unique-name>` (when inside herdr) + the report hook over
  the `$HERDR_SOCKET_PATH` grant: make herdr show the session and its state —
  see **herdr agent detection** below. Outside herdr the helper runs `nono`
  directly.
- `--dangerously-skip-permissions`: safe because **nono is the boundary**;
  containment = the profile's grants + the egress filter.

**Always `cd` into a project first** — never launch from `$HOME` (cwd would
overlap nono's state root `~/.local/state/nono` and be refused).

## herdr agent detection

nono keeps claude on an **inner pty**, so herdr's foreground-process detection
sees `nono` and never labels the pane as an agent. What does and doesn't work
(all verified macOS, herdr 0.7.4, 2026-07):

- **`HERDR_AGENT=claude` env hint** — inert on macOS (Linux `/proc` mechanism),
  even when injected by herdr itself via `agent start --env`. No label, ever.
- **The claude screen manifest** — unreachable: it only runs on panes with a
  detected agent label, and nothing can produce one under nono on macOS
  (process→agent mapping is baked into the herdr binary; local manifest
  overrides only patch screen rules for already-identified agents).
- **`herdr agent start claude`** — the pane gets an agent *name* but no durable
  label, and worse: the exact name `claude` (a known agent) makes herdr enforce
  Claude's screen-only integration policy, so `pane.report_agent` is **silently
  dropped** (returns `{"type":"ok"}`, changes nothing).
- **`herdr agent start <any-other-name>`** — the pane becomes an "unsupported
  agent" in herdr's model, and **`pane.report_agent` works** (first source to
  report holds authority; per-source `seq` must increase — the hook uses
  `time.time_ns()`).

**The working recipe** (what `_nono-claude` in `~/.zshrc` does when inside
herdr, `HERDR_ENV=1`):

```bash
herdr agent start "claude-${PWD:t}-${RANDOM}" --cwd "$PWD" --split right \
  --env HERDR_CLAUDE_LIFECYCLE=1 -- nono run … --profile <p> -- claude …
```

- **Unique non-reserved name** per session: reports are accepted, and several
  sessions can run side by side (names must be unique; a second
  `agent start claude` fails with `agent_name_taken`).
- **`--env HERDR_CLAUDE_LIFECYCLE=1`** gates the report hook to exactly these
  panes (scoped better than the old profile-wide `set_vars` gate, which stays
  removed from `claude-code-base.jsonc`).
- **`~/.claude/hooks/herdr-nono-lifecycle.sh`** (chezmoi-managed) reports
  `idle`/`working`/`blocked` over `$HERDR_SOCKET_PATH` (hence the socket grant)
  from six `settings.json` hook events: SessionStart/UserPromptSubmit/Stop/
  SessionEnd/Notification + PostToolUse `AskUserQuestion|ExitPlanMode`.
  Known limitation (inherent to CC hooks): permission approvals and Esc
  interrupts fire no hook, so a stale state can persist until the next event.
- **The stock claude session hook** (`herdr-agent-state.sh`, ungated) reports
  session identity alongside — it works fine under nono.

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
