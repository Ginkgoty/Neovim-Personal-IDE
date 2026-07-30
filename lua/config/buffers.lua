local M = {}

local function valid(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

---Return whether a buffer represents a real file suitable for the tab line.
function M.is_file(bufnr)
  if not valid(bufnr) then
    return false
  end
  return vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
    and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function is_editor_buffer(bufnr)
  return valid(bufnr)
    and vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
end

local function is_floating_window(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

---Close auxiliary windows when :q targets the last real editing window.
---This preserves native :q behavior while preventing a sidebar-only layout.
function M.close_auxiliary_windows_for_quit()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  if not is_editor_buffer(current_buf) then
    return
  end

  local editor_windows = {}
  local auxiliary_windows = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_floating_window(win) then
      if is_editor_buffer(vim.api.nvim_win_get_buf(win)) then
        editor_windows[#editor_windows + 1] = win
      elseif win ~= current_win then
        auxiliary_windows[#auxiliary_windows + 1] = win
      end
    end
  end

  if #editor_windows ~= 1 or editor_windows[1] ~= current_win then
    return
  end

  for _, win in ipairs(auxiliary_windows) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("safe_buffer_layout", { clear = true })
  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = M.close_auxiliary_windows_for_quit,
    desc = "Close sidebars before quitting the last editing window",
  })
end

local function replacement_for(current)
  local candidates = vim.fn.getbufinfo({ buflisted = true })
  table.sort(candidates, function(a, b)
    return a.lastused > b.lastused
  end)

  for _, info in ipairs(candidates) do
    if info.bufnr ~= current and is_editor_buffer(info.bufnr) then
      return info.bufnr
    end
  end
end

local function new_scratch()
  -- Listed so normal editing works, but unnamed so Bufferline hides it.
  return vim.api.nvim_create_buf(true, false)
end

local function prepare_modified_buffer(bufnr)
  if not vim.bo[bufnr].modified then
    return true, false
  end

  local choice = vim.fn.confirm(
    "Save changes before closing this buffer?",
    "&Save\n&Discard\n&Cancel",
    3
  )
  if choice == 1 then
    local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
      vim.cmd.write()
    end)
    if not ok then
      vim.notify("Could not save buffer: " .. tostring(err), vim.log.levels.ERROR)
      return false, false
    end
    return true, false
  end
  if choice == 2 then
    return true, true
  end
  return false, false
end

---Close a buffer without allowing a sidebar or tool panel to consume the UI.
function M.close(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not valid(bufnr) then
    return
  end

  local windows = vim.fn.win_findbuf(bufnr)
  local owned_by_plugin = vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].buflisted

  if owned_by_plugin then
    for _, win in ipairs(windows) do
      if vim.api.nvim_win_is_valid(win) then
        local has_other_editor = false
        for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if other ~= win and is_editor_buffer(vim.api.nvim_win_get_buf(other)) then
            has_other_editor = true
            break
          end
        end

        if has_other_editor then
          pcall(vim.api.nvim_win_close, win, false)
        else
          vim.api.nvim_win_set_buf(win, replacement_for(bufnr) or new_scratch())
        end
      end
    end
    return
  end

  -- Closing the sole empty scratch would only replace it with another one.
  if vim.api.nvim_buf_get_name(bufnr) == ""
      and not vim.bo[bufnr].modified
      and not replacement_for(bufnr) then
    return
  end

  local proceed, force = prepare_modified_buffer(bufnr)
  if not proceed then
    return
  end

  local replacement = replacement_for(bufnr) or new_scratch()
  for _, win in ipairs(windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_buf(win, replacement)
    end
  end
  vim.api.nvim_buf_delete(bufnr, { force = force })
end

return M
