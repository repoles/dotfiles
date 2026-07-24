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

local config_group = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Briefly highlight the text that was just yanked
vim.api.nvim_create_autocmd("TextYankPost", {
    group = config_group,
    callback = function()
        vim.hl.on_yank({ timeout = 150 })
    end,
})

-- Auto-copy mouse selection to clipboard
vim.keymap.set("v", "<LeftRelease>", '"+y', { silent = true })

-- Don't wrap long lines: in code a wrapped line misreads as two lines, so let it
-- scroll sideways instead. Prose filetypes turn 'wrap' back on below.
vim.opt.wrap = false

-- Signal text hidden off-screen: › in the last column when the line continues to
-- the right, ‹ in the first once scrolled away from the start. Those markers are
-- only drawn in 'list' mode, which also lets tabs and trailing spaces show up as
-- something other than blank.
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }

-- These only take effect where 'wrap' is on, but keep them global so that
-- turning wrap on anywhere (:set wrap) breaks at word boundaries rather than
-- mid-word, with continuation lines aligned to the original indentation.
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Show line numbers
vim.opt.number = true

-- Enable relative line numbers
-- vim.opt.relativenumber = true

-- Remember last cursor position. Git reuses one path per message kind, so the
-- shada mark from the *previous* commit would drop the cursor in the middle of
-- an unrelated message; those files always start at the top instead. Matching by
-- name rather than filetype is deliberate: 'filetype' is still empty this early.
local skip_cursor_restore = {
    ["COMMIT_EDITMSG"] = true,
    ["MERGE_MSG"] = true,
    ["SQUASH_MSG"] = true,
    ["TAG_EDITMSG"] = true,
    ["git-rebase-todo"] = true,
}

vim.api.nvim_create_autocmd("BufReadPost", {
    group = config_group,
    callback = function(args)
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":t")
        if skip_cursor_restore[name] then
            return
        end
        local row, col = unpack(vim.api.nvim_buf_get_mark(args.buf, '"'))
        if vim.api.nvim_get_current_buf() == args.buf
            and row > 0
            and row <= vim.api.nvim_buf_line_count(args.buf)
        then
            vim.api.nvim_win_set_cursor(0, { row, col })
        end
    end,
})

-- Wrap prose, where a long line is a paragraph rather than a statement
vim.api.nvim_create_autocmd("FileType", {
    group = config_group,
    pattern = { "markdown", "text" },
    callback = function()
        vim.opt_local.wrap = true
    end,
})

-- Set text width and color column for gitcommit filetype
vim.api.nvim_create_autocmd("FileType", {
    group = config_group,
    pattern = "gitcommit",
    callback = function()
        vim.opt_local.wrap = true -- Prose, so wrap instead of scrolling sideways
        vim.opt_local.textwidth = 72 -- Set text width to 72
        vim.opt_local.colorcolumn = "72" -- Highlight column 72
    end
})
