# nono sandbox for Codex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run OpenAI Codex CLI under nono with the same hardened/open profile pair and zsh entry points that Claude Code already has.

**Architecture:** Extract the agent-agnostic grants from `claude-code-base.jsonc` into a new `agent-common.jsonc` mixin, then build `codex-base` / `codex-hardened` / `codex-open` on top of nono's builtin `codex` package profile plus that mixin. Add `nono-codex` and `nono-codex-open` zsh functions mirroring `_nono-claude`.

**Tech Stack:** nono (JSONC profiles, `nono profile show|validate`), chezmoi (source in `~/.local/share/chezmoi`, deployed to `~/.config`), zsh.

**Spec:** `docs/superpowers/specs/2026-08-02-nono-codex-design.md`

## Global Constraints

- Work happens in the git worktree `/Users/fabien/.local/share/chezmoi/.worktrees/nono-codex` on branch `nono-codex`. Never edit `~/.config/nono/profiles/*` or `~/.zshrc` directly; edit `dot_config/nono/profiles/*` and `private_dot_zshrc` inside the worktree.
- `chezmoi apply` defaults to the main source tree, which is not this worktree. Always pass the source explicitly: `chezmoi apply -S "$PWD" <target>`, run from the worktree root. Applying without `-S` silently deploys the main branch and makes every verification meaningless.
- `nono profile show` reads the deployed copy under `~/.config`, so every verification step must be preceded by `chezmoi apply -S "$PWD"`.
- The Claude refactor is a pure move. `nono profile show claude-code-hardened` and `claude-code-open` must be identical before and after when compared as sorted line sets. Raw line order changes in appended array blocks are expected; see Task 2 Step 4.
- `allow_domain` must never appear in `agent-common.jsonc`. Any non-empty `allow_domain` switches on nono's default-deny proxy, which would silently filter the `-open` profiles.
- `open_urls` must never appear in `agent-common.jsonc` either, for a different reason. Per `nono profile guide`, `filesystem.*` and `open_port` append down the inheritance chain, but `open_urls` is replace-on-presence: a child that declares the field at all discards the inherited value completely. A shared list in the mixin would be silently dropped by every profile that declares its own. Each agent base restates its full list, shared origins included.
- Codex base URL is exactly `http://127.0.0.1:8787/v1`.
- No emojis, no em-dashes, in files or commit messages.
- Commit only the named files. Never `git add -A`.

## Pre-existing uncommitted changes

`git status` at plan time shows two uncommitted edits by the user, in files this plan also touches:

- `dot_config/nono/profiles/claude-code-base.jsonc`: `allow_launch_services` and `allow_gpu` flipped from `null` to `true`
- `private_dot_zshrc`: `_nono-claude` gained `--allow-gpu --allow-launch-services` and `--system-prompt=...`

Both are already reflected in this plan (the two booleans move to `agent-common`, the zsh line is the model for `_nono-codex`). Task 1 commits them first so the refactor diff stays readable.

---

### Task 1: Commit pre-existing edits and capture the Claude baseline (DONE, controller)

Completed during setup, before the worktree existed. The two pre-existing edits are committed on `main` as `b0482ee`, the `nono-codex` branch was created from that commit, and the baseline files exist at `/tmp/nono-baseline/`. Both are 114 and 116 lines. Do not redo this task. The steps below are kept as the record of what was run.


**Files:**
- Modify: none
- Create: `/tmp/nono-baseline/claude-code-hardened.txt`, `/tmp/nono-baseline/claude-code-open.txt`

**Interfaces:**
- Produces: two baseline text files that Task 2 diffs against. This is the regression test for the refactor.

- [ ] **Step 1: Confirm the working tree matches what this plan expects**

```bash
cd /Users/fabien/.local/share/chezmoi
git status --short
```

Expected: exactly two modified files, `dot_config/nono/profiles/claude-code-base.jsonc` and `private_dot_zshrc`, plus untracked `dot_claude/skills/` and the spec/plan docs. If anything else is modified, stop and ask the user.

- [ ] **Step 2: Commit the two pre-existing edits**

```bash
cd /Users/fabien/.local/share/chezmoi
git add dot_config/nono/profiles/claude-code-base.jsonc private_dot_zshrc
git commit -m "fix(nono): grant gpu and launch services to claude profile"
```

- [ ] **Step 3: Deploy so the on-disk profiles match the source**

```bash
chezmoi apply -S "$PWD" ~/.config/nono
```

- [ ] **Step 4: Capture the baseline**

```bash
mkdir -p /tmp/nono-baseline
nono profile show claude-code-hardened > /tmp/nono-baseline/claude-code-hardened.txt
nono profile show claude-code-open     > /tmp/nono-baseline/claude-code-open.txt
wc -l /tmp/nono-baseline/*.txt
```

Expected: both files non-empty (tens of lines each). If either is empty or the command errors, stop: the refactor cannot be verified without a baseline.

- [ ] **Step 5: Sanity-check the baseline captures what matters**

```bash
grep -E "Workdir access|network profile|allow \(r\+w\)" -i /tmp/nono-baseline/claude-code-hardened.txt
```

Expected: shows `Workdir access: ReadWrite` and the resolved network profile line. This confirms `nono profile show` renders the resolved chain, not just the file.

---

### Task 2: Extract `agent-common.jsonc` and slim `claude-code-base.jsonc`

**Files:**
- Create: `dot_config/nono/profiles/agent-common.jsonc`
- Modify: `dot_config/nono/profiles/claude-code-base.jsonc` (full rewrite, shrinks from 186 to ~60 lines)
- Test: diff against `/tmp/nono-baseline/*.txt` from Task 1

**Interfaces:**
- Produces: profile name `agent-common`, extended by `claude-code-base` and (in Task 3) `codex-base`. It defines no `extends` of its own and no `allow_domain`.

- [ ] **Step 1: Create the mixin**

Write `dot_config/nono/profiles/agent-common.jsonc`:

```jsonc
{
  // Agent-agnostic sandbox grants, shared by claude-code-base and codex-base.
  // Deliberately no "extends": this is a mixin. Both consumers list it as a
  // second parent (e.g. "extends": ["codex", "agent-common"]) so the agent's own
  // package profile stays the first base and this one only widens it.
  //
  // Deliberately no allow_domain either: any non-empty allow_domain turns on
  // nono's default-deny proxy, which would silently filter the -open profiles
  // that exist precisely to have no egress filter. Domain allowlists belong in
  // the -hardened leaves only.
  "meta": {
    "name": "",
    "version": "",
    "description": "Shared agent-agnostic sandbox grants",
    "author": null
  },
  "filesystem": {
    "allow": [
      // The current project, read+write. $WORKDIR expands to the process cwd,
      // so this replaces the --allow-cwd CLI flag: the grant is declared here
      // instead of depending on how nono was invoked. Verified with
      // `nono why --path <cwd>/f --op readwrite` -> ALLOWED, granted_path,
      // Source profile; with --workdir pointed elsewhere the same path is DENIED.
      // Still cd into a project first: from a parent dir this grants that whole
      // tree (and $HOME is refused anyway -- it overlaps ~/.local/state/nono).
      "$WORKDIR",
      "$HOME/.android",
      "$HOME/.bun",
      "$HOME/.ansible",
      "$HOME/.cache",
      "$HOME/.cache/codebase-memory-mcp",
      "$HOME/.codex",
      "$HOME/.cocoapods",
      "$HOME/.config",
      "$HOME/.dart-tool",
      "$HOME/.dartServer",
      "$HOME/.dolt",
      "$HOME/.gitlab-ci-local",
      "$HOME/.gradle",
      "$HOME/.headroom/",
      "$HOME/.local/share/chezmoi",
      "$HOME/.local/share/mise",
      "$HOME/.local/share/openspec",
      "$HOME/.local/share/state",
      "$HOME/.local/share/tokensave",
      "$HOME/.local/state/mise/",
      "$HOME/.nono-share",
      "$HOME/.npm",
      "$HOME/.pkl",
      "$HOME/.pub-cache",
      "$HOME/.serena",
      "$HOME/.tokensave",
      "$HOME/Library/Developer/Xcode",
      "$HOME/.local/share/uv/tools",
      "$HOME/workspace"
    ],
    "read": [
      "$HOME/Downloads",
      "$HOME/Library/Android",
      "$HOME/.local/share/mise",
      "$HOME/.config/gh",
      "$HOME/.config/glab-cli",
      "~/.agents/skills"
    ],
    "allow_file": [
      "$HOME/.zshrc"
    ],
    "read_file": [
      "$HOME/.gitconfig.local"
    ],
    "deny": [
      ".envrc"
    ],
    "bypass_protection": [
      "$HOME/.zshrc"
    ],
    "suppress_save_prompt": [
      "~/"
    ]
  },
  "network": {
    "open_port": [
      9222,
      5037,
      8787 // headroom
    ]
  },
  // Deliberately no open_urls here. Unlike filesystem.* and open_port, which
  // append down the chain, open_urls is replace-on-presence: if any child
  // provides the field at all, it overwrites the inherited value entirely
  // (`nono profile guide`). A shared list here would be silently dropped by
  // every consumer that declares its own. Each agent base therefore carries
  // its own complete list, api.supabase.com and github.com included.
  "allow_launch_services": true,
  "allow_gpu": true
}
```

- [ ] **Step 2: Validate the mixin parses**

```bash
nono profile validate ~/.local/share/chezmoi/dot_config/nono/profiles/agent-common.jsonc
```

Expected: `Result: valid`. If `meta` fields or a missing `extends` are rejected, fix per the error text before continuing.

- [ ] **Step 3: Rewrite `claude-code-base.jsonc` with only the Claude-specific parts**

Replace the whole file with:

```jsonc
{
  // Shared Claude Code sandbox: Claude-specific paths and env only. The
  // agent-agnostic grants (project dir, tool caches, ports) live in
  // agent-common.jsonc, which codex-base extends too.
  //
  // The two leaf profiles differ only in the network layer:
  //   claude-code-hardened -> adds network_profile + allow_domain (egress filter)
  //   claude-code-open     -> adds nothing (unrestricted egress)
  // The split is forced by nono's merge rules: array fields like allow_domain are
  // appended down the chain and can never be removed by a child, and any non-empty
  // allow_domain turns on the default-deny proxy. So "open" cannot be expressed as a
  // child of "hardened" -- it has to be a sibling that never inherits the filter.
  "extends": [
    "claude-code",
    "agent-common"
  ],
  "meta": {
    "name": "",
    "version": "",
    "description": "Shared Claude Code sandbox without egress filtering",
    "author": null
  },
  "filesystem": {
    "allow": [
      "$HOME/.claude/hooks/"
    ],
    "allow_file": [
      "$HOME/.claude.json"
    ]
  },
  "environment": {
    "set_vars": {
      "CLAUDE_CONFIG_DIR": "$HOME/.claude",
      // Both of the next two exist only because ANTHROPIC_BASE_URL below points
      // at headroom. Any custom base URL breaks them; headroom's own `wrap`
      // papers over both (--tool-search, --1m), but we set the base URL here
      // rather than via wrap, so we own the fixes.
      //
      // Without this, Claude Code stops deferring tool schemas behind a custom
      // base URL and materializes all of them, inflating context by tens of K
      // tokens -- cancelling much of what the proxy saves (headroom #746).
      "ENABLE_TOOL_SEARCH": "true",
      // Claude Code only sends the context-1m beta header when the model id
      // carries the [1m] suffix, and behind a custom base URL the /model picker
      // selection does not survive -- so it silently caps at 200k
      // (headroom #1158). The suffix is what triggers the header; the model name
      // is just whichever one you want as default.
      // Trade-off: this pins the default model, so update it when you move on
      // from Opus 5.
      "ANTHROPIC_MODEL": "claude-opus-5[1m]",
      "ANTHROPIC_BASE_URL": "http://localhost:8787"
    }
  },
  // Empty on purpose. workdir.access only sets the *level* used by the
  // --allow-cwd flag, which we no longer pass; the cwd grant comes from
  // "$WORKDIR" in agent-common. "access": "none" was misleading -- nono treats
  // it as unset, so the built-in claude-code profile's ReadWrite still won
  // (`nono profile show <name>` -> "Workdir access: ReadWrite").
  "workdir": {},
  // Unchanged from before the refactor, and it must stay that way. open_urls is
  // replace-on-presence, not append: this block overwrites whatever the parents
  // declare, so the shared origins have to be repeated here rather than
  // inherited from agent-common.
  "open_urls": {
    "allow_origins": [
      "https://api.supabase.com",
      "https://claude.com",
      "https://claude.ai",
      "https://github.com"
    ]
  }
}
```

- [ ] **Step 4: Deploy and diff against the baseline**

```bash
chezmoi apply -S "$PWD" ~/.config/nono
nono profile show claude-code-hardened > /tmp/nono-after-hardened.txt
nono profile show claude-code-open     > /tmp/nono-after-open.txt
diff <(sort /tmp/nono-baseline/claude-code-hardened.txt) <(sort /tmp/nono-after-hardened.txt)
diff <(sort /tmp/nono-baseline/claude-code-open.txt)     <(sort /tmp/nono-after-open.txt)
```

Expected: both diffs produce no output. Any difference means the refactor changed the effective policy: a path was dropped, added, or renamed. Do not proceed until the diff is empty.

The comparison is on sorted output, not raw output, and that is deliberate. nono appends array entries in inheritance-chain order, so a path that moves from `claude-code-base` into `agent-common` renders at a different position in the `allow (r+w)` list. Same set, different order, same policy. Sorting removes that noise while still catching any real add or drop.

`Open URLs` is not subject to this. That field is replace-on-presence, so `claude-code-base` keeps its own complete four-origin list and the block should render byte-identical to the baseline. If `Open URLs` changes at all, something is wrong.

- [ ] **Step 4b: Eyeball the raw diff once**

```bash
diff /tmp/nono-baseline/claude-code-hardened.txt /tmp/nono-after-hardened.txt
```

Expected: differences confined to the ordering of entries inside the `allow (r+w)` block. If a line moves between sections, if a section header changes, or if `Open URLs` differs at all, stop and investigate.

- [ ] **Step 5: Commit**

```bash
cd /Users/fabien/.local/share/chezmoi
git add dot_config/nono/profiles/agent-common.jsonc dot_config/nono/profiles/claude-code-base.jsonc
git commit -m "refactor(nono): extract agent-common profile from claude-code-base"
```

---

### Task 3: Add the three Codex profiles

**Files:**
- Create: `dot_config/nono/profiles/codex-base.jsonc`
- Create: `dot_config/nono/profiles/codex-hardened.jsonc`
- Create: `dot_config/nono/profiles/codex-open.jsonc`

**Interfaces:**
- Consumes: `agent-common` from Task 2, and nono's builtin `codex` package profile (installed from `nolabs-ai/codex`, which already grants `$HOME/.codex`, `$HOME/.agents`, and `https://auth.openai.com`).
- Produces: profile names `codex-hardened` and `codex-open`, used by the zsh functions in Task 4.

- [ ] **Step 1: Confirm the builtin codex profile is present**

```bash
nono profile list | grep -E "^\s+codex"
```

Expected: a `codex` row under Packages, `from nolabs-ai/codex`. If missing, run `nono pull nolabs-ai/codex` before continuing.

- [ ] **Step 2: Create `codex-base.jsonc`**

```jsonc
{
  // Shared Codex sandbox: Codex-specific env only. Filesystem, ports and the
  // rest come from agent-common; $HOME/.codex and $HOME/.agents come from the
  // builtin `codex` package profile, so they are not restated here.
  //
  // Same hardened/open split as Claude, forced by the same merge rule: any
  // non-empty allow_domain turns on the default-deny proxy and children can
  // never remove an inherited one, so "open" must be a sibling of "hardened".
  "extends": [
    "codex",
    "agent-common"
  ],
  "meta": {
    "name": "",
    "version": "",
    "description": "Shared Codex sandbox without egress filtering",
    "author": null
  },
  "environment": {
    "set_vars": {
      // Codex talks to headroom on loopback; headroom runs on the host, outside
      // the sandbox, and does the actual egress to OpenAI. Port 8787 is already
      // open via agent-common. Codex needs the /v1 suffix, unlike Claude Code.
      "OPENAI_BASE_URL": "http://127.0.0.1:8787/v1"
    }
  },
  // open_urls is replace-on-presence, not append (`nono profile guide`):
  // declaring it here overwrites both the builtin codex profile's value and
  // anything a parent set. So this list must restate everything Codex needs,
  // including the builtin's auth.openai.com and allow_localhost, plus the
  // shared origins that agent-common cannot carry for the same reason.
  "open_urls": {
    "allow_origins": [
      "https://auth.openai.com",
      "https://chatgpt.com",
      "https://api.supabase.com",
      "https://github.com"
    ],
    "allow_localhost": true
  }
}
```

- [ ] **Step 3: Create `codex-hardened.jsonc`**

```jsonc
{
  // Default Codex profile: codex-base + egress filtering.
  // network_profile is the real containment (see ../README.md); allow_domain widens
  // the proxy allowlist for hosts the codex network policy does not cover.
  "extends": [
    "codex-base"
  ],
  "meta": {
    "name": "",
    "version": "",
    "description": "Codex sandbox with egress filtering",
    "author": null
  },
  "network": {
    "network_profile": "codex",
    "allow_domain": [
      "api.supabase.com",
      "mcp.supabase.com",
      "registry.nono.sh",
      "nono.sh"
    ]
  }
}
```

- [ ] **Step 4: Create `codex-open.jsonc`**

```jsonc
{
  // codex-base with no egress filter: the proxy never starts, so Codex can reach
  // any host. Filesystem confinement, policy groups and command policy are
  // unchanged -- only network containment is dropped. Use for tasks that need
  // arbitrary hosts (scraping, unknown registries); prefer codex-hardened.
  "extends": [
    "codex-base"
  ],
  "meta": {
    "name": "",
    "version": "",
    "description": "Codex sandbox with unrestricted egress",
    "author": null
  }
}
```

- [ ] **Step 5: Deploy and verify the resolved profiles**

```bash
chezmoi apply -S "$PWD" ~/.config/nono
nono profile show codex-hardened
nono profile show codex-open
```

Expected in `codex-hardened`:
- `Extends: codex-base`
- `Workdir access: ReadWrite`
- the network profile line naming `codex`
- `$HOME/workspace`, `$HOME/.serena`, `$HOME/.config` under allow (proving `agent-common` merged in)
- `$HOME/.codex` under allow (proving the builtin `codex` profile merged in)
- `OPENAI_BASE_URL` in the environment section

Expected in `codex-open`: same filesystem grants, no network profile and no allow_domain.

- [ ] **Step 6: Verify the open profile really has no filter**

```bash
nono profile show codex-open | grep -i -E "network profile|allow_domain|proxy" || echo "NO FILTER (expected)"
```

Expected: `NO FILTER (expected)`. If a domain or network profile shows up, `allow_domain` leaked into `agent-common` or `codex-base`; move it back to the hardened leaf.

- [ ] **Step 7: Verify the Claude profiles are still untouched**

```bash
nono profile show claude-code-hardened > /tmp/nono-after2-hardened.txt
diff /tmp/nono-baseline/claude-code-hardened.txt /tmp/nono-after2-hardened.txt && echo "CLAUDE UNCHANGED"
```

Expected: `CLAUDE UNCHANGED`.

- [ ] **Step 8: Commit**

```bash
cd /Users/fabien/.local/share/chezmoi
git add dot_config/nono/profiles/codex-base.jsonc dot_config/nono/profiles/codex-hardened.jsonc dot_config/nono/profiles/codex-open.jsonc
git commit -m "feat(nono): add codex sandbox profiles"
```

---

### Task 4: Add the zsh entry points

**Files:**
- Modify: `private_dot_zshrc` (insert after the `nono-claude-open` line, around line 216)

**Interfaces:**
- Consumes: profile names `codex-hardened` and `codex-open` from Task 3.
- Produces: shell functions `nono-codex` and `nono-codex-open`.

- [ ] **Step 1: Locate the insertion point**

```bash
grep -n "nono-claude-open() { _nono-claude claude-code-open" /Users/fabien/.local/share/chezmoi/private_dot_zshrc
```

Expected: one match. Insert the new block immediately after that line, before the `# To customize prompt` comment.

- [ ] **Step 2: Insert the functions**

```zsh
# Codex under nono. Mirrors _nono-claude: nono is the only sandbox boundary, so
# Codex's own seatbelt is disabled -- nesting it inside nono produces
# `sandbox-exec: sandbox_apply: Operation not permitted`, which is exactly the
# failure the nono codex pack's developer instructions describe.
# No --system-prompt equivalent exists for Codex; it reads ~/.codex/AGENTS.md.
_nono-codex() {
  local profile=$1; shift
  local -a herdr_grant proxy_grant ssh_grant env_prefix
  [[ -n "$HERDR_SOCKET_PATH" ]] && herdr_grant=(--allow-unix-socket "$HERDR_SOCKET_PATH")
  [[ -n "$SSH_AUTH_SOCK" ]] && ssh_grant=(--allow-unix-socket "$SSH_AUTH_SOCK")
  # Only the filtering profile runs the TLS-intercepting proxy; without it there is
  # no nono CA for gh/Go tools to trust.
  [[ $profile == codex-hardened ]] && proxy_grant=(--trust-proxy-ca)
  [[ "${HERDR_ENV:-}" == 1 ]] && env_prefix=(HERDR_AGENT=codex)
  # No --allow-cwd: the profile grants "$WORKDIR" (the cwd) read+write itself.
  env "${env_prefix[@]}" nono run "${proxy_grant[@]}" "${ssh_grant[@]}" "${herdr_grant[@]}" \
    --profile "$profile" --allow-gpu --allow-launch-services \
    -- codex --dangerously-bypass-approvals-and-sandbox "$@"
}

nono-codex() { _nono-codex codex-hardened "$@" }

# Same sandbox, no egress filter: Codex can reach any host. Filesystem
# confinement still applies. Reach for this only when a task needs arbitrary
# hosts -- egress filtering is the real containment (see ~/.config/nono/README.md).
nono-codex-open() { _nono-codex codex-open "$@" }
```

- [ ] **Step 3: Check the syntax before deploying**

```bash
zsh -n /Users/fabien/.local/share/chezmoi/private_dot_zshrc && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`.

- [ ] **Step 4: Deploy and confirm the functions load**

```bash
chezmoi apply -S "$PWD" ~/.zshrc
zsh -ic 'whence -f nono-codex nono-codex-open' | head -20
```

Expected: both function bodies print. If `whence` finds nothing, the block landed outside the sourced region of the file.

- [ ] **Step 5: Verify the flag Codex actually accepts**

```bash
codex --help 2>&1 | grep -- "--dangerously-bypass-approvals-and-sandbox"
```

Expected: the flag appears. If this Codex version renamed it (older builds used `--dangerously-auto-approve-everything`, some use `--yolo` as an alias), update the function to whatever `codex --help` reports and note the version.

- [ ] **Step 6: Commit**

```bash
cd /Users/fabien/.local/share/chezmoi
git add private_dot_zshrc
git commit -m "feat(nono): add nono-codex and nono-codex-open shell functions"
```

---

### Task 5: Live smoke test

**Files:** none

**Interfaces:**
- Consumes: everything from Tasks 2 through 4.

This task must be run by the user in a normal terminal. Nested `nono run` fails inside an existing nono sandbox with `Failed to create session directory ... Operation not permitted`, so an agent running under nono cannot execute it.

- [ ] **Step 1: Start Codex hardened in a scratch project**

```bash
cd ~/workspace/<some-project>
nono-codex
```

Expected: nono banner shows `mode supervised (proxy, supervisor)` and the profile name `codex-hardened`, then Codex's TUI starts.

- [ ] **Step 1b: Confirm the env var actually reaches the sandboxed process**

```bash
nono run --profile codex-hardened -- sh -c 'echo $OPENAI_BASE_URL'
```

Expected: `http://127.0.0.1:8787/v1`.

This check exists because `nono profile show` does not render `environment.set_vars` in either text or JSON mode, for any profile. The profile file can be correct while the value never reaches the process, and nothing before this step would catch that. If the output is empty, the `environment.set_vars` block in `codex-base.jsonc` is not being applied and Codex is talking to OpenAI directly, bypassing Headroom.

- [ ] **Step 2: Confirm the model call path**

In Codex, run `/status`.

Expected: the configured model (`gpt-5.6-sol` per `~/.codex/config.toml`) and no auth error. An auth failure here means Headroom's OpenAI backend is not accepting the ChatGPT OAuth token, and the base URL decision needs revisiting.

- [ ] **Step 3: Confirm Headroom saw the traffic**

In a second terminal:

```bash
headroom doctor
```

Expected: the codex target reports recent traffic, or the proxy stats line advances after a Codex prompt.

- [ ] **Step 4: Confirm the sandbox boundary holds**

In Codex, ask it to read a file outside the grants, for example `~/Documents/`.

Expected: a permission denial that the nono pack's developer instructions recognise, not a successful read.

- [ ] **Step 5: Smoke test the open profile**

```bash
nono-codex-open
```

Expected: nono banner with no proxy line, Codex starts, filesystem grants unchanged.

- [ ] **Step 6: Clean up the baseline files**

```bash
rm -rf /tmp/nono-baseline /tmp/nono-after*.txt
```

---

## Notes for the implementer

- `nono profile validate <file>` checks JSON syntax and group references only. It does not validate `network_profile` names. A bad name surfaces at run time as `failed to resolve network_profile for sandbox state`. The name `codex` was confirmed valid by smoke test at plan time.
- `nono profile show` is the real test here. It renders the fully resolved chain, which is why the before/after diff in Task 2 Step 4 is the load-bearing verification.
- If Task 2 Step 4 shows a diff you cannot explain, the fastest recovery is `git checkout dot_config/nono/profiles/claude-code-base.jsonc && chezmoi apply -S "$PWD" ~/.config/nono` to restore the working Claude setup, then retry the extraction in smaller pieces.
