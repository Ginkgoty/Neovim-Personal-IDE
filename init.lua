-- Core config
require('core.options')
require('config.filetypes')
require('config.readonly').setup()
require('config.buffers').setup()
require('config.jumps').setup()
require('config.external_changes').setup()

-- Lazy.vim
require("config.lazy")

-- keymaps
require("config.keymaps")

-- autocmds
require("config.autocmd")
