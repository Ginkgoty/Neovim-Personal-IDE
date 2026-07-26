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
            {
                'ms-jpq/coq_nvim',
                branch = 'coq',
                dependencies = {
                    { 'ms-jpq/coq.artifacts', branch = 'artifacts' },
                    { 'ms-jpq/coq.thirdparty', branch = '3p' },
                },
            },
        },
        init = function()
            vim.g.coq_settings = {
                display = {
                    icons = { mode = 'none' },
                },
            }
        end,
        opts = {
            ensure_installed = {
                'clangd', 'jdtls', 'ruff', 'ty', 'sqls', 'lua_ls',
                'gopls', 'rust_analyzer',
            },
            -- Java is started by nvim-jdtls so it can load the debug bundles.
            automatic_enable = {
                'clangd', 'ruff', 'ty', 'sqls', 'lua_ls',
                'gopls', 'rust_analyzer',
            },
        },
        config = function(_, opts)
            local servers = { 'clangd', 'ruff', 'ty', 'sqls', 'gopls', 'rust_analyzer' }

            for _, server in ipairs(servers) do
                vim.lsp.config(server, {})
            end

            vim.lsp.config('lua_ls', {
                settings = {
                    Lua = {
                        diagnostics = {
                            globals = { 'vim' },
                        },
                    },
                },
            })

            require('mason-lspconfig').setup(opts)
        end,
    },
}
