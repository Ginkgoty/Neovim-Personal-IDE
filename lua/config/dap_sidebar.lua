local M = {}

local panels = {
  { id = "scopes", filetype = "dapui_scopes", label = "Variables" },
  { id = "watches", filetype = "dapui_watches", label = "Watch" },
  { id = "stacks", filetype = "dapui_stacks", label = "Call Stack" },
  { id = "breakpoints", filetype = "dapui_breakpoints", label = "Breakpoints" },
}

local states = {}
local configured = false
local applying = false
local refresh_pending = false
local observed_buffers = {}
local collapsed_namespace = vim.api.nvim_create_namespace("dap_sidebar_collapsed_titles")
local gap_filetype = "dapui_sidebar_gap"

local tool_filetypes = {
  dapui_scopes = true,
  dapui_watches = true,
  dapui_stacks = true,
  dapui_breakpoints = true,
  dapui_console = true,
  ["dap-repl"] = true,
}

-- Global debug mappings are useful in source buffers, but dangerous in DAP
-- views: a navigation typo in Watch must not start a session or open another
-- debug window. Buffer-local blockers take precedence over those globals.
local blocked_debug_keys = {
  "<F5>", "<F10>", "<F11>", "<F12>",
  "<leader>dc", "<leader>do", "<leader>di", "<leader>dO", "<leader>dp",
  "<leader>db", "<leader>dB", "<leader>dl", "<leader>dr", "<leader>dR", "<leader>dt",
  "<leader>du", "<leader>de", "<leader>dg", "<leader>dG", "<leader>dn",
  "<leader>df", "<leader>dj", "<leader>dJ",
}

local function reject_debug_action()
  vim.notify("Debug actions are unavailable from DAP tool windows", vim.log.levels.INFO)
end

local function guard_tool_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr)
      or not tool_filetypes[vim.bo[bufnr].filetype]
      or vim.b[bufnr].dap_tool_buffer_guarded then
    return
  end
  vim.b[bufnr].dap_tool_buffer_guarded = true
  for _, lhs in ipairs(blocked_debug_keys) do
    vim.keymap.set({ "n", "v" }, lhs, reject_debug_action, {
      buffer = bufnr,
      silent = true,
      desc = "DAP view: source-buffer action disabled",
    })
  end
  -- dap-ui normally assigns this to "send expression to REPL". Keep the
  -- single-key action inert even if a future dap-ui release restores it.
  vim.keymap.set("n", "r", reject_debug_action, {
    buffer = bufnr,
    silent = true,
    desc = "DAP view: REPL action disabled",
  })
end

local function options()
  return ((require("config.settings").ui or {}).debug_sidebar or {})
end

local function state(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  for existing in pairs(states) do
    if not vim.api.nvim_tabpage_is_valid(existing) then states[existing] = nil end
  end
  if not states[tab] then
    local expanded = {}
    local initial = options().initially_expanded
    if type(initial) == "table" then
      for _, panel in ipairs(panels) do
        if vim.tbl_contains(initial, panel.id) then
          expanded[panel.id] = true
        end
      end
    else
      for _, panel in ipairs(panels) do
        expanded[panel.id] = true
      end
    end
    -- A vertical split cannot leave unused rows. Keep at least one element
    -- expanded so collapsed sections remain header-sized rather than forcing
    -- an arbitrary collapsed window to consume the empty sidebar.
    if vim.tbl_isempty(expanded) then
      expanded.scopes = true
    end
    states[tab] = { expanded = expanded }
  end
  return states[tab]
end

local function panel_windows(tab)
  local result = {}
  -- Discover panels only through stable Neovim window/buffer APIs. Collapsed
  -- sections keep their real dap-ui buffer and filetype, so no plugin-private
  -- layout state is needed here.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      for index, panel in ipairs(panels) do
        if filetype == panel.filetype then
          result[index] = win
          break
        end
      end
    end
  end
  return result
end

local function gap_window(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == gap_filetype then
      return win
    end
  end
end

local function ensure_bottom_gap(tab, windows)
  local height = math.max(0, math.floor(tonumber(options().bottom_gap) or 1))
  local existing = gap_window(tab)
  if height == 0 then
    if existing and vim.api.nvim_win_is_valid(existing) then
      vim.api.nvim_win_close(existing, true)
    end
    return
  end
  if existing and vim.api.nvim_win_is_valid(existing) then
    vim.api.nvim_win_set_height(existing, height)
    return existing
  end

  local breakpoint_win = windows[#panels]
  if not breakpoint_win or not vim.api.nvim_win_is_valid(breakpoint_win) then
    return
  end
  local previous = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(breakpoint_win)
  vim.cmd("belowright " .. height .. "new")
  local win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = gap_filetype
  vim.wo[win].winfixheight = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].statuscolumn = ""
  vim.wo[win].winbar = ""
  vim.wo[win].cursorline = false
  vim.wo[win].fillchars = "eob: "
  vim.api.nvim_win_set_height(win, height)
  vim.api.nvim_create_autocmd("WinEnter", {
    group = vim.api.nvim_create_augroup("dap_sidebar_gap_" .. win, { clear = true }),
    buffer = bufnr,
    callback = function()
      if vim.api.nvim_win_is_valid(breakpoint_win) then
        vim.api.nvim_set_current_win(breakpoint_win)
      end
    end,
    desc = "Keep the DAP sidebar spacing row non-interactive",
  })
  if vim.api.nvim_win_is_valid(previous) then
    vim.api.nvim_set_current_win(previous)
  end
  return win
end

function M.close_gap(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local win = gap_window(tab)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function update_titles(tab, windows)
  local current = state(tab)
  for index, win in pairs(windows) do
    if vim.api.nvim_win_is_valid(win) then
      local panel = panels[index]
      if current.expanded[panel.id] then
        vim.wo[win].winbar = ("%%%d@v:lua.NvimDapSidebarToggle@%%#WinBar#  %s %%*%%X")
          :format(index, panel.label)
      else
        -- The sole body row renders the collapsed title. Keeping a winbar as
        -- well would expose a second row and no longer be a true fold.
        vim.wo[win].winbar = ""
      end
    end
  end
end

local function update_presentation(windows, current)
  for index, panel in ipairs(panels) do
    local win = windows[index]
    local bufnr = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_clear_namespace(bufnr, collapsed_namespace, 0, -1)
    if current.expanded[panel.id] then
      vim.wo[win].conceallevel = 0
      vim.wo[win].concealcursor = ""
    else
      -- Keep dap-ui's real buffer attached so it may continue refreshing in
      -- the background. Conceal its only visible row and overlay the section
      -- title; with a one-row window no element content remains visible.
      local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
      vim.wo[win].conceallevel = 2
      vim.wo[win].concealcursor = "nvi"
      vim.api.nvim_buf_set_extmark(bufnr, collapsed_namespace, 0, 0, {
        end_col = #line,
        conceal = "",
        virt_text = { { "  " .. panel.label, "WinBar" } },
        virt_text_win_col = 0,
        priority = 1000,
      })
      pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
      vim.api.nvim_win_call(win, function() vim.cmd("normal! zt") end)
    end
  end
end

local function content_height(win, maximum)
  local bufnr = vim.api.nvim_win_get_buf(win)
  local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))
  local ok, measured = pcall(vim.api.nvim_win_text_height, win, {
    start_row = 0,
    end_row = line_count - 1,
  })
  local height = ok and measured and measured.all or line_count
  return math.max(1, math.min(maximum, height))
end

local function resize_windows(windows, current, collapsed_height)
  -- Removing a winbar turns that screen row back into body space, so measure
  -- only after the expanded/collapsed presentation has been applied.
  local total, expanded_count = 0, 0
  for index, win in ipairs(windows) do
    total = total + vim.api.nvim_win_get_height(win)
    if current.expanded[panels[index].id] then
      expanded_count = expanded_count + 1
    end
  end
  local available = total - (#panels - expanded_count) * collapsed_height
  local maximum = math.max(1, math.floor(tonumber(options().max_expanded_height) or 18))
  local demands, demand_total, last_expanded = {}, 0
  for index, panel in ipairs(panels) do
    if current.expanded[panel.id] then
      demands[index] = content_height(windows[index], maximum)
      demand_total = demand_total + demands[index]
      last_expanded = index
    end
  end

  local targets = {}
  if demand_total <= available then
    for index, panel in ipairs(panels) do
      targets[index] = current.expanded[panel.id] and demands[index] or collapsed_height
    end
    -- A left split must span the editor height. Keep content-sized sections
    -- compact and let only the final expanded section absorb structural slack.
    targets[last_expanded] = targets[last_expanded] + (available - demand_total)
  else
    -- The screen cannot satisfy every capped demand. Give every expanded
    -- section one row, then allocate the rest proportionally to its content.
    local remaining = available - expanded_count
    local extra_demand = math.max(1, demand_total - expanded_count)
    local fractions = {}
    local assigned = 0
    for index, panel in ipairs(panels) do
      if current.expanded[panel.id] then
        local exact = remaining * math.max(0, demands[index] - 1) / extra_demand
        local extra = math.floor(exact)
        targets[index] = 1 + extra
        fractions[#fractions + 1] = { index = index, value = exact - extra }
        assigned = assigned + extra
      else
        targets[index] = collapsed_height
      end
    end
    table.sort(fractions, function(a, b) return a.value > b.value end)
    for offset = 1, remaining - assigned do
      local item = fractions[((offset - 1) % #fractions) + 1]
      targets[item.index] = targets[item.index] + 1
    end
  end

  -- Split resizing transfers rows between neighbours. A few bounded passes
  -- converge on the requested integer layout without dap-ui's fractional
  -- rounding drift (which is especially visible with four stacked panels).
  for _ = 1, 3 do
    for index = #panels, 1, -1 do
      pcall(vim.api.nvim_win_set_height, windows[index], targets[index])
    end
    for index = 1, #panels do
      if not current.expanded[panels[index].id] then
        pcall(vim.api.nvim_win_set_height, windows[index], collapsed_height)
      end
    end
  end
  return targets
end

local function schedule_refresh()
  if refresh_pending then return end
  refresh_pending = true
  vim.schedule(function()
    refresh_pending = false
    M.attach()
  end)
end

local function observe_buffer(bufnr)
  if observed_buffers[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then return end
  observed_buffers[bufnr] = true
  local attached = vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      schedule_refresh()
    end,
    on_detach = function()
      observed_buffers[bufnr] = nil
    end,
  })
  if not attached then observed_buffers[bufnr] = nil end
end

local function apply(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local windows = panel_windows(tab)
  if vim.tbl_count(windows) ~= #panels then
    return false
  end

  local current = state(tab)
  local expanded_count = 0
  for _, panel in ipairs(panels) do
    if current.expanded[panel.id] then expanded_count = expanded_count + 1 end
  end
  if expanded_count == 0 then
    return false
  end

  local collapsed_height = math.max(1, math.floor(tonumber(options().collapsed_height) or 1))
  if applying then
    return true
  end
  applying = true
  local ok, err = xpcall(function()
    update_titles(tab, windows)
    update_presentation(windows, current)
    resize_windows(windows, current, collapsed_height)
  end, debug.traceback)
  applying = false
  if not ok then
    vim.notify("Failed to update DAP sidebar layout:\n" .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function panel_by_id(id)
  for index, panel in ipairs(panels) do
    if panel.id == id or panel.filetype == id then
      return panel, index
    end
  end
end

function M.set(id, expanded)
  local panel = panel_by_id(id)
  if not panel then
    return false
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local current = state(tab)
  if not expanded and current.expanded[panel.id] then
    local count = 0
    for _, candidate in ipairs(panels) do
      if current.expanded[candidate.id] then
        count = count + 1
      end
    end
    if count == 1 then
      vim.notify("At least one debug panel must remain expanded", vim.log.levels.INFO)
      return false
    end
  end
  current.expanded[panel.id] = expanded == true
  return apply(tab)
end

function M.toggle(id)
  local panel = panel_by_id(id)
  if not panel then
    return false
  end
  local current = state()
  return M.set(panel.id, not current.expanded[panel.id])
end

function M.toggle_index(index)
  local panel = panels[tonumber(index)]
  return panel and M.toggle(panel.id) or false
end

function M.current(action)
  local filetype = vim.bo.filetype
  local panel = panel_by_id(filetype)
  if not panel then
    return false
  end
  if action == "open" then
    return M.set(panel.id, true)
  elseif action == "close" then
    return M.set(panel.id, false)
  end
  return M.toggle(panel.id)
end

local function handle_left_mouse()
  local mouse = vim.fn.getmousepos()
  local tab = vim.api.nvim_get_current_tabpage()
  local windows = panel_windows(tab)
  local current = state(tab)
  for index, win in ipairs(windows) do
    if win == mouse.winid and not current.expanded[panels[index].id] then
      M.set(panels[index].id, true)
      return
    end
  end
  -- Preserve dap-ui's ordinary mouse behaviour in expanded panels. `n`
  -- bypasses this buffer-local mapping and executes Neovim's native click.
  vim.api.nvim_feedkeys(vim.keycode("<LeftMouse>"), "n", false)
end

local function invoke_mapping(mapping)
  if type(mapping.callback) == "function" then
    mapping.callback()
  elseif type(mapping.rhs) == "string" and mapping.rhs ~= "" then
    vim.api.nvim_feedkeys(vim.keycode(mapping.rhs), "n", false)
  end
end

local function update_tray_titles(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if filetype == "dapui_console" then
      vim.wo[win].winbar = "%#WinBar#  Debug Console %*"
    end
  end
end

function M.attach()
  local tab = vim.api.nvim_get_current_tabpage()
  local windows = panel_windows(tab)
  if vim.tbl_count(windows) ~= #panels then
    return false
  end
  ensure_bottom_gap(tab, windows)
  for index, win in ipairs(windows) do
    local panel = panels[index]
    local bufnr = vim.api.nvim_win_get_buf(win)
    guard_tool_buffer(bufnr)
    observe_buffer(bufnr)
    if not vim.b[bufnr].dap_sidebar_fold_mappings then
      vim.b[bufnr].dap_sidebar_fold_mappings = true
      local original_enter = vim.api.nvim_win_call(win, function()
        return vim.fn.maparg("<CR>", "n", false, true)
      end)
      vim.keymap.set("n", "za", function() M.current("toggle") end, {
        buffer = bufnr,
        silent = true,
        desc = "Debug panel: toggle section",
      })
      vim.keymap.set("n", "zo", function() M.current("open") end, {
        buffer = bufnr,
        silent = true,
        desc = "Debug panel: expand section",
      })
      vim.keymap.set("n", "zc", function() M.current("close") end, {
        buffer = bufnr,
        silent = true,
        desc = "Debug panel: collapse section",
      })
      vim.keymap.set("n", "<LeftMouse>", handle_left_mouse, {
        buffer = bufnr,
        silent = true,
        desc = "Debug panel: expand collapsed section",
      })
      vim.keymap.set("n", "<CR>", function()
        local current = state(vim.api.nvim_get_current_tabpage())
        if not current.expanded[panel.id] then
          M.set(panel.id, true)
        else
          invoke_mapping(original_enter)
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = "Debug panel: expand section or item",
      })
    end
  end
  update_tray_titles(tab)
  return apply(tab)
end

function M.setup()
  if configured then
    return
  end
  configured = true
  _G.NvimDapSidebarToggle = function(minwid)
    M.toggle_index(minwid)
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("dap_tool_buffer_guards", { clear = true }),
    pattern = vim.tbl_keys(tool_filetypes),
    callback = function(args)
      guard_tool_buffer(args.buf)
    end,
    desc = "Keep debug actions out of DAP tool buffers",
  })
  vim.api.nvim_create_autocmd("WinResized", {
    group = vim.api.nvim_create_augroup("dap_sidebar_sections", { clear = true }),
    callback = function()
      schedule_refresh()
    end,
    desc = "Preserve collapsible DAP sidebar sections",
  })
end

M.panels = panels

return M
