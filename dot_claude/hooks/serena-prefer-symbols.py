#!/usr/bin/env python3
"""PreToolUse(Bash) hook: nudge code searches toward Serena's symbolic tools.

Serena ships its own `serena-hooks remind`, but it only counts the Grep/Read
tools and needs 3 consecutive uses to fire. Claude overwhelmingly greps via
Bash, which that hook treats as neutral, so a single well-aimed `grep` for a
code identifier never trips it.

This blocks the first such command per session (exit 2, message goes to the
model) and lets the retry through, so text searches over configs and logs stay
one keystroke away.
"""

import json
import os
import re
import shlex
import sys
import tempfile

SEARCHERS = {"grep", "egrep", "fgrep", "rg", "ag", "ack"}
# these walk a tree without being asked to
RECURSIVE_BY_DEFAULT = {"rg", "ag", "ack"}
RECURSIVE = {"-r", "-R", "-rn", "-rln", "-rnI", "-nr", "--recursive"}
# an identifier worth resolving with a language server, not a literal phrase
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{2,}$")
CODE_EXT = (
    ".py", ".ts", ".tsx", ".js", ".jsx", ".vue", ".java", ".go", ".rs",
    ".rb", ".php", ".kt", ".cs", ".scala", ".swift", ".c", ".h", ".cpp",
)

MESSAGE = """Blocked once: this looks like a search for the code symbol {sym!r}.

Serena resolves symbols through the language server instead of matching text.
Load its tools in one call, then use them:

  ToolSearch("select:mcp__serena__find_symbol,mcp__serena__get_symbols_overview,mcp__serena__find_referencing_symbols")

  where is it defined   -> find_symbol
  what references it    -> find_referencing_symbols
  what is in this file  -> get_symbols_overview

The project activates automatically from the working directory.

If you are searching text rather than code (YAML, Markdown, logs, a literal
string), run the exact same command again and it will go through."""


def search_pattern(command):
    """:return: (pattern, searcher) of the first search command, or (None, None).

    A searcher fed by a pipe is filtering a stream its predecessor produced —
    a file list from `find`, log lines, another search's output. Serena has no
    equivalent for that, so those are left alone.
    """
    try:
        tokens = shlex.split(command)
    except ValueError:
        return None, None
    for i, token in enumerate(tokens):
        searcher = os.path.basename(token)
        if searcher not in SEARCHERS:
            continue
        if "|" in tokens[:i]:
            return None, None
        for arg in tokens[i + 1:]:
            if arg.startswith("-"):
                continue
            return arg, searcher
        return None, None
    return None, None


def symbol_searched(command):
    """:return: the identifier this command hunts through code, else None."""
    pattern, searcher = search_pattern(command)
    if not pattern or not IDENTIFIER.match(pattern):
        return None
    # a bare identifier searched over a tree or over source files
    recursive = searcher in RECURSIVE_BY_DEFAULT or any(
        t in RECURSIVE for t in command.split()
    )
    targets_code = any(p.endswith(CODE_EXT) for p in re.findall(r"[\w./*-]+", command))
    return pattern if recursive or targets_code else None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    pattern = symbol_searched((payload.get("tool_input") or {}).get("command", ""))
    if not pattern:
        return 0

    cwd = payload.get("cwd") or os.getcwd()
    if not os.path.exists(os.path.join(cwd, ".serena", "project.yml")):
        return 0

    session = payload.get("session_id") or "none"
    marker = os.path.join(tempfile.gettempdir(), f"serena-nudge-{session}")
    if os.path.exists(marker):
        return 0
    open(marker, "w").close()

    print(MESSAGE.format(sym=pattern), file=sys.stderr)
    return 2


def self_test() -> None:
    """`python3 serena-prefer-symbols.py --self-test` — checks what gets nudged."""
    nudge = [
        'grep -rn "poll_for_token" --include=*.py .',
        "rg TokenSet src/",
        "grep -R DeviceFlowStart packages/",
        # a pipe downstream of the search does not excuse it
        "grep -rn poll_for_token --include=*.py . | head -50",
    ]
    allow = [
        "grep -rn image: k8s/values.yaml",       # not an identifier
        "grep -c serena history.jsonl",          # single non-code file
        'grep -n "def poll" oauth.py',           # phrase, not recursive
        "cat app.log | grep ERROR",              # log stream
        "ls -la",                                # not a search
        # filtering a file list out of find, not searching code
        "ls /repo; find /repo -name '*.py' -print | grep -i -E 'cli' | head -40",
    ]
    for command in nudge + allow:
        assert bool(symbol_searched(command)) is (command in nudge), command
    print(f"ok: {len(nudge)} nudged, {len(allow)} passed through")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        sys.exit(main())
