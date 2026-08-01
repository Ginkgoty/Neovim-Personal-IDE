local M = {}

local defaults = {
  auto_show = true,
  delay_ms = 3000,
  border = "rounded",
  max_width = 0.8,
  max_height = 0.5,
  navigation_hints = true,
  include_diagnostics = true,
  detect_quick_fixes = true,
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

local function line_diagnostics(bufnr, lnum)
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })
  table.sort(diagnostics, function(left, right)
    if left.severity ~= right.severity then
      return (left.severity or vim.diagnostic.severity.ERROR)
        < (right.severity or vim.diagnostic.severity.ERROR)
    end
    return (left.col or 0) < (right.col or 0)
  end)
  return diagnostics
end

local function diagnostic_lines(diagnostics)
  local lines = {}
  for _, diagnostic in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diagnostic.severity] or "INFO"
    severity = severity:sub(1, 1) .. severity:sub(2):lower()
    local origin = diagnostic.source or "LSP"
    if diagnostic.code ~= nil then
      origin = origin .. ":" .. tostring(diagnostic.code)
    end
    origin = origin:gsub("`", "'")

    local message = vim.split(diagnostic.message or "", "\n", { plain = true })
    lines[#lines + 1] = ("- **%s** `%s` — %s"):format(severity, origin, message[1] or "")
    for index = 2, #message do
      lines[#lines + 1] = "  " .. message[index]
    end
  end
  return lines
end

local function append_hover(results, lines)
  local seen = {}
  for _, response in pairs(results or {}) do
    if response.result and response.result.contents then
      local converted = vim.lsp.util.convert_input_to_markdown_lines(response.result.contents)
      converted = vim.split(table.concat(converted, "\n"), "\n", {
        plain = true,
        trimempty = true,
      })
      local key = table.concat(converted, "\n")
      if key ~= "" and not seen[key] then
        if #lines > 0 then
          lines[#lines + 1] = "---"
        end
        vim.list_extend(lines, converted)
        seen[key] = true
      end
    end
  end
end

local function title_for(has_documentation, has_diagnostics, has_quick_fix, opts)
  if opts.navigation_hints ~= false then
    local hints = { "gd Definition", "gD Declaration", "gri Implementation" }
    if has_quick_fix then
      hints[#hints + 1] = "<leader>xq Quick Fix"
    end
    return " " .. table.concat(hints, " · ") .. " "
  end

  local content = has_documentation and has_diagnostics and "Documentation + Diagnostics"
    or has_documentation and "Documentation"
    or "Diagnostics"
  if has_quick_fix then
    content = content .. " · <leader>xq Quick Fix"
  end
  return " " .. content .. " "
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

  vim.keymap.set("n", "gd", navigate(function()
    require("telescope.builtin").lsp_definitions()
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: go to definition",
  })
  vim.keymap.set("n", "gD", navigate(vim.lsp.buf.declaration), {
    buffer = float_buf,
    silent = true,
    desc = "Context: go to declaration",
  })
  vim.keymap.set("n", "gri", navigate(function()
    require("telescope.builtin").lsp_implementations()
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: find implementations",
  })
  vim.keymap.set("n", "<leader>xq", navigate(function()
    vim.lsp.buf.code_action({
      context = { only = { vim.lsp.protocol.CodeActionKind.QuickFix } },
    })
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: apply a quick fix",
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
    desc = "Add source navigation mappings to LSP context windows",
  })
end

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  local source_win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(source_win)
  local opts = settings()
  local diagnostics = opts.include_diagnostics == false and {} or line_diagnostics(bufnr, cursor[1] - 1)
  local hover_clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
  local action_clients = {}
  if opts.detect_quick_fixes ~= false and #diagnostics > 0 then
    action_clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })
  end

  if #hover_clients == 0 and #diagnostics == 0 then
    return
  end

  vim.b[bufnr].symbol_documentation_request =
    (vim.b[bufnr].symbol_documentation_request or 0) + 1
  local request = vim.b[bufnr].symbol_documentation_request
  local hover_results = {}
  local has_quick_fix = false
  local pending = (#hover_clients > 0 and 1 or 0) + (#action_clients > 0 and 1 or 0)

  local function render()
    if not vim.api.nvim_buf_is_valid(bufnr)
        or vim.b[bufnr].symbol_documentation_request ~= request
        or not vim.api.nvim_win_is_valid(source_win)
        or vim.api.nvim_win_get_buf(source_win) ~= bufnr then
      return
    end
    local current = vim.api.nvim_win_get_cursor(source_win)
    if current[1] ~= cursor[1] or current[2] ~= cursor[2] then
      return
    end

    local lines = {}
    append_hover(hover_results, lines)
    local has_documentation = #lines > 0
    if #diagnostics > 0 then
      if #lines > 0 then
        lines[#lines + 1] = "---"
      end
      -- This float is rendered as Markdown. Using an H3 here makes
      -- render-markdown.nvim prepend its circled level-3 heading icon, which
      -- is useful in documents but visually noisy in a compact LSP popup.
      lines[#lines + 1] = "**Diagnostics**"
      vim.list_extend(lines, diagnostic_lines(diagnostics))
    end
    if #lines == 0 then
      return
    end

    vim.api.nvim_set_current_win(source_win)
    local max_width = tonumber(opts.max_width) or defaults.max_width
    local max_height = tonumber(opts.max_height) or defaults.max_height
    local float_buf, float_win = vim.lsp.util.open_floating_preview(lines, "markdown", {
      border = opts.border,
      title = title_for(has_documentation, #diagnostics > 0, has_quick_fix, opts),
      title_pos = "center",
      max_width = math.max(1, math.floor(vim.o.columns * max_width)),
      max_height = math.max(1, math.floor(vim.o.lines * max_height)),
      focus_id = "symbol_documentation",
    })
    if vim.api.nvim_win_is_valid(float_win) then
      -- render-markdown derives code blocks from ColorColumn. Some themes
      -- (notably PaperColor) use the same surface for ColorColumn and
      -- CursorLine, which is also a natural inlay-hint background. Keep code
      -- in this LSP float on the theme's original NormalFloat surface. The
      -- remap is window-local, so regular Markdown buffers remain unchanged.
      local code_background = table.concat({
        "RenderMarkdownCode:NormalFloat",
        "RenderMarkdownCodeBorder:NormalFloat",
        "RenderMarkdownCodeInline:NormalFloat",
      }, ",")
      local window_highlights = vim.wo[float_win].winhighlight
      vim.wo[float_win].winhighlight = window_highlights ~= ""
          and (window_highlights .. "," .. code_background)
        or code_background

      vim.api.nvim_win_set_var(float_win, "textDocument/hover", bufnr)
      configure_hover_window(float_buf, float_win, bufnr, source_win)
    end
  end

  local function complete()
    pending = pending - 1
    if pending == 0 then
      render()
    end
  end

  if #hover_clients > 0 then
    vim.lsp.buf_request_all(bufnr, "textDocument/hover", function(client)
      return vim.lsp.util.make_position_params(source_win, client.offset_encoding)
    end, function(results)
      hover_results = results or {}
      complete()
    end)
  end

  if #action_clients > 0 then
    vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", function(client)
      local params = vim.lsp.util.make_range_params(source_win, client.offset_encoding)
      local lsp_diagnostics = {}
      for _, diagnostic in ipairs(diagnostics) do
        local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
        if lsp_diagnostic then
          lsp_diagnostics[#lsp_diagnostics + 1] = lsp_diagnostic
        end
      end
      params.context = {
        only = { vim.lsp.protocol.CodeActionKind.QuickFix },
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        diagnostics = lsp_diagnostics,
      }
      return params
    end, function(results)
      for _, response in pairs(results or {}) do
        for _, action in ipairs(response.result or {}) do
          if not action.disabled then
            has_quick_fix = true
            break
          end
        end
        if has_quick_fix then
          break
        end
      end
      complete()
    end)
  end

  if pending == 0 then
    render()
  end
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
      vim.b[bufnr].symbol_documentation_request =
        (vim.b[bufnr].symbol_documentation_request or 0) + 1
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
      local has_hover = #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" }) > 0
      local has_diagnostics = opts.include_diagnostics ~= false
        and #line_diagnostics(bufnr, cursor[1] - 1) > 0
      if not has_hover and not has_diagnostics then
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
    desc = "Show symbol context after the cursor rests",
  })
  vim.api.nvim_create_autocmd({ "CursorMovedI", "InsertEnter", "BufLeave" }, {
    group = group,
    buffer = bufnr,
    callback = cancel,
    desc = "Cancel pending symbol context",
  })

  schedule()
end

return M
