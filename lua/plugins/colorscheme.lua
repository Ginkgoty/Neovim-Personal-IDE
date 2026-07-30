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

      vim.api.nvim_create_user_command("ThemeXcode", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("xcode")
      end, { desc = "Use Xcode Light" })
    end,
  },
  {
    "lsdrfrx/xcode-theme.nvim",
    name = "xcode-theme",
    lazy = false,
    priority = 999,
  },
}
