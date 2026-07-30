-- Show the current mode (e.g., insert, normal)
vim.opt.showmode = true

-- Display incomplete commands
vim.opt.showcmd = true

-- Enable automatic indentation
vim.opt.autoindent = true

-- Enable smart indentation
vim.opt.smartindent = true

-- Set indentation width to 4 spaces
vim.opt.shiftwidth = 4

-- Use spaces instead of tabs
vim.opt.expandtab = true

-- Insert 4 spaces when the Tab key is pressed
vim.opt.softtabstop = 4

-- Display line numbers
vim.opt.number = true

-- Set maximum text width to 80 characters
vim.opt.textwidth = 80

-- Trigger LSP reference highlighting soon after the cursor stops moving.
vim.opt.updatetime = 500

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

-- Disable backup files
vim.opt.backup = false

-- Disable swap files
vim.opt.swapfile = false

--[[
 Fix for red background on Chinese characters:
 If spell checking is enabled, Neovim may flag non-English characters as misspellings.
 To avoid the issue, we turn off spell checking or limit it to English only.
]]
vim.opt.spell = false

-- 256 Colors
vim.opt.termguicolors = true

-- Allow copy to system clipboard
vim.opt.clipboard = "unnamedplus"

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
