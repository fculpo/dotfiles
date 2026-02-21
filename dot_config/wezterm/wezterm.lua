local wezterm            = require 'wezterm'
local config             = wezterm.config_builder()
local keybindings        = require("keybindings")
local utils              = require("utils")
local resurrect          = require("resurrect")

local tabline            = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")


-- config.default_gui_startup_args                   = { 'connect', 'unix' }
config.color_scheme                               = 'Catppuccin Mocha'
config.default_workspace                          = "~"
config.font                                       = wezterm.font_with_fallback({
                                                       'IosevkaTerm Nerd Font',
                                                       'Symbols Nerd Font Mono',
                                                       'Noto Sans Bamum',
                                                     })
config.font_size                                  = 14
config.front_end                                  = "WebGpu"
config.leader                                     = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.macos_window_background_blur               = 30
config.pane_focus_follows_mouse                   = true
config.scrollback_lines                           = 100000
config.set_environment_variables                  = { PATH = wezterm.home_dir .. '/.local/bin:/opt/homebrew/bin:' .. os.getenv('PATH') }
config.show_new_tab_button_in_tab_bar             = false
config.status_update_interval                     = 500
config.switch_to_last_active_tab_when_closing_tab = true
config.tab_bar_at_bottom                          = false
config.use_fancy_tab_bar                          = false
config.window_background_opacity                  = 0.95
config.inactive_pane_hsb                          = { saturation = 0.7, brightness = 0.75 }

wezterm.on('gui-startup', function(cmd)
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)
local exec_domains = utils.compute_docker_domains()
for _, domain in ipairs(utils.compute_sandbox_domains()) do
    table.insert(exec_domains, domain)
end
config.exec_domains                               = exec_domains
config.unix_domains                               = { { name = 'unix' } }

-- Remote detection: change pane background via OSC 11 escape sequence
-- This avoids set_config_overrides which triggers false output detection
local pane_bg_state = {}
local DEFAULT_BG  = '#1e1e2e'  -- Catppuccin Mocha base
local SSH_BG      = '#3d1a1a'  -- subtle red tint
local DOCKER_BG   = '#1e1e38'  -- subtle blue tint
local SANDBOX_BG  = '#2e2418'  -- subtle orange tint

wezterm.on('update-status', function(_, pane)
  local pane_id = tostring(pane:pane_id())
  local domain = pane:get_domain_name() or ''
  local is_docker = domain:match('^docker:') ~= nil
  local is_ssh = utils.is_ssh(pane)
  local is_sandbox = (pane:get_user_vars() or {}).sandbox == '1'

  local bg = (is_sandbox and SANDBOX_BG) or (is_docker and DOCKER_BG) or (is_ssh and SSH_BG) or DEFAULT_BG

  if pane_bg_state[pane_id] ~= bg then
    pane_bg_state[pane_id] = bg
    pane:inject_output('\x1b]11;' .. bg .. '\x1b\\')
  end
end)

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
        cond = function(tab) return utils.is_shell(tab) end,
        fmt = utils.fmt_process,
      },
      {
        'process',
        icons_only = false,
        cond = function(tab) return not utils.is_shell(tab) end,
        fmt = utils.fmt_process,
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
        cond = function(tab) return utils.is_shell(tab) end,
        padding = { left = 1, right = 0 },
        fmt = utils.fmt_process,
      },
      {
        'process',
        icons_only = false,
        cond = function(tab) return not utils.is_shell(tab) end,
        padding = { left = 1, right = 0 },
        fmt = utils.fmt_process,
      },
      utils.tab_cwd,
      { 'output', icon_no_output = '',                  padding = { left = 1, right = 0 } },
      { 'zoomed', icon = wezterm.nerdfonts.oct_zoom_in, padding = 0 },
    },
    tabline_w = { 'workspace' },
    tabline_x = { utils.hostname, 'ram', 'cpu' },
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
  extensions = { 'resurrect', 'smart_workspace_switcher' },
})

tabline.apply_to_config(config)
config.tab_max_width = 128
config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"

keybindings.apply_to_config(config)

workspace_switcher.apply_to_config(config)
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

resurrect.apply_to_config(config)

return config
