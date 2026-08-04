-- lua/config/keymaps.lua

local platform = require('config.platform')

vim.g.mapleader = ' '

vim.keymap.set('n', '<leader>,', function()
  vim.cmd.edit(vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'config', 'settings.lua'))
end, { silent = true, desc = 'Settings: edit global configuration' })

-- Jump history
vim.keymap.set('n', '<leader>jb', function()
  require('config.jumps').navigate('back')
end, { silent = true, desc = 'Jump: back in project' })
vim.keymap.set('n', '<leader>jf', function()
  require('config.jumps').navigate('forward')
end, { silent = true, desc = 'Jump: forward in project' })

-- Windows
vim.keymap.set('n', '<leader>wh', '<C-w>h', { silent = true, desc = 'Window: focus left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { silent = true, desc = 'Window: focus down' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { silent = true, desc = 'Window: focus up' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { silent = true, desc = 'Window: focus right' })
vim.keymap.set('n', '<leader>wH', '<cmd>vertical resize +2<CR>', {
  silent = true,
  desc = 'Window: increase width',
})
vim.keymap.set('n', '<leader>wL', '<cmd>vertical resize -2<CR>', {
  silent = true,
  desc = 'Window: decrease width',
})
vim.keymap.set('n', '<leader>wJ', '<cmd>resize +2<CR>', {
  silent = true,
  desc = 'Window: increase height',
})
vim.keymap.set('n', '<leader>wK', '<cmd>resize -2<CR>', {
  silent = true,
  desc = 'Window: decrease height',
})
vim.keymap.set('n', '<S-Left>', '<C-w>h', { silent = true, desc = 'Window: focus left' })
vim.keymap.set('n', '<S-Down>', '<C-w>j', { silent = true, desc = 'Window: focus down' })
vim.keymap.set('n', '<S-Up>', '<C-w>k', { silent = true, desc = 'Window: focus up' })
vim.keymap.set('n', '<S-Right>', '<C-w>l', { silent = true, desc = 'Window: focus right' })
vim.keymap.set('n', '<leader>ws', '<cmd>split<CR>', { silent = true, desc = 'Window: horizontal split' })
vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<CR>', { silent = true, desc = 'Window: vertical split' })
vim.keymap.set('n', '<leader>wc', '<cmd>close<CR>', { silent = true, desc = 'Window: close' })
vim.keymap.set('n', '<leader>wo', '<C-w>o', { silent = true, desc = 'Window: close others' })
vim.keymap.set('n', '<leader>w=', '<C-w>=', { silent = true, desc = 'Window: equalize sizes' })

vim.keymap.set('n', '<C-Up>', '<cmd>resize -2<CR>', { silent = true, desc = 'Window: decrease height' })
vim.keymap.set('n', '<C-Down>', '<cmd>resize +2<CR>', { silent = true, desc = 'Window: increase height' })
vim.keymap.set('n', '<C-Left>', '<cmd>vertical resize +2<CR>', { silent = true, desc = 'Window: increase width' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize -2<CR>', { silent = true, desc = 'Window: decrease width' })

-- Explorer
vim.keymap.set('n', '<leader>e', function()
  require('config.sidebar').toggle('explorer')
end, {
  silent = true,
  desc = 'Explorer: reveal current file / toggle',
})

-- Bufferline
vim.keymap.set('n', '<leader>bb', '<cmd>Telescope buffers<CR>', {
  silent = true,
  desc = 'Buffer: search',
})
vim.keymap.set('n', '<leader>bp', '<cmd>BufferLineCyclePrev<CR>', {
  silent = true,
  desc = 'Buffer: previous',
})
vim.keymap.set('n', '<leader>bn', '<cmd>BufferLineCycleNext<CR>', {
  silent = true,
  desc = 'Buffer: next',
})
vim.keymap.set('n', '<leader>bo', '<cmd>BufferLineCloseOthers<CR>', {
  silent = true,
  desc = 'Buffer: close others',
})
vim.keymap.set('n', '<leader>bh', '<cmd>BufferLineCloseLeft<CR>', {
  silent = true,
  desc = 'Buffer: close left',
})
vim.keymap.set('n', '<leader>bl', '<cmd>BufferLineCloseRight<CR>', {
  silent = true,
  desc = 'Buffer: close right',
})
vim.keymap.set('n', '<leader>bx', '<cmd>BufferLinePickClose<CR>', {
  silent = true,
  desc = 'Buffer: pick one to close',
})
vim.keymap.set('n', '<M-Left>', '<cmd>BufferLineCyclePrev<CR>', {
  silent = true,
  desc = 'Buffer: previous',
})
vim.keymap.set('n', '<M-Right>', '<cmd>BufferLineCycleNext<CR>', {
  silent = true,
  desc = 'Buffer: next',
})
-- Close files and plugin panels without allowing a sidebar to become the only
-- full-screen window. Bufferline's close buttons use the same implementation.
vim.keymap.set('n', '<leader>bq', function()
  require('config.buffers').close()
end, { silent = true, desc = 'Buffer: close safely' })

-- Quit the whole editor. Prompts once when buffers are modified:
-- Yes saves everything (:xa), No (default) discards (:qa!).
local function save_all_and_quit()
  if #vim.fn.getbufinfo({ bufmodified = true }) == 0 then
    vim.cmd('qa')
    return
  end
  local choice = vim.fn.confirm('Save all changes and quit?', '&Yes\n&No', 2)
  if choice == 1 then
    vim.cmd('xa')
  elseif choice == 2 then
    vim.cmd('qa!')
  end
end
vim.keymap.set('n', '<leader>q', save_all_and_quit, { silent = true, desc = 'Quit: exit (Yes saves all, No discards)' })


-- Terminal
-- A count opens a separate terminal tab: 2<leader>t toggles terminal 2.
-- Use :TermSelect to list and switch between open terminals.
vim.keymap.set('n', '<leader>t', '<cmd>exe v:count1 . "ToggleTerm"<CR>', {
  silent = true,
  desc = 'Terminal: toggle (count = terminal number)',
})
vim.keymap.set('t', '<leader>t', '<C-\\><C-n><cmd>ToggleTerm<CR>', {
  silent = true,
  desc = 'Terminal: toggle',
})
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', {
  silent = true,
  desc = 'Terminal: normal mode',
})

-- Telescope
vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { silent = true, desc = 'Find: files' })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { silent = true, desc = 'Find: text (grep)' })
vim.keymap.set({ 'n', 'v' }, '<leader>fw', function()
  require('telescope.builtin').grep_string()
end, { silent = true, desc = 'Find: word / selection' })
vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', { silent = true, desc = 'Find: recent files' })
vim.keymap.set('n', '<leader>fc', '<cmd>Telescope commands<CR>', { silent = true, desc = 'Find: commands' })
-- Windows has no man command or page database, so the picker can never list
-- anything there; keep the mapping on platforms where man pages exist.
if not platform.is_windows then
  vim.keymap.set('n', '<leader>fm', '<cmd>Telescope man_pages<CR>', { silent = true, desc = 'Find: man pages' })
end

-- Git pickers
vim.keymap.set('n', '<leader>gf', '<cmd>Telescope git_files<CR>', { silent = true, desc = 'Git: files' })
vim.keymap.set('n', '<leader>gs', '<cmd>Telescope git_status<CR>', { silent = true, desc = 'Git: status' })
vim.keymap.set('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { silent = true, desc = 'Git: commits' })
vim.keymap.set('n', '<leader>gb', '<cmd>Telescope git_branches<CR>', { silent = true, desc = 'Git: branches' })
