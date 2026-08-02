local M = {}
local pending = {}

local function cancel(bufnr)
  for client_id, request_id in pairs(pending[bufnr] or {}) do
    local client = vim.lsp.get_client_by_id(client_id)
    if client and not client:is_stopped() then
      client:cancel_request(request_id)
    end
  end
  pending[bufnr] = nil
end

local function clear(bufnr)
  cancel(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.lsp.util.buf_clear_references(bufnr)
  end
end

local function highlight(bufnr)
  cancel(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local clients = vim.lsp.get_clients { bufnr = bufnr, method = "textDocument/documentHighlight" }
  if #clients == 0 then
    return
  end
  pending[bufnr] = {}

  for _, client in ipairs(clients) do
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local _, request_id = client:request("textDocument/documentHighlight", params, function(err, result)
      if pending[bufnr] then
        pending[bufnr][client.id] = nil
      end
      if
        err
        or not result
        or not vim.api.nvim_buf_is_valid(bufnr)
        or not vim.api.nvim_buf_is_loaded(bufnr)
        or not vim.lsp.buf_is_attached(bufnr, client.id)
      then
        return
      end
      vim.lsp.util.buf_highlight_references(bufnr, result, client.offset_encoding)
    end, bufnr)
    if request_id then
      pending[bufnr][client.id] = request_id
    end
  end
end

function M.attach(bufnr)
  if vim.b[bufnr].lsp_reference_highlight then
    return
  end
  vim.b[bufnr].lsp_reference_highlight = true
  local group = vim.api.nvim_create_augroup("lsp_reference_highlight_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      highlight(bufnr)
    end,
    desc = "Highlight references under the cursor safely",
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      clear(bufnr)
    end,
    desc = "Cancel and clear LSP reference highlights",
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = bufnr,
    callback = function()
      cancel(bufnr)
    end,
    desc = "Cancel pending LSP reference highlights",
  })
end

return M
