return {
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        -- lazy = false -- prevent lazy loading!
        config = function()
            local title_highlight = "NvimSidebarTitle"

            local function sidebar_offset(filetype, text)
                return {
                    filetype = filetype,
                    text = text,
                    highlight = title_highlight,
                    text_align = "center",
                    separator = true,
                }
            end

            local function refresh_sidebar_title_highlight()
                local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
                local fill = vim.api.nvim_get_hl(0, { name = "BufferLineFill", link = false })
                vim.api.nvim_set_hl(0, title_highlight, {
                    fg = normal.fg,
                    bg = fill.bg or normal.bg,
                    bold = true,
                })
            end

            require('bufferline').setup {
                options = {
                    -- Keep the editor tab visible even when only one file is open.
                    always_show_bufferline = true,
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
                        sidebar_offset("NvimTree", "File Explorer"),
                        sidebar_offset("grug-far", "Search & Replace"),
                        -- The DAP sidebar is one column of four stacked
                        -- windows. Bufferline offsets must target the topmost
                        -- window of that column; Variables is our fixed anchor.
                        sidebar_offset("dapui_scopes", "Run & Debug"),
                    },
                }
            }

            refresh_sidebar_title_highlight()
            vim.api.nvim_create_autocmd("ColorScheme", {
                group = vim.api.nvim_create_augroup("SidebarTitleThemeSync", { clear = true }),
                desc = "Keep sidebar titles readable after changing theme",
                callback = function()
                    vim.schedule(refresh_sidebar_title_highlight)
                end,
            })
        end
    }
}
