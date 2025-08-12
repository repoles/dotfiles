-- Tailwind Color Palette Variables
local colors = {
  -- Slate palette (main theme)
  slate_950 = '#020617',
  slate_900 = '#0f172a',
  slate_800 = '#1e293b',
  slate_700 = '#334155',
  slate_600 = '#475569',
  slate_500 = '#64748b',
  slate_400 = '#94a3b8',
  slate_200 = '#e2e8f0',
  slate_100 = '#f1f5f9',
  slate_50  = '#f8fafc',

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
  background_primary   = colors.slate_900,
  background_secondary = colors.slate_800,
  background_darkest   = colors.slate_950,
  text_primary         = colors.slate_50,
  text_secondary       = colors.slate_200,
  text_muted           = colors.slate_400,
  border_primary       = colors.slate_700,
  border_secondary     = colors.slate_600,
  selection_bg         = colors.slate_500,
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
    colors.slate_800,   -- black
    colors.red_500,     -- red
    colors.green_500,   -- green
    colors.yellow_500,  -- yellow
    colors.blue_500,    -- blue
    colors.purple_500,  -- magenta
    colors.cyan_500,    -- cyan
    colors.slate_200,   -- white
  },

  brights = {
    colors.slate_600,   -- bright black
    colors.red_400,     -- bright red
    colors.green_400,   -- bright green
    colors.yellow_400,  -- bright yellow
    colors.blue_400,    -- bright blue
    colors.purple_400,  -- bright magenta
    colors.cyan_400,    -- bright cyan
    colors.slate_100,   -- bright white
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
