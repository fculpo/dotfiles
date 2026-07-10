#!/usr/bin/env bash
#
# nono-gui-host.sh - start the host-side browser for nono visual checks.
#
# Runs OUTSIDE the sandbox, on the host. Launches a headed Chrome with remote
# debugging so a sandboxed playwright-mcp can ATTACH to it over CDP.
#
# Architecture:
#   Claude (in nono) --stdio--> playwright-mcp (in nono, --cdp-endpoint)
#                                     |
#                                     +--CDP over localhost:9222--> Chrome (HOST)
#
# We use stdio + CDP because Claude Code's HTTP/SSE MCP client is broken
# (anthropics/claude-code#45368: 406 "must accept text/event-stream", then a
# bogus OAuth prompt). stdio avoids that bug; --cdp-endpoint keeps the browser
# on the host so no browser launches inside the sandbox.

set -euo pipefail

CDP_PORT="${CDP_PORT:-9222}"
CHROME_USER_DIR="${CHROME_USER_DIR:-${TMPDIR:-/tmp}/nono-cdp-profile}"
CHROME_BIN="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [ ! -x "$CHROME_BIN" ]; then
  echo "Chrome not found at: $CHROME_BIN (set CHROME_BIN)" >&2
  exit 1
fi

mkdir -p "$CHROME_USER_DIR"

echo "nono-gui-host: launching headed Chrome with CDP on 127.0.0.1:$CDP_PORT" >&2
"$CHROME_BIN" \
  --remote-debugging-port="$CDP_PORT" \
  --user-data-dir="$CHROME_USER_DIR" \
  --no-first-run --no-default-browser-check about:blank &
CHROME_PID=$!
trap 'kill "$CHROME_PID" 2>/dev/null || true' EXIT INT TERM

sleep 2
cat >&2 <<EOF

nono-gui-host: Chrome up (pid $CHROME_PID).

1. Add to your project .mcp.json (stdio + CDP attach; NOT type:http):

   "playwright": {
     "command": "npx",
     "args": ["-y", "@playwright/mcp@latest", "--cdp-endpoint=http://localhost:$CDP_PORT"]
   }

2. Run Claude under nono (open the CDP port; grant mise-node/npm for npx):

   nono run --allow-cwd --open-port $CDP_PORT \\
     --read ~/.local/share/mise --allow ~/.npm \\
     --profile claude-code -- claude

Leave this running; Ctrl-C stops Chrome.
EOF

wait "$CHROME_PID"
