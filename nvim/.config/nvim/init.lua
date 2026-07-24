-- Set color scheme
vim.cmd('colorscheme lunaperche')

-- Move by word with OPT+Left/Right (macOS-style).
-- WezTerm sends Alt+b/Alt+f (<M-b>/<M-f>); Ghostty sends <M-Left>/<M-Right>.
for _, lhs in ipairs({ "<M-Right>", "<M-f>" }) do
    vim.keymap.set({ "n", "v" }, lhs, "w")
    -- In insert mode, land just after the last char of the word (VSCode-style).
    vim.keymap.set("i", lhs, "<C-o>e<Right>")
end
for _, lhs in ipairs({ "<M-Left>", "<M-b>" }) do
    vim.keymap.set({ "n", "v" }, lhs, "b")
    vim.keymap.set("i", lhs, "<C-o>b")
end

-- Jump to start/end of line with CTRL+a/CTRL+e (readline/VSCode-style).
vim.keymap.set({ "n", "v" }, "<C-a>", "0")
vim.keymap.set({ "n", "v" }, "<C-e>", "$")
vim.keymap.set("i", "<C-a>", "<Home>")
vim.keymap.set("i", "<C-e>", "<End>")

-- CMD+Left -> first non-blank char (VSCode-style). The terminals (WezTerm/Ghostty)
-- send Shift+Home (\x1b[1;2H) for CMD+Left, which Neovim parses as <S-Home>.
vim.keymap.set({ "n", "v" }, "<S-Home>", "^")
vim.keymap.set("i", "<S-Home>", "<C-o>^")

-- CMD+Right -> end of line (VSCode-style). The terminals send Shift+End
-- (\x1b[1;2F) for CMD+Right, which Neovim parses as <S-End>.
vim.keymap.set({ "n", "v" }, "<S-End>", "$")
vim.keymap.set("i", "<S-End>", "<End>")

-- Use system clipboard
vim.opt.clipboard:append("unnamedplus")

-- Auto-copy mouse selection to clipboard
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 150 })
    end,
})
vim.keymap.set("v", "<LeftRelease>", '"+y', { silent = true })

-- Don't wrap long lines: in code a wrapped line misreads as two lines, so let it
-- scroll sideways instead. Prose filetypes turn 'wrap' back on below.
vim.opt.wrap = false

-- These only take effect where 'wrap' is on, but keep them global so that
-- turning wrap on anywhere (:set wrap) breaks at word boundaries rather than
-- mid-word, with continuation lines aligned to the original indentation.
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Show line numbers
vim.opt.number = true

-- Enable relative line numbers
-- vim.opt.relativenumber = true

-- Remember last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local row, col = unpack(vim.api.nvim_buf_get_mark(0, '"'))
        if row > 0 and row <= vim.api.nvim_buf_line_count(0) then
            vim.api.nvim_win_set_cursor(0, { row, col })
        end
    end,
})

-- Wrap prose, where a long line is a paragraph rather than a statement
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text" },
    callback = function()
        vim.opt_local.wrap = true
    end,
})

-- Set text width and color column for gitcommit filetype
vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function()
        vim.opt_local.wrap = true -- Prose, so wrap instead of scrolling sideways
        vim.opt_local.textwidth = 72 -- Set text width to 72
        vim.opt_local.colorcolumn = "72" -- Highlight column 72
        vim.fn.cursor(1, 1) -- Move cursor to the beginning of the file
    end
})
