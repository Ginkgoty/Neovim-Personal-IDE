-- autocmd
vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
  pattern = "*.owl",
  command = "set filetype=xml",
})

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Code navigation keymaps",
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local telescope = require("telescope.builtin")

    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, {
        buffer = bufnr,
        silent = true,
        desc = desc,
      })
    end

    local function map_modes(modes, lhs, rhs, desc)
      vim.keymap.set(modes, lhs, rhs, {
        buffer = bufnr,
        silent = true,
        desc = desc,
      })
    end

    map("gd", telescope.lsp_definitions, "Code: go to definition")
    map("gD", vim.lsp.buf.declaration, "Code: go to declaration")
    map("grr", telescope.lsp_references, "Code: find references")
    map("gri", telescope.lsp_implementations, "Code: find implementations")
    map("grt", telescope.lsp_type_definitions, "Code: go to type definition")
    map("gai", telescope.lsp_incoming_calls, "Code: incoming calls")
    map("gao", telescope.lsp_outgoing_calls, "Code: outgoing calls")
    local symbol_documentation = require("config.symbol_documentation")
    local hover_documentation = symbol_documentation.show

    -- K is Neovim's conventional documentation key. Keep a leader alias so
    -- the same action is also discoverable through which-key.
    map("K", hover_documentation, "Find: documentation under cursor")
    map("<leader>fd", hover_documentation, "Find: documentation under cursor")
    symbol_documentation.setup(bufnr)

    -- Smart symbol navigation: on a definition, list its references;
    -- anywhere else, jump to the definition (falling back to declaration).
    -- Uses the leader because most terminals cannot attach Shift to Enter.
    local function definition_or_references()
      local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })
      if #clients == 0 then
        vim.notify("No attached LSP client supports go to definition", vim.log.levels.WARN)
        return
      end

      local cursor = vim.api.nvim_win_get_cursor(0)
      local row, col = cursor[1] - 1, cursor[2]
      local current_uri = vim.uri_from_bufnr(bufnr)
      local pending = #clients
      local on_definition, found_definition = false, false

      local function finish()
        if on_definition then
          telescope.lsp_references()
        elseif found_definition then
          telescope.lsp_definitions()
        else
          vim.lsp.buf.declaration()
        end
      end

      for _, client in ipairs(clients) do
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        client:request("textDocument/definition", params, function(err, result)
          if not err and result then
            local locations = vim.islist(result) and result or { result }
            for _, location in ipairs(locations) do
              local uri = location.uri or location.targetUri
              local range = location.range or location.targetSelectionRange
              if uri and range then
                found_definition = true
                if uri == current_uri then
                  local first, last = range.start, range["end"]
                  local after_start = row > first.line or (row == first.line and col >= first.character)
                  local before_end = row < last.line or (row == last.line and col <= last.character)
                  if after_start and before_end then
                    on_definition = true
                  end
                end
              end
            end
          end
          pending = pending - 1
          if pending == 0 then
            vim.schedule(finish)
          end
        end, bufnr)
      end
    end

    map("<leader><CR>", definition_or_references, "Code: references on definition, else go to definition")

    local function code_action(kind)
      return function()
        vim.lsp.buf.code_action(kind and { context = { only = { kind } } } or nil)
      end
    end

    map("<leader>cr", vim.lsp.buf.rename, "Code: rename symbol")
    map_modes({ "n", "v" }, "<leader>ca", code_action(), "Code: contextual action")
    map_modes({ "n", "v" }, "<leader>ci", code_action(vim.lsp.protocol.CodeActionKind.RefactorInline),
      "Code: inline refactor")
    map_modes("v", "<leader>ce", code_action(vim.lsp.protocol.CodeActionKind.RefactorExtract),
      "Code: extract selection")
    map("<leader>co", code_action(vim.lsp.protocol.CodeActionKind.SourceOrganizeImports),
      "Code: organize imports")
    map("<leader>cF", code_action("source.fixAll"), "Code: fix all")
    map("<leader>fs", telescope.lsp_document_symbols, "Find: document symbols")
    map("<leader>fS", telescope.lsp_workspace_symbols, "Find: workspace symbols")

    if client and client:supports_method("textDocument/inlayHint", bufnr) then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      map("<leader>uh", function()
        local filter = { bufnr = bufnr }
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
      end, "UI: toggle inlay hints")
    end

    if client and client:supports_method("textDocument/codeLens", bufnr) then
      vim.lsp.codelens.enable(true, { bufnr = bufnr, client_id = client.id })
      map("<leader>ul", function()
        local filter = { bufnr = bufnr }
        vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled(filter), filter)
      end, "UI: toggle CodeLens")
      map("<leader>cl", vim.lsp.codelens.run, "Code: run CodeLens")
    end

    local function diagnostic_jump(count, severity)
      return function()
        vim.diagnostic.jump({ count = count, severity = severity })
      end
    end

    map("[e", diagnostic_jump(-1, vim.diagnostic.severity.ERROR), "Diagnostics: previous error")
    map("]e", diagnostic_jump(1, vim.diagnostic.severity.ERROR), "Diagnostics: next error")
    map("[w", diagnostic_jump(-1, vim.diagnostic.severity.WARN), "Diagnostics: previous warning")
    map("]w", diagnostic_jump(1, vim.diagnostic.severity.WARN), "Diagnostics: next warning")
    map("[d", diagnostic_jump(-1), "Diagnostics: previous")
    map("]d", diagnostic_jump(1), "Diagnostics: next")

    map("<leader>xc", function()
      vim.diagnostic.open_float({
        scope = "cursor",
        focusable = true,
        source = true,
      })
    end, "Diagnostics: show under cursor")

    map("<leader>xq", function()
      vim.lsp.buf.code_action({
        context = { only = { vim.lsp.protocol.CodeActionKind.QuickFix } },
      })
    end, "Diagnostics: quick fix")

    map("<leader>xf", function()
      require("config.diagnostics").telescope({ bufnr = 0 })
    end, "Diagnostics: current file")
    map("<leader>xa", function()
      require("config.diagnostics").telescope({
        sort_by = "severity",
        line_width = "full",
        prompt_title = "All Buffer Diagnostics",
      })
    end, "Diagnostics: all buffers")

    map("<leader>xt", function()
      require("config.diagnostics").open_buffer_table(bufnr)
    end, "Diagnostics: current buffer table")

    map("<leader>xT", function()
      require("config.diagnostics").open_all_table()
    end, "Diagnostics: all buffers table")

    if client and client.name == "clangd" then
      map("<leader>fh", "<cmd>LspClangdSwitchSourceHeader<CR>", "Find: alternate source/header")
      map("<leader>xi", function()
        require("config.clangd").info(bufnr)
      end, "Diagnostics: clangd status")
      require("config.clangd").warn_missing_database(bufnr, client)
    end

    if client
        and client:supports_method("textDocument/documentHighlight", bufnr)
        and not vim.b[bufnr].lsp_reference_highlight then
      vim.b[bufnr].lsp_reference_highlight = true
      local highlight_group = vim.api.nvim_create_augroup("lsp_reference_highlight_" .. bufnr, { clear = true })

      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
        desc = "Highlight references under the cursor",
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
        desc = "Clear LSP reference highlights",
      })
    end
  end,
})

vim.api.nvim_create_user_command("ToolchainInfo", function()
  local platform = require("config.platform")
  local toolchain = platform.c_toolchain()
  if not toolchain then
    vim.notify("No usable native C/C++ toolchain detected", vim.log.levels.WARN)
    return
  end

  local details
  if toolchain.kind == "msvc" then
    details = string.format("MSVC (%s)\ncl.exe: %s\nVisual Studio: %s", toolchain.generator, toolchain.compiler, toolchain.installation)
  elseif toolchain.kind == "mingw" then
    details = string.format("MinGW\ngcc: %s\ng++: %s\nmake: %s", toolchain.compiler, toolchain.cxx_compiler, toolchain.make)
  else
    details = string.format("%s\nC: %s\nC++: %s", toolchain.kind, toolchain.compiler, toolchain.cxx_compiler)
  end
  vim.notify(string.format("Selected native C/C++ toolchain:\n%s\nDebugger: %s", details, toolchain.debugger))
end, { desc = "Show the detected native build toolchain" })

vim.api.nvim_create_user_command("ClangdInfo", function()
  require("config.clangd").info(0)
end, { desc = "Show clangd configuration for the current buffer" })

vim.api.nvim_create_user_command("LanguageInfo", function()
  local languages = require("config.languages")
  local enabled, disabled, unavailable = {}, {}, {}
  for name, value in pairs(languages.enabled_languages) do
    table.insert(value and enabled or disabled, name)
    if value and not languages.available(name) then
      table.insert(unavailable, string.format("%s (%s)", name, languages.prerequisite_names[name] or "prerequisite missing"))
    end
  end
  table.sort(enabled)
  table.sort(disabled)
  table.sort(unavailable)
  local unavailable_text = #unavailable > 0 and ("\nUnavailable toolchains: " .. table.concat(unavailable, ", ")) or ""
  vim.notify(string.format(
    "Enabled languages: %s\nDisabled languages: %s%s\nDevice overrides: lua/config/languages_local.lua",
    table.concat(enabled, ", "),
    table.concat(disabled, ", "),
    unavailable_text
  ))
end, { desc = "Show enabled language support" })

local function language_prerequisite_message(languages, names)
  local lines = { "Some enabled languages are in highlighting-only mode:" }
  for _, name in ipairs(names) do
    local guide = languages.install_guides[name]
    lines[#lines + 1] = string.format(
      "- %s: %s\n  %s",
      languages.display_names[name] or name,
      guide.message,
      guide.url
    )
  end
  lines[#lines + 1] = "After installing the toolchain, restart Neovim."
  return table.concat(lines, "\n")
end

vim.api.nvim_create_user_command("LanguageInstall", function(args)
  local languages = require("config.languages")
  local guide = languages.install_guides[args.args]
  if not guide then
    vim.notify("No installation guide for language: " .. args.args, vim.log.levels.ERROR)
    return
  end
  vim.notify(string.format("%s\n%s", guide.message, guide.url))
  vim.ui.open(guide.url)
end, {
  nargs = 1,
  complete = function()
    local names = vim.tbl_keys(require("config.languages").install_guides)
    table.sort(names)
    return names
  end,
  desc = "Open the official SDK/toolchain installation page",
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  desc = "Warn once about enabled languages with missing toolchains",
  callback = function()
    -- Do not emit startup notifications in headless jobs or test runs.
    if #vim.api.nvim_list_uis() == 0 then
      return
    end
    local languages = require("config.languages")
    local unavailable = languages.unavailable_languages()
    if #unavailable > 0 then
      vim.schedule(function()
        vim.notify(language_prerequisite_message(languages, unavailable), vim.log.levels.WARN, {
          title = "Language toolchains",
        })
      end)
    end
  end,
})
