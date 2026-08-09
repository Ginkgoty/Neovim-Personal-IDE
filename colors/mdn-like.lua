-- A native Neovim adaptation of CodeMirror 5's MDN-like theme.
-- The original background texture is intentionally omitted: terminal cells
-- cannot reproduce it faithfully, and a flat surface keeps plugin UIs legible.
vim.cmd.highlight("clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd.syntax("reset")
end

vim.o.termguicolors = true
vim.o.background = "light"
vim.g.colors_name = "mdn-like"

local colors = {
  bg = "#ffffff",
  surface = "#f8f8f8",
  active = "#efefff",
  selection = "#ccffcc",
  fg = "#333333",
  muted = "#777777",
  subtle = "#aaaaaa",
  blue = "#0077aa",
  bright_blue = "#6262ff",
  pale_blue = "#8da6ce",
  green = "#669900",
  orange = "#ff9900",
  rust = "#ca7841",
  red = "#cc0000",
  magenta = "#990055",
  gold = "#9b7536",
  operator = "#9a761f",
  cyan = "#007c91",
}

local groups = {
  Normal = { fg = colors.fg, bg = colors.bg },
  NormalNC = { fg = colors.fg, bg = colors.bg },
  NormalFloat = { fg = colors.fg, bg = colors.surface },
  FloatBorder = { fg = colors.subtle, bg = colors.surface },
  FloatTitle = { fg = colors.blue, bg = colors.surface, bold = true },
  ColorColumn = { bg = colors.surface },
  Cursor = { fg = colors.bg, bg = "#222222" },
  CursorLine = { bg = colors.active },
  CursorColumn = { bg = colors.active },
  CursorLineNr = { fg = colors.blue, bg = colors.active, bold = true },
  LineNr = { fg = colors.subtle, bg = colors.surface },
  SignColumn = { fg = colors.muted, bg = colors.surface },
  FoldColumn = { fg = colors.subtle, bg = colors.surface },
  Folded = { fg = colors.muted, bg = colors.surface },
  Visual = { bg = colors.selection },
  Search = { fg = colors.fg, bg = "#fff2a8" },
  IncSearch = { fg = colors.bg, bg = colors.orange },
  CurSearch = { fg = colors.bg, bg = colors.orange },
  MatchParen = { fg = colors.fg, bg = colors.selection, bold = true },
  Pmenu = { fg = colors.fg, bg = colors.surface },
  PmenuSel = { fg = colors.bg, bg = colors.blue, bold = true },
  PmenuSbar = { bg = "#e5e5e5" },
  PmenuThumb = { bg = colors.subtle },
  StatusLine = { fg = colors.fg, bg = "#e8e8e8" },
  StatusLineNC = { fg = colors.muted, bg = colors.surface },
  TabLine = { fg = colors.muted, bg = colors.surface },
  TabLineFill = { fg = colors.muted, bg = colors.surface },
  TabLineSel = { fg = colors.blue, bg = colors.bg, bold = true },
  WinSeparator = { fg = "#d5d5d5", bg = colors.bg },
  VertSplit = { fg = "#d5d5d5", bg = colors.bg },
  Directory = { fg = colors.blue, bold = true },
  Title = { fg = "#ff6400", bold = true },
  NonText = { fg = "#d0d0d0" },
  Whitespace = { fg = "#d0d0d0" },
  SpecialKey = { fg = colors.subtle },

  Comment = { fg = colors.muted, italic = true },
  Constant = { fg = colors.orange },
  String = { fg = colors.blue, italic = true },
  Character = { fg = colors.blue },
  Number = { fg = colors.rust },
  Boolean = { fg = colors.orange, bold = true },
  Float = { fg = colors.rust },
  Identifier = { fg = colors.blue },
  Function = { fg = colors.pale_blue, bold = true },
  Statement = { fg = colors.bright_blue },
  Conditional = { fg = colors.bright_blue },
  Repeat = { fg = colors.bright_blue },
  Label = { fg = colors.green },
  Operator = { fg = colors.operator },
  Keyword = { fg = colors.bright_blue },
  Exception = { fg = colors.bright_blue },
  PreProc = { fg = colors.fg },
  Include = { fg = colors.bright_blue },
  Define = { fg = colors.bright_blue },
  Macro = { fg = colors.gold },
  Type = { fg = colors.cyan },
  StorageClass = { fg = colors.bright_blue },
  Structure = { fg = colors.cyan },
  Typedef = { fg = colors.cyan },
  Special = { fg = colors.magenta },
  Underlined = { fg = colors.blue, underline = true },
  Error = { fg = colors.red, underline = true },
  Todo = { fg = colors.fg, bg = "#fff2a8", bold = true },

  DiagnosticError = { fg = colors.red },
  DiagnosticWarn = { fg = "#a85d00" },
  DiagnosticInfo = { fg = colors.blue },
  DiagnosticHint = { fg = colors.green },
  DiagnosticUnderlineError = { undercurl = true, sp = colors.red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = "#a85d00" },
  DiagnosticUnderlineInfo = { undercurl = true, sp = colors.blue },
  DiagnosticUnderlineHint = { undercurl = true, sp = colors.green },
  LspInlayHint = { fg = colors.muted, bg = colors.active, italic = true },
  GitSignsAdd = { fg = colors.green },
  GitSignsChange = { fg = colors.orange },
  GitSignsDelete = { fg = colors.red },
  DiffAdd = { bg = "#e6ffe6" },
  DiffChange = { bg = "#fff7d6" },
  DiffDelete = { fg = colors.red, bg = "#ffe8e8" },
  DiffText = { bg = "#d7e8ff", bold = true },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

local links = {
  ["@comment"] = "Comment",
  ["@constant"] = "Constant",
  ["@constant.builtin"] = "Constant",
  ["@string"] = "String",
  ["@number"] = "Number",
  ["@boolean"] = "Boolean",
  ["@variable"] = "Identifier",
  ["@variable.builtin"] = "Special",
  ["@property"] = "Special",
  ["@function"] = "Function",
  ["@function.builtin"] = "Function",
  ["@function.macro"] = "Macro",
  ["@keyword"] = "Keyword",
  ["@keyword.import"] = "Include",
  ["@operator"] = "Operator",
  ["@type"] = "Type",
  ["@type.builtin"] = "Type",
  ["@tag"] = "Label",
  ["@tag.attribute"] = "Special",
  ["@markup.heading"] = "Title",
  ["@markup.link"] = "Underlined",
  ["@markup.raw"] = "String",
}

for name, target in pairs(links) do
  vim.api.nvim_set_hl(0, name, { link = target })
end

vim.g.terminal_color_0 = "#222222"
vim.g.terminal_color_1 = colors.red
vim.g.terminal_color_2 = colors.green
vim.g.terminal_color_3 = colors.gold
vim.g.terminal_color_4 = colors.blue
vim.g.terminal_color_5 = colors.magenta
vim.g.terminal_color_6 = colors.cyan
vim.g.terminal_color_7 = "#eeeeee"
vim.g.terminal_color_8 = colors.muted
vim.g.terminal_color_9 = "#ff3333"
vim.g.terminal_color_10 = "#77aa00"
vim.g.terminal_color_11 = colors.orange
vim.g.terminal_color_12 = colors.bright_blue
vim.g.terminal_color_13 = "#cc3388"
vim.g.terminal_color_14 = "#0099aa"
vim.g.terminal_color_15 = colors.bg
