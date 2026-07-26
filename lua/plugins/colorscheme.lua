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

      vim.api.nvim_create_user_command("ThemeMacvim", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("macvim-light")
      end, { desc = "Use MacVim Light" })
    end,
  },
  {
    "gmist/vim-palette",
    name = "vim-palette",
    lazy = false,
    priority = 999,
  },
}
