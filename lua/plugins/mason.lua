return {
  -- mason.nvim configuration
  {
    'williamboman/mason.nvim',
    config = function()
      require("mason").setup()  -- Initialize mason
    end
  },

  -- mason-lspconfig with dependencies and automatic LSP installation
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim' },  -- Ensure mason.nvim is loaded first
    config = function()
      require('mason-lspconfig').setup({
        ensure_installed = { "clangd", "jdtls", "ruff", "sqls", "lua_ls" },  -- Install these LSP servers
      })
    end
  },

  -- nvim-lspconfig to set up LSP servers, dependent on mason-lspconfig
  {
    'neovim/nvim-lspconfig',
    lazy = false, -- REQUIRED: tell lazy.nvim to start this plugin at startup
    dependencies = {
        -- Ensutre Mason load before
        { 'williamboman/mason-lspconfig.nvim' },
        
        -- main one
        { "ms-jpq/coq_nvim", branch = "coq" },

        -- 9000+ Snippets
        { "ms-jpq/coq.artifacts", branch = "artifacts" },

        -- lua & third party sources -- See https://github.com/ms-jpq/coq.thirdparty
        -- Need to **configure separately**
        { 'ms-jpq/coq.thirdparty', branch = "3p" }
        -- - shell repl
        -- - nvim lua api
        -- - scientific calculator
        -- - comment banner
        -- - etc
  },
    init = function()
        vim.g.coq_settings = {
            display = { statusline = { helo = false } },
            auto_start = true
        }
    end,  

    config = function()
      local lspconfig = require('lspconfig')

      -- Configure C/C++ LSP (clangd)
      lspconfig.clangd.setup{coq.lsp_ensure_capabilities({})}

      -- Configure Java LSP (jdtls)
      lspconfig.jdtls.setup{coq.lsp_ensure_capabilities({})}

      -- Configure Ruff for Python LSP
      lspconfig.ruff.setup{coq.lsp_ensure_capabilities({})}

      -- Configure SQL LSP (sqlls)
      lspconfig.sqls.setup{coq.lsp_ensure_capabilities({})}

      -- Configure Lua LSP
      lspconfig.lua_ls.setup{coq.lsp_ensure_capabilities({})}  
    end          
  }
}

