local languages = require "config.languages"

local function environment_info()
  local selector = require "venv-selector"
  local python = selector.python()
  local environment = selector.venv()

  if not python or python == "" then
    vim.notify(
      "No Python interpreter is selected. Use <leader>pe to select one.",
      vim.log.levels.WARN,
      { title = "Python environment" }
    )
    return
  end

  local clients = {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
    if client.name == "ty" or client.name == "ruff" then
      clients[#clients + 1] = client.name
    end
  end
  table.sort(clients)

  vim.notify(
    table.concat({
      "Interpreter: " .. python,
      "Environment: " .. (environment or "unknown"),
      "Python LSP: " .. (#clients > 0 and table.concat(clients, ", ") or "not attached"),
    }, "\n"),
    vim.log.levels.INFO,
    { title = "Python environment" }
  )
end

return {
  {
    "linux-cultist/venv-selector.nvim",
    enabled = languages.enabled "python" and languages.available "python",
    version = false,
    ft = "python",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      { "<leader>pe", "<cmd>VenvSelect<cr>", desc = "Python: select interpreter" },
      { "<leader>pE", environment_info, desc = "Python: environment info" },
    },
    opts = function()
      local settings = require("config.settings").python or {}
      local environment = settings.environment or {}
      return {
        options = {
          enable_cached_venvs = true,
          cached_venv_automatic_activation = environment.auto_restore ~= false,
          activate_venv_in_terminal = true,
          set_environment_variables = true,
          notify_user_on_venv_activation = environment.notify ~= false,
          require_lsp_activation = true,
          picker = environment.picker or "telescope",
          on_venv_activate_callback = function()
            local selector = require "venv-selector"
            require("config.readonly").protect_runtime_path(selector.venv())
          end,
        },
      }
    end,
    config = function(_, opts)
      local selector = require "venv-selector"
      selector.setup(opts)

      -- Cached activation can complete through more than one upstream path.
      -- Register the currently selected environment after setup and whenever
      -- entering a Python buffer, in addition to the activation callback.
      local function protect_selected_environment()
        require("config.readonly").protect_runtime_path(selector.venv())
      end
      local group = vim.api.nvim_create_augroup("python_environment_readonly", { clear = true })
      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "*.py",
        callback = function()
          vim.schedule(protect_selected_environment)
        end,
        desc = "Protect the selected Python environment",
      })
      vim.schedule(protect_selected_environment)
    end,
  },
}
