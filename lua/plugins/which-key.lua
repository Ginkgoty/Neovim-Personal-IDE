local languages = require("config.languages")
local ui = require("config.settings").ui or {}
local llm_icon = { icon = " ", color = "green" }
local function fold_description(normal, debug_panel)
  return function()
    if vim.bo.filetype:match("^dapui_") then
      return debug_panel
    end
    return normal
  end
end

local groups = {
  { "g", group = "Go / navigate", icon = { icon = "󰆾 ", color = "azure" } },
  { "ga", group = "Calls", icon = { icon = "󰘬 ", color = "blue" } },
  { "gr", group = "LSP relations", icon = { icon = "󰒕 ", color = "cyan" } },
  { "[", group = "Previous", icon = { icon = " ", color = "azure" } },
  { "]", group = "Next", icon = { icon = " ", color = "azure" } },
  { "z", group = "Fold / spell / view", icon = { icon = " ", color = "purple" } },
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

  -- Neovim's z-prefix combines folds, spelling, and viewport placement.
  -- DAP sidebar sections intentionally reuse za/zo/zc with the same meaning.
  { "z<CR>", desc = "Top this line", icon = { icon = " ", color = "blue" } },
  { "z=", desc = "Spelling suggestions", icon = { icon = "󰓆 ", color = "cyan" } },
  { "zf", desc = "Create fold", icon = { icon = " ", color = "green" } },
  { "zA", desc = "Toggle all folds under cursor", icon = { icon = " ", color = "purple" } },
  {
    "za",
    desc = fold_description("Toggle fold under cursor", "Debug panel: toggle section"),
    icon = { icon = " ", color = "purple" },
  },
  { "zC", desc = "Close all folds under cursor", icon = { icon = " ", color = "purple" } },
  {
    "zc",
    desc = fold_description("Close fold under cursor", "Debug panel: collapse section"),
    icon = { icon = " ", color = "purple" },
  },
  { "zM", desc = "Close all folds", icon = { icon = " ", color = "purple" } },
  { "zm", desc = "Fold more", icon = { icon = " ", color = "purple" } },
  { "zO", desc = "Open all folds under cursor", icon = { icon = " ", color = "purple" } },
  {
    "zo",
    desc = fold_description("Open fold under cursor", "Debug panel: expand section"),
    icon = { icon = " ", color = "purple" },
  },
  { "zR", desc = "Open all folds", icon = { icon = " ", color = "purple" } },
  { "zr", desc = "Fold less", icon = { icon = " ", color = "purple" } },
  { "zD", desc = "Delete all folds under cursor", icon = { icon = " ", color = "red" } },
  { "zd", desc = "Delete fold under cursor", icon = { icon = " ", color = "red" } },
  { "zE", desc = "Delete all folds in file", icon = { icon = " ", color = "red" } },
  { "zi", desc = "Toggle folding", icon = { icon = "󰔡 ", color = "yellow" } },
  { "zx", desc = "Update folds", icon = { icon = "󰑓 ", color = "cyan" } },
  { "zv", desc = "Show cursor line", icon = { icon = " ", color = "azure" } },
  { "zg", desc = "Add word to spell list", icon = { icon = "󰓎 ", color = "green" } },
  { "zw", desc = "Mark word as bad/misspelling", icon = { icon = "󰓍 ", color = "red" } },
  { "zH", desc = "Half screen to the left", icon = { icon = " ", color = "azure" } },
  { "zs", desc = "Left this line", icon = { icon = " ", color = "azure" } },
  { "zL", desc = "Half screen to the right", icon = { icon = " ", color = "azure" } },
  { "ze", desc = "Right this line", icon = { icon = " ", color = "azure" } },
  { "zt", desc = "Top this line", icon = { icon = " ", color = "blue" } },
  { "zz", desc = "Center this line", icon = { icon = "󰉠 ", color = "blue" } },
  { "zb", desc = "Bottom this line", icon = { icon = " ", color = "blue" } },
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
