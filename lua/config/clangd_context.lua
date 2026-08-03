local M = {}

local clients_by_tab = {}
local setup_done = false
local clangd_filetypes = {
  c = true,
  cpp = true,
  objc = true,
  objcpp = true,
  cuda = true,
}

local function usable_project_client(client)
  return client
    and client.name == "clangd"
    and client.root_dir
    and client.config._standalone_header ~= true
    and not client:is_stopped()
end

function M.project_client()
  local client_id = clients_by_tab[vim.api.nvim_get_current_tabpage()]
  local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
  return usable_project_client(client) and client or nil
end

local function remember(bufnr)
  local tabpage = vim.api.nvim_get_current_tabpage()
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "clangd" }) do
    if usable_project_client(client) then
      clients_by_tab[tabpage] = client.id
      return
    end
  end
end

-- Inheriting the tab's project client only helps a protected header when that
-- project can actually supply a compilation context. Without a compilation
-- database there is no translation-unit context to inherit, and clangd parses
-- the header with its generic fallback, which is Objective-C++ for .h and
-- extensionless files; the standalone path assigns the real language instead.
local function project_has_context(client, filename)
  return client and require("config.clangd").client_compilation_database(client, filename) ~= nil
end

local function inherit(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or not require("config.readonly").should_lock(filename) then
    remember(bufnr)
    return
  end
  if not clangd_filetypes[vim.bo[bufnr].filetype] then
    return
  end

  -- Project navigation wins over the standalone compiler-header fallback only
  -- when the project owns a compilation database, so clangd's command
  -- inference can retain the originating translation unit's real context.
  local client = M.project_client()
  if project_has_context(client, filename) then
    vim.lsp.buf_attach_client(bufnr, client.id)
  end
end

local function prepare_standalone(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or not require("config.readonly").should_lock(filename) then
    return
  end
  -- A clangd client attached by inherit() above already provides context.
  if next(vim.lsp.get_clients { bufnr = bufnr, name = "clangd" }) then
    return
  end
  local context = require("config.platform").standard_header_context(filename)
  if not context or vim.b[bufnr].clangd_standalone_language == context.language then
    return
  end
  vim.b[bufnr].clangd_standalone_language = context.language
  if vim.bo[bufnr].filetype ~= context.language then
    vim.bo[bufnr].filetype = context.language
  end
end

function M.remember(bufnr, client)
  if usable_project_client(client) then
    clients_by_tab[vim.api.nvim_get_current_tabpage()] = client.id
  else
    remember(bufnr)
  end
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  local group = vim.api.nvim_create_augroup("clangd_project_context", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      inherit(args.buf)
      prepare_standalone(args.buf)
    end,
    desc = "Inherit project clangd context in protected dependency headers",
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      for tabpage in pairs(clients_by_tab) do
        if not vim.api.nvim_tabpage_is_valid(tabpage) then
          clients_by_tab[tabpage] = nil
        end
      end
    end,
    desc = "Forget clangd context for closed tabs",
  })
end

return M
