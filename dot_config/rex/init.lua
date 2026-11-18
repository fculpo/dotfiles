-- Migrated from Ghostty and zellij.
-- cmd+k stays on Rex's session picker (your decision).

---------------------------------------------------------------------------
-- Ghostty (~/.config/ghostty/config)
---------------------------------------------------------------------------
rex.bind("cmd+c", "pane.copy")
rex.bind("cmd+v", "pane.paste")
rex.bind("shift+cmd+,", "client.config.reload")

---------------------------------------------------------------------------
-- zellij (~/.config/zellij/config.kdl, clear-defaults=true)
---------------------------------------------------------------------------
rex.action{
  name  = "then_normal",
  title = "Run an action and return to normal mode",
  args  = { action = "string", args = "object?" },
  run   = function(ctx, args)
    rex.client.queue(args.action, args.args or {})
    rex.client.queue("client.mode.exit_all")
  end,
}

-- zellij modes the user stays in; scroll, search, session, locked and the
-- rename/entersearch modes have no Rex counterpart.
local zmodes = { "pane", "tab", "resize", "move", "tmux" }
for _, m in ipairs(zmodes) do rex.mode(m, { exclusive = true }) end

-- normal mode
rex.bind("cmd+left", "client.tab.previous")
rex.bind("cmd+right", "client.tab.next")
rex.bind("shift+left", "client.tab.previous")
rex.bind("shift+right", "client.tab.next")

-- shared_except "locked": normal mode and every zellij mode
local shared = {
  { "cmd+n", "pane.split", { direction = "auto" } },
  { "cmd+i", "client.tab.move", { direction = "backward" } },
  { "cmd+o", "client.tab.move", { direction = "forward" } },
  { "alt+h", "pane.focus", { direction = "left" } },
  { "alt+l", "pane.focus", { direction = "right" } },
  { "cmd+up", "pane.focus", { direction = "up" } },
  { "alt+up", "pane.focus", { direction = "up" } },
  { "cmd+down", "pane.focus", { direction = "down" } },
  { "alt+down", "pane.focus", { direction = "down" } },
  { "cmd+j", "pane.focus", { direction = "down" } },
  { "cmd+[", "client.tab.previous" },
  { "cmd+]", "client.tab.next" },
}
for _, b in ipairs(shared) do
  rex.bind(b[1], b[2], b[3])
  for _, m in ipairs(zmodes) do rex.bind(m .. "/" .. b[1], b[2], b[3]) end
end
-- Super t: plain cmd+t is already Rex's New Tab; inside a mode it also returns to normal
for _, m in ipairs(zmodes) do
  rex.bind(m .. "/cmd+t", "then_normal", { action = "client.tab.new" })
end

-- mode switches (shared_except "locked" "<mode>"), and enter/esc back to normal
local enter = { ["ctrl+p"] = "pane", ["ctrl+t"] = "tab", ["ctrl+n"] = "resize", ["ctrl+h"] = "move", ["ctrl+a"] = "tmux" }
for key, name in pairs(enter) do
  rex.bind(key, "client.mode.enter", { name = name })
  for _, m in ipairs(zmodes) do
    if m ~= name then rex.bind(m .. "/" .. key, "client.mode.enter", { name = name }) end
  end
end
for _, m in ipairs(zmodes) do
  rex.bind(m .. "/enter", "client.mode.exit_all")
  rex.bind(m .. "/esc", "client.mode.exit_all")
end

-- hjkl and arrows
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  for _, k in ipairs({ key, dir }) do
    rex.bind("pane/" .. k, "pane.focus", { direction = dir })
    rex.bind("resize/" .. k, "pane.resize", { direction = dir })
    rex.bind("move/" .. k, "pane.move", { direction = dir })
    rex.bind("tmux/" .. k, "then_normal", { action = "pane.focus", args = { direction = dir } })
    rex.bind("tab/" .. k, (dir == "left" or dir == "up") and "client.tab.previous" or "client.tab.next")
  end
end

-- pane mode
rex.bind("pane/ctrl+p", "client.mode.exit_all")
rex.bind("pane/p", "pane.focus_next")
rex.bind("pane/n", "then_normal", { action = "pane.split", args = { direction = "auto" } })
rex.bind("pane/d", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("pane/r", "then_normal", { action = "pane.split", args = { direction = "right" } })
rex.bind("pane/x", "then_normal", { action = "pane.close" })
rex.bind("pane/f", "then_normal", { action = "pane.zoom" })
rex.bind("pane/c", "then_normal", { action = "pane.rename" })

-- tab mode
rex.bind("tab/ctrl+t", "client.mode.exit_all")
for i = 1, 9 do
  rex.bind("tab/" .. i, "then_normal", { action = "client.tab.goto", args = { index = i } })
end
rex.bind("tab/b", "then_normal", { action = "pane.move_to_new_tab" })
rex.bind("tab/n", "then_normal", { action = "client.tab.new" })
rex.bind("tab/r", "then_normal", { action = "client.tab.rename" })
rex.bind("tab/x", "then_normal", { action = "client.tab.close" })

-- resize and move modes
rex.bind("resize/ctrl+n", "client.mode.exit_all")
rex.bind("move/ctrl+h", "client.mode.exit_all")

-- tmux mode (ctrl+a)
rex.bind("tmux/ctrl+a", "then_normal", { action = "pane.send_key", args = { key = "ctrl+a" } })
rex.bind("tmux/-", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("tmux/shift+\\", "then_normal", { action = "pane.split", args = { direction = "right" } })
rex.bind("tmux/,", "then_normal", { action = "client.tab.rename" })
rex.bind("tmux/shift+7", "then_normal", { action = "client.tab.close" })
rex.bind("tmux/c", "then_normal", { action = "client.tab.new" })
rex.bind("tmux/n", "then_normal", { action = "client.tab.next" })
rex.bind("tmux/o", "pane.focus_next")
rex.bind("tmux/p", "then_normal", { action = "client.tab.previous" })
rex.bind("tmux/r", "client.mode.enter", { name = "resize" })
rex.bind("tmux/t", "then_normal", { action = "client.tab.rename" })
rex.bind("tmux/x", "then_normal", { action = "pane.close" })
rex.bind("tmux/z", "then_normal", { action = "pane.zoom" })
