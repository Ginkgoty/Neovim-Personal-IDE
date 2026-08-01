-- User-facing global settings. Open this file with <leader>,.
-- :SettingsReload immediately reapplies editor, read-only, terminal, and LSP
-- behavior. Restart Neovim after changing plugin UI/startup options.
return {
  editor = {
    indent_size = 4,
    expand_tabs = true,
    text_width = 80,
    line_numbers = true,
    system_clipboard = true,

    -- Also controls CursorHold features such as reference highlighting.
    cursor_hold_ms = 500,
  },

  files = {
    backup = false,
    swap = false,

    -- Reload clean buffers after an Agent or another process writes the file.
    -- "ask" protects unsaved Neovim edits; "reload" discards them.
    auto_reload_external_changes = true,
    external_change_conflict = "ask",
  },

  formatting = {
    on_save = true,
    timeout_ms = 2000,
  },

  ui = {
    which_key_delay_ms = 300,

    screenkey = {
      clear_after = 3,
      compress_after = 3,
      width = 36,
      height = 3,
      border = "rounded",
      show_leader = true,
    },

    images = {
      enabled = true,
      inline = true,
      float = true,
      max_width = 80,
      max_height = 40,
    },

    search_replace = {
      -- grug-far temporarily replaces NvimTree, like VSCode's Search view.
      sidebar_width = 48,
      -- Keep each match on one visual line in the narrow search sidebar.
      wrap_results = false,
      -- Full g? help opens over the editor instead of inside the sidebar.
      help_width = 100,
      help_height = 30,
      highlights = {
        -- All result matches, the active source match, and the selected row.
        result_match = "Search",
        current_match = "IncSearch",
        current_result_line = "Visual",
      },
    },

    codecompanion = {
      -- A value below 1 is a fraction of the total editor width.
      chat_width = 0.36,
    },
  },

  plugins = {
    check_for_updates = true,
  },

  navigation = {
    jump_history = {
      -- Keep <leader>jb/jf focused on jumps made during this Neovim session
      -- and inside the current project. Native Ctrl-o/Ctrl-i remain global.
      clear_restored_on_start = true,
      project_only = true,
    },
  },

  python = {
    environment = {
      -- Remember one interpreter per workspace and restore it automatically.
      auto_restore = true,
      notify = true,
      picker = "telescope",
    },
  },

  readonly = {
    enabled = true,

    -- Protect OS SDK/toolchain headers and Neovim-managed tool packages.
    protect_system_paths = true,
    protect_package_paths = true,
    -- Protect the complete environment selected by venv-selector.nvim.
    protect_python_environments = true,

    -- true prevents edits entirely; false only warns when writing.
    lock_modifications = true,

    -- Glob syntax supports *, **, ?, [], and {}. Paths are normalized to use /.
    -- Exclude rules always win over include rules.
    include = {
      -- Example: "/path/to/vendor/**",
    },
    exclude = {
      -- Example: "/path/to/vendor/editable-fork/**",
    },
  },

  terminal = {
    -- Explicit shell for the integrated terminal. nil (or "") auto-detects:
    -- on Windows PowerShell 7 (pwsh) > Windows PowerShell 5.1 > cmd; other
    -- platforms use $SHELL. Examples: "pwsh", "powershell", "cmd",
    -- "C:/Program Files/Git/bin/bash.exe"
    shell = nil,
  },

  explorer = {
    -- true shows files ignored by .gitignore (e.g. .env) in nvim-tree,
    -- like the VSCode explorer. false hides them (nvim-tree's default).
    -- Press I in the tree to toggle the filter at runtime. nvim-tree reads
    -- this once at startup, so restart Neovim after changing it.
    show_git_ignored = true,
  },

  lsp = {
    documentation = {
      -- K and <leader>fd remain available when automatic display is disabled.
      auto_show = true,
      delay_ms = 1000,
      border = "rounded",
      max_width = 0.8,
      max_height = 0.5,
      navigation_hints = true,
      -- Merge diagnostics from the current line into the documentation float.
      include_diagnostics = true,
      -- Ask LSP servers for Quick Fix actions and advertise <leader>xq when found.
      detect_quick_fixes = true,
    },
  },
}
