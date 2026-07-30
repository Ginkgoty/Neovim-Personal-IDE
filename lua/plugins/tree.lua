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
  end
}
