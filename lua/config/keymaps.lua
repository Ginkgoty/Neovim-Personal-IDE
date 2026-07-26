-- lua/config/keymaps.lua

vim.g.mapleader = ' '

-- Windows options
vim.api.nvim_set_keymap("n", "<leader>h", "<C-w>h", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>j", "<C-w>j", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>k", "<C-w>k", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>l", "<C-w>l", { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<leader>ws', ':split<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>wv', ':vsplit<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>wc', ':close<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<C-Up>', ':resize -2<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-Down>', ':resize +2<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<C-Left>', ':vertical resize +2<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-Right>', ':vertical resize -2<CR>', { noremap = true, silent = true })

-- Nvim Tree
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Bufferline
vim.api.nvim_set_keymap('n', '<leader>bp', ':BufferLineCyclePrev<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>bn', ':BufferLineCycleNext<CR>', { noremap = true, silent = true })
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
vim.keymap.set('n', '<leader>bd', close_buffer_or_quit, { silent = true, desc = 'Close buffer or quit' })


-- ToggleTerm
vim.api.nvim_set_keymap('n', '<leader>t', ':ToggleTerm<CR>', { noremap = true, silent = true })

-- Telescope
vim.api.nvim_set_keymap('n', '<leader>ff', ':Telescope find_files<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fg', ':Telescope live_grep<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fc', ':Telescope commands<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fm', ':Telescope man_pages<CR>', { noremap = true, silent = true })

-- Git pickers
vim.api.nvim_set_keymap('n', '<leader>gf', ':Telescope git_files<CR>', { noremap = true, silent = true, desc = 'Git files' })
vim.api.nvim_set_keymap('n', '<leader>gs', ':Telescope git_status<CR>', { noremap = true, silent = true, desc = 'Git status' })
vim.api.nvim_set_keymap('n', '<leader>gc', ':Telescope git_commits<CR>', { noremap = true, silent = true, desc = 'Git commits' })
vim.api.nvim_set_keymap('n', '<leader>gb', ':Telescope git_branches<CR>', { noremap = true, silent = true, desc = 'Git branches' })
