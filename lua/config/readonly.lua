local M = {}

local compiled = { include = {}, exclude = {} }
local settings

local function normalize(path)
  local home = vim.uv.os_homedir() or ""
  path = path:gsub("^~", home)
  path = path:gsub("%${([%w_]+)}", function(name)
    return vim.env[name] or ""
  end)
  path = path:gsub("%$([%w_]+)", function(name)
    return vim.env[name] or ""
  end)
  path = path:gsub("%%([%w_]+)%%", function(name)
    return vim.env[name] or ""
  end)
  return vim.fs.normalize(path):gsub("\\", "/")
end

local function append(target, value)
  if value and value ~= "" then
    target[#target + 1] = normalize(value)
  end
end

local function system_patterns()
  local patterns = {}
  if vim.fn.has("macunix") == 1 then
    append(patterns, "/Applications/Xcode.app/**")
    append(patterns, "/Library/Developer/CommandLineTools/**")
    append(patterns, "/System/Library/Frameworks/**")
    append(patterns, "/usr/include/**")
    append(patterns, "/opt/homebrew/Cellar/**/include/**")
    append(patterns, "/usr/local/Cellar/**/include/**")
  elseif vim.fn.has("win32") == 1 then
    local program_files = vim.env.ProgramFiles
    local program_files_x86 = vim.env["ProgramFiles(x86)"]
    if program_files then
      append(patterns, program_files .. "/Microsoft Visual Studio/**/VC/Tools/MSVC/**/include/**")
      append(patterns, program_files .. "/Windows Kits/**/Include/**")
    end
    if program_files_x86 then
      append(patterns, program_files_x86 .. "/Microsoft Visual Studio/**/VC/Tools/MSVC/**/include/**")
      append(patterns, program_files_x86 .. "/Windows Kits/**/Include/**")
    end
  else
    append(patterns, "/usr/include/**")
    append(patterns, "/usr/local/include/**")
    append(patterns, "/usr/lib/gcc/**")
    append(patterns, "/usr/lib/llvm-*/**")
  end
  return patterns
end

local function package_patterns()
  local data = normalize(vim.fn.stdpath("data"))
  return {
    data .. "/mason/packages/**",
    data .. "/nvim-java/packages/**",
  }
end

local function compile(patterns, kind)
  local result = {}
  for _, pattern in ipairs(patterns) do
    local normalized = normalize(pattern)
    local ok, matcher = pcall(vim.glob.to_lpeg, normalized)
    if ok then
      result[#result + 1] = matcher
    else
      vim.notify(
        ("Invalid readonly %s glob %q: %s"):format(kind, pattern, matcher),
        vim.log.levels.ERROR,
        { title = "Settings" }
      )
    end
  end
  return result
end

local function matches(matchers, path)
  for _, matcher in ipairs(matchers) do
    if matcher:match(path) then
      return true
    end
  end
  return false
end

local function load_settings()
  settings = require("config.settings").readonly or {}
  local include = vim.deepcopy(settings.include or {})
  if settings.protect_system_paths ~= false then
    vim.list_extend(include, system_patterns())
  end
  if settings.protect_package_paths ~= false then
    vim.list_extend(include, package_patterns())
  end
  compiled.include = compile(include, "include")
  compiled.exclude = compile(settings.exclude or {}, "exclude")
end

function M.should_lock(path)
  if not settings or settings.enabled == false or path == "" then
    return false
  end
  path = normalize(path)
  return not matches(compiled.exclude, path) and matches(compiled.include, path)
end

function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr)
      or vim.bo[bufnr].buftype ~= ""
      or vim.b[bufnr].readonly_unlocked then
    return
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if not M.should_lock(path) then
    return
  end

  vim.bo[bufnr].readonly = true
  if settings.lock_modifications ~= false then
    vim.bo[bufnr].modifiable = false
  end
  vim.b[bufnr].readonly_managed = true
end

local function unlock(bufnr)
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true
  vim.b[bufnr].readonly_managed = false
  vim.b[bufnr].readonly_unlocked = true
end

local function lock(bufnr)
  vim.b[bufnr].readonly_unlocked = false
  vim.bo[bufnr].readonly = true
  if settings.lock_modifications ~= false then
    vim.bo[bufnr].modifiable = false
  end
  vim.b[bufnr].readonly_managed = true
end

function M.reload()
  package.loaded["config.settings"] = nil
  load_settings()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      if vim.b[bufnr].readonly_managed then
        unlock(bufnr)
        vim.b[bufnr].readonly_unlocked = false
      end
      M.apply(bufnr)
    end
  end
  vim.notify("Global settings reloaded", vim.log.levels.INFO, { title = "Settings" })
end

function M.setup()
  load_settings()

  local group = vim.api.nvim_create_augroup("readonly_paths", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufFilePost" }, {
    group = group,
    callback = function(args)
      M.apply(args.buf)
    end,
    desc = "Protect configured read-only paths",
  })

  vim.api.nvim_create_user_command("ReadonlyUnlock", function()
    unlock(vim.api.nvim_get_current_buf())
  end, { desc = "Temporarily unlock the current buffer" })

  vim.api.nvim_create_user_command("ReadonlyLock", function()
    lock(vim.api.nvim_get_current_buf())
  end, { desc = "Lock the current buffer" })

  vim.api.nvim_create_user_command("ReadonlyInfo", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(bufnr)
    vim.notify(("Path: %s\nConfigured match: %s\nManaged lock: %s\nUnlocked: %s"):format(
      path,
      M.should_lock(path),
      vim.b[bufnr].readonly_managed == true,
      vim.b[bufnr].readonly_unlocked == true
    ), vim.log.levels.INFO, { title = "Read-only" })
  end, { desc = "Show read-only status for the current buffer" })

  vim.api.nvim_create_user_command("SettingsReload", M.reload, {
    desc = "Reload global settings",
  })
end

return M
