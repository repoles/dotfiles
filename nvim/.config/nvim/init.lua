-- Set color scheme
vim.cmd('colorscheme lunaperche')

-- Use system clipboard
vim.opt.clipboard:append("unnamedplus")

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
