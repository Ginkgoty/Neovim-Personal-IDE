return {
    {
        -- lazy.nvim
        "m4xshen/hardtime.nvim",
        dependencies = { "MunifTanjim/nui.nvim" },
        opts = {
            -- Navigation should stay comfortable. Hardtime can still suggest
            -- better operators and motions without blocking directional keys.
            restricted_keys = {
                ["h"] = false,
                ["j"] = false,
                ["k"] = false,
                ["l"] = false,
            },
            disabled_keys = {
                ["<Up>"] = false,
                ["<Down>"] = false,
                ["<Left>"] = false,
                ["<Right>"] = false,
            },
        },

        config = function(_, opts)
            require("hardtime").setup(opts)
        end
    },
}
