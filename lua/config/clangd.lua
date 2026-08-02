local M = {}

local database_names = { "compile_commands.json", "compile_flags.txt" }
local warned_roots = {}
local standalone_roots = {}
local standalone_contexts = {}
local root_markers = {
  ".clangd",
  ".clang-tidy",
  ".clang-format",
  "compile_commands.json",
  "compile_flags.txt",
  "configure.ac",
  ".git",
}

local function readable(path)
  return vim.fn.filereadable(path) == 1
end

function M.root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  -- Protected compiler headers inherit a project client when one is available.
  -- Otherwise only headers inside compiler-reported standard include roots get
  -- a constrained standalone client; arbitrary package paths are not guessed.
  if filename == "" then
    return
  end

  if require("config.readonly").should_lock(filename) then
    if require("config.clangd_context").project_client() then
      return
    end
    local context = require("config.platform").standard_header_context(filename)
    if context then
      standalone_roots[context.root] = true
      standalone_contexts[context.root] = context
      on_dir(context.root)
    end
    return
  end

  local root = vim.fs.root(bufnr, root_markers) or vim.fs.dirname(filename)
  if root then
    on_dir(root)
  end
end

function M.before_init(params, config)
  local context = standalone_contexts[config.root_dir]
  if not context then
    return
  end
  params.initializationOptions = params.initializationOptions or {}
  params.initializationOptions.fallbackFlags = vim.deepcopy(context.fallback_flags)
end

local function standalone_database(context)
  if not context or not context.driver or not context.filename then
    return nil
  end
  local identity = table.concat({ context.root, context.driver, context.language }, "\0")
  local directory = vim.fs.joinpath(vim.fn.stdpath "cache", "clangd-standalone", vim.fn.sha256(identity):sub(1, 16))
  vim.fn.mkdir(directory, "p")

  local arguments = { context.driver }
  vim.list_extend(arguments, context.compile_flags or context.fallback_flags)
  arguments[#arguments + 1] = context.filename
  local database = vim.json.encode {
    {
      directory = vim.fs.dirname(context.filename),
      file = context.filename,
      arguments = arguments,
    },
  }
  local path = vim.fs.joinpath(directory, "compile_commands.json")
  local current = vim.fn.filereadable(path) == 1 and table.concat(vim.fn.readfile(path), "\n") or nil
  if current ~= database then
    vim.fn.writefile({ database }, path)
  end
  return directory
end

local function command_driver(entry)
  if type(entry.arguments) == "table" and type(entry.arguments[1]) == "string" then
    return entry.arguments[1]
  end
  if type(entry.command) ~= "string" then
    return
  end
  local command = vim.trim(entry.command)
  local quote = command:sub(1, 1)
  if quote == '"' or quote == "'" then
    return command:match("^" .. quote .. "(.-)" .. quote)
  end
  return command:match "^(%S+)"
end

function M.compilation_database_compilers(path)
  local database = M.find_compilation_database(path)
  if not database or vim.fs.basename(database) ~= "compile_commands.json" then
    return {}
  end
  local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(database), "\n"))
  if not ok or type(entries) ~= "table" then
    return {}
  end

  local platform = require "config.platform"
  local normalized_path = vim.fs.normalize(path)
  local path_stat = vim.uv.fs_stat(normalized_path)
  local root = path_stat and path_stat.type == "directory" and normalized_path or vim.fs.dirname(normalized_path)
  local result, seen = {}, {}
  for _, entry in ipairs(entries) do
    local driver = command_driver(entry)
    if driver and not platform.is_absolute(driver) then
      local unresolved = driver
      driver = vim.fn.exepath(unresolved)
      if driver == "" and type(entry.directory) == "string" then
        driver = vim.fs.joinpath(entry.directory, unresolved)
      end
    end
    driver = driver and vim.fs.normalize(driver) or nil
    if driver and not seen[driver] and platform.trusted_query_driver(driver, root) then
      seen[driver] = true
      result[#result + 1] = driver
    end
  end
  table.sort(result)
  return result
end

function M.find_compilation_database(filename)
  local normalized = vim.fs.normalize(filename)
  local stat = vim.uv.fs_stat(normalized)
  local directory = stat and stat.type == "directory" and normalized or vim.fs.dirname(normalized)
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

function M.find_compilation_directory(path)
  local database = M.find_compilation_database(path)
  if database then
    return vim.fs.dirname(database)
  end

  local normalized = vim.fs.normalize(path)
  local stat = vim.uv.fs_stat(normalized)
  local directory = stat and stat.type == "directory" and normalized or vim.fs.dirname(normalized)
  local build_directories = (require("config.settings").tasks or {}).build_directories or {}
  while directory and directory ~= "" do
    for _, relative in ipairs(build_directories) do
      local build = vim.fs.joinpath(directory, relative)
      if vim.uv.fs_stat(build) then
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

function M.cmd(root_dir)
  local cmd = {
    require("config.platform").clangd_path(),
    "--background-index",
    "--background-index-priority=low",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--function-arg-placeholders",
    "--enable-config",
  }

  local platform = require "config.platform"
  local drivers, seen = {}, {}
  local function append_driver(driver)
    if not seen[driver] then
      seen[driver] = true
      drivers[#drivers + 1] = driver
    end
  end
  for _, driver in ipairs(platform.clangd_query_drivers()) do
    append_driver(driver)
  end
  local standalone_context = standalone_contexts[root_dir]
  if
    standalone_context
    and standalone_context.driver
    and platform.trusted_query_driver(standalone_context.driver, root_dir)
  then
    append_driver(standalone_context.driver)
  end
  local database_compilers = root_dir and M.compilation_database_compilers(root_dir) or {}
  for _, driver in ipairs(database_compilers) do
    append_driver(driver)
  end
  if #drivers > 0 then
    cmd[#cmd + 1] = "--query-driver=" .. table.concat(drivers, ",")
  end
  local resource_dir
  if #database_compilers > 0 then
    local all_clang = true
    for _, compiler in ipairs(database_compilers) do
      if platform.compiler_family(compiler) ~= "clang" then
        all_clang = false
        break
      end
    end
    resource_dir = all_clang and platform.clang_resource_dir(database_compilers[1]) or nil
  else
    resource_dir = platform.clang_resource_dir()
  end
  if resource_dir then
    cmd[#cmd + 1] = "--resource-dir=" .. resource_dir
  end
  local compilation_directory = standalone_database(standalone_context)
    or (root_dir and M.find_compilation_directory(root_dir) or nil)
  if compilation_directory then
    cmd[#cmd + 1] = "--compile-commands-dir=" .. compilation_directory
  end
  return cmd
end

function M.start(dispatchers, config)
  local cmd = M.cmd(config.root_dir)
  config._resolved_cmd = cmd
  config._standalone_header = standalone_roots[config.root_dir] == true
  return vim.lsp.rpc.start(cmd, dispatchers, {
    cwd = config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })
end

local function database_in_directory(directory)
  if not directory or directory == "" then
    return
  end
  for _, name in ipairs(database_names) do
    local path = vim.fs.joinpath(directory, name)
    if readable(path) then
      return path
    end
  end
end

function M.client_compilation_database(client, filename)
  local cmd = client.config._resolved_cmd
    or (type(client.config.cmd) == "table" and client.config.cmd)
    or M.cmd(client.root_dir)
  for _, argument in ipairs(cmd) do
    local directory = type(argument) == "string" and argument:match "^%-%-compile%-commands%-dir=(.+)$" or nil
    local database = database_in_directory(directory)
    if database then
      return database
    end
  end

  -- The database belongs to the LSP project, not necessarily to the current
  -- buffer. Definitions in SDK/standard-library headers remain parsed in the
  -- originating translation unit's compile context.
  local database = client.root_dir and M.find_compilation_database(client.root_dir) or nil
  if database then
    return database
  end
  return filename and filename ~= "" and M.find_compilation_database(filename) or nil
end

function M.warn_missing_database(bufnr, client)
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  -- SDK, toolchain, Mason, and other protected dependency headers are not
  -- standalone projects. They inherit useful context from the translation
  -- unit that opened them and must not emit a project-database warning.
  local readonly = require "config.readonly"
  if readonly.should_lock(filename) then
    return
  end
  if filename == "" or M.client_compilation_database(client, filename) then
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
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = "clangd" }
  local client = clients[1]
  if not client then
    vim.notify("clangd is not attached to the current buffer", vim.log.levels.WARN)
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local database = M.client_compilation_database(client, filename)
  local cmd = client.config._resolved_cmd
    or (type(client.config.cmd) == "table" and client.config.cmd)
    or M.cmd(client.root_dir)
  local executable = vim.fn.exepath(cmd[1])
  local lines = {
    "Executable: " .. (executable ~= "" and executable or cmd[1]),
    "Arguments: " .. table.concat(vim.list_slice(cmd, 2), " "),
    "Root: " .. (client.root_dir or "not detected"),
    "Compilation database: " .. (database or "not found (fallback flags)"),
    "Log: " .. vim.lsp.log.get_filename(),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "clangd status" })
end

return M
