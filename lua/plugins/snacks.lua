local ginkgo_header = [[
              _..-''''-._  _.-''''-.._
          _.-'           \/           '-._
       .-'                               '-.
     .'                                     '.
    /                                         \
   ;        .-._                    _.-.        ;
   |     .-'    '-.              .-'    '-.     |
    \  .'          '-.        .-'          '.  /
     \/               '-.  .-'               \/
      \                  \/                  /
       \                                    /
        '.                                .'
          '-._                        _.-'
              '--..              ..--'
                   '-.        .-'
                      \      /
                       \    /
                        \  /
                         ||
                         ||

       _       _                    _
  __ _(_)_ __ | | _____   _ ____   ___(_)_ __ ___
 / _` | | '_ \| |/ / _ \ | '_ \ \ / / | '_ ` _ \
| (_| | | | | |   < (_) || | | \ V /| | | | | | |
 \__, |_|_| |_|_|\_\___(_)_| |_|\_/ |_|_| |_| |_|
 |___/
]]

return {
  {
    "folke/snacks.nvim",
    version = "*",
    priority = 1000,
    lazy = false,
    opts = function()
      local ui = require("config.settings").ui or {}
      local dashboard = ui.dashboard or {}
      local images = ui.images or {}
      return {
        dashboard = {
          enabled = dashboard.enabled ~= false,
          width = 58,
          formats = { header = { "%s", align = "left" } },
          preset = {
            header = ginkgo_header,
            keys = {
              { icon = " ", key = "f", desc = "Find file", action = ":Telescope find_files" },
              { icon = " ", key = "g", desc = "Find text", action = ":Telescope live_grep" },
              { icon = " ", key = "r", desc = "Recent files", action = ":Telescope oldfiles" },
              { icon = " ", key = "n", desc = "New file", action = ":ene | startinsert" },
              {
                icon = " ",
                key = "c",
                desc = "Configure ginko.nvim",
                action = ":edit " .. vim.fn.stdpath "config" .. "/lua/config/settings.lua",
              },
              { icon = "󰒲 ", key = "l", desc = "Manage plugins", action = ":Lazy" },
              { icon = " ", key = "m", desc = "Manage IDE tools", action = ":Mason" },
              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
          sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            { text = { { "Grow ideas, one branch at a time.", hl = "SnacksDashboardFooter" } }, align = "center" },
            { section = "startup" },
          },
        },
        image = {
          enabled = images.enabled ~= false,
          resolve = function(_, source)
            return require("config.symbol_documentation").resolve_hover_image(source)
          end,
          math = {
            enabled = false,
          },
          doc = {
            enabled = images.enabled ~= false,
            inline = images.inline ~= false,
            float = images.float ~= false,
            max_width = tonumber(images.max_width) or 80,
            max_height = tonumber(images.max_height) or 40,
          },
        },
      }
    end,
  },
}
