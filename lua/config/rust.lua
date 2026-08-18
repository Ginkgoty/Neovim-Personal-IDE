local platform = require "config.platform"
local M = {}

local function executable_file(path)
  local stat = path and path ~= "" and vim.uv.fs_stat(path) or nil
  return stat and stat.type == "file"
end

local function active_sysroot_analyzer(root_dir)
  local rustc = vim.fn.exepath "rustc"
  if rustc == "" then
    return nil
  end

  -- rustc is the source of truth for the active workspace toolchain. This
  -- follows rustup overrides when present, but also works unchanged with
  -- Scoop, Homebrew, system packages, or a manually installed toolchain.
  local ok, process = pcall(vim.system, { rustc, "--print", "sysroot" }, {
    cwd = root_dir,
    text = true,
  })
  if not ok then
    return nil
  end
  local result = process:wait()
  local sysroot = result.code == 0 and vim.trim(result.stdout or "") or ""
  if sysroot == "" then
    return nil
  end

  local path = vim.fs.joinpath(sysroot, "bin", platform.executable "rust-analyzer")
  return executable_file(path) and path or nil
end

local function path_analyzer(root_dir)
  local path = vim.fn.exepath "rust-analyzer"
  if not executable_file(path) then
    return nil
  end

  -- A rustup proxy can exist even when its component is absent. Verify the
  -- candidate before selecting it so the Mason fallback remains usable.
  local ok, process = pcall(vim.system, { path, "--version" }, {
    cwd = root_dir,
    text = true,
  })
  if not ok then
    return nil
  end
  return process:wait().code == 0 and path or nil
end

local function mason_analyzer()
  local path = platform.mason_package("rust-analyzer", platform.executable "rust-analyzer")
  return executable_file(path) and path or nil
end

function M.cmd(root_dir)
  root_dir = root_dir or vim.fn.getcwd()

  local path = active_sysroot_analyzer(root_dir)
  if path then
    return { path }, "active Rust sysroot"
  end

  path = path_analyzer(root_dir)
  if path then
    return { path }, "PATH"
  end

  path = mason_analyzer()
  if path then
    return { path }, "Mason fallback"
  end

  return { "rust-analyzer" }, "PATH fallback"
end

function M.start(dispatchers, config)
  local cmd, source = M.cmd(config.root_dir)
  config._resolved_cmd = cmd
  config._rust_analyzer_source = source
  return vim.lsp.rpc.start(cmd, dispatchers, {
    -- The working directory determines project-local toolchain selection for
    -- cargo/rustc processes spawned by rust-analyzer.
    cwd = config.root_dir or config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })
end

return M
