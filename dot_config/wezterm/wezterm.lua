local wezterm = require 'wezterm'
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local config = wezterm.config_builder()

config.front_end = "WebGpu"
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 50

config.font = wezterm.font({ family = 'IosevkaTerm Nerd Font' })
config.font_size = 14

config.color_scheme = 'Catppuccin Mocha'
config.status_update_interval = 500

config.window_background_opacity = 0.9
config.macos_window_background_blur = 30
config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"

local shells = { zsh = true, bash = true, fish = true, sh = true, dash = true, nu = true, pwsh = true }

local function is_shell(tab)
  local process = tab.active_pane and tab.active_pane.foreground_process_name or ''
  process = process:match('([^/\\]+)$') or process
  return shells[process] ~= nil
end

local function tab_cwd(tab)
  if not is_shell(tab) then return '' end
  local cwd = tab.active_pane and tab.active_pane.current_working_dir
  if cwd then
    local path = (cwd.file_path or tostring(cwd):gsub('file://[^/]*', '')):gsub("/$", "")
    if path == wezterm.home_dir then return '~' end
    -- TODO: fish compression
    return path:gsub("^" .. wezterm.home_dir .. "/", "")
  end
end

tabline.setup({
  options = {
    icons_enabled = true,
    theme = 'Catppuccin Mocha',
    tabs_enabled = true,
    theme_overrides = {
      resize_mode = {
        a = { fg = '#181825', bg = '#cba6f7' },
        b = { fg = '#cba6f7', bg = '#313244' },
        c = { fg = '#cdd6f4', bg = '#181825' },
      },
      tab = {
        active = { fg = '#000000', bg = '#77A3F8' },
        -- inactive = { fg = '#ffffff', bg = '#000000' },
        -- inactive_hover = { fg = '#f5c2e7', bg = '#313244' },
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
      right = '',
    },
  },
  sections = {
    tabline_a = { 'mode' },
    tabline_b = { 'workspace' },
    tabline_c = { ' ' },
    tab_active = {
      wezterm.nerdfonts.pl_left_hard_divider .. ' ' .. wezterm.nerdfonts.fa_hashtag,
      { 'index', padding = { left = 1, right = 0 } },
      {
        'tab',
        icon = wezterm.nerdfonts.cod_bookmark,
        cond = function(tab) return tab.tab_title ~= '' end,
        padding = { left = 1, right = 0 }
      },
      {
        'process',
        icons_only = true,
        cond = function(tab) return is_shell(tab) end
      },
      {
        'process',
        icons_only = false,
        cond = function(tab) return not is_shell(tab) end
      },
      {
        "zoomed",
        icon = wezterm.nerdfonts.oct_zoom_in,
        padding = { left = 0, right = 0 },
      },
    },
    tab_inactive = {
      ' ' .. wezterm.nerdfonts.fa_hashtag,
      {
        'index',
        padding = { left = 1, right = 0 }
      },
      {
        'tab',
        icon = wezterm.nerdfonts.fa_bookmark,
        cond = function(tab) return tab.tab_title ~= '' end,
        padding = { left = 1, right = 0 },
      },
      {
        'process',
        icons_only = true,
        cond = function(tab) return is_shell(tab) end,
        padding = { left = 1, right = 0 }
      },
      {
        'process',
        icons_only = false,
        cond = function(tab) return not is_shell(tab) end,
        padding = { left = 1, right = 0 }

      },
      tab_cwd,
      { 'output', icon_no_output = '',                  padding = { left = 1, right = 0 } },
      { 'zoomed', icon = wezterm.nerdfonts.oct_zoom_in, padding = 0 },
    },
    tabline_w = { 'workspace' },
    tabline_x = { 'hostname', 'ram', 'cpu' },
    tabline_y = { 'battery' },
    tabline_z = {
      'domain',
      domain_to_icon = {
        default = wezterm.nerdfonts.md_monitor,
        ssh = wezterm.nerdfonts.md_ssh,
        wsl = wezterm.nerdfonts.md_microsoft_windows,
        docker = wezterm.nerdfonts.md_docker,
        unix = wezterm.nerdfonts.cod_terminal_linux,
      },
    },
  },
  extensions = { 'resurrect', 'smart_workspace_switcher', 'quick_domains' },
})


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
  },
  -- Override default click to only select text, not open links
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- CMD+click to open hyperlinks
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  -- Disable the Down event to avoid conflicts
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.Nop,
  },
}

config.keys = {
  { key = 'LeftArrow',  mods = 'SUPER', action = wezterm.action.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'SUPER', action = wezterm.action.ActivateTabRelative(1) },
  { key = "Enter",      mods = "SHIFT", action = wezterm.action { SendString = "\x1b\r" } },
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
    key = 'z',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
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
