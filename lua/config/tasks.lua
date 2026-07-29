local M = {}

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
