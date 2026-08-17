local has_node = vim.fn.executable "node" == 1

return {
  {
    "github/copilot.vim",
    enabled = has_node,
    branch = "release",
    cmd = "Copilot",
    event = "InsertEnter",
    init = function()
      -- Keep Tab owned by blink/snippets and use Copilot's explicit mapping.
      vim.g.copilot_no_tab_map = true
      -- The official plugin normally permits npx to update its language
      -- server at startup. Use its bundled, tested server instead: plugin
      -- updates remain an explicit Lazy operation and startup stays offline.
      vim.g.copilot_version = false
    end,
    config = function()
      vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        desc = "Copilot: accept suggestion",
      })
      vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", {
        desc = "Copilot: next suggestion",
      })
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", {
        desc = "Copilot: previous suggestion",
      })
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)", {
        desc = "Copilot: dismiss suggestion",
      })
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    enabled = has_node,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/codecompanion-history.nvim",
    },
    keys = {
      {
        "<leader>ac",
        "<cmd>CodeCompanionChat Toggle<CR>",
        mode = { "n", "v" },
        desc = "LLM: toggle chat",
      },
      {
        "<leader>ah",
        "<cmd>CodeCompanionHistory<CR>",
        desc = "LLM: chat history",
      },
    },
    -- The default chat/inline adapter is already "copilot". It reuses the
    -- credentials that :Copilot setup writes under github-copilot, and
    -- plenary.curl honors the HTTPS_PROXY environment variable.
    opts = {
      interactions = {
        chat = {
          keymaps = {
            -- Chat actions are local to the CodeCompanion buffer. Navigation
            -- keys (]], [[, }, {, gR) and <C-s>/q/? keep plugin defaults.
            regenerate = { modes = { n = "<localleader>r" } },
            change_adapter = { modes = { n = "<localleader>a" } },
            clear = { modes = { n = "<localleader>x" } },
            yank_code = { modes = { n = "<localleader>y" } },
            codeblock = { modes = { n = "<localleader>b" } },
            fold_code = { modes = { n = "<localleader>f" } },
            system_prompt = { modes = { n = "<localleader>p" } },
            copilot_stats = { modes = { n = "<localleader>S" } },
            rules = { modes = { n = "<localleader>R" } },
            _btw = { modes = { n = "<localleader>m" } },
            debug = { modes = { n = "<localleader>i" } },
            buffer_sync_all = { modes = { n = "<localleader>ba" } },
            buffer_sync_diff = { modes = { n = "<localleader>bd" } },
            clear_approvals = { modes = { n = "<localleader>tx" } },
            yolo_mode = { modes = { n = "<localleader>ty" } },
          },
        },
        shared = {
          keymaps = {
            view_diff = { modes = { n = "<localleader>v" } },
            always_accept = { modes = { n = "<localleader>1" } },
            accept_change = { modes = { n = "<localleader>2" } },
            reject_change = { modes = { n = "<localleader>3" } },
            cancel = { modes = { n = "<localleader>4" } },
          },
        },
      },
      extensions = {
        history = {
          enabled = true,
          opts = {
            -- History and manual save use LocalLeader instead of the
            -- extension's gh/sc defaults.
            keymap = "<localleader>h",
            save_chat_keymap = "<localleader>s",
            auto_save = true,
            picker = "telescope",
            auto_generate_title = true,
            -- The extension falls back to its gcs/gbs defaults when these
            -- are false, so they must be remapped, not disabled.
            summary = {
              create_summary_keymap = "<localleader>G",
              browse_summaries_keymap = "<localleader>B",
            },
          },
        },
      },
      display = {
        chat = {
          window = {
            position = "right",
            -- codecompanion's shared ui.lua compares the raw window.width
            -- against 0, so a function value errors; resolve the setting now.
            width = (function()
              local ui = require("config.settings").ui or {}
              local settings = ui.codecompanion or {}
              return tonumber(settings.chat_width) or 0.36
            end)(),
            -- Keep the chat out of the bufferline tab bar.
            buflisted = false,
            opts = {
              number = false,
              relativenumber = false,
              signcolumn = "no",
            },
          },
        },
      },
    },
  },
}
