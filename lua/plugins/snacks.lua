local ginkgo_header = require "config.banner"

local function style_dashboard()
  local header = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false })
  header.bold = true
  vim.api.nvim_set_hl(0, "SnacksDashboardHeader", header)

  for suffix, source in pairs { Desc = "Special", Icon = "Special", Key = "Number" } do
    local highlight = vim.api.nvim_get_hl(0, { name = source, link = false })
    highlight.bold = true
    vim.api.nvim_set_hl(0, "SnacksDashboard" .. suffix, highlight)
  end
end

return {
  {
    "folke/snacks.nvim",
    version = "*",
    priority = 1000,
    lazy = false,
    opts = function()
      local highlight_group = vim.api.nvim_create_augroup("GinkoDashboardHighlights", { clear = true })
      style_dashboard()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = highlight_group,
        callback = style_dashboard,
      })

      local ui = require("config.settings").ui or {}
      local dashboard = ui.dashboard or {}
      local images = ui.images or {}
      return {
        dashboard = {
          enabled = dashboard.enabled ~= false,
          width = 48,
          formats = { header = { "%s", align = "left" } },
          preset = {
            header = ginkgo_header,
            keys = {
              { icon = " ", key = "r", desc = "Recent files", action = ":Telescope oldfiles" },
              {
                icon = " ",
                key = "c",
                desc = "Configure ginko.nvim",
                action = ":edit " .. vim.fn.stdpath "config" .. "/lua/config/settings.lua",
              },
              { icon = "󰒲 ", key = "l", desc = "Manage plugins", action = ":Lazy" },
              { icon = " ", key = "m", desc = "Manage IDE tools", action = ":Mason" },
              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
          sections = {
            { header = ginkgo_header },
            { section = "keys", gap = 1, padding = 1 },
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
