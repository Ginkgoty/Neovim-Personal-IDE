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

  tasks = {
    -- Overseer's built-in Make provider only searches upward. Check these
    -- project-root children for out-of-source configure/CMake builds too.
    build_directories = { "build", "Build", "out", "cmake-build-debug", "cmake-build-release" },
    make = {
      -- Capture real compiler invocations for clangd. Bear is a host build
      -- tool and must be installed through the OS package manager.
      use_bear = true,
      append_existing_compilation_database = true,
    },
  },

  editing = {
    completion = {
      documentation = true,
      documentation_delay_ms = 300,
      signature_help = true,
      -- Disabled by default because inlay hints already provide inline type
      -- information; enable this only if completion ghost text is desirable.
      ghost_text = false,
      -- Keep arbitrary words from the current buffer out of short API queries.
      buffer_min_keyword_length = 3,
    },
  },

  diagnostics = {
    -- Keep the coding surface quiet: all severities retain signs and
    -- underlines, while only errors receive an end-of-line message.
    virtual_text_errors = true,
    update_in_insert = false,
    severity_sort = true,
  },

  ui = {
    which_key_delay_ms = 300,

    -- Improve LSP type/parameter inlay hints only when the active theme does
    -- not provide enough contrast. Colors are derived from that theme.
    inlay_hint_min_contrast = 5,
    inlay_hint_background_contrast = 1.05,

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
    -- Neovim's recursive workspace file watcher can exhaust file descriptors
    -- in large projects on macOS/Windows. Language servers still watch/index
    -- files internally; open-buffer diagnostics and navigation are unaffected.
    workspace_file_watching = false,

    document_links = {
      -- Underline only include paths that clangd resolved to a real target.
      -- Buffer-local gx opens the target inside Neovim rather than delegating
      -- file:// links to the operating system's external application handler.
      enabled = true,
      -- clangd semantic tokens underline macro definitions and uses as a
      -- visual promise that <leader><Enter> supports bidirectional navigation.
      underline_macros = true,
      refresh_delay_ms = 250,
    },

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
