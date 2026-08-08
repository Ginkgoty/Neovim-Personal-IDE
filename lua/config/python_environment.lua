local M = {}

local supported_targets = {}

local function command_output(command, timeout)
  local ok, result = pcall(function()
    return vim.system(command, { text = true }):wait(timeout or 2000)
  end)
  if not ok or not result or result.code ~= 0 then return nil end
  return vim.trim(result.stdout or "")
end

local function selected_python(config)
  local ok, selector = pcall(require, "venv-selector")
  if ok then
    local python = selector.python()
    if type(python) == "string" and python ~= "" and vim.fn.executable(python) == 1 then
      return python
    end
  end

  local env = config.cmd_env or {}
  local prefix = env.VIRTUAL_ENV or env.CONDA_PREFIX
  if type(prefix) ~= "string" or prefix == "" then return nil end
  local candidates = require("config.platform").is_windows
      and { vim.fs.joinpath(prefix, "Scripts", "python.exe"), vim.fs.joinpath(prefix, "python.exe") }
    or { vim.fs.joinpath(prefix, "bin", "python"), vim.fs.joinpath(prefix, "bin", "python3") }
  for _, candidate in ipairs(candidates) do
    if vim.fn.executable(candidate) == 1 then return candidate end
  end
end

local function python_target(python)
  if not python then return nil end
  local target = command_output({
    python,
    "-c",
    "import sys; print(f'py{sys.version_info.major}{sys.version_info.minor}')",
  })
  return target and target:match("^py%d%d+$") and target or nil
end

local function ruff_command(config)
  local command = type(config.cmd) == "table" and config.cmd[1] or "ruff"
  local executable = vim.fn.exepath(command)
  return executable ~= "" and executable or command
end

local function ruff_supports(command, target)
  if not target then return false end
  if supported_targets[command] == nil then
    local output = command_output({ command, "config", "target-version", "--output-format", "json" })
    local ok, decoded = pcall(vim.json.decode, output or "")
    supported_targets[command] = ok and type(decoded) == "table" and decoded.value_type or false
  end
  local description = supported_targets[command]
  return type(description) == "string" and description:find('"' .. target .. '"', 1, true) ~= nil
end

local function remove_managed_fallback(config)
  if not config._nvim_ruff_venv_fallback then return end
  local settings = config.init_options and config.init_options.settings
  local configuration = settings and settings.configuration
  if type(configuration) == "table" then
    configuration["target-version"] = nil
    if vim.tbl_isempty(configuration) then settings.configuration = nil end
  end
  config._nvim_ruff_venv_fallback = nil
end

-- Ruff does not infer a target version from VIRTUAL_ENV. Supply the selected
-- interpreter only as an editor fallback. `filesystemFirst` guarantees that a
-- project target-version or project.requires-python remains authoritative.
function M.ruff_before_init(params, config)
  remove_managed_fallback(config)
  config.init_options = config.init_options or {}
  config.init_options.settings = config.init_options.settings or {}
  local settings = config.init_options.settings
  settings.configurationPreference = "filesystemFirst"

  local target = python_target(selected_python(config))
  if not target or not ruff_supports(ruff_command(config), target) then
    params.initializationOptions = vim.deepcopy(config.init_options)
    return
  end

  -- Respect an explicit editor configuration as well. A configuration path or
  -- an explicit inline target is authoritative; unrelated inline options can
  -- safely receive the fallback and are preserved when it is later removed.
  if type(settings.configuration) == "string" then
    params.initializationOptions = vim.deepcopy(config.init_options)
    return
  end
  if settings.configuration == nil then settings.configuration = {} end
  if type(settings.configuration) ~= "table"
      or settings.configuration["target-version"] ~= nil then
    params.initializationOptions = vim.deepcopy(config.init_options)
    return
  end
  settings.configuration["target-version"] = target
  config._nvim_ruff_venv_fallback = true
  -- Neovim constructs initialize params before invoking before_init. Update
  -- both objects so the current client and any later restart see the fallback.
  params.initializationOptions = vim.deepcopy(config.init_options)
end

return M
