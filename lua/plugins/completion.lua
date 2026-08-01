local editing = require("config.settings").editing or {}
local completion = editing.completion or {}

return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    lazy = false,
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        -- Enter never accepts an unselected suggestion. This keeps ordinary
        -- newlines predictable while still confirming an explicit selection.
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<C-n>"] = { "select_next", "fallback_to_mappings" },
        ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
      },
      completion = {
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        documentation = {
          auto_show = completion.documentation ~= false,
          auto_show_delay_ms = completion.documentation_delay_ms or 300,
          window = { border = "rounded" },
        },
        menu = {
          border = "rounded",
          draw = {
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },
        ghost_text = { enabled = completion.ghost_text == true },
      },
      signature = {
        enabled = completion.signature_help ~= false,
        window = { border = "rounded" },
      },
      snippets = { preset = "default" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = { score_offset = 100 },
          snippets = { score_offset = 20 },
          path = { score_offset = 10 },
          -- Buffer words are useful as a fallback, but should not outrank a
          -- language server's semantic API suggestions.
          buffer = {
            min_keyword_length = completion.buffer_min_keyword_length or 3,
            score_offset = -10,
          },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      check_ts = true,
      map_cr = true,
      map_bs = true,
      map_c_h = true,
      map_c_w = true,
      disable_filetype = { "TelescopePrompt", "grug-far", "snacks_picker_input" },
    },
  },
}
