local languages = require("config.languages")
local ui = require("config.settings").ui or {}
local groups = {
  { "<leader>b", group = "Buffer" },
  { "<leader>c", group = "Code actions" },
  { "<leader>d", group = "Debug" },
  { "<leader>f", group = "Find / navigate" },
  { "<leader>g", group = "Git" },
  { "<leader>j", group = "Jump history", icon = { icon = " ", color = "azure" } },
  { "<leader>l", group = "LLM", icon = { icon = " ", color = "green" } },
  { "<leader>r", group = "Run / build" },
  { "<leader>u", group = "UI toggles" },
  { "<leader>w", group = "Windows" },
  { "<leader>x", group = "Diagnostics" },
}

-- Icon-only entries for mappings whose description matches none of
-- which-key's built-in icon rules. The mappings themselves are defined
-- globally at startup, so these entries only add the missing icon.
local icons = {
  { "<leader>,", icon = { icon = " ", color = "azure" } },
  { "<leader>jb", icon = { icon = " ", color = "azure" } },
  { "<leader>jf", icon = { icon = " ", color = "azure" } },
  { "<leader>lh", icon = { icon = " ", color = "azure" } },
}

local python_icon = { cat = "filetype", name = "python" }
if languages.enabled("python") then
  table.insert(groups, { "<leader>p", group = "Python / uv", icon = python_icon })
  table.insert(icons, { "<leader>pe", icon = python_icon })
  table.insert(icons, { "<leader>pE", icon = python_icon })
end

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = ui.which_key_delay_ms or 300,
      spec = vim.list_extend(groups, icons),
    },
  },
}
