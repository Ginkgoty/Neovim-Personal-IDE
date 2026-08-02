local platform = require("config.platform")
local M = {}

-- This is the single shared switchboard for language support. A machine may
-- override these values in languages_local.lua without changing tracked files.
M.enabled_languages = {
  lua = true,
  python = true,
  cpp = true,
  go = true,
  rust = true,
  java = true,
  sql = true,
  json = true,
  javascript = true,
  -- Modern .NET development is supported across Windows, macOS, and Linux.
  csharp = true,
}

M.prerequisites = {
  cpp = function()
    return platform.has_c_compiler()
  end,
  csharp = function()
    return vim.fn.executable("dotnet") == 1
  end,
  go = function()
    return vim.fn.executable("go") == 1
  end,
  rust = function()
    return vim.fn.executable("rustc") == 1 and vim.fn.executable("cargo") == 1
  end,
  java = function()
    return platform.has_java_21()
  end,
  javascript = function()
    return vim.fn.executable("node") == 1 and vim.fn.executable("npm") == 1
  end,
}

M.prerequisite_names = {
  cpp = "C/C++ compiler",
  csharp = ".NET SDK (dotnet)",
  go = "Go SDK (go)",
  rust = "Rust toolchain (rustc + cargo)",
  java = "JDK 21+ (java + javac)",
  javascript = "Node.js toolchain (node + npm)",
}

M.display_names = {
  cpp = "C/C++",
  csharp = "C#/.NET",
  go = "Go",
  rust = "Rust",
  java = "Java",
  javascript = "JavaScript/TypeScript",
}

local cpp_install_url = platform.is_windows and "https://visualstudio.microsoft.com/downloads/"
  or platform.is_macos and "https://developer.apple.com/xcode/"
  or "https://clang.llvm.org/get_started.html"

M.install_guides = {
  cpp = {
    message = platform.is_windows and "Install Visual Studio Build Tools with Desktop development with C++."
      or platform.is_macos and "Install Xcode Command Line Tools (xcode-select --install)."
      or "Install GCC/G++ or Clang/Clang++ with your distribution package manager.",
    url = cpp_install_url,
  },
  csharp = {
    message = "Install the .NET SDK (the runtime alone is not sufficient).",
    url = "https://dotnet.microsoft.com/download",
  },
  go = {
    message = "Install the Go toolchain.",
    url = "https://go.dev/dl/",
  },
  rust = {
    message = "Install Rust with rustup.",
    url = "https://rust-lang.github.io/rustup/installation/",
  },
  java = {
    message = "Install JDK 21 or newer and make both java and javac available on PATH.",
    url = "https://dev.java/download/",
  },
  javascript = {
    message = "Install the current Node.js LTS release, including npm.",
    url = "https://nodejs.org/en/download",
  },
}

local ok, local_overrides = pcall(require, "config.languages_local")
if ok and type(local_overrides) == "table" then
  M.enabled_languages = vim.tbl_extend("force", M.enabled_languages, local_overrides)
end

M.definitions = {
  lua = {
    lsp = { "lua_ls" },
    mason_tools = { "stylua" },
    formatters = { lua = { "stylua" } },
    treesitter = { "lua", "vim", "vimdoc" },
  },
  python = {
    lsp = { "ruff", "ty" },
    -- uv is a host-level project/package manager and is intentionally not
    -- installed by Mason. uv.nvim uses the uv command already on PATH.
    mason_tools = { "debugpy" },
    formatters = { python = { "ruff_format" } },
    treesitter = { "python" },
  },
  cpp = {
    lsp = { "clangd" },
    mason_tools = { "codelldb" },
    formatters = {
      c = { "clang_format" },
      cpp = { "clang_format" },
      cuda = { "clang_format" },
    },
    treesitter = { "c", "cpp", "cuda" },
  },
  go = {
    lsp = { "gopls" },
    mason_tools = { "delve", "goimports" },
    formatters = { go = { "goimports", "gofmt", stop_after_first = true } },
    treesitter = { "go", "gomod", "gosum", "gowork" },
  },
  rust = {
    lsp = { "rust_analyzer" },
    mason_tools = { "codelldb" },
    formatters = { rust = { "rustfmt", lsp_format = "fallback" } },
    treesitter = { "rust" },
  },
  java = {
    -- nvim-java owns the versioned JDTLS, test, and debug toolchain.
    treesitter = { "java" },
  },
  sql = {
    lsp = { "sqls" },
    treesitter = { "sql" },
  },
  json = {
    lsp = { "jsonls" },
    -- jsonc is a filetype handled by the json parser, not a separate parser.
    treesitter = { "json" },
  },
  javascript = {
    lsp = { "ts_ls", "eslint" },
    mason_tools = { "prettier", "js-debug-adapter" },
    formatters = {
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
    },
    treesitter = { "javascript", "typescript", "tsx", "jsdoc" },
  },
  csharp = {
    lsp = { "csharp_ls" },
    mason_tools = { "csharpier", "netcoredbg" },
    formatters = { cs = { "csharpier" } },
    treesitter = { "c_sharp" },
  },
}

function M.enabled(name)
  return M.enabled_languages[name] == true
end

function M.available(name)
  local check = M.prerequisites[name]
  return not check or check()
end

function M.unavailable_languages()
  local result = {}
  for name in pairs(M.enabled_languages) do
    if M.enabled(name) and not M.available(name) then
      result[#result + 1] = name
    end
  end
  table.sort(result)
  return result
end

local function append_unique(target, seen, value)
  if not seen[value] then
    seen[value] = true
    target[#target + 1] = value
  end
end

function M.collect(field)
  local result, seen = {}, {}
  for name, definition in pairs(M.definitions) do
    local requires_toolchain = field == "lsp" or field == "mason_tools"
    if M.enabled(name) and (not requires_toolchain or M.available(name)) then
      for _, value in ipairs(definition[field] or {}) do
        append_unique(result, seen, value)
      end
    end
  end
  table.sort(result)
  return result
end

function M.mason_tools()
  return M.collect("mason_tools")
end

function M.mason_lsp_servers()
  return M.collect("lsp")
end

function M.formatters()
  local result = {}
  for name, definition in pairs(M.definitions) do
    if M.enabled(name) and M.available(name) then
      for filetype, formatters in pairs(definition.formatters or {}) do
        result[filetype] = formatters
      end
    end
  end
  return result
end

return M
