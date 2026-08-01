local M = {}

local marker_names = {
  [".git"] = true,
  ["CMakeLists.txt"] = true,
  ["Cargo.toml"] = true,
  ["go.mod"] = true,
  ["pyproject.toml"] = true,
  ["package.json"] = true,
  ["pom.xml"] = true,
  ["build.gradle"] = true,
  ["build.gradle.kts"] = true,
}

local function is_marker(name)
  return marker_names[name] == true or vim.endswith(name, ".sln") or vim.endswith(name, ".csproj")
end

local function canonical(path)
  path = vim.fs.normalize(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

function M.root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  return canonical(vim.fs.root(start, is_marker) or vim.fn.getcwd())
end

function M.contains(root, path)
  if not root or root == "" or not path or path == "" then
    return false
  end
  local relative = vim.fs.relpath(canonical(root), canonical(path))
  return relative ~= nil and relative ~= ".." and not vim.startswith(relative, "../")
end

-- Telescope currently uses a prefix comparison for root_dir. A trailing path
-- separator prevents /project from also matching /project-other.
function M.telescope_root(bufnr)
  local root = M.root(bufnr):gsub("[/\\]+$", "")
  local separator = package.config:sub(1, 1)
  return root .. separator
end

return M
