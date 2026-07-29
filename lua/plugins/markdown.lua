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
        coq = { enabled = true },
      },
    },
  },
}
