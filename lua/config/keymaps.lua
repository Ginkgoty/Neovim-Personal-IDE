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
vim.api.nvim_set_keymap('n', '<leader>bd', ':bdelete<CR>', { noremap = true, silent = true })

-- Custom function: close the current buffer, switch to the next, or confirm exit if no buffers remain
function close_buffer_or_quit()
  local buffers = vim.fn.getbufinfo({ buflisted = true })
  
  if #buffers > 1 then
    local current_buf = vim.api.nvim_get_current_buf()
    vim.cmd('bnext')
    vim.cmd('confirm bdelete ' .. current_buf)
  else
    vim.cmd('confirm qa')
  end
end 

-- Map <leader>bd to close the current buffer or quit if no buffers remain
vim.api.nvim_set_keymap('n', '<leader>bd', ':lua close_buffer_or_quit()<CR>', { noremap = true, silent = true })


-- ToggleTerm
vim.api.nvim_set_keymap('n', '<leader>t', ':ToggleTerm<CR>', { noremap = true, silent = true })

-- Telescope
vim.api.nvim_set_keymap('n', '<leader>ff', ':Telescope find_files<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fg', ':Telescope live_grep<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fc', ':Telescope commands<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fm', ':Telescope man_pages<CR>', { noremap = true, silent = true })

