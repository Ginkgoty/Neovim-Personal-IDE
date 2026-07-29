local M = {}

local database_names = { "compile_commands.json", "compile_flags.txt" }
local warned_roots = {}

local function readable(path)
  return vim.fn.filereadable(path) == 1
end

function M.find_compilation_database(filename)
  local directory = vim.fs.dirname(vim.fs.normalize(filename))
  while directory and directory ~= "" do
    for _, name in ipairs(database_names) do
      local direct = vim.fs.joinpath(directory, name)
      if readable(direct) then
        return direct
      end

      local build = vim.fs.joinpath(directory, "build", name)
      if readable(build) then
        return build
      end
    end

    local parent = vim.fs.dirname(directory)
    if not parent or parent == directory then
      break
    end
    directory = parent
  end
end

function M.cmd()
  local cmd = {
    "clangd",
    "--background-index",
    "--background-index-priority=low",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--function-arg-placeholders",
    "--enable-config",
  }

  local drivers = require("config.platform").clangd_query_drivers()
  if #drivers > 0 then
    cmd[#cmd + 1] = "--query-driver=" .. table.concat(drivers, ",")
  end
  return cmd
end

function M.warn_missing_database(bufnr, client)
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or M.find_compilation_database(filename) then
    return
  end

  local key = client.root_dir or vim.fs.dirname(filename)
  if warned_roots[key] then
    return
  end
  warned_roots[key] = true

  vim.schedule(function()
    vim.notify(
      "No compile_commands.json or compile_flags.txt was found for this project. "
        .. "clangd is using fallback flags, so diagnostics and navigation may be incomplete. "
        .. "A project .clangd file may also point to a compilation database.\n"
        .. "https://clangd.llvm.org/installation#project-setup",
      vim.log.levels.WARN,
      { title = "clangd project setup" }
    )
  end)
end

function M.info(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })
  local client = clients[1]
  if not client then
    vim.notify("clangd is not attached to the current buffer", vim.log.levels.WARN)
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local database = filename ~= "" and M.find_compilation_database(filename) or nil
  local executable = vim.fn.exepath(client.config.cmd[1])
  local lines = {
    "Executable: " .. (executable ~= "" and executable or client.config.cmd[1]),
    "Arguments: " .. table.concat(vim.list_slice(client.config.cmd, 2), " "),
    "Root: " .. (client.root_dir or "not detected"),
    "Compilation database: " .. (database or "not found (fallback flags)"),
    "Log: " .. vim.lsp.log.get_filename(),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "clangd status" })
end

return M
