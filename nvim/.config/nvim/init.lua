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

-- Use system clipboard
vim.opt.clipboard:append("unnamedplus")

-- Auto-copy mouse selection to clipboard
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 150 })
    end,
})
vim.keymap.set("v", "<LeftRelease>", '"+y', { silent = true })

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

-- Set text width and color column for gitcommit filetype
vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function()
        vim.opt_local.textwidth = 72 -- Set text width to 72
        vim.opt_local.colorcolumn = "72" -- Highlight column 72
        vim.fn.cursor(1, 1) -- Move cursor to the beginning of the file
    end
})
