local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

-- https://github.com/prettier-solidity/prettier-plugin-solidity
null_ls.setup {
  debug = false,
  sources = {
    -- C/C++ support
    formatting.clang_format.with {
      extra_filetypes = { "cc", "cxx", "h", "hpp", "hh", "hxx", "cppm", "ixx" },
      disabled_filetypes = { "java" }
    },
    diagnostics.cppcheck.with {
      extra_filetypes = { "cc", "cxx", "h", "hpp", "hh", "hxx", "cppm", "ixx" },
      extra_args = { "-j8" },
    },
    -- rust
    formatting.prettier.with {
      extra_filetypes = { "toml" },
      extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
    },
    formatting.black.with { extra_args = { "--fast" } },
    -- lua
    formatting.stylua,
    -- java
    formatting.google_java_format,
    diagnostics.semgrep.with {
      disabled_filetypes = { "python" },
      extra_args={ "--config", "auto" }
    },
    diagnostics.flake8,
  },
}
