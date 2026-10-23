-- Open a new window running a program in the focused pane's
-- directory, like `rex window new --cwd $PWD -- program`
local function open_in_window(ctx, program)
  local cwd
  if ctx.block_id ~= nil then
    local p = rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
    if p ~= nil then
      cwd = (p.foreground and p.foreground.cwd) or (p.child and p.child.cwd)
    end
  end

  local _, err = rex.session.new_window{
    layout = rex.layout.block{
      flavor  = "com.superlogical.terminal.shell",
      options = { command = { program }, cwd = cwd },
    },
  }
  if err ~= nil then error(err, 0) end
end

rex.action{
  name  = "claude",
  title = "Open Claude Code",
  run   = function(ctx, args) open_in_window(ctx, "claude") end,
}

rex.action{
  name  = "codex",
  title = "Open Codex",
  run   = function(ctx, args) open_in_window(ctx, "codex") end,
}

-- Rex's clear leaves a screen of blank lines behind, and a
-- second clear removes them, but only after a short pause
rex.action{
  name  = "clear",
  title = "Clear Screen and Scrollback",
  run   = function(ctx, args)
    local terminal = "com.superlogical.terminal"
    rex.block.call(terminal, "clear", {})
    rex.exec({ "sleep", "0.2" })
    rex.block.call(terminal, "clear", {})
  end,
}

rex.bind("cmd+f1", "claude")
rex.bind("cmd+f2", "codex")
rex.bind("cmd+l", "clear")
