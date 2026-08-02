# nono sandbox for Codex

Date: 2026-08-02

## Goal

Run OpenAI Codex CLI under the nono sandbox the same way Claude Code already runs:
a hardened profile with egress filtering by default, an open profile for tasks
needing arbitrary hosts, and two zsh entry points.

## Context

nono already ships a `codex` package profile (`nolabs-ai/codex`, installed) that
grants `$HOME/.codex` and `$HOME/.agents`, allows `https://auth.openai.com` in
`open_urls`, and wires a Codex plugin plus developer instructions into
`~/.codex/config.toml`. nono also ships a `codex` network profile for proxy
egress filtering, and knows `CODEX_CA_CERTIFICATE` as a CA env var.

What is missing is the user layer: the filesystem allowlist, the Headroom base
URL, and the shell functions.

The existing Claude setup is three profiles (`claude-code-base`,
`claude-code-hardened`, `claude-code-open`) plus `_nono-claude` in
`private_dot_zshrc`.

## Design

### Profile layout

All files live in `dot_config/nono/profiles/` (chezmoi source; deploys to
`~/.config/nono/profiles/`).

| File | Extends | Holds |
| --- | --- | --- |
| `agent-common.jsonc` (new) | none | Agent-agnostic filesystem lists, `open_port`, deny/bypass/suppress rules |
| `claude-code-base.jsonc` (refactor) | `claude-code`, `agent-common` | Claude-only paths and env |
| `codex-base.jsonc` (new) | `codex`, `agent-common` | Codex-only env and open_urls |
| `codex-hardened.jsonc` (new) | `codex-base` | `network_profile: "codex"` + `allow_domain` extras |
| `codex-open.jsonc` (new) | `codex-base` | Nothing; inherits no filter |

`extends` accepts a list and merges left to right, with the selected profile as
the final override layer, so multi-parent inheritance is supported.

The hardened/open split mirrors the Claude split and is forced by the same nono
merge rule: array fields such as `allow_domain` only append down the chain and
can never be removed by a child, so "open" cannot be a child of "hardened".

### Contents split

Stays in `claude-code-base`:

- `$HOME/.claude/hooks/`, `$HOME/.claude.json`
- `CLAUDE_CONFIG_DIR`, `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL`, `ENABLE_TOOL_SEARCH`
- The complete `open_urls` list, unchanged: `api.supabase.com`, `claude.com`,
  `claude.ai`, `github.com`
- The existing explanatory comments move with the vars they explain.

Moves to `agent-common`:

- All remaining `filesystem.allow`, `filesystem.read`, `filesystem.allow_file`,
  `filesystem.read_file` entries, including `$WORKDIR`
- `network.open_port` `[9222, 5037, 8787]`
- `filesystem.deny` `[".envrc"]`, `bypass_protection`, `suppress_save_prompt`
- `allow_gpu: true`, `allow_launch_services: true`

`open_urls` stays out of the mixin. `filesystem.*` and `open_port` append down
the inheritance chain, but `open_urls` is replace-on-presence: a child that
declares the field discards the inherited value entirely. A shared list in
`agent-common` would be silently dropped by every profile that declares its
own. Each agent base therefore restates its full list, including the shared
`github.com` and `api.supabase.com` origins.

New in `codex-base`:

- `environment.set_vars.OPENAI_BASE_URL = "http://127.0.0.1:8787/v1"` (Headroom)
- A complete `open_urls` list: `auth.openai.com`, `chatgpt.com`,
  `api.supabase.com`, `github.com`, plus `allow_localhost: true`. The first and
  last of those come from the builtin `codex` profile and must be restated,
  since declaring the field replaces the inherited value.
- `$HOME/.codex` and `$HOME/.agents` are inherited from the builtin `codex`
  profile; they are not restated. Unlike `open_urls`, filesystem grants append.

New in `codex-hardened`:

- `network.network_profile = "codex"`
- `network.allow_domain`: `api.supabase.com`, `mcp.supabase.com`,
  `registry.nono.sh`, `nono.sh`

`allow_domain` must not live in `agent-common`. Any non-empty `allow_domain`
turns on the default-deny proxy, which would silently filter the `-open`
profiles too. The four domains are therefore duplicated in each hardened
profile. This duplication is deliberate.

### Network path

Codex talks to Headroom on `127.0.0.1:8787`, already covered by the inherited
`open_port` grant. Headroom runs on the host, outside the sandbox, so it
performs the actual egress to OpenAI. The nono proxy sees only loopback traffic
for model calls; the `codex` network profile governs everything else Codex
reaches (auth, updates, registries).

`--trust-proxy-ca` is passed only for the hardened profile, since only that
profile starts the TLS-intercepting proxy and therefore has a CA to trust.

### Shell functions

Added to `private_dot_zshrc` beside the Claude pair:

```zsh
_nono-codex() {
  local profile=$1; shift
  local -a herdr_grant proxy_grant ssh_grant env_prefix
  [[ -n "$HERDR_SOCKET_PATH" ]] && herdr_grant=(--allow-unix-socket "$HERDR_SOCKET_PATH")
  [[ -n "$SSH_AUTH_SOCK" ]] && ssh_grant=(--allow-unix-socket "$SSH_AUTH_SOCK")
  [[ $profile == codex-hardened ]] && proxy_grant=(--trust-proxy-ca)
  [[ "${HERDR_ENV:-}" == 1 ]] && env_prefix=(HERDR_AGENT=codex)
  env "${env_prefix[@]}" nono run "${proxy_grant[@]}" "${ssh_grant[@]}" "${herdr_grant[@]}" \
    --profile "$profile" --allow-gpu --allow-launch-services \
    -- codex --dangerously-bypass-approvals-and-sandbox "$@"
}

nono-codex()      { _nono-codex codex-hardened "$@" }
nono-codex-open() { _nono-codex codex-open "$@" }
```

`--dangerously-bypass-approvals-and-sandbox` disables Codex's own seatbelt so
nono is the single boundary. Nesting Codex's sandbox inside nono produces
`sandbox-exec: sandbox_apply: Operation not permitted`, the exact failure the
nono Codex pack's developer instructions describe.

There is no `--system-prompt` equivalent for Codex, so the Serena system prompt
override used by `_nono-claude` is dropped. Codex reads `~/.codex/AGENTS.md`.

## Non-goals

- Changing how Claude Code runs. The `claude-code-base` refactor is a pure move
  of entries into `agent-common`, with no additions or removals.
- Routing Codex through `headroom wrap codex`. The base URL is set in the
  profile so the setup owns it, matching the Claude approach.
- Migrating the Claude Headroom workarounds (`ENABLE_TOOL_SEARCH`,
  `ANTHROPIC_MODEL` suffix) to Codex. They are Anthropic-specific.

## Verification

1. Capture `nono profile show claude-code-hardened` before the refactor and
   again after. The two must be identical. Same for `claude-code-open`.
2. `nono profile show codex-hardened` shows workdir access ReadWrite, the
   `codex` network profile, and the four extra domains.
3. `nono profile show codex-open` shows no network profile.
4. From a project directory, `nono-codex` starts Codex, `/status` reports the
   configured model, and Headroom records the traffic
   (`headroom doctor` or the proxy stats).
5. `nono-codex-open` starts Codex with no proxy banner.

Steps 4 and 5 must be run outside a nono sandbox; nested `nono run` fails on the
session state directory.
