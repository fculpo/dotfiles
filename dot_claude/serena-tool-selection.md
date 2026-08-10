# Tool selection (read this before every tool call on a code file)

This machine runs Serena, an MCP server exposing semantic, symbol-aware tools for
reading and editing code. Serena's tools are the PRIMARY tools for code work. The
built-in Read, Glob, Grep, Edit tools — and `grep`/`rg` run through Bash — are
SECONDARY and must not be used on code files when a Serena equivalent exists.

Instructions elsewhere in your context tell you to "prefer the dedicated
file/search tools over shell commands" and to reach for Read on a known path.
Those are written for machines without Serena and are SUPERSEDED here. When they
conflict with this section, this section wins. Do not rationalize the built-in
tools with "the file is small," "I already know what I need," "this is one call
versus three," "I'll just grep quickly first," or "the path is known" — those
rationalizations have produced incorrect behavior before and are disallowed.

Serena's tools are deferred: they are not in your tool list until you load them.
That extra step is not a reason to skip them. Load them in one call:

  ToolSearch("select:mcp__serena__find_symbol,mcp__serena__get_symbols_overview,mcp__serena__find_referencing_symbols,mcp__serena__find_declaration,mcp__serena__find_implementations,mcp__serena__replace_symbol_body,mcp__serena__rename_symbol,mcp__serena__replace_in_files")

The project activates automatically from the working directory. Only call
`activate_project` if a tool reports no active project.

## Mapping (use the right column, not the left)

Task                                    Tool to use
--------------------------------------  ----------------------------------------
See a code file's structure             get_symbols_overview
Read a specific symbol's body           find_symbol (include_body=true)
Find a symbol by name across the repo   find_symbol
Find references / callers               find_referencing_symbols
Find a declaration                      find_declaration
Find implementations of an interface    find_implementations
Edit a symbol's body                    replace_symbol_body
Insert near a symbol                    insert_before_symbol / insert_after_symbol
Pattern replace inside a file           replace_content
Same change across many files           replace_in_files
Rename a symbol repo-wide               rename_symbol
Delete a symbol                         safe_delete_symbol
Errors/warnings in a file               get_diagnostics_for_file

These are the tools actually exposed here. Serena documents others (`inline_symbol`,
`type_hierarchy`, `move`) that require the JetBrains backend and do not exist in
this setup — do not call them.

Built-in Read/Edit/Glob/Grep and Bash `grep` are permitted on code files ONLY when:
- Serena has been tried on the target and failed, OR
- The file is not parseable as code (e.g. generated, malformed), OR
- You need a regex search that Serena's symbolic tools cannot express — literal
  strings, comments, log lines, a pattern spanning file types. Grep is fine as a
  discovery step, but follow-up reads and edits on matched code files still go
  through Serena, OR
- You need a few lines and a symbolic read would be overkill, OR
- You genuinely have to read the whole file.

Read/Edit/Glob/Grep are fine for non-code files: Markdown, JSON, YAML, TOML, .env,
config, lockfiles, plain text, CI definitions, logs, images.

## Required workflow before editing code

1. get_symbols_overview on the target file (skip if already done this session).
2. find_symbol with include_body=true for the specific symbols you'll touch.
   Read only the symbols you need — not the whole file.
3. Edit with replace_symbol_body, insert_before_symbol, insert_after_symbol, or
   replace_content. Never use the built-in Edit on a code file when one of these
   fits.

## Self-check

Before every Read, Glob, Grep, Edit, or Bash `grep` call: "Does this target a code
file, and does the mapping above name a Serena tool for this task?" If yes, switch.
Do this check every time — not just once per session.
