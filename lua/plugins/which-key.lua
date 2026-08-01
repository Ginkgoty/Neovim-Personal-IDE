local languages = require("config.languages")
local ui = require("config.settings").ui or {}
local llm_icon = { icon = " ", color = "green" }
local groups = {
  { "g", group = "Go / navigate", icon = { icon = "󰆾 ", color = "azure" } },
  { "ga", group = "Calls", icon = { icon = "󰘬 ", color = "blue" } },
  { "gr", group = "LSP relations", icon = { icon = "󰒕 ", color = "cyan" } },
  { "[", group = "Previous", icon = { icon = " ", color = "azure" } },
  { "]", group = "Next", icon = { icon = " ", color = "azure" } },
  { "<leader>a", group = "AI / Agent", icon = llm_icon },
  { "<leader>b", group = "Buffer" },
  { "<leader>c", group = "Code actions", mode = { "n", "v" } },
  { "<leader>d", group = "Debug" },
  { "<leader>f", group = "Find / navigate" },
  { "<leader>g", group = "Git" },
  { "<leader>j", group = "Jump history", icon = { icon = " ", color = "azure" } },
  { "<localleader>", group = "Local actions", icon = { icon = "󰌌 ", color = "azure" } },
  { "<leader>r", group = "Run / build", icon = { icon = " ", color = "orange" } },
  { "<leader>u", group = "UI toggles" },
  { "<leader>w", group = "Windows" },
  { "<leader>x", group = "Diagnostics" },
}

-- Icon-only entries for mappings whose description matches none of
-- which-key's built-in icon rules. The mappings themselves are defined
-- globally at startup, so these entries only add the missing icon.
local icons = {
  { "<leader>ac", icon = llm_icon, mode = { "n", "v" } },
  { "<leader>ah", icon = { icon = " ", color = "azure" } },
  { "<leader>,", icon = { icon = " ", color = "azure" } },
  { "<leader>jb", icon = { icon = " ", color = "azure" } },
  { "<leader>jf", icon = { icon = " ", color = "azure" } },
  { "<leader>xq", icon = { icon = "󰁨 ", color = "yellow" } },
  { "<leader>xt", icon = { icon = " ", color = "cyan" } },
  { "<leader>xT", icon = { icon = " ", color = "azure" } },
  { "<leader>F", icon = { icon = "󰛔 ", color = "orange" }, mode = { "n", "v" } },
  { "<leader>ce", icon = { icon = "󰘧 ", color = "purple" }, mode = "v" },
  { "<leader>ci", icon = { icon = "󰘦 ", color = "purple" }, mode = { "n", "v" } },
  { "<leader>co", icon = { icon = "󰉢 ", color = "cyan" } },
  { "<leader>cF", icon = { icon = "󰁨 ", color = "yellow" } },

  -- Neovim's native g-prefix entries do not match WhichKey's built-in icon
  -- rules. Keep their semantics visible alongside the LSP navigation maps.
  { "g%", icon = { icon = "󰑐 ", color = "purple" } },
  { "g,", icon = { icon = " ", color = "azure" } },
  { "g;", icon = { icon = " ", color = "azure" } },
  { "gi", icon = { icon = "󰏫 ", color = "cyan" } },
  { "gv", icon = { icon = "󰒉 ", color = "purple" } },
  { "gU", icon = { icon = "󰬴 ", color = "orange" } },
  { "gu", icon = { icon = "󰬵 ", color = "orange" } },
  { "g~", icon = { icon = "󰬶 ", color = "orange" } },

  -- LSP mappings are buffer-local, so these specs only provide stable icons
  -- when the corresponding client attaches.
  { "gd", icon = { icon = "󰊕 ", color = "azure" } },
  { "gD", icon = { icon = "󰙨 ", color = "azure" } },
  { "grr", icon = { icon = "󰈇 ", color = "cyan" } },
  { "gri", icon = { icon = "󰡱 ", color = "cyan" } },
  { "grt", icon = { icon = "󰉺 ", color = "cyan" } },
  { "gai", icon = { icon = "󰁝 ", color = "blue" } },
  { "gao", icon = { icon = "󰁅 ", color = "blue" } },

  -- Bracket navigation is buffer-local (LSP diagnostics and Git hunks).
  -- Pair every Previous/Next entry with the same semantic icon.
  { "[d", icon = { icon = "󰒮 ", color = "red" } },
  { "]d", icon = { icon = "󰒭 ", color = "red" } },
  { "[e", icon = { icon = " ", color = "red" } },
  { "]e", icon = { icon = " ", color = "red" } },
  { "[w", icon = { icon = " ", color = "yellow" } },
  { "]w", icon = { icon = " ", color = "yellow" } },
  { "[c", icon = { icon = " ", color = "green" } },
  { "]c", icon = { icon = " ", color = "green" } },
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
      icons = {
        rules = {
          -- Overseer mappings and the group itself consistently start with
          -- "Run", which is not covered by WhichKey's built-in rules.
          { pattern = "^run", icon = " ", color = "orange" },
          { pattern = "^llm", icon = llm_icon.icon, color = llm_icon.color },
        },
      },
    },
  },
}
