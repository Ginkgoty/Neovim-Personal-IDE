return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",

    config = function()
      local languages = {
        "c", "cpp", "python", "java", "sql", "lua", "vim", "vimdoc",
        "go", "gomod", "gosum", "gowork", "rust",
      }
      local treesitter = require("nvim-treesitter")
      treesitter.setup({})
      treesitter.install(languages)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = languages,
        callback = function()
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end
  }
}
