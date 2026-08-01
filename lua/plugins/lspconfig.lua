local languages = require('config.languages')
local lsp_servers = languages.collect('lsp')
local automatic_servers = lsp_servers

return {
    {
        'mason-org/mason.nvim',
        opts = {},
    },
    {
        'mason-org/mason-lspconfig.nvim',
        dependencies = {
            { 'mason-org/mason.nvim', opts = {} },
            'neovim/nvim-lspconfig',
            'saghen/blink.cmp',
        },
        opts = {
            ensure_installed = languages.mason_lsp_servers(),
            automatic_enable = automatic_servers,
        },
        config = function(_, opts)
            -- Advertise one completion capability set to every language
            -- server. Server-specific vim.lsp.config() calls below inherit it.
            vim.lsp.config('*', {
                capabilities = require('blink.cmp').get_lsp_capabilities(),
            })

            for _, server in ipairs(automatic_servers) do
                vim.lsp.config(server, {})
            end

            if languages.enabled('go') then vim.lsp.config('gopls', {
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
            }) end

            if languages.enabled('rust') then vim.lsp.config('rust_analyzer', {
                settings = {
                    ['rust-analyzer'] = {
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
            }) end

            if languages.enabled('cpp') then
                vim.lsp.config('clangd', {
                    cmd = require('config.clangd').cmd(),
                })
            end

            if languages.enabled('lua') then vim.lsp.config('lua_ls', {
                settings = {
                    Lua = {
                        diagnostics = {
                            globals = { 'vim' },
                        },
                    },
                },
            }) end

            if languages.enabled('csharp') then
                vim.lsp.config('csharp_ls', {
                    settings = {
                        csharp = {
                            analyzersEnabled = true,
                        },
                    },
                })
            end

            require('mason-lspconfig').setup(opts)
        end,
    },
}
