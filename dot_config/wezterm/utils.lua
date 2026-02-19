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
    { path_match = 'claude', name_match = '^%d+%.%d+%.%d+$', display = 'claude', use_title = true },
}

-- Format process name with aliases (for tabline fmt)
function M.fmt_process(str, tab)
    local pane = tab.active_pane
    if not pane then return str end

    -- Show container name for Docker domains
    local domain = pane.domain_name or ''
    if domain:match('^docker:') then
        return domain:gsub('^docker:', '')
    end

    local full_path = pane.foreground_process_name or ''

    for _, alias in ipairs(process_aliases) do
        if full_path:match(alias.path_match) and str:match(alias.name_match) then
            if alias.use_title then
                local title = (pane.title or ''):match('%S') and pane.title
                if title then return title end
            end
            return alias.display
        end
    end
    return str
end

-- Hostname: show container name for Docker domains, otherwise system hostname
function M.hostname(window, pane)
    if not pane then return wezterm.hostname() end
    local domain = pane:get_domain_name()
    if domain and domain:match('^docker:') then
        return domain:gsub('^docker:', '')
    end
    return wezterm.hostname()
end

-- Find docker in PATH (including homebrew)
local function find_in_path(cmd)
    local path = wezterm.home_dir .. '/.local/bin:/opt/homebrew/bin:' .. (os.getenv('PATH') or '')
    for dir in path:gmatch('[^:]+') do
        local full = dir .. '/' .. cmd
        local f = io.open(full)
        if f then f:close(); return full end
    end
    return cmd
end

local docker = find_in_path('docker')

-- Docker exec domain auto-discovery
local function docker_list()
    local containers = {}
    local success, stdout = wezterm.run_child_process({
        docker, 'container', 'ls', '--format', '{{.ID}}:{{.Names}}',
    })
    if success then
        for _, line in ipairs(wezterm.split_by_newlines(stdout)) do
            local id, name = line:match('(.-):(.+)')
            if id and name then
                containers[id] = name
            end
        end
    end
    return containers
end

local function make_docker_label_func(id)
    return function(name)
        local success, stdout = wezterm.run_child_process({
            docker, 'inspect', '--format', '{{.State.Running}}', id,
        })
        local running = stdout == 'true\n'
        local color = running and 'Green' or 'Red'
        return wezterm.format({
            { Foreground = { AnsiColor = color } },
            { Text = 'docker: ' .. name },
        })
    end
end

local function make_docker_fixup_func(id)
    return function(cmd)
        cmd.args = cmd.args or { '/bin/zsh' }
        local wrapped = { docker, 'exec', '-it', id }
        for _, arg in ipairs(cmd.args) do
            table.insert(wrapped, arg)
        end
        cmd.args = wrapped
        return cmd
    end
end

function M.compute_docker_domains()
    local exec_domains = {}
    for id, name in pairs(docker_list()) do
        table.insert(exec_domains,
            wezterm.exec_domain('docker:' .. name,
                make_docker_fixup_func(id),
                make_docker_label_func(id)
            )
        )
    end
    return exec_domains
end

-- Sandbox exec domain for Claude Code
local claude_sandbox = find_in_path('claude-sandbox')

local function make_sandbox_fixup_func()
    return function(cmd)
        local cwd = cmd.cwd or wezterm.home_dir
        cmd.args = { claude_sandbox, '--project-dir', cwd }
        return cmd
    end
end

local function make_sandbox_label_func()
    return function(_name)
        return wezterm.format({
            { Foreground = { AnsiColor = 'Yellow' } },
            { Text = wezterm.nerdfonts.md_lock .. ' sandbox:claude' },
        })
    end
end

function M.compute_sandbox_domains()
    return {
        wezterm.exec_domain('sandbox:claude',
            make_sandbox_fixup_func(),
            make_sandbox_label_func()
        ),
    }
end

return M
