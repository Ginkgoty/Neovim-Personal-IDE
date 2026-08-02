return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerRun",
      "OverseerShell",
      "OverseerTaskAction",
    },
    keys = {
      {
        "<leader>rr",
        function()
          require("config.tasks").select_task()
        end,
        desc = "Run: search project tasks",
      },
      {
        "<leader>rc",
        function()
          require("config.task_templates").create()
        end,
        desc = "Run: create/open tasks.json",
      },
      { "<leader>rt", "<cmd>OverseerToggle bottom<CR>", desc = "Run: toggle task list" },
      { "<leader>ra", "<cmd>OverseerTaskAction<CR>", desc = "Run: task action" },
      {
        "<leader>rl",
        function()
          require("config.tasks").restart_last()
        end,
        desc = "Run: restart latest task",
      },
      {
        "<leader>ro",
        function()
          require("config.tasks").open_last_output()
        end,
        desc = "Run: open latest output",
      },
      {
        "<leader>rs",
        function()
          require("config.tasks").stop_last_running()
        end,
        desc = "Run: stop latest running task",
      },
    },
    opts = {
      dap = true,
      output = {
        use_terminal = true,
        preserve_output = false,
      },
      task_list = {
        direction = "bottom",
        min_height = 8,
        max_height = { 20, 0.3 },
      },
    },
    config = function(_, opts)
      local overseer = require("overseer")
      overseer.setup(opts)
      require("config.tasks").setup(overseer)
    end,
    dependencies = { "nvim-telescope/telescope.nvim" },
  },
}
