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
  # Runs claude (under nono) in the CURRENT pane; on exit you are back at your
  # shell. Inside herdr, HERDR_AGENT=claude lets herdr's screen manifest see
  # through the nono wrapper (herdr >= 0.7.5, see below).
  local profile=$1; shift
  local -a herdr_grant proxy_grant ssh_grant env_prefix
  [[ -n "$HERDR_SOCKET_PATH" ]] && herdr_grant=(--allow-unix-socket "$HERDR_SOCKET_PATH")
  [[ -n "$SSH_AUTH_SOCK" ]] && ssh_grant=(--allow-unix-socket "$SSH_AUTH_SOCK")
  [[ $profile == claude-code-hardened ]] && proxy_grant=(--trust-proxy-ca)
  [[ "${HERDR_ENV:-}" == 1 ]] && env_prefix=(HERDR_AGENT=claude)
  env "${env_prefix[@]}" nono run "${proxy_grant[@]}" "${ssh_grant[@]}" "${herdr_grant[@]}" \
    --profile "$profile" -- claude --dangerously-skip-permissions "$@"
}

nono-claude()      { _nono-claude claude-code-hardened "$@" }
nono-claude-open() { _nono-claude claude-code-open "$@" }
```

- `--trust-proxy-ca`: lets Go tools (`gh`) trust nono's TLS-intercepting proxy.
  Hardened only — under `claude-code-open` no proxy runs, so there is no CA to trust
  and TLS goes direct.
- `--allow-unix-socket "$SSH_AUTH_SOCK"`: ssh-agent for commit signing (dynamic
  launchd path, so it can't live in the profile).
- `HERDR_AGENT=claude` (when inside herdr) + the `$HERDR_SOCKET_PATH` grant:
  screen-manifest detection through the nono wrapper, plus the stock claude
  integration for session resume -- see **herdr agent detection** below.
- **No `--allow-cwd`**: the profile grants `$WORKDIR` (the cwd) read+write
  itself, so the grant is declarative instead of depending on the invocation.
  `workdir.access` only sets the level that `--allow-cwd` would have used --
  and `"none"` there was a no-op, since nono treats it as unset and the
  built-in `claude-code` profile's `ReadWrite` wins (`nono profile show`).
- `--dangerously-skip-permissions`: safe because **nono is the boundary**;
  containment = the profile's grants + the egress filter.

**Always `cd` into a project first** — never launch from `$HOME` (cwd would
overlap nono's state root `~/.local/state/nono` and be refused). With the
`$WORKDIR` grant this matters more, not less: from a parent dir you grant that
whole tree read+write.

## herdr agent detection

nono keeps claude on an **inner pty**, so herdr's foreground-process detection
sees `nono`, not `claude` (`herdr pane process-info` confirms: `argv0: nono`).

**Solved upstream in herdr 0.7.5** — one env var, `HERDR_AGENT=claude`, set by
the launcher:

> Added macOS support for the `HERDR_AGENT=<agent>` foreground-process hint,
> allowing agents hidden behind host-visible wrappers such as `nono` to use the
> named agent's screen manifest. (#679)

Verified 0.7.5, 2026-07, on a nono pane with **no hook and without granting the
herdr socket**: `agent: claude`, `screen_detection_skipped: false`,
`matched_rule: live_prompt_box`, correct state. States now come from the claude
screen manifest (fetched into `~/.local/state/herdr/agent-detection/remote/`).
Under nono the OSC title reads `⠐ nono` rather than `✳ Claude Code`, but the
braille-spinner prefix is what `osc_title_working` matches.

Because `HERDR_CLAUDE_LIFECYCLE` is no longer set, the stock herdr claude
integration is un-gated again, so **session resume works** — the thing the old
workaround gave up.

`~/.claude/hooks/herdr-nono-lifecycle.sh` and its 6 `settings.json` entries are
now inert (the hook exits on the same missing gate). Remove them once this is
confirmed in daily use.

<details>
<summary>Historical: the 0.7.4 workaround (pushed state)</summary>

On 0.7.4 the screen manifest could not run at all — it needed a process-detected
label, and `HERDR_AGENT` was Linux-only. So state was **pushed** instead:

- **`~/.claude/hooks/herdr-nono-lifecycle.sh`** (chezmoi-managed) reports
  `idle`/`working`/`blocked` for the **current pane** via `pane.report_agent`
  over `$HERDR_SOCKET_PATH` (hence the socket grant), gated on
  `HERDR_CLAUDE_LIFECYCLE=1` (set by the launcher only inside herdr). Six
  `settings.json` events: SessionStart/UserPromptSubmit/Stop/SessionEnd/
  Notification + PostToolUse `AskUserQuestion|ExitPlanMode`. It sends the
  session id/transcript inside the report, uses `seq = time_ns` (herdr ignores
  non-increasing seq per source), and on SessionEnd sends `pane.release_agent`
  so the pane returns to plain-shell display when claude exits. Spurious
  SessionEnds (`/clear`, nested `claude -p`) just flicker and self-correct on
  the next event.
- **The stock claude session hook** (`herdr-agent-state.sh`) is **gated OFF
  under nono** in `settings.json`
  (`[ "${HERDR_CLAUDE_LIFECYCLE:-}" = 1 ] || bash ... session`): once its
  `herdr:claude` `agent_session` touches a pane, herdr switches the pane to
  Claude's official integration policy and **silently drops `report_agent`
  from every other source** (states freeze). Trade-off: no official
  session-resume under nono.
- **Do not use `herdr agent start` for this**: its pane dies with the process,
  its child PATH lacks mise, names must be unique, and it adds nothing --
  plain panes accept `pane.report_agent` fine as long as no `herdr:claude`
  session is attached.

</details>

Debugging: `herdr agent explain <pane> --json`, `herdr pane get <pane>`,
`herdr pane process-info --pane <pane>`. Get a pane id from `herdr agent list`
(its output is already JSON) filtered by `cwd`. Beware: `pane.report_agent`
returns `{"type":"ok"}` even when a report is silently dropped — 0.7.5 adds
`pane.clear_agent_authority` ("release Herdr's full-lifecycle authority") to
unstick a pane an `agent_session` has taken over.

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
