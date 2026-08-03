return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    cmd = { "RenderMarkdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<leader>um",
        "<cmd>RenderMarkdown buf_toggle<CR>",
        desc = "UI: toggle Markdown rendering",
      },
    },
    opts = {
      completions = {
        blink = { enabled = true },
      },
      overrides = {
        buftype = {
          nofile = {
            -- LSP Hover is an interactive rendered view. Keep it stable when
            -- focused instead of revealing raw Markdown around the cursor;
            -- links expose their URL through the cursor-aware float footer.
            anti_conceal = { enabled = false },
          },
        },
      },
    },
  },
}
