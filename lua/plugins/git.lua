return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = false,
      current_line_blame_opts = { delay = 500 },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Git: next hunk")
        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Git: previous hunk")

        map("n", "<leader>ga", gs.stage_hunk, "Git: stage hunk")
        map("v", "<leader>ga", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Git: stage selected hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Git: reset hunk")
        map("v", "<leader>gr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Git: reset selected hunk")
        map("n", "<leader>gA", gs.stage_buffer, "Git: stage buffer")
        map("n", "<leader>gR", gs.reset_buffer, "Git: reset buffer")
        map("n", "<leader>gp", gs.preview_hunk, "Git: preview hunk")
        map("n", "<leader>gl", gs.blame_line, "Git: blame line")
        map("n", "<leader>gL", gs.toggle_current_line_blame, "Git: toggle line blame")
        map("n", "<leader>gd", gs.diffthis, "Git: diff against index")
        map("n", "<leader>gD", function() gs.diffthis("~") end, "Git: diff against HEAD")
        map({ "o", "x" }, "ih", gs.select_hunk, "Git: select hunk")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Git: current file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Git: repository history" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Git: close diff/history view" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = "diff2_horizontal" },
        file_history = { layout = "diff2_horizontal" },
      },
    },
  },
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      {
        "<leader>gg",
        function()
          require("neogit").open({ kind = "split" })
        end,
        desc = "Git: status UI",
      },
    },
    opts = {
      kind = "split",
      graph_style = "ascii",
      integrations = {
        diffview = true,
        telescope = true,
      },
    },
  },
}
