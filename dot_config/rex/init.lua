-- Rex config, migrated from tmux, zellij and Ghostty.
-- cmd+k keeps Rex's session picker (your choice).
-- tmux and zellij both bound alt+left/right/up/down outside any mode; tmux's won (your choice).

---------------------------------------------------------------------------
-- tmux (~/.config/tmux/tmux.conf), prefix ctrl+space
---------------------------------------------------------------------------
rex.bind("ctrl+space>ctrl+space", "pane.send_key", { key = "ctrl+space" })
rex.bind("ctrl+space>q", "client.config.reload")
rex.bind("ctrl+space>h", "pane.split", { direction = "down" })
rex.bind("ctrl+space>v", "pane.split", { direction = "right" })
rex.bind("ctrl+space>x", "pane.close")
rex.bind("ctrl+alt+left", "pane.focus", { direction = "left" })
rex.bind("ctrl+alt+right", "pane.focus", { direction = "right" })
rex.bind("ctrl+alt+up", "pane.focus", { direction = "up" })
rex.bind("ctrl+alt+down", "pane.focus", { direction = "down" })
rex.bind("ctrl+alt+shift+left", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+alt+shift+down", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+alt+shift+up", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+alt+shift+right", "pane.resize", { amount = 5, direction = "right" })
rex.bind("ctrl+space>r", "client.tab.rename")
rex.bind("ctrl+space>c", "client.tab.new")
rex.bind("ctrl+space>k", "client.tab.close")
rex.bind("alt+1", "client.tab.goto", { index = 1 })
rex.bind("alt+2", "client.tab.goto", { index = 2 })
rex.bind("alt+3", "client.tab.goto", { index = 3 })
rex.bind("alt+4", "client.tab.goto", { index = 4 })
rex.bind("alt+5", "client.tab.goto", { index = 5 })
rex.bind("alt+6", "client.tab.goto", { index = 6 })
rex.bind("alt+7", "client.tab.goto", { index = 7 })
rex.bind("alt+8", "client.tab.goto", { index = 8 })
rex.bind("alt+9", "client.tab.goto", { index = 9 })
rex.bind("alt+left", "client.tab.goto", { index = -1 })
rex.bind("alt+right", "client.tab.goto", { index = 1 })
rex.bind("ctrl+space>shift+r", "session.rename")
rex.bind("ctrl+space>shift+c", "session.new")
rex.bind("ctrl+space>shift+k", "session.close")
rex.bind("ctrl+space>shift+p", "session.previous")
rex.bind("ctrl+space>shift+n", "session.next")
rex.bind("alt+up", "session.previous")
rex.bind("alt+down", "session.next")

---------------------------------------------------------------------------
-- Ghostty (~/.config/ghostty/config)
---------------------------------------------------------------------------
rex.bind("shift+insert", "pane.paste")
rex.bind("ctrl+insert", "pane.copy")

---------------------------------------------------------------------------
-- zellij (~/.config/zellij/config.kdl)
-- No clear-defaults=true: zellij's own defaults were also active there;
-- only the bindings written in config.kdl are migrated.
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

-- Modes you stay in until you leave them.
rex.mode("pane",   { exclusive = true })
rex.mode("resize", { exclusive = true })
rex.mode("move",   { exclusive = true })
rex.mode("tab",    { exclusive = true })
rex.mode("tmux",   { exclusive = true })
-- locked is not exclusive: keys must keep reaching the program.

-- Mode entry keys (shared_except "<mode>" "locked"), config.kdl:147,165,168,177,180,183
local entries = {
  { key = "ctrl+g", mode = "locked" },
  { key = "ctrl+p", mode = "pane" },
  { key = "ctrl+n", mode = "resize" },
  { key = "ctrl+t", mode = "tab" },
  { key = "ctrl+h", mode = "move" },
  { key = "ctrl+b", mode = "tmux" },
}

-- shared_except "locked" actions, config.kdl:149-155
-- (alt+left/right/up/down outside a mode stay tmux's, by your choice)
local shared = {
  { "alt+n",     "pane.split",      { direction = "auto" } },
  { "alt+i",     "client.tab.move", { direction = "backward" } },
  { "alt+o",     "client.tab.move", { direction = "forward" } },
  { "alt+h",     "pane.focus",      { direction = "left" } },
  { "alt+l",     "pane.focus",      { direction = "right" } },
  { "alt+j",     "pane.focus",      { direction = "down" } },
  { "alt+k",     "pane.focus",      { direction = "up" } },
}
local shared_arrows = {
  { "alt+left",  "pane.focus", { direction = "left" } },
  { "alt+right", "pane.focus", { direction = "right" } },
  { "alt+down",  "pane.focus", { direction = "down" } },
  { "alt+up",    "pane.focus", { direction = "up" } },
}

-- Normal mode (no Rex mode)
for _, e in ipairs(entries) do
  rex.bind(e.key, "client.mode.enter", { name = e.mode })
end
for _, b in ipairs(shared) do
  rex.bind(b[1], b[2], b[3])
end

-- Shared keys inside every exclusive mode
for _, m in ipairs({ "pane", "resize", "move", "tab", "tmux" }) do
  for _, e in ipairs(entries) do
    if e.mode ~= m then
      rex.bind(m .. "/" .. e.key, "client.mode.enter", { name = e.mode })
    end
  end
  for _, b in ipairs(shared) do
    rex.bind(m .. "/" .. b[1], b[2], b[3])
  end
  for _, b in ipairs(shared_arrows) do
    rex.bind(m .. "/" .. b[1], b[2], b[3])
  end
  -- shared_except "normal" "locked", config.kdl:162
  rex.bind(m .. "/enter", "client.mode.exit_all")
  rex.bind(m .. "/esc", "client.mode.exit_all")
end

-- locked, config.kdl:7
rex.bind("locked/ctrl+g", "client.mode.exit_all")
-- In zellij's locked mode its own keys go to the program; send them through.
for _, e in ipairs(entries) do
  if e.mode ~= "locked" then
    rex.bind("locked/" .. e.key, "pane.send_key", { key = e.key })
  end
end
for _, b in ipairs(shared) do
  rex.bind("locked/" .. b[1], "pane.send_key", { key = b[1] })
end

-- resize, config.kdl:10-14
rex.bind("resize/ctrl+n", "client.mode.exit")
rex.bind("resize/h", "pane.resize", { direction = "left" })
rex.bind("resize/left", "pane.resize", { direction = "left" })
rex.bind("resize/j", "pane.resize", { direction = "down" })
rex.bind("resize/down", "pane.resize", { direction = "down" })
rex.bind("resize/k", "pane.resize", { direction = "up" })
rex.bind("resize/up", "pane.resize", { direction = "up" })
rex.bind("resize/l", "pane.resize", { direction = "right" })
rex.bind("resize/right", "pane.resize", { direction = "right" })

-- pane, config.kdl:23-37
rex.bind("pane/ctrl+p", "client.mode.exit")
rex.bind("pane/h", "pane.focus", { direction = "left" })
rex.bind("pane/left", "pane.focus", { direction = "left" })
rex.bind("pane/l", "pane.focus", { direction = "right" })
rex.bind("pane/right", "pane.focus", { direction = "right" })
rex.bind("pane/j", "pane.focus", { direction = "down" })
rex.bind("pane/down", "pane.focus", { direction = "down" })
rex.bind("pane/k", "pane.focus", { direction = "up" })
rex.bind("pane/up", "pane.focus", { direction = "up" })
rex.bind("pane/p", "pane.focus_next")
rex.bind("pane/n", "then_normal", { action = "pane.split", args = { direction = "auto" } })
rex.bind("pane/d", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("pane/r", "then_normal", { action = "pane.split", args = { direction = "right" } })
rex.bind("pane/x", "then_normal", { action = "pane.close" })
rex.bind("pane/f", "then_normal", { action = "pane.zoom" })
rex.bind("pane/c", "then_normal", { action = "pane.rename" })

-- move, config.kdl:40-46
rex.bind("move/ctrl+h", "client.mode.exit")
rex.bind("move/h", "pane.move", { direction = "left" })
rex.bind("move/left", "pane.move", { direction = "left" })
rex.bind("move/j", "pane.move", { direction = "down" })
rex.bind("move/down", "pane.move", { direction = "down" })
rex.bind("move/k", "pane.move", { direction = "up" })
rex.bind("move/up", "pane.move", { direction = "up" })
rex.bind("move/l", "pane.move", { direction = "right" })
rex.bind("move/right", "pane.move", { direction = "right" })

-- tab, config.kdl:49-67
rex.bind("tab/ctrl+t", "client.mode.exit")
rex.bind("tab/r", "then_normal", { action = "client.tab.rename" })
for _, k in ipairs({ "h", "left", "up", "k" }) do
  rex.bind("tab/" .. k, "client.tab.previous")
end
for _, k in ipairs({ "l", "right", "down", "j" }) do
  rex.bind("tab/" .. k, "client.tab.next")
end
rex.bind("tab/n", "then_normal", { action = "client.tab.new" })
rex.bind("tab/x", "then_normal", { action = "client.tab.close" })
rex.bind("tab/b", "then_normal", { action = "pane.move_to_new_tab" })
for i = 1, 9 do
  rex.bind("tab/" .. i, "then_normal", { action = "client.tab.goto", args = { index = i } })
end

-- tmux, config.kdl:125-144
rex.bind("tmux/ctrl+b", "then_normal", { action = "pane.send_key", args = { key = "ctrl+b" } })
rex.bind("tmux/shift+'", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("tmux/shift+5", "then_normal", { action = "pane.split", args = { direction = "right" } })
rex.bind("tmux/z", "then_normal", { action = "pane.zoom" })
rex.bind("tmux/c", "then_normal", { action = "client.tab.new" })
rex.bind("tmux/,", "then_normal", { action = "client.tab.rename" })
rex.bind("tmux/p", "then_normal", { action = "client.tab.previous" })
rex.bind("tmux/n", "then_normal", { action = "client.tab.next" })
for _, d in ipairs({ { "left", "h" }, { "right", "l" }, { "down", "j" }, { "up", "k" } }) do
  rex.bind("tmux/" .. d[1], "then_normal", { action = "pane.focus", args = { direction = d[1] } })
  rex.bind("tmux/" .. d[2], "then_normal", { action = "pane.focus", args = { direction = d[1] } })
end
rex.bind("tmux/o", "pane.focus_next")
rex.bind("tmux/x", "then_normal", { action = "pane.close" })
