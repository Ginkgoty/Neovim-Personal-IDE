return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local explorer = require("config.settings").explorer or {}
    require("nvim-tree").setup {
      filters = {
        -- Controlled by explorer.show_git_ignored in lua/config/settings.lua.
        -- Press I in the tree to toggle this filter at runtime.
        git_ignored = explorer.show_git_ignored == false,
      },
      renderer = {
        icons = {
          glyphs = {
            -- VSCode-style git status letters instead of abstract symbols.
            git = {
              unstaged = "M",
              staged = "A",
              unmerged = "C",
              renamed = "R",
              untracked = "U",
              deleted = "D",
              ignored = "I",
            },
          },
        },
      },
    }

    require("config.sidebar").register("explorer", {
      find_window = function(tab)
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
            return win
          end
        end
      end,
      open = function()
        local buf = vim.api.nvim_get_current_buf()
        local path = vim.api.nvim_buf_get_name(buf)
        if vim.bo[buf].buftype == "" and path ~= "" then
          vim.cmd.NvimTreeFindFile()
        else
          vim.cmd.NvimTreeOpen()
        end
      end,
      close = function()
        vim.cmd.NvimTreeClose()
      end,
    })
  end
}
