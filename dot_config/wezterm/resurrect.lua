local wezterm = require 'wezterm'
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

local M = {}

function M.apply_to_config(config)
    if config == nil then
        config = {}
    end

    if config.keys == nil then
        config.keys = {}
    end

    -- Resurrect plugin keybindings (ALT+w/W/T/s/r)
    table.insert(config.keys, {
        key = "w",
        mods = "ALT",
        action = wezterm.action_callback(function(_, _)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        end),
    })

    table.insert(config.keys, {
        key = "W",
        mods = "ALT",
        action = resurrect.window_state.save_window_action(),
    })

    table.insert(config.keys, {
        key = "T",
        mods = "ALT",
        action = resurrect.tab_state.save_tab_action(),
    })

    table.insert(config.keys, {
        key = "s",
        mods = "ALT",
        action = wezterm.action_callback(function(_, _)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.window_state.save_window_action()
        end),
    })

    -- Loading workspace or window state via. fuzzy finder
    table.insert(config.keys, {
        key = "r",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, _)
                local type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$")         -- match after '/'
                id = string.match(id, "(.+)%..+$")        -- remove file extension
                local opts = {
                    relative = true,
                    restore_text = true,
                    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end),
    })
end

-- Restores workspace state
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
    local workspace_state = resurrect.workspace_state

    workspace_state.restore_workspace(resurrect.state_manager.load_state(label, "workspace"), {
        window = window,
        relative = true,
        restore_text = true,
        on_pane_restore = resurrect.tab_state.default_on_pane_restore,
    })
end)

-- Saves the state whenever I select a workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
    local workspace_state = resurrect.workspace_state
    resurrect.state_manager.save_state(workspace_state.get_workspace_state())
end)

return M
