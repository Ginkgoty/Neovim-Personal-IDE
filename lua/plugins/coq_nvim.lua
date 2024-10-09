return {
  {
    'ms-jpq/coq_nvim',
    branch = 'coq',
    dependencies = {
      { 'ms-jpq/coq.artifacts', branch = 'artifacts' },
      { 'ms-jpq/coq.thirdparty', branch = '3p' }
    },
    config = function()
      -- Setup coq with status bar disabled
      local coq = require("coq")
      coq.setup({
        display = {
          icons = {
            mode = "none"  -- Disable the icons/status bar at the bottom
          }
        }
      })

      -- Integrating coq with LSP servers
      require('lspconfig').ruff.setup(coq.lsp_ensure_capabilities({}))
      require('lspconfig').clangd.setup(coq.lsp_ensure_capabilities({}))
      require('lspconfig').jdtls.setup(coq.lsp_ensure_capabilities({}))
      require('lspconfig').sqls.setup(coq.lsp_ensure_capabilities({}))
      require('lspconfig').lua_ls.setup(coq.lsp_ensure_capabilities({}))
    end
  }
}
