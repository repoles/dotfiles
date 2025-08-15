-- Tailwind Color Palette Variables
local colors = {
  -- Gray palette (main theme)
  gray_950 = '#030712',
  gray_900 = '#111827',
  gray_800 = '#1f2937',
  gray_700 = '#374151',
  gray_600 = '#4b5563',
  gray_500 = '#6b7280',
  gray_400 = '#9ca3af',
  gray_300 = '#d1d5db',
  gray_200 = '#e5e7eb',
  gray_100 = '#f3f4f6',
  gray_50  = '#f9fafb',

  -- Semantic colors
  red_500    = '#ef4444',
  red_400    = '#f87171',
  green_500  = '#22c55e',
  green_400  = '#4ade80',
  yellow_500 = '#eab308',
  yellow_400 = '#facc15',
  blue_500   = '#3b82f6',
  blue_400   = '#60a5fa',
  purple_500 = '#a855f7',
  purple_400 = '#c084fc',
  cyan_500   = '#06b6d4',
  cyan_400   = '#22d3ee',
}

-- Theme definition
local theme = {
  background_primary   = colors.gray_900,
  background_secondary = colors.gray_800,
  background_darkest   = colors.gray_950,
  text_primary         = colors.gray_200,
  text_secondary       = colors.gray_300,
  text_muted           = colors.gray_400,
  border_primary       = colors.gray_700,
  border_secondary     = colors.gray_600,
  selection_bg         = colors.gray_500,
}

return {
  foreground    = theme.text_primary,
  background    = theme.background_primary,
  cursor_bg     = theme.text_primary,
  cursor_fg     = theme.background_primary,
  cursor_border = theme.text_primary,

  selection_fg = theme.background_primary,
  selection_bg = theme.selection_bg,

  scrollbar_thumb = theme.border_secondary,
  split = theme.border_primary,

  ansi = {
    colors.gray_800,    -- black
    colors.red_500,     -- red
    colors.green_500,   -- green
    colors.yellow_500,  -- yellow
    colors.blue_500,    -- blue
    colors.purple_500,  -- magenta
    colors.cyan_500,    -- cyan
    colors.gray_200,    -- white
  },

  brights = {
    colors.gray_600,    -- bright black
    colors.red_400,     -- bright red
    colors.green_400,   -- bright green
    colors.yellow_400,  -- bright yellow
    colors.blue_400,    -- bright blue
    colors.purple_400,  -- bright magenta
    colors.cyan_400,    -- bright cyan
    colors.gray_100,    -- bright white
  },

  tab_bar = {
    background = theme.background_darkest,
    active_tab = {
      bg_color = theme.background_primary,
      fg_color = theme.text_primary,
    },
    inactive_tab = {
      bg_color = theme.background_darkest,
      fg_color = theme.text_muted,
    },
    inactive_tab_hover = {
      bg_color = theme.background_secondary,
      fg_color = theme.text_secondary,
    },
    new_tab = {
      bg_color = theme.background_darkest,
      fg_color = theme.text_muted,
    },
    new_tab_hover = {
      bg_color = theme.background_secondary,
      fg_color = theme.text_secondary,
    },
  },
}
