-- Core WezTerm keybindings (no 3rd party plugin dependencies)
local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux

local M = {}

local function move_pane(key, direction)
  return {
    key = key,
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection(direction),
  }
end

local function resize_pane(key, direction)
  return {
    key = key,
    action = wezterm.action.AdjustPaneSize { direction, 3 }
  }
end

function M.apply_to_config(config)
  if config == nil then
    config = {}
  end

  if config.keys == nil then
    config.keys = {}
  end

  -- Key tables
  config.key_tables = {
    resize_mode = {},
  }
  table.insert(config.key_tables.resize_mode, resize_pane('DownArrow', 'Down'))
  table.insert(config.key_tables.resize_mode, resize_pane('UpArrow', 'Up'))
  table.insert(config.key_tables.resize_mode, resize_pane('LeftArrow', 'Left'))
  table.insert(config.key_tables.resize_mode, resize_pane('RightArrow', 'Right'))

  -- Mouse bindings
  if config.mouse_bindings == nil then
    config.mouse_bindings = {}
  end

  table.insert(config.mouse_bindings, {
    event = { Down = { streak = 3, button = 'Left' } },
    action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
  })

  table.insert(config.mouse_bindings, {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  })

  table.insert(config.mouse_bindings, {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.OpenLinkAtMouseCursor,
  })

  table.insert(config.mouse_bindings, {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.Nop,
  })

  -- Show tab navigator = LEADER+w
  table.insert(config.keys, {
    key = 'w',
    mods = 'LEADER',
    action = act.ShowTabNavigator,
  })

  -- Close tab = LEADER+&
  table.insert(config.keys, {
    key = '&',
    mods = 'LEADER|SHIFT',
    action = act.CloseCurrentTab { confirm = true },
  })

  -- Copy mode = LEADER+[
  table.insert(config.keys, {
    key = '[',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode,
  })

  -- Previous tab = SUPER+LeftArrow
  table.insert(config.keys, { key = 'LeftArrow', mods = 'SUPER', action = wezterm.action.ActivateTabRelative(-1) })

  -- Next tab = SUPER+RightArrow
  table.insert(config.keys, { key = 'RightArrow', mods = 'SUPER', action = wezterm.action.ActivateTabRelative(1) })

  -- Break line = SHIFT+Enter
  table.insert(config.keys, { key = "Enter", mods = "SHIFT", action = wezterm.action { SendString = "\x1b\r" } })

  -- Split right = LEADER+|
  table.insert(config.keys, {
    key = '|',
    mods = 'LEADER|SHIFT',
    action = act.SplitPane {
      direction = 'Right',
      size = { Percent = 50 },
    },
  })

  -- Split down = LEADER+-
  table.insert(config.keys, {
    key = '-',
    mods = 'LEADER',
    action = act.SplitPane {
      direction = 'Down',
      size = { Percent = 50 },
    },
  })

  -- Swap Panes = LEADER+{
  table.insert(config.keys, {
    key = '{',
    mods = 'LEADER|SHIFT',
    action = act.PaneSelect { mode = 'SwapWithActiveKeepFocus' }
  })

  -- Previous pane = LEADER+;
  table.insert(config.keys, {
    key = ';',
    mods = 'LEADER',
    action = act.ActivatePaneDirection('Prev'),
  })

  -- Next pane = LEADER+o
  table.insert(config.keys, {
    key = 'o',
    mods = 'LEADER',
    action = act.ActivatePaneDirection('Next'),
  })

  -- Attach UNIX domain = LEADER+SHIFT+a
  table.insert(config.keys, {
    key = 'a',
    mods = 'LEADER|SHIFT',
    action = act.AttachDomain 'unix',
  })

  -- Detach domain = LEADER+d
  table.insert(config.keys, {
    key = 'd',
    mods = 'LEADER',
    action = act.DetachDomain { DomainName = 'unix' },
  })

  -- Rename workspace = LEADER+$
  table.insert(config.keys, {
    key = '$',
    mods = 'LEADER|SHIFT',
    action = act.PromptInputLine {
      description = 'Enter new name for session',
      action = wezterm.action_callback(
        function(window, _, line)
          if line then
            mux.rename_workspace(
              window:mux_window():get_workspace(),
              line
            )
          end
        end
      ),
    },
  })

  -- Rename current tab = LEADER+t
  table.insert(config.keys, {
    key = 't',
    mods = 'LEADER',
    action = wezterm.action.PromptInputLine {
      description = 'Enter new name for tab',
      action = wezterm.action_callback(
        function(window, _, line)
          if line then
            window:active_tab():set_title(line)
          end
        end
      ),
    },
  })

  -- Jump to previous command = SHIFT+up
  table.insert(config.keys, {
    key = 'UpArrow',
    mods = 'SHIFT',
    action = wezterm.action.ScrollToPrompt(-1)
  })

  -- Jump to next command = SHIFT+down
  table.insert(config.keys, {
    key = 'DownArrow',
    mods = 'SHIFT',
    action = wezterm.action.ScrollToPrompt(1)
  })

  -- Send actual CTRL+a = LEADER+CTRL+a
  table.insert(config.keys, {
    key = 'a',
    mods = 'LEADER|CTRL',
    action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' },
  })

  -- Enable resize mode = LEADER+r
  table.insert(config.keys, {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.ActivateKeyTable {
      name = 'resize_mode',
      one_shot = false,
      timeout_milliseconds = 1000,
    }
  })

  -- Zoom pane = LEADER+z
  table.insert(config.keys, {
    key = 'z',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
  })

  -- Zoom pane = ALT+f
  table.insert(config.keys, {
    key = 'f',
    mods = 'ALT',
    action = act.TogglePaneZoomState,
  })

  -- Move pane bindings
  table.insert(config.keys, move_pane('DownArrow', 'Down'))
  table.insert(config.keys, move_pane('UpArrow', 'Up'))
  table.insert(config.keys, move_pane('LeftArrow', 'Left'))
  table.insert(config.keys, move_pane('RightArrow', 'Right'))

  -- Edit config file = SUPER+,
  table.insert(config.keys, {
    key = ',',
    mods = 'SUPER',
    action = wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir,
      args = { 'code', wezterm.config_file },
    },
  })

  -- Jump word backward = OPT+LeftArrow
  table.insert(config.keys, {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bb',
  })

  -- Jump word forward = OPT+RightArrow
  table.insert(config.keys, {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bf',
  })
end

return M
