-- Show line numbers
vim.opt.number = true

-- Enable relative line numbers
-- vim.opt.relativenumber = true

-- Remember last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local row, col = unpack(vim.api.nvim_buf_get_mark(0, '"'))
    if row > 0 and row <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, {row, col})
    end
  end,
})

