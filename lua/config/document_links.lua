local M = {}
local namespace = vim.api.nvim_create_namespace("clangd_document_links")
local attached = {}
local generations = {}
local rendered_links = {}

local function resolve_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function settings()
  return (require("config.settings").lsp or {}).document_links or {}
end

local function byte_position(bufnr, position, encoding)
  local line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1] or ""
  return position.line, vim.str_byteindex(line, encoding, position.character, false)
end

function M.refresh(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or settings().enabled == false then
    return
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    name = "clangd",
    method = "textDocument/documentLink",
  })
  if #clients == 0 then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    return
  end

  generations[bufnr] = (generations[bufnr] or 0) + 1
  local generation = generations[bufnr]
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local pending = #clients
  local collected = {}

  for _, client in ipairs(clients) do
    client:request("textDocument/documentLink", {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
    }, function(err, links)
      pending = pending - 1
      if not err then
        for _, link in ipairs(links or {}) do
          if link.target and link.range then
            collected[#collected + 1] = {
              link = link,
              encoding = client.offset_encoding,
              client_id = client.id,
            }
          end
        end
      end
      if pending ~= 0 or generations[bufnr] ~= generation or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      if vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
        M.schedule(bufnr)
        return
      end

      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      rendered_links[bufnr] = {}
      for _, item in ipairs(collected) do
        local range = item.link.range
        local start_row, start_col = byte_position(bufnr, range.start, item.encoding)
        local end_row, end_col = byte_position(bufnr, range["end"], item.encoding)
        vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "LspDocumentLink",
          hl_mode = "combine",
          priority = 120,
        })
        rendered_links[bufnr][#rendered_links[bufnr] + 1] = {
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
          target = item.link.target,
          encoding = item.encoding,
          client_id = item.client_id,
        }
      end
    end, bufnr)
  end
end

function M.follow_at_cursor(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  for _, link in ipairs(rendered_links[bufnr] or {}) do
    local after_start = row > link.start_row or (row == link.start_row and col >= link.start_col)
    local before_end = row < link.end_row or (row == link.end_row and col < link.end_col)
    if after_start and before_end then
      local opened = vim.lsp.util.show_document({ uri = link.target }, link.encoding or "utf-16", {
        reuse_win = true,
        focus = true,
      })
      if opened and link.client_id then
        local target_bufnr = vim.api.nvim_get_current_buf()
        local source_client = vim.lsp.get_client_by_id(link.client_id)
        if source_client and not source_client:is_stopped() then
          vim.lsp.buf_attach_client(target_bufnr, link.client_id)
          vim.schedule(function()
            for _, candidate in ipairs(vim.lsp.get_clients({ bufnr = target_bufnr, name = "clangd" })) do
              if candidate.id ~= link.client_id and not candidate.root_dir then
                vim.lsp.buf_detach_client(target_bufnr, candidate.id)
                if vim.tbl_isempty(candidate.attached_buffers) then
                  candidate:stop()
                end
              end
            end
          end)
        end
      end
      return opened
    end
  end
  return false
end

function M.schedule(bufnr)
  generations[bufnr] = (generations[bufnr] or 0) + 1
  local generation = generations[bufnr]
  vim.defer_fn(function()
    if generations[bufnr] == generation then
      M.refresh(bufnr)
    end
  end, settings().refresh_delay_ms or 250)
end

function M.attach(bufnr, client)
  if client.name ~= "clangd" or not client:supports_method("textDocument/documentLink", bufnr) then
    return
  end
  vim.api.nvim_set_hl(0, "LspDocumentLink", { link = "Underlined", default = true })
  if not attached[bufnr] then
    attached[bufnr] = true
    local group = vim.api.nvim_create_augroup("clangd_document_links_" .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
      group = group,
      buffer = bufnr,
      callback = function()
        M.schedule(bufnr)
      end,
      desc = "Refresh resolved clangd document links",
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
      group = group,
      buffer = bufnr,
      callback = function()
        attached[bufnr] = nil
        generations[bufnr] = nil
        rendered_links[bufnr] = nil
      end,
    })
  end
  M.schedule(bufnr)
end

return M
