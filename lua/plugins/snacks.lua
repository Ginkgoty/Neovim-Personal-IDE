return {
  {
    "folke/snacks.nvim",
    version = "*",
    priority = 1000,
    lazy = false,
    opts = function()
      local ui = require("config.settings").ui or {}
      local images = ui.images or {}
      return {
        image = {
          enabled = images.enabled ~= false,
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
