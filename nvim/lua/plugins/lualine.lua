return {
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        -- lazy = false, -- prevent lazy loading
        config = function()
            require('lualine').setup {
                options = {
                    theme = 'powerline',
                }
            }
        end
    }
}
