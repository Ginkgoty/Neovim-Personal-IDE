local languages = require "config.languages"
local lsp_servers = languages.collect "lsp"
local automatic_servers = lsp_servers

return {
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup()
      require("config.mason").setup()
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
      "b0o/SchemaStore.nvim",
    },
    opts = {
      ensure_installed = languages.mason_lsp_servers(),
      automatic_enable = automatic_servers,
    },
    config = function(_, opts)
      -- Advertise one completion capability set to every language
      -- server. Server-specific vim.lsp.config() calls below inherit it.
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local lsp_settings = require("config.settings").lsp or {}
      if lsp_settings.workspace_file_watching == false then
        -- Neovim enables recursive workspace/didChangeWatchedFiles on
        -- macOS and Windows by default. Large repositories can exhaust
        -- the process file-descriptor limit and prevent Telescope,
        -- terminals, formatters, and every other job from spawning.
        capabilities.workspace = capabilities.workspace or {}
        capabilities.workspace.didChangeWatchedFiles = {
          dynamicRegistration = false,
        }
      end
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      for _, server in ipairs(automatic_servers) do
        vim.lsp.config(server, {})
      end

      if languages.enabled "go" then
        vim.lsp.config("gopls", {
          settings = {
            gopls = {
              hints = {
                assignVariableTypes = true,
                ignoredError = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        })
      end

      if languages.enabled "rust" then
        vim.lsp.config("rust_analyzer", {
          settings = {
            ["rust-analyzer"] = {
              lens = {
                enable = true,
                references = {
                  adt = { enable = true },
                  enumVariant = { enable = true },
                  method = { enable = true },
                  trait = { enable = true },
                },
              },
            },
          },
        })
      end

      if languages.enabled "cpp" then
        vim.lsp.config("clangd", {
          cmd = require("config.clangd").start,
          root_dir = require("config.clangd").root_dir,
          before_init = require("config.clangd").before_init,
        })
      end

      if languages.enabled "lua" then
        vim.lsp.config("lua_ls", {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
            },
          },
        })
      end

      if languages.enabled "json" then
        vim.lsp.config("jsonls", {
          settings = {
            json = {
              schemas = require("config.json").schemas(),
              validate = { enable = true },
            },
          },
        })
      end

      if languages.enabled "javascript" and languages.available "javascript" then
        -- Vue 3 delegates the TypeScript portions of SFCs to vtsls. Use the
        -- plugin bundled with vue-language-server so both sides always have
        -- exactly the same version, including on Windows.
        local vue_language_server_path = require("config.platform").join(
          vim.fn.stdpath "data",
          "mason",
          "packages",
          "vue-language-server",
          "node_modules",
          "@vue",
          "language-server"
        )
        vim.lsp.config("vtsls", {
          settings = {
            vtsls = {
              tsserver = {
                globalPlugins = {
                  {
                    name = "@vue/typescript-plugin",
                    location = vue_language_server_path,
                    languages = { "vue" },
                    configNamespace = "typescript",
                  },
                },
              },
            },
          },
          filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
        })
        vim.lsp.config("tailwindcss", {
          -- The upstream config advertises dynamic recursive file watching.
          -- Keep the global large-workspace policy intact: the Tailwind
          -- server discovers its CSS/config graph itself, while Neovim must
          -- not watch every node_modules/build directory on its behalf.
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = false,
              },
            },
          },
        })
      end

      if languages.enabled "csharp" then
        vim.lsp.config("csharp_ls", {
          settings = {
            csharp = {
              analyzersEnabled = true,
            },
          },
        })
      end

      require("mason-lspconfig").setup(opts)
    end,
  },
}
