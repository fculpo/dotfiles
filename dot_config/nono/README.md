# Running Claude Code under nono

One profile + one shell function. macOS. Validated 2026-07.

## Profile: `claude-code-hardened.jsonc`

Extends the built-in `claude-code` (so the **keychain**, git config, runtimes, and
workdir-rw are inherited). Adds only deltas:

- `filesystem.read`: `~/.local/share/mise` (mise tools), `~/.config/gh`,
  `~/.config/glab-cli`
- `filesystem.write`: `~/workspace`
- `filesystem.allow`: `~/.npm` (npx), `~/.nono-share`
- `network.network_profile`: `claude-code` (egress filter — LLM APIs, registries,
  github/gitlab, docs)
- `network.open_port`: `9222` (browser CDP), `5037` (adb)
- `command_policies`: `{}` (NOT `null` — see gotchas)

## Launch function (`~/.zshrc`, chezmoi'd)

```bash
nono-claude() {
  nono run --allow-cwd --trust-proxy-ca \
    --allow-unix-socket "$SSH_AUTH_SOCK" \
    --profile claude-code-hardened -- \
    claude --dangerously-skip-permissions "$@"
}
```

- `--trust-proxy-ca`: lets Go tools (`gh`) trust nono's TLS-intercepting proxy.
- `--allow-unix-socket "$SSH_AUTH_SOCK"`: ssh-agent for commit signing (dynamic
  launchd path, so it can't live in the profile).
- `--dangerously-skip-permissions`: safe because **nono is the boundary**;
  containment = the profile's grants + the egress filter.

**Always `cd` into a project first** — never launch from `$HOME` (cwd would
overlap nono's state root `~/.local/state/nono` and be refused).

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
