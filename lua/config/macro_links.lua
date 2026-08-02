local M = {}
local definition_cache = {}

local function enabled()
  return ((require("config.settings").lsp or {}).document_links or {}).underline_macros ~= false
end

local function token_text(bufnr, token)
  local line = vim.api.nvim_buf_get_lines(bufnr, token.line, token.line + 1, false)[1] or ""
  return line:sub(token.start_col + 1, token.end_col)
end

local function meaningful_definition(line, expected_name)
  local name, suffix = line:match "^%s*#%s*define%s+([%a_][%w_]*)(.*)$"
  if not name or name ~= expected_name then
    return false
  end
  if suffix:sub(1, 1) == "(" then
    local parameters = suffix:match "^%b()"
    suffix = parameters and suffix:sub(#parameters + 1) or suffix
  end
  suffix = suffix:gsub("/%*.-%*/", ""):gsub("//.*$", "")
  return vim.trim(suffix) ~= ""
end

local function source_line(uri, line)
  if type(uri) ~= "string" or not uri:match "^file:" then
    return
  end
  local filename = vim.uri_to_fname(uri)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr >= 0 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
  end
  local lines = vim.fn.readfile(filename, "", line + 1)
  return lines[line + 1]
end

local function definition_is_meaningful(uri, range, name)
  if not uri or not range then
    return false
  end
  local key = table.concat({ uri, range.start.line, name }, ":")
  if definition_cache[key] == nil then
    definition_cache[key] = meaningful_definition(source_line(uri, range.start.line) or "", name)
  end
  return definition_cache[key]
end

local function underline(token, bufnr, client_id)
  vim.lsp.semantic_tokens.highlight_token(token, bufnr, client_id, "LspMacroLink")
end

local function inspect_token(args)
  local token = args.data and args.data.token
  local client_id = args.data and args.data.client_id
  if not enabled() or not token or token.type ~= "macro" or not client_id then
    return
  end

  local bufnr = args.buf
  local name = token_text(bufnr, token)
  local current_line = vim.api.nvim_buf_get_lines(bufnr, token.line, token.line + 1, false)[1] or ""
  if meaningful_definition(current_line, name) then
    underline(token, bufnr, client_id)
    return
  end

  local client = vim.lsp.get_client_by_id(client_id)
  if not client or client.name ~= "clangd" or not client:supports_method("textDocument/definition", bufnr) then
    return
  end
  local character = vim.str_utfindex(current_line, client.offset_encoding, token.start_col, false)
  client:request("textDocument/definition", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = token.line, character = character },
  }, function(err, result)
    if err or not result or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local locations = vim.islist(result) and result or { result }
    for _, location in ipairs(locations) do
      local uri = location.uri or location.targetUri
      local range = location.range or location.targetSelectionRange
      if definition_is_meaningful(uri, range, name) then
        underline(token, bufnr, client_id)
        return
      end
    end
  end, bufnr)
end

function M.setup()
  vim.api.nvim_set_hl(0, "LspMacroLink", { underline = true })
  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = vim.api.nvim_create_augroup("ResolvedMacroLinks", { clear = true }),
    desc = "Underline navigable macros with non-empty replacement bodies",
    callback = inspect_token,
  })
end

return M
