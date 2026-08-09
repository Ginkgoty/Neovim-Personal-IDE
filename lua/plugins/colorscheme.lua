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
        vim.o.background = "light"
        vim.cmd.colorscheme("github_light_default")
      end, { desc = "Use GitHub Light" })

      vim.api.nvim_create_user_command("ThemePaperColor", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("PaperColor")
      end, { desc = "Use PaperColor Light" })

      vim.api.nvim_create_user_command("ThemePaperColorDark", function()
        vim.o.background = "dark"
        vim.cmd.colorscheme("PaperColor")
      end, { desc = "Use PaperColor Dark" })

      vim.api.nvim_create_user_command("ThemePaper", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("paper")
      end, { desc = "Use Paper" })

      vim.api.nvim_create_user_command("ThemeXcode", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("xcodelight")
      end, { desc = "Use Xcode Light" })

      vim.api.nvim_create_user_command("ThemeDuotone", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("base2tone_morning_light")
      end, { desc = "Use DuoTone Morning Light" })

      vim.api.nvim_create_user_command("ThemeMdnLike", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("mdn-like")
      end, { desc = "Use MDN-like Light" })

      vim.api.nvim_create_user_command("ThemeSolarized", function()
        vim.o.background = "light"
        vim.cmd.colorscheme("solarized")
      end, { desc = "Use Solarized Light" })

      vim.api.nvim_create_user_command("ThemeOxocarbon", function()
        vim.o.background = "dark"
        vim.cmd.colorscheme("oxocarbon")
      end, { desc = "Use Oxocarbon Dark" })

      vim.api.nvim_create_user_command("ThemeAyu", function()
        vim.o.background = "dark"
        vim.cmd.colorscheme("ayu-dark")
      end, { desc = "Use Ayu Dark" })

    end,
  },
  {
    "NLKNguyen/papercolor-theme",
    name = "papercolor-theme",
    lazy = false,
    priority = 999,
  },
  {
    "yorickpeterse/vim-paper",
    name = "vim-paper",
    lazy = false,
    priority = 999,
  },
  {
    "lunacookies/vim-colors-xcode",
    lazy = false,
    priority = 999,
  },
  {
    "atelierbram/Base2Tone-nvim",
    name = "base2tone-nvim",
    lazy = false,
    priority = 999,
  },
  {
    "maxmx03/solarized.nvim",
    name = "solarized.nvim",
    lazy = false,
    priority = 999,
    opts = {
      palette = "solarized",
      variant = "winter",
    },
    config = function(_, opts)
      require("solarized").setup(opts)
    end,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 999,
  },
  {
    "Shatur/neovim-ayu",
    name = "neovim-ayu",
    lazy = false,
    priority = 999,
    config = function()
      require("ayu").setup({})
    end,
  },
}
