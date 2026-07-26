-- autocmd
vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
  pattern = "*.owl",
  command = "set filetype=xml",
})
