#!/usr/bin/env bash

# zsh-patina ships as a Rust source repo (external ".zsh-patina"); .zshrc evals
# the release binary, so it has to be built here. `after` so the external is
# already cloned/pulled. Rebuilds only when the checked-out commit changed.

set -eu

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

repo="$HOME/.zsh-patina"
bin="$repo/target/release/zsh-patina"
stamp="$repo/.build-rev"

[ -d "$repo/.git" ] || exit 0

rev="$(git -C "$repo" rev-parse HEAD)"
if [ -x "$bin" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$rev" ]; then
    exit 0
fi

cargo build --release --manifest-path "$repo/Cargo.toml"
printf '%s\n' "$rev" >"$stamp"
