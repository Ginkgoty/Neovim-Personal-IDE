-- Do not start plugin, Mason, or Tree-sitter setup until their host tools are
-- usable. A blocked startup remains a minimal Neovim session with instructions.
if not require("config.bootstrap").check() then
  return
end

-- Core config
require "core.options"
require "config.filetypes"
require("config.readonly").setup()
require("config.buffers").setup()
require("config.jumps").setup()
require("config.external_changes").setup()
require("config.diagnostics").setup()

-- Lazy.vim
require "config.lazy"
require("config.ui_highlights").setup()

-- keymaps
require "config.keymaps"

-- autocmds
require "config.autocmd"
