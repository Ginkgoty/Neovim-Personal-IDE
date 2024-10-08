-- Disable compatibility mode (use Neovim's extended features)
vim.opt.compatible = false

-- Enable syntax highlighting
vim.cmd('syntax on')

-- Show the current mode (e.g., insert, normal)
vim.opt.showmode = true

-- Display incomplete commands
vim.opt.showcmd = true

-- Set file encoding to UTF-8
vim.opt.encoding = 'utf-8'

-- Enable 256 color support
vim.opt.termguicolors = true

-- Enable filetype-based indentation
vim.cmd('filetype indent on')

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

-- Show cursor position in the status line
vim.opt.ruler = true
-- vim.opt.cursorline = true

-- Highlight matching parentheses
vim.opt.showmatch = true

-- Highlight search results
vim.opt.hlsearch = true

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

-- Ensure UTF-8 encoding is used for file display.
vim.opt.fileencoding = 'utf-8'

-- Fileformat Unix style
vim.opt.fileformat = 'unix'

-- Colorscheme
vim.api.nvim_command('colorscheme lunaperche')

-- 256 Colors
vim.opt.termguicolors = true

