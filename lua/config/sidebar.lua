local M = {}

local providers = {}
local states = {}

local function tab_state(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  states[tab] = states[tab] or {}
  return states[tab], tab
end

local function valid_normal_window(win)
  return win
    and vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_config(win).relative == ""
end

local function is_editor_window(win)
  if not valid_normal_window(win) then
    return false
  end
  local tab = vim.api.nvim_win_get_tabpage(win)
  for _, provider in pairs(providers) do
    if provider.find_window(tab) == win then
      return false
    end
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ""
end

local function find_editor(tab)
  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_tabpage(current) == tab and is_editor_window(current) then
    return current
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if is_editor_window(win) then
      return win
    end
  end
end

local function ensure_editor(tab)
  local editor = find_editor(tab)
  if editor then
    return editor
  end

  local wins = vim.api.nvim_tabpage_list_wins(tab)
  if #wins == 0 then
    error("Sidebar: current tab has no window")
  end
  vim.api.nvim_set_current_win(wins[1])
  vim.cmd("botright vnew")
  return vim.api.nvim_get_current_win()
end

function M.register(name, provider)
  assert(type(name) == "string" and name ~= "", "Sidebar provider requires a name")
  assert(type(provider) == "table", "Sidebar provider requires a specification")
  assert(type(provider.find_window) == "function", "Sidebar provider requires find_window(tab)")
  assert(type(provider.open) == "function", "Sidebar provider requires open(context)")
  assert(type(provider.close) == "function", "Sidebar provider requires close(window, context)")
  providers[name] = provider
end

function M.active(tab)
  local state
  state, tab = tab_state(tab)
  if state.name and providers[state.name] then
    local win = providers[state.name].find_window(tab)
    if valid_normal_window(win) then
      state.win = win
      return state.name, win
    end
  end

  for name, provider in pairs(providers) do
    local win = provider.find_window(tab)
    if valid_normal_window(win) then
      state.name = name
      state.win = win
      return name, win
    end
  end
  state.name, state.win = nil, nil
end

local function close_active(context)
  local state, tab = tab_state()
  local name, win = M.active(tab)
  if not name then
    return
  end
  -- Clear first: provider close operations can synchronously trigger WinClosed.
  state.name, state.win = nil, nil
  providers[name].close(win, context or {})
end

-- Close whichever provider currently occupies the shared sidebar slot.
function M.close(context)
  close_active(context)
end

-- Open a provider in the shared slot: a no-op when it already occupies the
-- slot, otherwise the current occupant is closed and the provider takes over.
function M.open(name, context)
  local provider = providers[name]
  if not provider then
    vim.notify("Sidebar provider is not available: " .. name, vim.log.levels.WARN)
    return false
  end

  local active_name = M.active()
  if active_name == name then
    return true
  end
  if active_name then
    close_active({ reason = "switch", target = name })
  end

  provider.open(context or {})
  local state = tab_state()
  local win = provider.find_window(vim.api.nvim_get_current_tabpage())
  state.name, state.win = name, win
  return true
end

function M.toggle(name, context)
  if not providers[name] then
    vim.notify("Sidebar provider is not available: " .. name, vim.log.levels.WARN)
    return false
  end
  if M.active() == name then
    close_active({ reason = "toggle", target = name })
    return false
  end
  return M.open(name, context)
end

-- Reserve the shared left sidebar slot for a provider that creates its own
-- buffer after executing a windowCreationCommand (such as grug-far).
function M.claim_window(name, width)
  local state, tab = tab_state()
  local editor = ensure_editor(tab)
  local active_name = M.active(tab)
  if active_name then
    close_active({ reason = "switch", target = name })
  end
  if not vim.api.nvim_win_is_valid(editor) then
    editor = ensure_editor(tab)
  end

  vim.api.nvim_set_current_win(editor)
  vim.cmd("topleft " .. math.max(20, math.floor(tonumber(width) or 40)) .. "vsplit")
  local win = vim.api.nvim_get_current_win()
  state.name, state.win, state.editor = name, win, editor

  local group = vim.api.nvim_create_augroup("sidebar_slot_" .. tab .. "_" .. win, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function()
      vim.schedule(function()
        local current = states[tab]
        if current and current.win == win then
          current.name, current.win = nil, nil
        end
        pcall(vim.api.nvim_del_augroup_by_id, group)
      end)
    end,
    desc = "Release the shared sidebar slot",
  })
  return win, editor
end

function M.editor_window(tab)
  local state
  state, tab = tab_state(tab)
  if valid_normal_window(state.editor) and vim.api.nvim_win_get_tabpage(state.editor) == tab then
    return state.editor
  end
  return find_editor(tab)
end

return M
