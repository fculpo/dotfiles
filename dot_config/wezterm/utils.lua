local wezterm = require 'wezterm'

local M = {}

-- SSH detection: check if foreground process is ssh
-- Handles both Pane objects (method call) and pane info tables (property access)
function M.is_ssh(pane)
    if not pane then return false end
    local process
    if type(pane.get_foreground_process_name) == 'function' then
        -- Pane object (from update-status event)
        process = pane:get_foreground_process_name() or ''
    else
        -- Pane info table (from format-tab-title)
        process = pane.foreground_process_name or ''
    end
    return process:match('ssh$') ~= nil
end

-- Check if tab's active pane is in SSH
function M.is_ssh_tab(tab)
    local pane = tab.active_pane
    return M.is_ssh(pane)
end

local shells = {
    sh = true,
    bash = true,
    zsh = true,
    fish = true,
    dash = true,
    ash = true,
    ksh = true,
    csh = true,
    tcsh = true,
    nu = true,
    pwsh = true,
    elvish = true,
}

function M.is_shell(tab)
    local pane = tab.active_pane
    if not pane then return false end
    local process = pane.foreground_process_name:match('([^/\\]+)$') or ''
    return shells[process] == true
end

-- Get tab cwd with fish-style compression: ~/projects/myapp -> ~/p/myapp
function M.tab_cwd(tab)
    if not M.is_shell(tab) then return '' end
    local cwd = tab.active_pane and tab.active_pane.current_working_dir
    if not cwd then return '' end

    local path = (cwd.file_path or tostring(cwd):gsub('file://[^/]*', '')):gsub("/$", "")
    if path == wezterm.home_dir then return '~' end
    path = path:gsub("^" .. wezterm.home_dir, "~")

    -- Fish-style compression
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    if #parts <= 1 then return path end

    local compressed = {}
    for i, part in ipairs(parts) do
        if i == #parts then
            table.insert(compressed, part)
        elseif part == "~" then
            table.insert(compressed, part)
        elseif part:sub(1, 1) == "." then
            table.insert(compressed, part:sub(1, 2))
        else
            table.insert(compressed, part:sub(1, 1))
        end
    end
    return table.concat(compressed, "/")
end

-- Process display name aliases
-- Each entry: { path_match = "pattern", name_match = "pattern", display = "name" }
local process_aliases = {
    { path_match = 'claude', name_match = '^%d+%.%d+%.%d+$', display = 'claude' },
}

-- Format process name with aliases (for tabline fmt)
function M.fmt_process(str, tab)
    local pane = tab.active_pane
    if not pane then return str end

    local full_path = pane.foreground_process_name or ''

    for _, alias in ipairs(process_aliases) do
        if full_path:match(alias.path_match) and str:match(alias.name_match) then
            return alias.display
        end
    end
    return str
end

return M
