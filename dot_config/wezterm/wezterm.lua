local wezterm = require 'wezterm'
local appearance = require 'appearance'
local docker_domains = require 'docker_domains'

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

local config = wezterm.config_builder()

config.front_end = "WebGpu"

-- When set to true (the default), the tab bar is rendered in a native style with proportional fonts.
-- When set to false, the tab bar is rendered using a retro aesthetic using the main terminal font.
config.use_fancy_tab_bar = false

config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 64

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

if appearance.is_dark() then
  config.color_scheme = 'Tokyo Night'
else
  config.color_scheme = 'Tokyo Night Day'
end

-- Choose your favourite font, make sure it's installed on your machine
config.font = wezterm.font({ family = 'Zenbones Brainy' })
-- And a font size that won't have you squinting
config.font_size = 14

-- Slightly transparent and blurred background
config.window_background_opacity = 0.9
config.macos_window_background_blur = 30
config.window_decorations = "RESIZE"
-- Sets the font for the window frame (tab bar)
config.window_frame = {
  -- An idea could be to try a serif font here instead of
  -- monospace for a nicer look
  font = wezterm.font({ family = 'Zenbones Brainy', weight = 'Bold' }),
  font_size = 13,
}

local function segments_for_right_status(window)
  return {
    window:active_workspace(),
    wezterm.strftime('%a %b %-d %H:%M'),
    wezterm.hostname(),
  }
end

-- wezterm.on('update-status', function(window, _)
--   local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
--   local segments = segments_for_right_status(window)

--   local color_scheme = window:effective_config().resolved_palette
--   -- Note the use of wezterm.color.parse here, this returns
--   -- a Color object, which comes with functionality for lightening
--   -- or darkening the colour (amongst other things).
--   local bg = wezterm.color.parse(color_scheme.background)
--   local fg = color_scheme.foreground

--   -- Each powerline segment is going to be coloured progressively
--   -- darker/lighter depending on whether we're on a dark/light colour
--   -- scheme. Let's establish the "from" and "to" bounds of our gradient.
--   local gradient_to, gradient_from = bg, nil
--   if appearance.is_dark() then
--     gradient_from = gradient_to:lighten(0.2)
--   else
--     gradient_from = gradient_to:darken(0.2)
--   end

--   -- Yes, WezTerm supports creating gradients, because why not?! Although
--   -- they'd usually be used for setting high fidelity gradients on your terminal's
--   -- background, we'll use them here to give us a sample of the powerline segment
--   -- colours we need.
--   local gradient = wezterm.color.gradient(
--     {
--       orientation = 'Horizontal',
--       colors = { gradient_from, gradient_to },
--     },
--     #segments -- only gives us as many colours as we have segments.
--   )

--   -- We'll build up the elements to send to wezterm.format in this table.
--   local elements = {}

--   for i, seg in ipairs(segments) do
--     local is_first = i == 1

--     if is_first then
--       table.insert(elements, { Background = { Color = 'none' } })
--     end
--     table.insert(elements, { Foreground = { Color = gradient[i] } })
--     table.insert(elements, { Text = SOLID_LEFT_ARROW })

--     table.insert(elements, { Foreground = { Color = fg } })
--     table.insert(elements, { Background = { Color = gradient[i] } })
--     table.insert(elements, { Text = ' ' .. seg .. ' ' })
--   end

--   window:set_right_status(wezterm.format(elements))
-- end)

config.set_environment_variables = {
  PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
}

-- Docker container ExecDomains for seamless container access
config.exec_domains = docker_domains.compute_exec_domains()
config.launch_menu = docker_domains.get_launcher_items()

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
        function(window, pane, line)
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
    mods = 'LEADER|CTRL',
    -- Actually send CTRL + A key to the terminal
    action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' },
  },
  {
    -- When we push LEADER + R...
    key = 'r',
    mods = 'LEADER',
    -- Activate the `resize_mode` keytable
    action = wezterm.action.ActivateKeyTable {
      name = 'resize_mode',
      -- Ensures the keytable stays active after it handles its
      -- first keypress.
      one_shot = false,
      -- Deactivate the keytable after a timeout.
      timeout_milliseconds = 1000,
    }
  },
  {
    -- I'm used to tmux bindings, so am using the quotes (") key to
    -- split horizontally, and the percent (%) key to split vertically.
    key = '"',
    -- Note that instead of a key modifier mapped to a key on your keyboard
    -- like CTRL or ALT, we can use the LEADER modifier instead.
    -- This means that this binding will be invoked when you press the leader
    -- (CTRL + A), quickly followed by quotes (").
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
    -- When the left arrow is pressed
    key = 'LeftArrow',
    -- With the "Option" key modifier held down
    mods = 'OPT',
    -- Perform this action, in this case - sending ESC + B
    -- to the terminal
    action = wezterm.action.SendString '\x1bb',
  },
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bf',
  },
  -- Docker domain shortcuts
  {
    key = 'l',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs({ flags = "DOMAINS|LAUNCH_MENU_ITEMS" }),
  },
  {
    key = 'd',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs({ flags = "DOMAINS" }),
  },
}

wezterm.on("format-tab-title", function(tab)
  local vars = tab.active_pane:get_user_vars()

  -- If the remote shell set a custom title, use it
  if vars.TabTitle then
    return "🔐 " .. vars.TabTitle
  end

  -- Otherwise fallback to default title behavior
  return tab.active_pane.title
end)


-- config.switch_to_last_active_tab_when_closing_tab = true
-- config.colors = {
--   tab_bar = {
--     active_tab = {
--       fg_color = '#073642',
--       bg_color = '#2aa198'
--     }
--   }
-- }

-- config.unix_domains = {
--   {
--     name = 'unix',
--   },
-- }

-- Returns our config to be evaluated. We must always do this at the bottom of this file
return config
