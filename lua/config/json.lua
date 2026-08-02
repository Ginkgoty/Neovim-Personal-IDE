local M = {}

local tasks_schema_url = "https://www.schemastore.org/task.json"

local function tasks_schema_path()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "schemas", "vscode-tasks.json")
end

local function read_schema(path)
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" or type(decoded.properties) ~= "table"
      or type(decoded.definitions) ~= "table" then
    return nil, "downloaded file is not a valid VS Code tasks JSON Schema"
  end
  return decoded
end

function M.schemas()
  local schemas = vim.deepcopy(require("schemastore").json.schemas())
  schemas = vim.tbl_filter(function(schema)
    return schema.name ~= "task.json"
  end, schemas)

  local schema, err = read_schema(tasks_schema_path())
  if not schema then
    error("Unable to load the bundled VS Code tasks Schema: " .. err)
  end
  table.insert(schemas, 1, {
    name = "VS Code tasks.json (bundled)",
    description = "Pinned from the authoritative SchemaStore upstream for offline, reproducible completion.",
    fileMatch = { "/.vscode/tasks.json", ".vscode/tasks.json" },
    schema = schema,
  })
  return schemas
end

function M.update_tasks_schema()
  local destination = tasks_schema_path()
  local temporary = destination .. ".tmp"
  local command
  if vim.fn.executable("curl") == 1 then
    command = { "curl", "--fail", "--location", "--silent", "--show-error", tasks_schema_url, "--output", temporary }
  else
    local powershell = vim.fn.exepath("pwsh")
    if powershell == "" then
      powershell = vim.fn.exepath("powershell")
    end
    if powershell == "" then
      vim.notify("Install curl or PowerShell to update the tasks Schema", vim.log.levels.ERROR, { title = "Tasks Schema" })
      return
    end
    local escaped_destination = temporary:gsub("'", "''")
    command = {
      powershell,
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      ("Invoke-WebRequest -UseBasicParsing -Uri '%s' -OutFile '%s'"):format(tasks_schema_url, escaped_destination),
    }
  end

  vim.notify("Downloading the VS Code tasks Schema from SchemaStore…", vim.log.levels.INFO, { title = "Tasks Schema" })
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.uv.fs_unlink(temporary)
        local message = vim.trim(result.stderr or "")
        vim.notify(message ~= "" and message or "Schema download failed", vim.log.levels.ERROR, { title = "Tasks Schema" })
        return
      end

      local _, validation_error = read_schema(temporary)
      if validation_error then
        vim.uv.fs_unlink(temporary)
        vim.notify(validation_error, vim.log.levels.ERROR, { title = "Tasks Schema" })
        return
      end

      local lines = vim.fn.readfile(temporary)
      vim.uv.fs_unlink(temporary)
      local write_result = vim.fn.writefile(lines, destination)
      if write_result ~= 0 then
        vim.notify("Unable to write " .. destination, vim.log.levels.ERROR, { title = "Tasks Schema" })
        return
      end
      vim.notify(
        "Updated schemas/vscode-tasks.json. Restart Neovim to reload jsonls and review the Git diff.",
        vim.log.levels.INFO,
        { title = "Tasks Schema" }
      )
    end)
  end)
end

return M
