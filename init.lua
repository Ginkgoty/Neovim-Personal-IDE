-- Core config
require('core.options')
require('config.filetypes')
require('config.readonly').setup()

-- Lazy.vim
require("config.lazy")

-- keymaps
require("config.keymaps")

-- autocmds
require("config.autocmd")
