return {
  {
    "NStefan002/screenkey.nvim",
    version = "*",
    cmd = "Screenkey",
    keys = {
      {
        "<leader>uk",
        "<cmd>Screenkey toggle<CR>",
        desc = "UI: toggle pressed keys",
      },
    },
    opts = function()
      local ui = require("config.settings").ui or {}
      local screenkey = ui.screenkey or {}
      local width = tonumber(screenkey.width) or 36
      local height = tonumber(screenkey.height) or 3

      return {
        win_opts = {
          relative = "editor",
          anchor = "SE",
          row = vim.o.lines - vim.o.cmdheight - 1,
          col = vim.o.columns - 1,
          width = width,
          height = height,
          border = screenkey.border or "rounded",
          title = " Keys ",
          title_pos = "center",
          style = "minimal",
          focusable = false,
          noautocmd = true,
        },
        compress_after = tonumber(screenkey.compress_after) or 3,
        clear_after = tonumber(screenkey.clear_after) or 3,
        show_leader = screenkey.show_leader ~= false,
        disable = {
          buftypes = { "terminal", "prompt" },
          events = true,
        },
      }
    end,
  },
}
