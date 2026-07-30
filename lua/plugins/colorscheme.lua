return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 1000,
    opts = {
      options = {
        styles = {
          comments = "italic",
        },
      },
    },
    config = function(_, opts)
      require("github-theme").setup(opts)
      vim.cmd.colorscheme("github_light_default")

      vim.api.nvim_create_user_command("ThemeGithub", function()
        vim.cmd.colorscheme("github_light_default")
      end, { desc = "Use GitHub Light" })

      vim.api.nvim_create_user_command("ThemePaperColor", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("PaperColor")
      end, { desc = "Use PaperColor Light" })

      vim.api.nvim_create_user_command("ThemeRosePine", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("rose-pine-dawn")
      end, { desc = "Use Rosé Pine Dawn" })

      vim.api.nvim_create_user_command("ThemePaper", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("paper")
      end, { desc = "Use Paper" })
    end,
  },
  {
    "NLKNguyen/papercolor-theme",
    name = "papercolor-theme",
    lazy = false,
    priority = 999,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 999,
  },
  {
    "yorickpeterse/vim-paper",
    name = "vim-paper",
    lazy = false,
    priority = 999,
  },
}
