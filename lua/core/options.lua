local M = {}

function M.apply_user_settings()
  local settings = require("config.settings")
  local editor = settings.editor or {}
  local files = settings.files or {}

  local indent_size = tonumber(editor.indent_size) or 4
  vim.opt.shiftwidth = indent_size
  vim.opt.tabstop = indent_size
  vim.opt.softtabstop = indent_size
  vim.opt.expandtab = editor.expand_tabs ~= false
  vim.opt.number = editor.line_numbers ~= false
  vim.opt.textwidth = tonumber(editor.text_width) or 80
  vim.opt.updatetime = tonumber(editor.cursor_hold_ms) or 500
  vim.opt.backup = files.backup == true
  vim.opt.swapfile = files.swap == true
  vim.opt.autoread = files.auto_reload_external_changes ~= false
  vim.opt.clipboard = editor.system_clipboard == false and "" or "unnamedplus"
end

M.apply_user_settings()

-- Show the current mode (e.g., insert, normal)
vim.opt.showmode = true

-- Display incomplete commands
vim.opt.showcmd = true

-- Enable automatic indentation
vim.opt.autoindent = true

-- Enable smart indentation
vim.opt.smartindent = true

-- Show cursor position in the status line
vim.opt.ruler = true
-- vim.opt.cursorline = true

-- Highlight matching parentheses
vim.opt.showmatch = true

-- Highlight search results
vim.opt.hlsearch = true

-- Ignore case-sensitive search
vim.opt.ignorecase = true

-- Smart case-sensitive search
vim.opt.smartcase = true

-- File blur match
vim.opt.wildignorecase = true

-- Enable spell check with English (US) language
-- vim.opt.spell = true
-- vim.opt.spelllang = {'en_us'}

--[[
 Fix for red background on Chinese characters:
 If spell checking is enabled, Neovim may flag non-English characters as misspellings.
 To avoid the issue, we turn off spell checking or limit it to English only.
]]
vim.opt.spell = false

-- 256 Colors
vim.opt.termguicolors = true

-- These optional remote providers are not used by this configuration.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Pasting in a nomodifiable buffer (nvim-tree, picker panels, read-only
-- protected files) makes Neovim's built-in paste handler call nvim_put and
-- throw E21 with a full Lua traceback. Show the plain E21 message instead.
-- Terminal-mode and cmdline pastes are left to the original handler.
vim.paste = (function(overridden)
  return function(lines, phase)
    local mode = vim.api.nvim_get_mode().mode
    if not vim.bo.modifiable and vim.fn.getcmdtype() == "" and mode:find("^[nvV\22sS\19]") then
      vim.api.nvim_echo({ { "E21: Cannot make changes, 'modifiable' is off", "ErrorMsg" } }, true, {})
      return false
    end
    return overridden(lines, phase)
  end
end)(vim.paste)

return M
