-- lua/config/keymaps.lua

vim.g.mapleader = ' '

vim.keymap.set('n', '<leader>,', function()
  vim.cmd.edit(vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'config', 'settings.lua'))
end, { silent = true, desc = 'Settings: edit global configuration' })

-- Jump history
vim.keymap.set('n', '<leader>jb', '<C-o>', { silent = true, desc = 'Jump: back' })
vim.keymap.set('n', '<leader>jf', '<C-i>', { silent = true, desc = 'Jump: forward' })

-- Windows
vim.keymap.set('n', '<leader>wh', '<C-w>h', { silent = true, desc = 'Window: focus left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { silent = true, desc = 'Window: focus down' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { silent = true, desc = 'Window: focus up' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { silent = true, desc = 'Window: focus right' })
vim.keymap.set('n', '<M-Left>', '<C-w>h', { silent = true, desc = 'Window: focus left' })
vim.keymap.set('n', '<M-Down>', '<C-w>j', { silent = true, desc = 'Window: focus down' })
vim.keymap.set('n', '<M-Up>', '<C-w>k', { silent = true, desc = 'Window: focus up' })
vim.keymap.set('n', '<M-Right>', '<C-w>l', { silent = true, desc = 'Window: focus right' })
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
vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeFindFileToggle<CR>', {
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
vim.keymap.set('n', '<S-Left>', '<cmd>BufferLineCyclePrev<CR>', {
  silent = true,
  desc = 'Buffer: previous',
})
vim.keymap.set('n', '<S-Right>', '<cmd>BufferLineCycleNext<CR>', {
  silent = true,
  desc = 'Buffer: next',
})
-- Custom function: close the current buffer, switch to the next, or confirm exit if no buffers remain
local function close_buffer_or_quit()
  local buffers = vim.fn.getbufinfo({ buflisted = true })

  if #buffers > 1 then
    local current_buf = vim.api.nvim_get_current_buf()
    -- 尝试切换到下一个缓冲区
    vim.cmd('bnext')
    local new_buf = vim.api.nvim_get_current_buf()

    -- 如果切换成功且当前缓冲区不是新缓冲区，则删除当前缓冲区
    if current_buf ~= new_buf then
      vim.cmd('confirm bdelete ' .. current_buf)
    else
      -- 如果切换失败，尝试切换到其他缓冲区（避免死锁）
      vim.cmd('bprev')
      vim.cmd('confirm bdelete ' .. current_buf)
    end
  else
    -- 仅剩一个缓冲区时，尝试退出 Neovim
    vim.cmd('confirm qa')
  end
end

-- Map <leader>bd to close the current buffer or quit if no buffers remain
vim.keymap.set('n', '<leader>bd', close_buffer_or_quit, { silent = true, desc = 'Buffer: close or quit' })
vim.keymap.set('n', '<M-x>', close_buffer_or_quit, { silent = true, desc = 'Buffer: close or quit' })


-- Terminal
vim.keymap.set('n', '<leader>t', '<cmd>ToggleTerm<CR>', { silent = true, desc = 'Terminal: toggle' })
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
vim.keymap.set('n', '<leader>fm', '<cmd>Telescope man_pages<CR>', { silent = true, desc = 'Find: man pages' })

-- Git pickers
vim.keymap.set('n', '<leader>gf', '<cmd>Telescope git_files<CR>', { silent = true, desc = 'Git: files' })
vim.keymap.set('n', '<leader>gs', '<cmd>Telescope git_status<CR>', { silent = true, desc = 'Git: status' })
vim.keymap.set('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { silent = true, desc = 'Git: commits' })
vim.keymap.set('n', '<leader>gb', '<cmd>Telescope git_branches<CR>', { silent = true, desc = 'Git: branches' })
