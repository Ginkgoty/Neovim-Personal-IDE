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

function M.mark()
  -- LSP clients and pickers vary in whether they push their source position.
  -- Record it before dispatch so same-buffer Vue component/tag jumps are as
  -- reversible as cross-file jumps. Duplicate marks are skipped by navigate.
  vim.cmd([[normal! m']])
end

local function is_current_location(entry)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return entry.bufnr == bufnr
    and entry.lnum == cursor[1]
    and (entry.col or 0) == cursor[2]
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
      if path
          and not is_current_location(entries[target])
          and (opts.project_only == false or project.contains(root, path)) then
        execute_jump(key, index - target + 1)
        return
      end
    end
  else
    for target = index + 2, #entries do
      local path = entry_path(entries[target])
      if path
          and not is_current_location(entries[target])
          and (opts.project_only == false or project.contains(root, path)) then
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
