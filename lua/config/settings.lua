-- User-facing global settings.
-- Open this file with <leader>, and run :SettingsReload after saving.
return {
  readonly = {
    enabled = true,

    -- Protect OS SDK/toolchain headers and Neovim-managed tool packages.
    protect_system_paths = true,
    protect_package_paths = true,

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
}
