local M = {}

local namespace = vim.api.nvim_create_namespace "rust.codelens"
local states = {}

local commands = {
  run = "rust-analyzer.runSingle",
  debug = "rust-analyzer.debugSingle",
  references = "rust-analyzer.showReferences",
}

local priorities = {
  [commands.run] = 1,
  [commands.debug] = 2,
  [commands.references] = 3,
}

local function state(bufnr)
  return states[bufnr]
end

local function resolve_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function command_name(lens)
  return lens.command and lens.command.command or nil
end

local function title(lens)
  local name = command_name(lens)
  if name == commands.run then
    return "Run(<leader>cl)"
  end
  if name == commands.debug then
    return "Debug(<leader>dr)"
  end
  if name == commands.references then
    local count = tostring(lens.command.title or ""):match "(%d+)%s+[Rr]eferences?"
    if count then
      return count .. (count == "1" and " reference" or " references")
    end
  end
end

local function render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  local current = state(bufnr)
  if not current or not current.enabled then
    return
  end

  local rows = {}
  for _, lens in ipairs(current.lenses or {}) do
    local text = title(lens)
    if text then
      local row = lens.range.start.line
      rows[row] = rows[row] or {}
      rows[row][#rows[row] + 1] = { lens = lens, text = text }
    end
  end

  for row, items in pairs(rows) do
    table.sort(items, function(left, right)
      return (priorities[command_name(left.lens)] or 99) < (priorities[command_name(right.lens)] or 99)
    end)

    local chunks = {}
    for index, item in ipairs(items) do
      if index > 1 then
        chunks[#chunks + 1] = { " | ", "LspCodeLensSeparator" }
      end
      chunks[#chunks + 1] = { item.text, "LspCodeLens" }
    end

    -- Do not copy rust-analyzer's range.start.character here. Native Neovim
    -- uses it as left padding, although Rust lenses point at the function name
    -- rather than column zero.
    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
      virt_lines = { chunks },
      virt_lines_above = true,
      virt_lines_overflow = "scroll",
      hl_mode = "combine",
    })
  end
end

local function refresh(bufnr)
  local current = state(bufnr)
  local client = current and vim.lsp.get_client_by_id(current.client_id) or nil
  if not current or not current.enabled or not client or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  current.generation = current.generation + 1
  local generation = current.generation
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  client:request("textDocument/codeLens", params, function(err, result)
    current = state(bufnr)
    if err or not current or current.generation ~= generation then
      return
    end

    current.lenses = result or {}
    render(bufnr)

    for index, lens in ipairs(current.lenses) do
      if not lens.command then
        client:request("codeLens/resolve", lens, function(resolve_err, resolved)
          current = state(bufnr)
          if
            resolve_err
            or not resolved
            or not current
            or current.generation ~= generation
            or current.lenses[index] ~= lens
          then
            return
          end
          current.lenses[index] = resolved
          render(bufnr)
        end, bufnr)
      end
    end
  end, bufnr)
end

local function lens_at_cursor(bufnr, wanted)
  local current = state(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, lens in ipairs(current and current.lenses or {}) do
    if lens.range.start.line == row and command_name(lens) == wanted then
      return lens
    end
  end
end

local function runnable(lens)
  local arguments = lens and lens.command and lens.command.arguments or nil
  local value = arguments and arguments[1] or nil
  return type(value) == "table" and value.args or nil
end

local function notify_result(action, result)
  vim.schedule(function()
    local output = result.code == 0 and result.stdout or result.stderr
    vim.notify(
      output and vim.trim(output) ~= "" and vim.trim(output)
        or action .. (result.code == 0 and " finished" or " failed"),
      result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR,
      { title = "Rust " .. action }
    )
  end)
end

function M.run(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local lens = lens_at_cursor(bufnr, commands.run)
  local args = runnable(lens)
  if not args or type(args.cargoArgs) ~= "table" then
    vim.notify("No Rust Run CodeLens on the current line", vim.log.levels.INFO)
    return
  end

  local cmd = { "cargo" }
  vim.list_extend(cmd, args.cargoArgs)
  vim.notify("Running " .. table.concat(cmd, " "), vim.log.levels.INFO, { title = "Rust Run" })
  vim.system(cmd, {
    cwd = args.cwd,
    env = args.environment,
    text = true,
  }, function(result)
    notify_result("Run", result)
  end)
end

local function build_command(args)
  local cargo_args = vim.deepcopy(args.cargoArgs or {})
  local subcommand = cargo_args[1]
  if subcommand == "run" then
    cargo_args[1] = "build"
  elseif subcommand == "test" or subcommand == "bench" then
    if not vim.tbl_contains(cargo_args, "--no-run") then
      table.insert(cargo_args, 2, "--no-run")
    end
  else
    return nil
  end

  for _, argument in ipairs(cargo_args) do
    if argument:match "^%-%-message%-format" then
      local cmd = { "cargo" }
      vim.list_extend(cmd, cargo_args)
      return cmd
    end
  end
  table.insert(cargo_args, 2, "--message-format=json")
  local cmd = { "cargo" }
  vim.list_extend(cmd, cargo_args)
  return cmd
end

local function executable_from_messages(output)
  local executable
  for line in tostring(output or ""):gmatch "[^\r\n]+" do
    local ok, message = pcall(vim.json.decode, line)
    if ok and message.reason == "compiler-artifact" and type(message.executable) == "string" then
      executable = message.executable
    end
  end
  return executable
end

function M.debug(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local lens = lens_at_cursor(bufnr, commands.debug)
  local args = runnable(lens)
  local cmd = args and build_command(args) or nil
  if not args or not cmd then
    vim.notify("No supported Rust Debug CodeLens on the current line", vim.log.levels.INFO)
    return
  end

  vim.notify("Building debug target", vim.log.levels.INFO, { title = "Rust Debug" })
  vim.system(cmd, {
    cwd = args.cwd,
    env = args.environment,
    text = true,
  }, function(result)
    local executable = result.code == 0 and executable_from_messages(result.stdout) or nil
    if not executable then
      notify_result("Debug build", result)
      return
    end

    vim.schedule(function()
      require("dap").run {
        name = "Debug " .. tostring(args.label or vim.fs.basename(executable)),
        type = "codelldb",
        request = "launch",
        program = executable,
        cwd = args.cwd,
        args = args.executableArgs or {},
        env = args.environment,
        stopOnEntry = false,
      }
    end)
  end)
end

function M.toggle(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local current = state(bufnr)
  if not current then
    return
  end
  current.enabled = not current.enabled
  if current.enabled then
    refresh(bufnr)
  else
    render(bufnr)
  end
end

function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end
  for bufnr, current in pairs(states) do
    if current.client_id == ctx.client_id then
      refresh(bufnr)
    end
  end
  return vim.NIL
end

function M.attach(bufnr, client)
  if states[bufnr] and states[bufnr].client_id == client.id then
    refresh(bufnr)
    return
  end

  states[bufnr] = {
    client_id = client.id,
    enabled = true,
    generation = 0,
    lenses = {},
  }

  vim.keymap.set("n", "<leader>cl", function()
    M.run(bufnr)
  end, { buffer = bufnr, silent = true, desc = "Rust: run CodeLens target" })
  vim.keymap.set("n", "<leader>dr", function()
    M.debug(bufnr)
  end, { buffer = bufnr, silent = true, desc = "Rust: debug CodeLens target" })
  vim.keymap.set("n", "<leader>ul", function()
    M.toggle(bufnr)
  end, { buffer = bufnr, silent = true, desc = "UI: toggle Rust CodeLens" })

  local group = vim.api.nvim_create_augroup("RustCodeLens" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      refresh(bufnr)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "LspDetach" }, {
    group = group,
    buffer = bufnr,
    callback = function(args)
      if args.event == "BufWipeout" or not args.data or args.data.client_id == client.id then
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        states[bufnr] = nil
        pcall(vim.api.nvim_del_augroup_by_id, group)
      end
    end,
  })

  refresh(bufnr)
end

return M
