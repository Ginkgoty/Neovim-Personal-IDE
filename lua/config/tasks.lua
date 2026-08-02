local M = {}
local bear_warning_shown = false
local setup_done = false

local preferred_targets = {
  all = 1,
  build = 2,
  test = 3,
  check = 4,
  install = 5,
  clean = 6,
}

local function search_params()
  local directory = vim.fn.getcwd()
  if vim.bo.buftype == "" then
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" then
      directory = vim.fs.dirname(name)
    end
  end
  return { dir = directory, filetype = vim.bo.filetype }
end

local function target_name(name)
  return name:match("^make%s+(.+)$") or name
end

local function sort_templates(templates)
  table.sort(templates, function(left, right)
    local left_priority = preferred_targets[target_name(left.name):lower()] or math.huge
    local right_priority = preferred_targets[target_name(right.name):lower()] or math.huge
    if left_priority ~= right_priority then
      return left_priority < right_priority
    end
    return left.name:lower() < right.name:lower()
  end)
end

local function task_sorter(templates)
  local sorters = require("telescope.sorters")
  local fuzzy = sorters.get_fzy_sorter({})

  return sorters.Sorter:new({
    discard = true,
    highlighter = fuzzy.highlighter,
    scoring_function = function(_, prompt, line, entry)
      local query = vim.trim(prompt):lower()
      if query == "" then
        return entry.index or 1
      end

      local template = templates[entry.value]
      local name = target_name(template.name):lower()
      local full_name = line:lower()
      if name == query or full_name == query then
        return 0
      elseif vim.startswith(name, query) then
        return 0.1 + (#name - #query) / 10000
      elseif vim.startswith(full_name, query) then
        return 0.2 + (#full_name - #query) / 10000
      end

      local position = name:find(query, 1, true) or full_name:find(query, 1, true)
      if position then
        return 1 + position / 1000 + #name / 100000
      end

      local score = fuzzy:scoring_function(prompt, line, entry)
      return score == -1 and -1 or 2 + score
    end,
  })
end

local function parse_arguments(input)
  local arguments = {}
  local current = {}
  local quote
  local index = 1
  local is_windows = require("config.platform").is_windows
  local function finish()
    if #current > 0 then
      arguments[#arguments + 1] = table.concat(current)
      current = {}
    end
  end

  while index <= #input do
    local character = input:sub(index, index)
    if quote then
      if character == quote then
        quote = nil
      elseif character == "\\" and quote == '"' and input:sub(index + 1, index + 1):match('["\\]') then
        index = index + 1
        current[#current + 1] = input:sub(index, index)
      else
        current[#current + 1] = character
      end
    elseif character == '"' or character == "'" then
      quote = character
    elseif character:match("%s") then
      finish()
    elseif character == "\\" and not is_windows and index < #input then
      index = index + 1
      current[#current + 1] = input:sub(index, index)
    else
      current[#current + 1] = character
    end
    index = index + 1
  end
  if quote then
    return nil, "Unclosed quote in Make arguments"
  end
  finish()
  return arguments
end

local function run_template_by_index(templates, index, search, extra_arguments)
  local template = templates[index]
  if not template then
    vim.notify("The selected task is no longer available", vim.log.levels.WARN, { title = "Tasks" })
    return
  end

  -- Re-enter Overseer through its public API. Telescope deliberately carries
  -- only a numeric index, never Overseer's function-bearing template table.
  require("overseer").run_task({
    name = template.name,
    first = true,
    search_params = search,
    on_build = extra_arguments and function(task_definition)
      if type(task_definition.cmd) ~= "table" then
        return
      end
      for command_index, argument in ipairs(task_definition.cmd) do
        if vim.fs.basename(argument) == "make" then
          for offset, extra in ipairs(extra_arguments) do
            table.insert(task_definition.cmd, command_index + offset, extra)
          end
          return
        end
      end
    end or nil,
  }, function(_, err)
    if err then
      vim.notify(err, vim.log.levels.ERROR, { title = "Tasks" })
    end
  end)
end

function M.select_task()
  local search = search_params()
  require("overseer.template").list(search, function(templates)
    templates = vim.tbl_filter(function(template)
      return not template.hide
    end, templates)
    if vim.tbl_isempty(templates) then
      vim.notify("No tasks found for the current project", vim.log.levels.WARN, { title = "Tasks" })
      return
    end
    sort_templates(templates)
    local indices = {}
    for index = 1, #templates do
      indices[index] = index
    end

    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    require("telescope.pickers").new({}, {
      prompt_title = "Project tasks — Enter: run  Ctrl-A: Make arguments",
      results_title = string.format("%d available", #templates),
      finder = require("telescope.finders").new_table({
        results = indices,
        entry_maker = function(index)
          local template = templates[index]
          local display = template.desc and string.format("%s  —  %s", template.name, template.desc)
            or template.name
          return { value = index, display = display, ordinal = template.name }
        end,
      }),
      sorter = task_sorter(templates),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            run_template_by_index(templates, selection.value, search)
          end
        end)
        local function run_with_arguments()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          local template = templates[selection.value]
          if not template.name:match("^make%s+") then
            vim.notify("Extra Make arguments are only available for Make tasks", vim.log.levels.INFO, { title = "Tasks" })
            return
          end
          vim.ui.input({ prompt = "Extra Make arguments: " }, function(input)
            if input == nil then
              -- Cancellation leaves the task picker open at the same query
              -- and selection, so no navigation state is lost.
              return
            end
            local arguments, err = parse_arguments(input)
            if not arguments then
              vim.notify(err, vim.log.levels.ERROR, { title = "Tasks" })
              return
            end
            actions.close(prompt_bufnr)
            run_template_by_index(templates, selection.value, search, arguments)
          end)
        end
        map("i", "<C-a>", run_with_arguments)
        map("n", "<C-a>", run_with_arguments)
        return true
      end,
    }):find()
  end)
end

local function is_clean_make_command(cmd)
  if type(cmd) ~= "table" then
    return false
  end
  for _, argument in ipairs(cmd) do
    if type(argument) == "string" and argument:lower():match("^.-clean$") then
      return true
    end
  end
  return false
end

local function wrap_make_with_bear(task_definition)
  local make_settings = ((require("config.settings").tasks or {}).make or {})
  if make_settings.use_bear == false or is_clean_make_command(task_definition.cmd) then
    return
  end
  if vim.fn.executable("bear") ~= 1 then
    if not bear_warning_shown then
      bear_warning_shown = true
      vim.schedule(function()
        vim.notify(
          "Bear is not installed; this Make task will run without updating compile_commands.json. "
            .. "Install Bear with your system package manager.\nhttps://github.com/rizsotto/Bear",
          vim.log.levels.WARN,
          { title = "Make compilation database" }
        )
      end)
    end
    return
  end

  local original = vim.deepcopy(task_definition.cmd)
  if type(original) == "string" then
    -- Overseer's Make provider currently uses a list. Do not put an arbitrary
    -- shell command behind Bear if that implementation changes in the future.
    return
  end

  task_definition.name = task_definition.name or table.concat(original, " ")
  local command = { vim.fn.exepath("bear") }
  local database = vim.fs.joinpath(task_definition.cwd or vim.fn.getcwd(), "compile_commands.json")
  if make_settings.append_existing_compilation_database ~= false and vim.uv.fs_stat(database) then
    command[#command + 1] = "--append"
  end
  command[#command + 1] = "--"
  vim.list_extend(command, original)
  task_definition.cmd = command
end

function M.setup(overseer)
  if setup_done then
    return
  end
  setup_done = true
  for _, module_pattern in ipairs({
    "^make$",
    "^out_of_source_make$",
  }) do
    overseer.add_template_hook({ module = module_pattern }, wrap_make_with_bear)
  end
end

local function latest_task(filter)
  local latest
  for _, task in ipairs(require("overseer").list_tasks({})) do
    if (not filter or filter(task)) and (not latest or task.id > latest.id) then
      latest = task
    end
  end
  return latest
end

function M.restart_last()
  local task = latest_task(function(candidate)
    return not candidate:is_disposed()
  end)
  if not task then
    vim.notify("No previous build/run task is available", vim.log.levels.WARN, { title = "Tasks" })
    return
  end
  task:restart(true)
end

function M.open_last_output()
  local task = latest_task(function(candidate)
    return not candidate:is_disposed() and candidate:get_bufnr() ~= nil
  end)
  if not task then
    vim.notify("No task output is available", vim.log.levels.WARN, { title = "Tasks" })
    return
  end
  task:open_output("horizontal")
end

function M.stop_last_running()
  local task = latest_task(function(candidate)
    return candidate:is_running()
  end)
  if not task then
    vim.notify("No build/run task is currently running", vim.log.levels.INFO, { title = "Tasks" })
    return
  end
  task:stop()
end

return M
