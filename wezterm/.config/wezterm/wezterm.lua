local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.initial_cols = 80
config.initial_rows = 25

-- config.font = wezterm.font('JetBrains Mono', { weight = 'Medium' })
-- config.font = wezterm.font('MonoLisa', { weight = 'Medium' })
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.font_size = 18

-- config.color_scheme = 'Dracula'
config.color_scheme = 'Argonaut'
-- config.color_scheme = 'GitHub Dark'
-- config.color_scheme = 'Ayu Dark (Gogh)'
-- config.color_scheme = 'Gruvbox Dark (Gogh)'

config.colors = {
  background = '#171717',     -- neutral-900

  cursor_bg = '#404040',      -- neutral-700
  cursor_fg = 'transparent',
  cursor_border = '#404040',  -- neutral-700

  selection_fg = '#fafafa',   -- neutral-100
  selection_bg = '#262626'    -- neutral-800
}

-- config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_max_width = 25

-- config.default_cursor_style = 'BlinkingBlock'
-- config.cursor_blink_ease_out = 'Constant'
-- config.cursor_blink_ease_in = 'Constant'
-- config.cursor_blink_rate = 600

-- config.window_background_opacity = 0.8
-- config.macos_window_background_blur = 30

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0
}

config.window_decorations = 'RESIZE | TITLE' -- MACOS_FORCE_ENABLE_SHADOW
config.enable_scroll_bar = false

-- Disable hyperlinks
config.hyperlink_rules = {}

-- For OPT + Left/Right Arrow to work in SSH sessions
config.keys = {
  -- Option + Left Arrow
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bb'
  },
  -- Option + Right Arrow
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendString '\x1bf'
  },
}

return config
