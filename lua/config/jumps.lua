local M = {}

local function settings()
  local navigation = require("config.settings").navigation or {}
  return navigation.jump_history or {}
end

local function entry_path(entry)
  if entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
    if vim.bo[entry.bufnr].buftype ~= "" or not vim.bo[entry.bufnr].buflisted then
      return
    end
    local path = vim.api.nvim_buf_get_name(entry.bufnr)
    return path ~= "" and path or nil
  end
  if entry.filename and entry.filename ~= "" and vim.fn.filereadable(entry.filename) == 1 then
    return entry.filename
  end
end

local function execute_jump(key, count)
  vim.api.nvim_feedkeys(tostring(count) .. vim.keycode(key), "nx", false)
end

function M.navigate(direction)
  local opts = settings()
  local key = direction == "back" and "<C-o>" or "<C-i>"
  local project = require("config.project")
  local root = project.root()
  local result = vim.fn.getjumplist()
  local entries, index = result[1], result[2]

  if direction == "back" then
    for target = index, 1, -1 do
      local path = entry_path(entries[target])
      if path and (opts.project_only == false or project.contains(root, path)) then
        execute_jump(key, index - target + 1)
        return
      end
    end
  else
    for target = index + 2, #entries do
      local path = entry_path(entries[target])
      if path and (opts.project_only == false or project.contains(root, path)) then
        execute_jump(key, target - index - 1)
        return
      end
    end
  end

  vim.notify(
    direction == "back"
        and "No older jump in the current project"
        or "No newer jump in the current project",
    vim.log.levels.INFO,
    { title = "Jump history" }
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("session_jump_history", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      if settings().clear_restored_on_start ~= false then
        vim.cmd.clearjumps()
      end
    end,
    desc = "Discard cross-session jump history restored by ShaDa",
  })
end

return M
