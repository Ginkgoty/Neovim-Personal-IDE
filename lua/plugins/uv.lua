local languages = require("config.languages")

return {
  {
    "benomahony/uv.nvim",
    enabled = languages.enabled("python"),
    ft = { "python" },
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      auto_activate_venv = true,
      picker_integration = true,
      keymaps = {
        -- <leader>x belongs to Diagnostics in this configuration.
        prefix = "<leader>p",
      },
    },
  },
}
