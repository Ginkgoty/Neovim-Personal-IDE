local M = {}

local function quick_fix_at_selection(prompt_bufnr)
  local action_set = require("telescope.actions.set")
  local action_state = require("telescope.actions.state")
  local entry = action_state.get_selected_entry()
  if not entry then
    return
  end

  -- Let Telescope perform its normal edit/jump first. Requesting the action
  -- afterwards ensures every LSP client receives the correct target buffer,
  -- cursor position, diagnostics, and position encoding.
  action_set.select(prompt_bufnr, "default")
  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" }) == 0 then
      return
    end
    vim.lsp.buf.code_action({
      context = { only = { vim.lsp.protocol.CodeActionKind.QuickFix } },
    })
  end)
end

function M.telescope(opts)
  opts = vim.deepcopy(opts or {})
  local previous_attach = opts.attach_mappings
  opts.attach_mappings = function(prompt_bufnr, map)
    if previous_attach and previous_attach(prompt_bufnr, map) == false then
      return false
    end

    require("telescope.actions").select_default:replace(function()
      quick_fix_at_selection(prompt_bufnr)
    end)
    return true
  end
  require("telescope.builtin").diagnostics(opts)
end

local severity_labels = {
  E = "ERROR",
  W = "WARN",
  I = "INFO",
  N = "HINT",
}

local function fit(text, width)
  text = tostring(text or "")
  if vim.fn.strdisplaywidth(text) <= width then
    return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
  end

  local shortened = vim.fn.pathshorten(text)
  if vim.fn.strdisplaywidth(shortened) <= width then
    return shortened .. string.rep(" ", width - vim.fn.strdisplaywidth(shortened))
  end

  while shortened ~= "" and vim.fn.strdisplaywidth(shortened .. "…") > width do
    shortened = vim.fn.strcharpart(shortened, 0, vim.fn.strchars(shortened) - 1)
  end
  shortened = shortened .. "…"
  return shortened .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(shortened)))
end

function M.format_table(info)
  local list
  local winid = info.winid
  if info.quickfix == 1 then
    list = vim.fn.getqflist({ id = info.id, items = 0 })
    winid = vim.fn.getqflist({ id = info.id, winid = 0 }).winid
  else
    list = vim.fn.getloclist(info.winid, { id = info.id, items = 0 })
  end
  local items = list.items or {}
  local window_width = winid and winid > 0 and vim.api.nvim_win_is_valid(winid)
      and vim.api.nvim_win_get_width(winid)
    or vim.o.columns

  local widest_path = 12
  local paths = {}
  for index, item in ipairs(items) do
    local path = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename or ""
    path = path ~= "" and vim.fn.fnamemodify(path, ":~:.") or "[No File]"
    paths[index] = path
    widest_path = math.max(widest_path, vim.fn.strdisplaywidth(path))
  end
  local path_width = math.max(12, math.min(48, window_width - 42, widest_path))

  local result = {}
  for index = info.start_idx, info.end_idx do
    local item = items[index]
    if item then
      local severity = fit(severity_labels[item.type] or item.type or "", 5)
      local position = ("%5d:%-3d"):format(item.lnum or 0, item.col or 0)
      local message = tostring(item.text or ""):gsub("[\r\n]+", " ")
      result[#result + 1] = ("%s │ %s │ %s │ %s"):format(
        severity,
        fit(paths[index], path_width),
        position,
        message
      )
    end
  end
  return result
end

local filters = {
  a = { label = "ALL" },
  e = { label = "ERROR", severity = vim.diagnostic.severity.ERROR },
  w = { label = "WARN", severity = vim.diagnostic.severity.WARN },
  i = { label = "INFO", severity = vim.diagnostic.severity.INFO },
  h = { label = "HINT", severity = vim.diagnostic.severity.HINT },
}

local function diagnostics_for(state, filter)
  local diagnostics = vim.diagnostic.get(state.scope == "buffer" and state.bufnr or nil)
  if not filter.severity then
    return diagnostics
  end
  return vim.tbl_filter(function(diagnostic)
    return diagnostic.severity == filter.severity
  end, diagnostics)
end

local function update_table(state, filter)
  local scope = state.scope == "buffer" and "Current Buffer" or "All Buffers"
  local what = {
    title = ("%s Diagnostics [%s]"):format(scope, filter.label),
    items = vim.diagnostic.toqflist(diagnostics_for(state, filter)),
    context = { nvim_diagnostic_table = true, scope = state.scope, filter = filter.label },
    quickfixtextfunc = "v:lua.NvimDiagnosticTableText",
  }
  if state.scope == "buffer" then
    vim.fn.setloclist(state.source_win, {}, " ", what)
  else
    vim.fn.setqflist({}, " ", what)
  end
  return #what.items
end

local function configure_table_window(state)
  local table_win = vim.api.nvim_get_current_win()
  local table_buf = vim.api.nvim_get_current_buf()
  vim.b[table_buf].nvim_diagnostic_table = true
  vim.wo[table_win].winbar = " Diagnostics: a All · e Error · w Warn · i Info · h Hint · q Close "

  local keys = { "q" }
  vim.keymap.set("n", "q", function()
    if state.scope == "buffer" then
      vim.cmd.lclose()
    else
      vim.cmd.cclose()
    end
  end, {
    buffer = table_buf,
    silent = true,
    nowait = true,
    desc = "Diagnostics table: close",
  })

  for key, filter in pairs(filters) do
    keys[#keys + 1] = key
    vim.keymap.set("n", key, function()
      update_table(state, filter)
      if vim.api.nvim_win_is_valid(table_win) then
        vim.api.nvim_set_current_win(table_win)
      end
    end, {
      buffer = table_buf,
      silent = true,
      nowait = true,
      desc = "Diagnostics table: " .. filter.label,
    })
  end

  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = table_buf,
    once = true,
    callback = function()
      if not vim.api.nvim_buf_is_valid(table_buf) then
        return
      end
      for _, key in ipairs(keys) do
        pcall(vim.keymap.del, "n", key, { buffer = table_buf })
      end
      vim.b[table_buf].nvim_diagnostic_table = nil
    end,
    desc = "Remove diagnostic table filters when its window closes",
  })
end

local function open_table(state)
  if update_table(state, filters.a) == 0 then
    vim.notify("No diagnostics found", vim.log.levels.INFO)
    return
  end
  if state.scope == "buffer" then
    vim.api.nvim_set_current_win(state.source_win)
    vim.cmd.lopen()
  else
    vim.cmd.copen()
  end
  configure_table_window(state)
end

function M.open_buffer_table(bufnr)
  open_table({
    scope = "buffer",
    bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr,
    source_win = vim.api.nvim_get_current_win(),
  })
end

function M.open_all_table()
  open_table({ scope = "all" })
end

_G.NvimDiagnosticTableText = M.format_table

return M
