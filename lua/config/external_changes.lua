local M = {}

local function settings()
  return require("config.settings").files or {}
end

local function checktime()
  if settings().auto_reload_external_changes == false
      or vim.fn.getcmdwintype() ~= ""
      or vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    return
  end
  pcall(vim.cmd.checktime)
end

function M.setup()
  vim.opt.autoread = settings().auto_reload_external_changes ~= false

  local group = vim.api.nvim_create_augroup("external_file_changes", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
    group = group,
    callback = checktime,
    desc = "Check for files changed outside Neovim",
  })

  vim.api.nvim_create_autocmd("FileChangedShell", {
    group = group,
    callback = function(args)
      local reason = vim.v.fcs_reason
      if reason == "conflict" then
        -- The native prompt offers OK (keep the Neovim buffer), Load File
        -- (discard local edits), and Load File and Options.
        vim.v.fcs_choice = settings().external_change_conflict == "reload" and "reload" or "ask"
      elseif reason == "changed" then
        vim.v.fcs_choice = "reload"
      elseif reason == "deleted" then
        vim.v.fcs_choice = ""
        vim.notify(
          "File was deleted externally; keeping the Neovim buffer:\n" .. args.file,
          vim.log.levels.WARN,
          { title = "External file change" }
        )
      else
        -- A mode or timestamp-only change does not require replacing text.
        vim.v.fcs_choice = ""
      end
    end,
    desc = "Resolve external file changes without silent data loss",
  })
end

return M
