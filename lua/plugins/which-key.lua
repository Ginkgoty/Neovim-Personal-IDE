local languages = require("config.languages")
local groups = {
  { "<leader>b", group = "Buffer" },
  { "<leader>c", group = "Code actions" },
  { "<leader>d", group = "Debug" },
  { "<leader>f", group = "Find / navigate" },
  { "<leader>g", group = "Git" },
  { "<leader>j", group = "Jump history" },
  { "<leader>r", group = "Run / build" },
  { "<leader>u", group = "UI toggles" },
  { "<leader>w", group = "Windows" },
  { "<leader>x", group = "Diagnostics" },
}
if languages.enabled("python") then
  table.insert(groups, { "<leader>p", group = "Python / uv" })
end

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 300,
      spec = groups,
    },
  },
}
