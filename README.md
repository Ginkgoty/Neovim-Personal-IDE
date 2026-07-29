# Neovim Personal IDE

A modern, cross-platform Neovim configuration for C/C++, C#/.NET, Python,
Go, Rust, Java, SQL, and Lua.

## Requirements

- Neovim 0.12+
- Git, ripgrep, fd, and a C compiler
- A Nerd Font for file icons
- Windows: PowerShell 7 and CMake are recommended. Native builds prefer an
  installed MSVC C++ toolset (detected with `vswhere.exe`), then MinGW
  (`gcc`, `g++`, and `mingw32-make`). If neither is usable, Telescope falls
  back to its built-in sorter.
- C#/.NET: install the .NET SDK separately and confirm it with
  `dotnet --list-sdks`. Mason manages the editor-side C# tools, not the SDK.
- Java requires JDK 21 or newer. Go and Rust require their normal host
  toolchains (`go`, or `rustc` + `cargo`). Python project management through
  uv.nvim requires a host-installed `uv` command.

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Language servers, debug adapters, and command-line tools are managed by Mason where possible.

## Install

Back up an existing configuration, then clone this repository:

```sh
git clone https://github.com/Ginkgoty/Neovim-Personal-IDE.git ~/.config/nvim
nvim
```

On Windows PowerShell:

```powershell
git clone https://github.com/Ginkgoty/Neovim-Personal-IDE.git $env:LOCALAPPDATA\nvim
nvim
```

The configuration resolves Mason's platform-specific executable layouts
automatically, including `python.exe`, `dlv.exe`, and `codelldb.exe` on Windows.

On first launch, lazy.nvim installs plugins and Mason installs configured development tools.

## Main features

- LSP and completion for C/C++, C#/.NET, Python, Go, Rust, Java, SQL, and Lua
- Ruff and ty for modern Python projects
- DAP debugging with CodeLLDB, GDB, NetCoreDbg, debugpy, Delve, and Java Debug
- Formatting through Conform: Ruff, clang-format, CSharpier,
  goimports/gofmt, rustfmt, and StyLua
- Telescope search, nvim-tree, Neogit/Diffview, Gitsigns, WhichKey, and ToggleTerm
- Overseer task management for build, run, test, and project task output
- In-buffer Markdown rendering for headings, lists, tables, links, and code blocks
- Read-only protection for SDK, toolchain, package-manager, and custom paths
- Platform-aware C/C++ toolchain, clangd, formatter, and debugger selection
- GitHub Light by default, with MacVim Light as an alternative

## Useful commands

```vim
:Lazy sync          " Install/update plugins
:Mason              " Manage LSP/DAP/formatter tools
:TSUpdate           " Update Treesitter parsers
:checkhealth        " Diagnose the installation
:ConformInfo        " Show the formatter for the current buffer
:FormatToggle       " Toggle format-on-save globally
:FormatToggle!      " Toggle format-on-save for the current buffer
:ThemeGithub        " Use GitHub Light
:ThemeMacvim        " Use MacVim Light
:ToolchainInfo      " Show the selected MSVC/MinGW toolchain on Windows
:ClangdInfo         " Show clangd executable, arguments, root, and compile database
:LanguageInfo       " Show enabled and disabled language support
:LanguageInstall csharp " Open the official SDK/toolchain installation page
:SettingsReload     " Reload lua/config/settings.lua without restarting
:ReadonlyInfo       " Explain the current buffer's read-only state
:ReadonlyUnlock     " Temporarily unlock the current buffer
:ReadonlyLock       " Lock the current buffer again
:Neogit             " Open the Git status UI
:DiffviewFileHistory " Browse repository history and diffs
:OverseerRun        " Select and run a project task
:OverseerShell cmd  " Run an arbitrary command as a managed task
:OverseerToggle     " Toggle the build/run task list
:RenderMarkdown buf_toggle " Toggle rendering for the current Markdown buffer
```

Press `<Space>` and pause briefly to discover configured shortcuts with which-key.
Press `<Space>,` to edit the centralized `lua/config/settings.lua` file.

### Shortcut model

Each prefix has one responsibility:

| Prefix | Responsibility |
| --- | --- |
| `g...` (no leader) | Navigate code relationships: definitions, references, implementations, and calls |
| `<leader>b` | Buffers |
| `<leader>c` | Code-changing actions: action, rename, format, and CodeLens |
| `<leader>d` | Debugging |
| `<leader>f` | Find or navigate files, text, symbols, and source/header pairs |
| `<leader>g` | Git |
| `<leader>j` | Jump-list history |
| `<leader>r` | Build, run, test, and task output |
| `<leader>u` | UI toggles |
| `<leader>w` | Windows and splits |
| `<leader>x` | Diagnostics |

Bracket mappings such as `[d`/`]d`, `[e`/`]e`, and `[c`/`]c` move to the
previous/next diagnostic, error, or Git hunk. `K` shows LSP documentation.

Useful non-leader aliases are deliberately kept small:

| Key | Action |
| --- | --- |
| `Shift-Left` / `Shift-Right` | Previous/next buffer |
| `Option-Arrow` / `Alt-Arrow` | Focus the adjacent window |
| `Option-x` / `Alt-x` | Close the current buffer, or quit if it is the last one |
| `Ctrl-Arrow` | Resize the current window |
| `F5` / `F10` / `F11` / `F12` | Continue, step over, step into, and step out |

On macOS, the terminal must send Option as Alt. For Ghostty, a practical
configuration is `macos-option-as-alt = left`, leaving the right Option key
available for macOS character input. The leader-key equivalents remain
available when terminal Alt handling is unavailable.

### Code navigation and diagnostics

These mappings are available when an LSP client is attached:

| Key | Action |
| --- | --- |
| `gd` / `gD` | Go to definition/declaration |
| `grr` / `gri` / `grt` | Find references/implementations/type definition |
| `gai` / `gao` | Incoming/outgoing calls |
| `K` | Hover documentation and inferred type information |
| `<leader>ca` / `<leader>cr` | Code action/rename |
| `<leader>xf` | Show the complete diagnostic under the cursor |
| `<leader>xd` / `<leader>xD` | Buffer/workspace diagnostics |
| `<leader>xi` | Show clangd status in a C/C++ buffer |
| `<leader>uh` | Toggle inlay hints |
| `<leader>um` | Toggle rendered/raw Markdown view |

`<leader>jb` and `<leader>jf` provide discoverable aliases for jump-list back
and forward (`Ctrl-o` and `Ctrl-i`). This is also how to return after following
a definition with `gd`.

clangd uses background indexing, clang-tidy, detailed completion, include
insertion, and a platform-restricted compiler query-driver. Accurate project
diagnostics still depend on `compile_commands.json`, `compile_flags.txt`, or a
project `.clangd` file. Neovim warns once per project when no compilation
database is found; it does not guess a C++ standard, macro set, or include path.

### Workspace panels

| Key | Panel/action |
| --- | --- |
| `<leader>e` | Reveal the current file in nvim-tree and toggle the explorer |
| `<leader>t` | Toggle the terminal; press `Esc Esc` to leave terminal mode |
| `<leader>du` | Toggle the DAP UI |
| `<leader>gg` | Open the Neogit status split |
| `<leader>gh` / `<leader>gH` | Current-file/repository history in Diffview |
| `<leader>gq` | Close the Diffview history/diff view |
| `<leader>rr` | Select and run an Overseer task |
| `<leader>rt` | Toggle the bottom task list |
| `<leader>rl` / `<leader>ro` | Restart/open output for the latest task |
| `<leader>rs` / `<leader>ra` | Stop the latest running task/select a task action |

Overseer discovers task definitions from supported project frameworks such as
Make, Cargo, npm, Just, and `.vscode/tasks.json`. Use `:OverseerShell <command>`
for an ad-hoc command. For reproducible cross-device builds, keep the build,
run, and test commands in a project task file instead of hard-coding them in
this Neovim configuration.

### Global settings and protected files

Edit `lua/config/settings.lua` to change user-facing global behavior. Its
`readonly` section protects system SDK/toolchain headers and Neovim-managed
tool packages by default. Add custom glob patterns to `include` and `exclude`;
exclude patterns always win. Save the file and run `:SettingsReload` to apply
changes to open buffers. Protected buffers use both `readonly` and
`nomodifiable`; use `:ReadonlyUnlock` for an intentional temporary edit.

## Language profiles

Edit `lua/config/languages.lua` to change the shared language set. Every switch
controls its LSP, Mason tools, formatter, Treesitter parsers, debugger, and
language-specific plugins.

For an untracked per-device override, create `lua/config/languages_local.lua`:

```lua
return {
  java = false,
  go = true,
  csharp = true,
}
```

Restart Neovim and run `:Lazy sync` after changing the set. Removing a language
from the profile does not uninstall tools already present; remove those from
`:Mason` when desired.

Mason manages most Neovim LSP servers, formatters, and debug adapters. Java is
managed as a versioned JDTLS/test/debug bundle by nvim-java. The `uv` package
manager is another deliberate exception: install it as a host command and
uv.nvim will use it from PATH. Language SDK tools such as `dotnet`, `gofmt`,
and `rustfmt` also remain owned by their host toolchains.
Syntax highlighting remains available when an enabled language toolchain is
missing, but its LSP, formatter, debugger, and Mason tools wait for the host
prerequisite: a C/C++ compiler, `dotnet`, `go`, `rustc` + `cargo`, or a JDK.
Install the toolchain, restart Neovim, and the integrations become active.
Neovim displays one startup warning per session for enabled languages whose
toolchains are missing. The warning includes the official installation URL;
`:LanguageInstall cpp|csharp|go|rust|java` opens the same page on demand.

## Updating

The update layers are intentionally separate:

1. Run `:Lazy sync` to install, update, and remove Neovim plugins according to
   the configuration and `lazy-lock.json`.
2. Open `:Mason` to update or remove editor-side language servers, formatters,
   and debug adapters. Mason does not update host SDKs or compilers.
3. Run `:TSUpdate` to update enabled Treesitter parsers.
4. Update host tools such as Xcode Command Line Tools, Visual Studio, `.NET`,
   Go, Rust, Java, and `uv` using their platform package managers.
5. Run `:checkhealth` after large updates.

Before committing configuration changes, run:

```sh
git diff --check
nvim --headless '+checkhealth' '+qa'
```
