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
    config = function(_, opts)
      require("uv").setup(opts)
      -- uv.nvim's keymap descriptions match none of which-key's built-in
      -- icon rules. Its keymaps are registered globally together with this
      -- setup call, so icon-only entries are safe here.
      local python_icon = { cat = "filetype", name = "python" }
      require("which-key").add({
        { "<leader>ps", icon = python_icon, mode = { "n", "v" } },
        { "<leader>pf", icon = python_icon },
        { "<leader>pi", icon = python_icon },
        { "<leader>pa", icon = python_icon },
        { "<leader>pd", icon = python_icon },
        { "<leader>pc", icon = python_icon },
        { "<leader>pC", icon = python_icon },
      })
    end,
  },
}
