local document_colors = (require("config.settings").lsp or {}).document_colors or {}

return {
  {
    "brenoprata10/nvim-highlight-colors",
    event = { "BufReadPost", "BufNewFile" },
    enabled = document_colors.enabled ~= false,
    opts = {
      render = "virtual",
      virtual_symbol = document_colors.swatch or "■",
      virtual_symbol_prefix = "",
      virtual_symbol_suffix = " ",
      virtual_symbol_position = "inline",
      enable_hex = true,
      enable_short_hex = true,
      enable_rgb = true,
      enable_hsl = true,
      enable_hsl_without_function = false,
      -- Avoid decorating ordinary prose words such as "red" and terminal
      -- escape sequences. Semantic CSS variables remain supported.
      enable_named_colors = false,
      enable_ansi = false,
      enable_tailwind = document_colors.tailwind == true,
      exclude_buftypes = { "nofile", "prompt", "terminal" },
    },
  },
}
