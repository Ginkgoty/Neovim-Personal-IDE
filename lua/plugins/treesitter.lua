local languages = require("config.languages")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",

    config = function()
      local parsers = languages.collect("treesitter")
      -- Markdown rendering is an editor-wide UI feature rather than a
      -- language profile, so its parsers are always available.
      vim.list_extend(parsers, { "markdown", "markdown_inline" })
      local enabled_parsers = {}
      for _, parser in ipairs(parsers) do
        enabled_parsers[parser] = true
      end
      local treesitter = require("nvim-treesitter")
      treesitter.setup({})
      treesitter.install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function(args)
          -- Ask Tree-sitter for its registered filetype-to-parser mapping.
          -- This covers aliases such as cs -> c_sharp and help -> vimdoc
          -- without duplicating filetype lists in our language profile.
          local parser = vim.treesitter.language.get_lang(args.match)
          if parser and enabled_parsers[parser] then
            -- Tree-sitter owns syntax highlighting. Indentation remains with
            -- Neovim's mature per-language runtime scripts (C cindent,
            -- python.vim, and equivalents) instead of one generic algorithm.
            pcall(vim.treesitter.start, args.buf, parser)
          end
        end,
      })
    end
  }
}
