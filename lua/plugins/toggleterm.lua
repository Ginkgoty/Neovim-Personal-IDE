return {
    {
        'akinsho/toggleterm.nvim',
        version = "*",
        opts = {
            -- Resolved per terminal so :SettingsReload applies to new terminals.
            shell = function()
                return require('config.terminal').shell()
            end,
        },
    }
}
