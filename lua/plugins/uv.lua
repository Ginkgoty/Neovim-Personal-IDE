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
    config = function(_, opts)
      -- uv.nvim hardcodes the Unix venv layout ("bin" joined with ":"). On
      -- Windows that corrupts PATH and makes Mason shims unresolvable, which
      -- prevents every LSP server from starting. Patch activation to use the
      -- Windows layout ("Scripts" joined with ";"). This must happen before
      -- setup() because setup auto-activates the project venv immediately.
      local uv = require("uv")
      if require("config.platform").is_windows then
        function uv.activate_venv(venv_path)
          vim.env.VIRTUAL_ENV = venv_path
          vim.env.PATH = venv_path .. "/Scripts;" .. vim.env.PATH
          if uv.config.notify_activate_venv then
            vim.notify("Activated virtual environment: " .. venv_path, vim.log.levels.INFO)
          end
        end
      end

      uv.setup(opts)
    end,
  },
}
