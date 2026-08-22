local M = {}

local minimum = {
  neovim = { 0, 12, 0 },
  git = { 2, 19, 0 },
  tree_sitter = { 0, 26, 1 },
}

local is_windows = package.config:sub(1, 1) == "\\"
local cached_report
local cached_python_venv

local function executable(names)
  for _, name in ipairs(names) do
    if vim.fn.executable(name) == 1 then
      return true, name
    end
  end
  return false
end

local function parse_version(text)
  local major, minor, patch = tostring(text or ""):match "(%d+)%.(%d+)%.?(%d*)"
  if not major then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) or 0 }
end

local function version_at_least(actual, wanted)
  if not actual then
    return false
  end
  for index = 1, 3 do
    if actual[index] ~= wanted[index] then
      return actual[index] > wanted[index]
    end
  end
  return true
end

local function command_version(command, arguments)
  if vim.fn.executable(command) ~= 1 then
    return nil
  end
  local argv = { command }
  vim.list_extend(argv, arguments or { "--version" })
  local output = vim.fn.system(argv)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return parse_version(output)
end

local function version_text(version)
  return table.concat(version, ".")
end

local function c_compiler_available()
  if not is_windows then
    return executable { "cc", "gcc", "clang" }
  end

  local direct = executable { "cl.exe", "clang.exe", "clang-cl.exe", "gcc.exe" }
  if direct then
    return true
  end

  -- The platform module also detects an MSVC installation through vswhere,
  -- even when cl.exe is intentionally absent from the ordinary user PATH.
  local ok, platform = pcall(require, "config.platform")
  return ok and platform.windows_c_toolchain() ~= nil
end

function M.python_with_venv(refresh)
  if cached_python_venv ~= nil and not refresh then
    return cached_python_venv
  end

  cached_python_venv = false
  for _, candidate in ipairs { "python3", "python3.exe", "python", "python.exe" } do
    if vim.fn.executable(candidate) == 1 then
      vim.fn.system { candidate, "-c", "import venv" }
      if vim.v.shell_error == 0 then
        cached_python_venv = true
        break
      end
    end
  end
  return cached_python_venv
end

local function dependency(level, name, available, purpose, hint)
  return {
    level = level,
    name = name,
    available = available == true,
    purpose = purpose,
    hint = hint,
  }
end

function M.report(refresh)
  if cached_report and not refresh then
    return cached_report
  end

  local nvim_version = { vim.version().major, vim.version().minor, vim.version().patch }
  local git_version = command_version "git"
  local tree_sitter_version = command_version "tree-sitter"
  local has_node = executable { "node", "node.exe" }
  local has_npm = executable { "npm", "npm.cmd" }

  local required = {
    dependency(
      "required",
      "Neovim >= " .. version_text(minimum.neovim),
      version_at_least(nvim_version, minimum.neovim),
      "run this configuration",
      "Install a current Neovim release."
    ),
    dependency(
      "required",
      "Git >= " .. version_text(minimum.git),
      version_at_least(git_version, minimum.git),
      "clone Lazy.nvim and plugins",
      "Install or update Git."
    ),
    dependency("required", "ripgrep (rg)", executable { "rg", "rg.exe" }, "search and replace", "Install ripgrep."),
    dependency("required", "curl", executable { "curl", "curl.exe" }, "download Tree-sitter parsers", "Install curl."),
    dependency(
      "required",
      "tar",
      executable { "tar", "tar.exe", "gtar" },
      "extract downloaded packages",
      "Install GNU tar."
    ),
    dependency(
      "required",
      is_windows and "7-Zip-compatible extractor" or "unzip",
      is_windows and executable { "7z", "7z.exe", "7za", "7za.exe", "unzip", "WinRAR.exe" } or executable { "unzip" },
      "extract Mason packages",
      is_windows and "Install 7-Zip." or "Install unzip."
    ),
    dependency(
      "required",
      is_windows and "PowerShell" or "gzip",
      is_windows and executable { "pwsh", "pwsh.exe", "powershell", "powershell.exe" } or executable { "gzip" },
      "install and extract Mason packages",
      is_windows and "Install PowerShell 7 or enable Windows PowerShell." or "Install gzip."
    ),
    dependency(
      "required",
      is_windows and "CMake" or "make",
      is_windows and executable { "cmake", "cmake.exe" } or executable { "make", "gmake" },
      "build native editor components",
      is_windows and "Install CMake." or "Install make or the platform build tools."
    ),
    dependency(
      "required",
      "C/C++ compiler",
      c_compiler_available(),
      "compile Tree-sitter parsers",
      is_windows and "Install Visual Studio Build Tools with Desktop development with C++, or MinGW."
        or "Install GCC/Clang or Xcode Command Line Tools."
    ),
    dependency(
      "required",
      "tree-sitter CLI >= " .. version_text(minimum.tree_sitter),
      version_at_least(tree_sitter_version, minimum.tree_sitter),
      "install the configured parsers",
      "Install the official tree-sitter CLI (not the npm package)."
    ),
  }

  local needed = {
    dependency(
      "needed",
      "fd/fdfind",
      executable { "fd", "fd.exe", "fdfind" },
      "discover Python environments",
      "Install fd (fd-find on Debian/Ubuntu)."
    ),
    dependency(
      "needed",
      "Node.js + npm",
      has_node and has_npm,
      "install JSON/JavaScript tools and run Copilot",
      "Install the current Node.js LTS release with npm."
    ),
    dependency(
      "needed",
      "Python 3 + venv",
      M.python_with_venv(refresh),
      "install Python editor tools",
      "Install Python 3 with its venv support."
    ),
  }

  local optional = {
    dependency("optional", "uv", executable { "uv", "uv.exe" }, "Python project commands", "Install uv when needed."),
    dependency(
      "optional",
      "Bear",
      executable { "bear", "bear.exe" },
      "capture Make commands",
      "Install Bear or disable it in settings."
    ),
    dependency(
      "optional",
      "ImageMagick",
      is_windows and executable { "magick", "magick.exe" } or executable { "magick", "convert" },
      "render non-PNG images",
      "Install ImageMagick when terminal images are desired."
    ),
  }

  cached_report = { required = required, needed = needed, optional = optional }
  return cached_report
end

local function missing(items)
  local result = {}
  for _, item in ipairs(items) do
    if not item.available then
      result[#result + 1] = item
    end
  end
  return result
end

local function report_lines(report, include_available)
  local lines = {}
  for _, level in ipairs { "required", "needed", "optional" } do
    lines[#lines + 1] = level:upper() .. ":"
    for _, item in ipairs(report[level]) do
      if include_available or not item.available then
        lines[#lines + 1] =
          string.format("  [%s] %s — %s", item.available and "OK" or "MISSING", item.name, item.purpose)
        if not item.available then
          lines[#lines + 1] = "            " .. item.hint
        end
      end
    end
    lines[#lines + 1] = ""
  end
  return lines
end

local function bootstrap_command()
  local config = vim.fn.stdpath "config"
  if is_windows then
    return string.format(
      'powershell -ExecutionPolicy Bypass -File "%s"',
      vim.fs.joinpath(config, "scripts", "bootstrap.ps1")
    )
  end
  return string.format('bash "%s"', vim.fs.joinpath(config, "scripts", "bootstrap.sh"))
end

function M.info()
  local lines = report_lines(M.report(true), true)
  lines[#lines + 1] = "Bootstrap command:"
  lines[#lines + 1] = "  " .. bootstrap_command()
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Bootstrap dependencies" })
end

local function render_blocked(report)
  local lines = {
    "# ginko.nvim bootstrap required",
    "",
    "Plugin, Mason, and Tree-sitter loading has been stopped because required dependencies are missing.",
    "",
  }
  vim.list_extend(lines, report_lines({ required = missing(report.required), needed = {}, optional = {} }, false))
  lines[#lines + 1] = "Run:"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. bootstrap_command()
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Then restart Neovim. Press q to quit this minimal session."

  if #vim.api.nvim_list_uis() == 0 then
    vim.api.nvim_err_writeln(table.concat(lines, "\n"))
    vim.schedule(function()
      vim.cmd "cquit 1"
    end)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modifiable = false
  pcall(vim.api.nvim_buf_set_name, bufnr, "nvim-bootstrap://requirements")
  vim.keymap.set("n", "q", "<cmd>qa<cr>", { buffer = bufnr, silent = true, desc = "Quit Neovim" })
end

local function install_tools()
  local languages = require "config.languages"
  local packages = languages.mason_packages()
  if #packages > 0 then
    vim.cmd("MasonInstall " .. table.concat(packages, " "))
  end

  local parsers = languages.collect "treesitter"
  vim.list_extend(parsers, { "markdown", "markdown_inline" })
  local seen, unique = {}, {}
  for _, parser in ipairs(parsers) do
    if not seen[parser] then
      seen[parser] = true
      unique[#unique + 1] = parser
    end
  end
  local task = require("nvim-treesitter").install(unique)
  task:wait(300000)
  print(string.format("Bootstrap complete: %d Mason packages, %d Tree-sitter parsers", #packages, #unique))
end

function M.setup()
  vim.api.nvim_create_user_command("BootstrapInfo", M.info, {
    desc = "Show required, needed, and optional external dependencies",
    force = true,
  })
  vim.api.nvim_create_user_command("BootstrapInstall", install_tools, {
    desc = "Install configured Mason tools and Tree-sitter parsers synchronously",
    force = true,
  })
end

function M.check()
  M.setup()
  local report = M.report()
  if #missing(report.required) > 0 then
    render_blocked(report)
    return false
  end

  local needed = missing(report.needed)
  if #needed > 0 and vim.env.NVIM_BOOTSTRAP ~= "1" then
    vim.schedule(function()
      vim.notify(
        "Some IDE integrations are disabled until their host tools are installed:\n"
          .. table.concat(report_lines({ required = {}, needed = needed, optional = {} }, false), "\n")
          .. "\nRun :BootstrapInfo for details.",
        vim.log.levels.WARN,
        { title = "Bootstrap dependencies" }
      )
    end)
  end
  return true
end

return M
