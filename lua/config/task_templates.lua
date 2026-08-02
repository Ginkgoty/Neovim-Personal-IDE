local M = {}

local templates = {
  {
    label = "Build + run (CMake)",
    tasks = {
      {
        label = "Build",
        type = "shell",
        command = "cmake",
        args = { "--build", "${workspaceFolder}/build" },
        group = { kind = "build", isDefault = true },
        problemMatcher = {},
      },
      {
        label = "Run",
        type = "process",
        command = "${workspaceFolder}/build/app",
        dependsOn = "Build",
        dependsOrder = "sequence",
        problemMatcher = {},
      },
    },
  },
  {
    label = "Build task",
    tasks = {
      {
        label = "Build",
        type = "shell",
        command = "replace-with-build-command",
        group = { kind = "build", isDefault = true },
        problemMatcher = {},
      },
    },
  },
  {
    label = "Run task",
    tasks = {
      {
        label = "Run",
        type = "process",
        command = "replace-with-program",
        problemMatcher = {},
      },
    },
  },
  { label = "Empty tasks file", tasks = {} },
}

local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function pretty_json(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return { string.rep("  ", depth) .. vim.json.encode(value) }
  end

  local is_list = vim.islist(value)
  local open_char, close_char = is_list and "[" or "{", is_list and "]" or "}"
  if vim.tbl_isempty(value) then
    return { string.rep("  ", depth) .. open_char .. close_char }
  end
  local lines = { string.rep("  ", depth) .. open_char }
  local entries = {}
  if is_list then
    for index, item in ipairs(value) do
      entries[#entries + 1] = { value = item, index = index }
    end
  else
    local keys = vim.tbl_keys(value)
    local order = {
      version = 1,
      tasks = 2,
      label = 3,
      type = 4,
      command = 5,
      args = 6,
      options = 7,
      dependsOn = 8,
      dependsOrder = 9,
      group = 10,
      problemMatcher = 11,
    }
    table.sort(keys, function(left, right)
      local left_order, right_order = order[left] or 100, order[right] or 100
      return left_order == right_order and left < right or left_order < right_order
    end)
    for _, key in ipairs(keys) do
      entries[#entries + 1] = { key = key, value = value[key] }
    end
  end

  for index, entry in ipairs(entries) do
    local child = pretty_json(entry.value, depth + 1)
    if entry.key then
      child[1] = string.rep("  ", depth + 1) .. vim.json.encode(entry.key) .. ": " .. vim.trim(child[1])
    end
    if index < #entries then
      child[#child] = child[#child] .. ","
    end
    vim.list_extend(lines, child)
  end
  lines[#lines + 1] = string.rep("  ", depth) .. close_char
  return lines
end

function M.create()
  local root = require("config.project").root()
  local directory = vim.fs.joinpath(root, ".vscode")
  local path = vim.fs.joinpath(directory, "tasks.json")
  if vim.fn.filereadable(path) == 1 then
    open(path)
    vim.notify("Opened existing .vscode/tasks.json", vim.log.levels.INFO, { title = "Tasks" })
    return
  end

  vim.ui.select(templates, {
    prompt = "Create .vscode/tasks.json:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    vim.fn.mkdir(directory, "p")
    vim.fn.writefile(pretty_json({ version = "2.0.0", tasks = choice.tasks }), path)
    open(path)
    vim.notify("Created " .. path, vim.log.levels.INFO, { title = "Tasks" })
  end)
end

return M
