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
}
