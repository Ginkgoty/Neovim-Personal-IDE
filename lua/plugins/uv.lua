local languages = require("config.languages")

return {
  {
    "benomahony/uv.nvim",
    enabled = languages.enabled("python"),
    ft = { "python" },
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      -- Interpreter discovery and activation belong to venv-selector.nvim.
      -- uv.nvim remains the project/package runner only.
      auto_activate_venv = false,
      picker_integration = true,
      keymaps = {
        -- <leader>x belongs to Diagnostics in this configuration.
        prefix = "<leader>p",
        -- Reserve <leader>pe for the unified interpreter selector.
        venv = false,
      },
    },
  },
}
