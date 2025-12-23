local wezterm = require 'wezterm'
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local config = wezterm.config_builder()

config.front_end = "WebGpu"
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 64
config.color_scheme = 'Tokyo Night'

tabline.setup({
  options = {
    icons_enabled = true,
    theme = 'Tokyo Night',
    tabs_enabled = true,
    theme_overrides = {
      resize_mode = {
        a = { fg = '#181825', bg = '#cba6f7' },
        b = { fg = '#cba6f7', bg = '#313244' },
        c = { fg = '#cdd6f4', bg = '#181825' },
      },
      tab = {
        active = { fg = '#89b4fa', bg = '#313244' },
        inactive = { fg = '#cdd6f4', bg = '#181825' },
        inactive_hover = { fg = '#f5c2e7', bg = '#313244' },
      }
    },
    section_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
    component_separators = {
      left = wezterm.nerdfonts.pl_left_soft_divider,
      right = wezterm.nerdfonts.pl_right_soft_divider,
    },
    tab_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
  },
  sections = {
    tabline_a = { 'mode' },
    tabline_b = { 'workspace' },
    tabline_c = { ' ' },
    tab_active = {
      'index',
      { 'parent', padding = 0 },
      '/',
      { 'cwd',    padding = { left = 0, right = 1 } },
      { 'zoomed', padding = 0 },
    },
    tab_inactive = { 'index', { 'process', padding = { left = 0, right = 1 } } },
    tabline_w = { 'workspace' },
    tabline_x = { 'hostname', 'ram', 'cpu' },
    tabline_y = { 'battery' },
    tabline_z = { 'domain' },
  },
  extensions = {},
})

config.font = wezterm.font({ family = 'IosevkaTerm Nerd Font' })
config.font_size = 14

config.window_background_opacity = 0.9
config.macos_window_background_blur = 30
config.window_decorations = "RESIZE"
config.window_frame = {
  font = wezterm.font({ family = 'Iosevka Nerd Font', weight = 'Bold' }),
  font_size = 13,
}

config.set_environment_variables = {
  PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
}

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

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

config.key_tables = {
  resize_mode = {
    resize_pane('DownArrow', 'Down'),
    resize_pane('UpArrow', 'Up'),
    resize_pane('LeftArrow', 'Left'),
    resize_pane('RightArrow', 'Right'),
  },
}

config.mouse_bindings = {
  {
    event = { Down = { streak = 3, button = 'Left' } },
    action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
  }
}

config.keys = {
  {
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
  },
  {
    key = 'UpArrow',
    mods = 'SHIFT',
    action = wezterm.action.ScrollToPrompt(-1)
  },
  {
    key = 'DownArrow',
    mods = 'SHIFT',
    action = wezterm.action.ScrollToPrompt(1)
  },
  {
    key = 'a',
    -- When we're in leader mode _and_ CTRL + A is pressed...
    -- Actually send CTRL + A key to the terminal
    mods = 'LEADER|CTRL',
    action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' },
  },
  {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.ActivateKeyTable {
      name = 'resize_mode',
      one_shot = false,
      timeout_milliseconds = 1000,
    }
  },
  {
    key = '"',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '%',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  move_pane('DownArrow', 'Down'),
  move_pane('UpArrow', 'Up'),
  move_pane('LeftArrow', 'Left'),
  move_pane('RightArrow', 'Right'),
  {
    key = ',',
    mods = 'SUPER',
    action = wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir,
      args = { 'code', wezterm.config_file },
    },
  },
  -- Sends ESC + b and ESC + f sequence, which is used
  -- for telling your shell to jump back/forward.
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bb',
  },
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bf',
  }
}

return config
