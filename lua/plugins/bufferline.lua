return {
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        -- lazy = false -- prevent lazy loading!
        config = function()
            require('bufferline').setup {
                options = {
                    -- The bar represents open files, not windows or plugin
                    -- panels. Hide it when fewer than two files are open.
                    always_show_bufferline = false,
                    custom_filter = function(buf)
                        return require("config.buffers").is_file(buf)
                    end,
                    close_command = function(buf)
                        require("config.buffers").close(buf)
                    end,
                    right_mouse_command = function(buf)
                        require("config.buffers").close(buf)
                    end,
                    name_formatter = function(buf)
                        local options = vim.bo[buf.bufnr]
                        if options.readonly or not options.modifiable then
                            return " " .. buf.name
                        end
                        return buf.name
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
