return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      -- Chat is provided by codecompanion.nvim below.
      panel = { enabled = false },
      suggestion = {
        auto_trigger = true,
        keymap = {
          -- Keep Tab free for snippet jumps (coq leaves it unmapped on
          -- purpose). Accept the suggestion with CTRL-J instead.
          accept = "<C-J>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
    },
  },
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/codecompanion-history.nvim",
    },
    keys = {
      {
        "<leader>lc",
        "<cmd>CodeCompanionChat Toggle<CR>",
        mode = { "n", "v" },
        desc = "LLM: toggle chat",
      },
      {
        "<leader>lh",
        "<cmd>CodeCompanionHistory<CR>",
        desc = "LLM: chat history",
      },
    },
    -- The default chat/inline adapter is already "copilot". It reuses the
    -- OAuth token that :Copilot auth writes to github-copilot/hosts.json,
    -- and plenary.curl honors the HTTPS_PROXY environment variable.
    opts = {
      interactions = {
        chat = {
          keymaps = {
            -- All LLM actions live under the <leader>l group, matching the
            -- global keymap architecture. Buffer-local, so normal buffers
            -- are unaffected. Navigation keys (]], [[, }, {, gR) and
            -- <C-s>/q/? keep plugin defaults.
            regenerate = { modes = { n = "<leader>lr" } },
            change_adapter = { modes = { n = "<leader>la" } },
            clear = { modes = { n = "<leader>lx" } },
            yank_code = { modes = { n = "<leader>ly" } },
            codeblock = { modes = { n = "<leader>lb" } },
            fold_code = { modes = { n = "<leader>lf" } },
            system_prompt = { modes = { n = "<leader>lp" } },
            copilot_stats = { modes = { n = "<leader>lS" } },
            rules = { modes = { n = "<leader>lR" } },
            _btw = { modes = { n = "<leader>lm" } },
            debug = { modes = { n = "<leader>li" } },
            buffer_sync_all = { modes = { n = "<leader>lba" } },
            buffer_sync_diff = { modes = { n = "<leader>lbd" } },
            clear_approvals = { modes = { n = "<leader>ltx" } },
            yolo_mode = { modes = { n = "<leader>lty" } },
          },
        },
        shared = {
          keymaps = {
            -- Inline-diff review actions also join the <leader>l group.
            view_diff = { modes = { n = "<leader>lv" } },
            always_accept = { modes = { n = "<leader>l1" } },
            accept_change = { modes = { n = "<leader>l2" } },
            reject_change = { modes = { n = "<leader>l3" } },
            cancel = { modes = { n = "<leader>l4" } },
          },
        },
      },
      extensions = {
        history = {
          enabled = true,
          opts = {
            -- History and manual save join the <leader>l LLM group instead
            -- of the extension's gh/sc defaults.
            keymap = "<leader>lh",
            save_chat_keymap = "<leader>ls",
            auto_save = true,
            picker = "telescope",
            auto_generate_title = true,
            -- Summary keys join the <leader>l group too. Note: the
            -- extension falls back to its gcs/gbs defaults when these are
            -- false, so they must be remapped, not disabled.
            summary = {
              create_summary_keymap = "<leader>lG",
              browse_summaries_keymap = "<leader>lB",
            },
          },
        },
      },
      display = {
        chat = {
          window = {
            position = "right",
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
