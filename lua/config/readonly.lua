local M = {}

local compiled = { include = {}, exclude = {} }
local runtime_paths = {}
local discovered_roots = {}
local discovery_requests = {}
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

local function canonical(path)
  path = normalize(path)
  return normalize(vim.uv.fs_realpath(path) or path)
end

local function append(target, value)
  if value and value ~= "" then
    target[#target + 1] = normalize(value)
  end
end

local function system_patterns()
  local patterns = {}
  if vim.fn.has "macunix" == 1 then
    append(patterns, "/Applications/Xcode.app/**")
    append(patterns, "/Library/Developer/CommandLineTools/**")
    append(patterns, "/System/Library/Frameworks/**")
    append(patterns, "/usr/include/**")
    append(patterns, "/opt/homebrew/Cellar/**/include/**")
    append(patterns, "/usr/local/Cellar/**/include/**")
  elseif vim.fn.has "win32" == 1 then
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
  local data = normalize(vim.fn.stdpath "data")
  return {
    data .. "/mason/packages/**",
    data .. "/nvim-java/packages/**",
  }
end

local function compile(patterns, kind, reason)
  local result = {}
  for _, pattern in ipairs(patterns) do
    local normalized = normalize(pattern)
    local ok, matcher = pcall(vim.glob.to_lpeg, normalized)
    if ok then
      result[#result + 1] = {
        matcher = matcher,
        pattern = normalized,
        reason = reason,
      }
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
  for _, entry in ipairs(matchers) do
    if entry.matcher:match(path) then
      return entry
    end
  end
  return nil
end

local function contains(root, path)
  return path == root or vim.startswith(path, root .. "/")
end

local function candidate_paths(path)
  local logical = normalize(path)
  local real = canonical(logical)
  return logical == real and { logical } or { logical, real }
end

local function matches_runtime_path(paths)
  if settings.protect_python_environments == false then
    return nil
  end

  for root in pairs(runtime_paths) do
    for _, path in ipairs(paths) do
      if contains(root, path) then
        return {
          reason = "Python environment",
          root = root,
        }
      end
    end
  end

  -- Avoid an activation/autocmd ordering gap when opening a package file
  -- immediately after cached environment restoration.
  local selector = package.loaded["venv-selector"]
  if selector and type(selector.venv) == "function" then
    local root = selector.venv()
    if root and root ~= "" then
      root = canonical(root):gsub("/+$", "")
      for _, path in ipairs(paths) do
        if contains(root, path) then
          return {
            reason = "Python environment",
            root = root,
          }
        end
      end
    end
  end
  return nil
end

local function root_enabled(entry)
  if entry.kind == "language_toolchain" then
    return settings.protect_language_toolchains ~= false
  end
  if entry.kind == "dependency_cache" then
    return settings.protect_dependency_caches ~= false
  end
  return true
end

local function matches_discovered_root(paths)
  local best
  for _, entry in pairs(discovered_roots) do
    if root_enabled(entry) then
      for _, path in ipairs(paths) do
        if
          (contains(entry.root, path) or contains(entry.real_root, path))
          and (not best or #entry.root > #best.root)
        then
          best = entry
        end
      end
    end
  end
  return best
end

local function load_settings()
  settings = require("config.settings").readonly or {}
  compiled.include = compile(settings.include or {}, "include", "Configured include")
  if settings.protect_system_paths ~= false then
    vim.list_extend(compiled.include, compile(system_patterns(), "include", "System SDK or toolchain"))
  end
  if settings.protect_package_paths ~= false then
    vim.list_extend(compiled.include, compile(package_patterns(), "include", "Neovim-managed package"))
  end
  compiled.exclude = compile(settings.exclude or {}, "exclude")
end

function M.match(path)
  if not settings or settings.enabled == false or path == "" then
    return nil
  end

  local paths = candidate_paths(path)
  for _, candidate in ipairs(paths) do
    if matches(compiled.exclude, candidate) then
      return nil
    end
  end

  local root_match = matches_discovered_root(paths) or matches_runtime_path(paths)
  if root_match then
    return root_match
  end

  for _, candidate in ipairs(paths) do
    local entry = matches(compiled.include, candidate)
    if entry then
      return {
        reason = entry.reason,
        root = entry.pattern,
      }
    end
  end

  if vim.fn.has "win32" == 1 and settings.protect_system_paths ~= false then
    local context = require("config.platform").standard_header_context(paths[#paths])
    if context then
      return {
        reason = "System compiler header",
        root = context.root,
      }
    end
  end
  return nil
end

function M.should_lock(path)
  return M.match(path) ~= nil
end

function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" or vim.b[bufnr].readonly_unlocked then
    return
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local match = M.match(path)
  if not match then
    return
  end

  vim.bo[bufnr].readonly = true
  if settings.lock_modifications ~= false then
    vim.bo[bufnr].modifiable = false
  end
  vim.b[bufnr].readonly_managed = true
  vim.b[bufnr].readonly_reason = match.reason
  vim.b[bufnr].readonly_root = match.root
end

local function refresh_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.apply(bufnr)
  end
  vim.cmd.redrawtabline()
end

local function register_root(path, kind, reason)
  if not path or path == "" then
    return false
  end

  local root = normalize(path):gsub("/+$", "")
  local real_root = canonical(root):gsub("/+$", "")
  local key = table.concat({ kind, root, real_root, reason }, "\0")
  if discovered_roots[key] then
    return false
  end

  discovered_roots[key] = {
    kind = kind,
    reason = reason,
    root = root,
    real_root = real_root,
  }
  return true
end

local function command_cwd(cwd)
  cwd = cwd and cwd ~= "" and normalize(cwd) or normalize(vim.fn.getcwd())
  local stat = vim.uv.fs_stat(cwd)
  return stat and stat.type == "directory" and cwd or nil
end

local function discover_command(key, command, cwd, callback)
  cwd = command_cwd(cwd)
  key = key .. ":" .. (cwd or "")
  if discovery_requests[key] then
    return
  end

  local executable = vim.fn.exepath(command[1])
  if executable == "" then
    discovery_requests[key] = true
    return
  end

  discovery_requests[key] = true
  command = vim.deepcopy(command)
  command[1] = executable
  local options = { text = true }
  if cwd then
    options.cwd = cwd
  end
  vim.system(command, options, function(result)
    vim.schedule(function()
      if result.code == 0 then
        callback(result.stdout or "")
      end
    end)
  end)
end

local function discover_rust(cwd)
  local changed = false
  if settings.protect_dependency_caches ~= false then
    local cargo_home = vim.env.CARGO_HOME
    if not cargo_home or cargo_home == "" then
      cargo_home = (vim.uv.os_homedir() or "") .. "/.cargo"
    end
    changed = register_root(cargo_home .. "/registry/src", "dependency_cache", "Cargo registry cache") or changed
    changed = register_root(cargo_home .. "/git/checkouts", "dependency_cache", "Cargo Git checkout cache") or changed
  end
  if changed then
    refresh_buffers()
  end

  if settings.protect_language_toolchains == false then
    return
  end
  discover_command("rust-sysroot", { "rustc", "--print", "sysroot" }, cwd, function(output)
    local sysroot = vim.trim(output)
    if
      sysroot ~= ""
      and register_root(sysroot .. "/lib/rustlib/src/rust/library", "language_toolchain", "Rust standard library")
    then
      refresh_buffers()
    end
  end)
end

local function discover_go(cwd)
  if settings.protect_language_toolchains == false and settings.protect_dependency_caches == false then
    return
  end
  discover_command("go-environment", { "go", "env", "-json", "GOROOT", "GOMODCACHE" }, cwd, function(output)
    local ok, environment = pcall(vim.json.decode, output)
    if not ok or type(environment) ~= "table" then
      return
    end

    local changed = false
    if settings.protect_language_toolchains ~= false then
      changed = register_root(
        environment.GOROOT and environment.GOROOT .. "/src",
        "language_toolchain",
        "Go standard library"
      ) or changed
    end
    if settings.protect_dependency_caches ~= false then
      changed = register_root(environment.GOMODCACHE, "dependency_cache", "Go module cache") or changed
    end
    if changed then
      refresh_buffers()
    end
  end)
end

function M.discover_language_paths(cwd, language)
  if language == nil or language == "rust" or language == "rust_analyzer" then
    discover_rust(cwd)
  end
  if language == nil or language == "go" or language == "gopls" then
    discover_go(cwd)
  end
end

-- Add an exact runtime-owned directory such as the environment selected by
-- venv-selector.nvim. Keep paths for the session so files from an environment
-- remain protected after switching projects or interpreters.
function M.protect_runtime_path(path)
  if not path or path == "" then
    return
  end
  path = canonical(path):gsub("/+$", "")
  if runtime_paths[path] then
    return
  end

  runtime_paths[path] = true
  load_settings()
  refresh_buffers()
end

local function unlock(bufnr)
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true
  vim.b[bufnr].readonly_managed = false
  vim.b[bufnr].readonly_unlocked = true
  vim.b[bufnr].readonly_reason = nil
  vim.b[bufnr].readonly_root = nil
  vim.cmd.redrawtabline()
end

local function lock(bufnr)
  vim.b[bufnr].readonly_unlocked = false
  vim.bo[bufnr].readonly = true
  if settings.lock_modifications ~= false then
    vim.bo[bufnr].modifiable = false
  end
  vim.b[bufnr].readonly_managed = true
  vim.cmd.redrawtabline()
end

function M.reload()
  package.loaded["config.settings"] = nil
  local core_options = package.loaded["core.options"]
  if core_options then
    core_options.apply_user_settings()
  end
  local diagnostics = package.loaded["config.diagnostics"]
  if diagnostics then
    diagnostics.setup()
  end
  local ui_highlights = package.loaded["config.ui_highlights"]
  if ui_highlights then
    ui_highlights.refresh()
  end
  discovery_requests = {}
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
  M.discover_language_paths(vim.fn.getcwd())
  vim.notify("Global settings reloaded", vim.log.levels.INFO, { title = "Settings" })
end

function M.setup()
  load_settings()

  local group = vim.api.nvim_create_augroup("readonly_paths", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufFilePost", "BufEnter" }, {
    group = group,
    callback = function(args)
      M.apply(args.buf)
    end,
    desc = "Protect configured read-only paths",
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or (client.name ~= "rust_analyzer" and client.name ~= "gopls") then
        return
      end

      local root = client.config.root_dir
      if type(root) ~= "string" or root == "" then
        root = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf))
      end
      M.discover_language_paths(root, client.name)
    end,
    desc = "Discover workspace language toolchain paths",
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
    local match = M.match(path)
    vim.notify(
      ("Path: %s\nConfigured match: %s\nReason: %s\nRoot: %s\nManaged lock: %s\nUnlocked: %s"):format(
        path,
        match ~= nil,
        match and match.reason or "none",
        match and match.root or "none",
        vim.b[bufnr].readonly_managed == true,
        vim.b[bufnr].readonly_unlocked == true
      ),
      vim.log.levels.INFO,
      { title = "Read-only" }
    )
  end, { desc = "Show read-only status for the current buffer" })

  vim.api.nvim_create_user_command("SettingsReload", M.reload, {
    desc = "Reload global settings",
  })

  M.discover_language_paths(vim.fn.getcwd())
end

return M
