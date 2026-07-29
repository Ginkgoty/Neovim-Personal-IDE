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
                keymap = {
                    -- Keep Tab available for Neovim's built-in snippet jumps.
                    recommended = false,
                    manual_complete = '<C-Space>',
                },
            }
        end,
        opts = {
            ensure_installed = languages.mason_lsp_servers(),
            automatic_enable = automatic_servers,
        },
        config = function(_, opts)
            local coq = require('coq')
            coq.setup()

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

            local function completion_key(key, fallback)
                return function()
                    if vim.fn.pumvisible() == 1 then
                        return key
                    end
                    return fallback
                end
            end

            vim.keymap.set('i', '<C-n>', completion_key('<C-n>', '<C-n>'), {
                expr = true,
                silent = true,
                desc = 'Select next completion item',
            })
            vim.keymap.set('i', '<C-p>', completion_key('<C-p>', '<C-p>'), {
                expr = true,
                silent = true,
                desc = 'Select previous completion item',
            })
            vim.keymap.set({ 'i', 's' }, '<CR>', function()
                if vim.fn.pumvisible() == 0 then
                    return '<CR>'
                end
                if vim.fn.complete_info({ 'selected' }).selected == -1 then
                    return '<C-e><CR>'
                end
                return '<C-y>'
            end, {
                expr = true,
                silent = true,
                desc = 'Confirm completion or insert newline',
            })

            require('mason-lspconfig').setup(opts)
        end,
    },
}
