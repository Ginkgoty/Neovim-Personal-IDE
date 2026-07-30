local languages = require("config.languages")
local formatting = require("config.settings").formatting or {}
local timeout_ms = formatting.timeout_ms or 2000

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<S-A-f>",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer or selection",
      },
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer or selection",
      },
    },
    opts = {
      formatters_by_ft = languages.formatters(),
      default_format_opts = {
        lsp_format = "fallback",
        timeout_ms = timeout_ms,
      },
      format_on_save = function(bufnr)
        if formatting.on_save == false
            or vim.g.disable_autoformat
            or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = timeout_ms, lsp_format = "fallback" }
      end,
      notify_on_error = true,
      notify_no_formatters = false,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

      vim.api.nvim_create_user_command("FormatToggle", function(args)
        if args.bang then
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          vim.notify("Format on save " .. (vim.b.disable_autoformat and "disabled" or "enabled") .. " for this buffer")
        else
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("Format on save " .. (vim.g.disable_autoformat and "disabled" or "enabled") .. " globally")
        end
      end, {
        bang = true,
        desc = "Toggle format on save (! for current buffer)",
      })
    end,
  },
}
