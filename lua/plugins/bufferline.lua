return {
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        -- lazy = false -- prevent lazy loading!
        config = function()
            require('bufferline').setup {
                options = {
                    always_show_bufferline = true,
                    -- Never show the CodeCompanion chat as a tab.
                    custom_filter = function(buf)
                        return vim.bo[buf].filetype ~= "codecompanion"
                    end,
                    offsets = {
                        {
                            filetype = "NvimTree",
                            text = "File Explorer",  -- 你可以自定义这里的文本显示
                            highlight = "Directory",
                            text_align = "center",  -- 你可以选择文本对齐方式（"left", "center", "right"）
                            separator = true  -- 如果想要 separator 分隔符
                        }
                    },
                }
            }
        end
    }
}
