local M = {}

local defaults = {
  auto_show = true,
  delay_ms = 3000,
  border = "rounded",
  max_width = 0.8,
  max_height = 0.5,
  navigation_hints = true,
}

local function settings()
  local lsp = require("config.settings").lsp or {}
  return vim.tbl_deep_extend("force", defaults, lsp.documentation or {})
end

local function has_floating_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return true
    end
  end
  return false
end

function M.show()
  local opts = settings()
  local max_width = tonumber(opts.max_width) or defaults.max_width
  local max_height = tonumber(opts.max_height) or defaults.max_height
  vim.lsp.buf.hover({
    border = opts.border,
    title = opts.navigation_hints == false
        and " Documentation "
        or " gd Definition · gD Declaration · gri Implementation ",
    title_pos = "center",
    max_width = math.max(1, math.floor(vim.o.columns * max_width)),
    max_height = math.max(1, math.floor(vim.o.lines * max_height)),
  })
end

local function configure_hover_window(float_buf, float_win, source_buf, source_win)
  if vim.b[float_buf].symbol_documentation_mapped then
    return
  end
  vim.b[float_buf].symbol_documentation_mapped = true

  local function navigate(action)
    return function()
      if not vim.api.nvim_buf_is_valid(source_buf) then
        vim.notify("The source buffer is no longer available", vim.log.levels.WARN)
        return
      end

      if not vim.api.nvim_win_is_valid(source_win)
          or vim.api.nvim_win_get_buf(source_win) ~= source_buf then
        source_win = vim.fn.win_findbuf(source_buf)[1]
      end
      if not source_win or not vim.api.nvim_win_is_valid(source_win) then
        vim.notify("The source window is no longer available", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(source_win)
      if vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
      end
      action()
    end
  end

  local telescope = require("telescope.builtin")
  vim.keymap.set("n", "gd", navigate(telescope.lsp_definitions), {
    buffer = float_buf,
    silent = true,
    desc = "Documentation: go to definition",
  })
  vim.keymap.set("n", "gD", navigate(vim.lsp.buf.declaration), {
    buffer = float_buf,
    silent = true,
    desc = "Documentation: go to declaration",
  })
  vim.keymap.set("n", "gri", navigate(telescope.lsp_implementations), {
    buffer = float_buf,
    silent = true,
    desc = "Documentation: find implementations",
  })
end

local function setup_hover_window_mappings()
  if vim.g.symbol_documentation_window_mappings then
    return
  end
  vim.g.symbol_documentation_window_mappings = true

  local group = vim.api.nvim_create_augroup("symbol_documentation_windows", { clear = true })
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local ok, source_buf = pcall(vim.api.nvim_win_get_var, win, "textDocument/hover")
          if ok and source_buf then
            local float_buf = vim.api.nvim_win_get_buf(win)
            local source_win
            for _, candidate in ipairs(vim.fn.win_findbuf(source_buf)) do
              if vim.api.nvim_win_get_config(candidate).relative == "" then
                source_win = candidate
                break
              end
            end
            if source_win then
              configure_hover_window(float_buf, win, source_buf, source_win)
            end
          end
        end
      end)
    end,
    desc = "Add source navigation mappings to LSP documentation windows",
  })
end

function M.setup(bufnr)
  setup_hover_window_mappings()
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if vim.b[bufnr].symbol_documentation_configured then
    return
  end
  vim.b[bufnr].symbol_documentation_configured = true
  vim.b[bufnr].symbol_documentation_generation = 0

  local function cancel()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr].symbol_documentation_generation =
        (vim.b[bufnr].symbol_documentation_generation or 0) + 1
    end
  end

  local function schedule()
    cancel()
    local opts = settings()
    local delay_ms = tonumber(opts.delay_ms) or defaults.delay_ms
    if opts.auto_show == false or delay_ms < 0 then
      return
    end

    local generation = vim.b[bufnr].symbol_documentation_generation
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr)
          or vim.api.nvim_get_current_buf() ~= bufnr
          or vim.b[bufnr].symbol_documentation_generation ~= generation
          or vim.api.nvim_get_mode().mode ~= "n"
          or vim.bo[bufnr].buftype ~= ""
          or vim.fn.pumvisible() == 1
          or has_floating_window() then
        return
      end

      local current_cursor = vim.api.nvim_win_get_cursor(0)
      if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
        return
      end
      if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" }) == 0 then
        return
      end
      M.show()
    end, delay_ms)
  end

  local group = vim.api.nvim_create_augroup("symbol_documentation_" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = bufnr,
    callback = schedule,
    desc = "Show symbol documentation after the cursor rests",
  })
  vim.api.nvim_create_autocmd({ "CursorMovedI", "InsertEnter", "BufLeave" }, {
    group = group,
    buffer = bufnr,
    callback = cancel,
    desc = "Cancel pending symbol documentation",
  })

  schedule()
end

return M
