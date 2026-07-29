local platform = require('config.platform')
local windows_toolchain = platform.windows_c_toolchain()

return {
    'nvim-telescope/telescope.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim',
        {
            'nvim-telescope/telescope-fzf-native.nvim',
            enabled = not platform.is_windows or windows_toolchain ~= nil,
            build = platform.is_windows and function(plugin)
                platform.build_windows_cmake(plugin.dir)
            end or 'make',
        },
    },
    config = function()
        local ok = pcall(require('telescope').load_extension, 'fzf')
        if not ok then
            vim.notify('telescope-fzf-native is unavailable; using the built-in sorter', vim.log.levels.WARN)
        end
    end
}
