local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.initial_cols = 100
config.initial_rows = 30

-- WezTerm bundles JetBrains Mono, Nerd Font Symbols and Noto Color Emoji
-- https://wezterm.org/config/fonts.html

-- local font_family = 'JetBrains Mono'
-- local font_features = { 'calt=0', 'clig=0', 'liga=0' }

local font_family = 'MonoLisaCode'
-- https://www.monolisa.dev/tester/code
local font_features = { 'ss11=1', 'ss13=1', 'cv04=1', 'cv05=1', 'cv08=1', 'cv09=1', 'cv11=1' }

local function font(opts)
  opts = opts or {}

  return wezterm.font {
    family = font_family,
    weight = opts.weight or 'Regular',
    style = opts.style or 'Normal',
    harfbuzz_features = font_features
  }
end

config.font = font()

config.font_rules = {
  {
    intensity = 'Bold',
    italic = false,
    font = font { weight = 'Black' },
  },
  {
    intensity = 'Bold',
    italic = true,
    font = font { weight = 'Black', style = 'Italic' },
  },
  {
    intensity = 'Half',
    italic = false,
    font = font { weight = 'Thin' },
  },
  {
    intensity = 'Half',
    italic = true,
    font = font { weight = 'Thin', style = 'Italic' },
  }
}

config.font_size = 18

-- config.color_scheme = 'Dracula'
-- config.color_scheme = 'Argonaut (Gogh)'
-- config.color_scheme = 'Gruvbox Dark (Gogh)'

-- Custom color scheme defined in colors/ayu.toml
config.color_scheme = 'Ayu Ghostty'

-- config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_max_width = 25

-- config.default_cursor_style = 'BlinkingBlock' -- 'SteadyBlock'
-- config.cursor_blink_ease_out = 'Constant'
-- config.cursor_blink_ease_in = 'Constant'
-- config.cursor_blink_rate = 600
-- config.cursor_thickness = 4

-- config.window_background_opacity = 0.9
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
-- config.hyperlink_rules = {}

local act = wezterm.action

config.mouse_bindings = {
  {
    -- Select text on triple click
    event = { Down = { streak = 1, button = 'Right' } },
    action = act.SelectTextAtMouseCursor 'SemanticZone',
    mods = 'CMD',
  }
}

config.keys = {
  -- Option + Left Arrow
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = act.SendString '\x1bb'
  },
  -- Option + Right Arrow
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = act.SendString '\x1bf'
  },
  -- Cmd + Left Arrow -> Shift+Home (first non-blank char in nvim)
  {
    key = 'LeftArrow',
    mods = 'CMD',
    action = act.SendString '\x1b[1;2H'
  },
  -- Cmd + Right Arrow -> Shift+End (end of line in nvim)
  {
    key = 'RightArrow',
    mods = 'CMD',
    action = act.SendString '\x1b[1;2F'
  },
  -- Shift + Enter to insert newline
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = act.SendString '\n'
  },
  -- Shift + Up/Down Arrow to scroll to prompt
  -- { key = 'UpArrow',
  --   mods = 'SHIFT',
  --   action = act.ScrollToPrompt(-1)
  -- },
  -- {
  --   key = 'DownArrow',
  --   mods = 'SHIFT',
  --   action = act.ScrollToPrompt(1)
  -- }
}

return config
