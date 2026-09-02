# Serena tool selection

Serena (MCP) provides symbol-aware code tools. They are deferred; load once with:

  ToolSearch("select:mcp__serena__find_symbol,mcp__serena__get_symbols_overview,mcp__serena__find_referencing_symbols,mcp__serena__find_declaration,mcp__serena__find_implementations,mcp__serena__replace_symbol_body,mcp__serena__rename_symbol,mcp__serena__replace_in_files")

Project activates from cwd. Call activate_project only if a tool reports no active project. Do not call initial_instructions.

For source files, prefer Serena:

- structure of a file: get_symbols_overview
- read or find a symbol: find_symbol (include_body=true to read)
- callers, declaration, implementations: find_referencing_symbols, find_declaration, find_implementations
- edit: replace_symbol_body, insert_before_symbol, insert_after_symbol, replace_content; many files: replace_in_files; rename: rename_symbol; delete: safe_delete_symbol
- errors: get_diagnostics_for_file

Before editing a symbol, read it with find_symbol first. Read only the symbols you need.

Built-in Read/Edit/Grep/Glob and Bash grep are fine for: non-code files (Markdown, JSON, YAML, TOML, config, logs), literal-string or comment searches, reading a few lines, whole-file reads, or when Serena failed on the target. In bypass-permissions mode the Bash-first guidance applies to those same cases; symbolic reads and edits of code still go through Serena.

Not available here (JetBrains-only): inline_symbol, type_hierarchy, move.
