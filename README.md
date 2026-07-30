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
- GitHub Copilot inline suggestions (accept with `Ctrl-J`) plus a
  CodeCompanion chat sidebar (`<leader>lc`); sign in once with
  `:Copilot auth` and both pick it up. Chats are auto-saved and can be
  browsed and restored with `<leader>lh`
- Ruff and ty for modern Python projects
- DAP debugging with CodeLLDB, GDB, NetCoreDbg, debugpy, Delve, and Java Debug
- Formatting through Conform: Ruff, clang-format, CSharpier,
  goimports/gofmt, rustfmt, and StyLua
- Telescope search, nvim-tree, Neogit/Diffview, Gitsigns, WhichKey, and ToggleTerm
- Overseer task management for build, run, test, and project task output
- In-buffer Markdown rendering for headings, lists, tables, links, and code blocks
- Read-only protection for SDK, toolchain, package-manager, and custom paths
- Platform-aware C/C++ toolchain, clangd, formatter, and debugger selection
- GitHub Light by default, with PaperColor Light, Rosé Pine Dawn, and Paper
  as eye-care alternatives

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
:ThemePaperColor    " Use PaperColor Light
:ThemeRosePine      " Use Rosé Pine Dawn
:ThemePaper         " Use Paper
:ToolchainInfo      " Show the selected MSVC/MinGW toolchain on Windows
:ClangdInfo         " Show clangd executable, arguments, root, and compile database
:LanguageInfo       " Show enabled and disabled language support
:LanguageInstall csharp " Open the official SDK/toolchain installation page
:SettingsReload     " Reload settings that support live application
:ReadonlyInfo       " Explain the current buffer's read-only state
:ReadonlyUnlock     " Temporarily unlock the current buffer
:ReadonlyLock       " Lock the current buffer again
:Neogit             " Open the Git status UI
:DiffviewFileHistory " Browse repository history and diffs
:OverseerRun        " Select and run a project task
:OverseerShell cmd  " Run an arbitrary command as a managed task
:OverseerToggle     " Toggle the build/run task list
:RenderMarkdown buf_toggle " Toggle rendering for the current Markdown buffer
:Screenkey toggle    " Toggle the pressed-key overlay
:checkhealth snacks  " Diagnose terminal image rendering
:Copilot auth       " Sign in to GitHub Copilot (first use)
:Copilot status     " Show Copilot sign-in and service status
:CodeCompanionChat Toggle " Toggle the Copilot chat sidebar
:CodeCompanionHistory " Browse saved chat sessions
:CodeCompanionSummaries " Browse generated chat summaries
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
| `<leader>l` | LLM: Copilot chat, chat history, and in-chat actions |
| `<leader>r` | Build, run, test, and task output |
| `<leader>u` | UI toggles |
| `<leader>w` | Windows and splits |
| `<leader>x` | Diagnostics |

Bracket mappings such as `[d`/`]d`, `[e`/`]e`, and `[c`/`]c` move to the
previous/next diagnostic, error, or Git hunk. `K` or `<leader>fd` shows the
LSP signature, inferred type, and documentation for the symbol under the
cursor. Press the same key again to focus the documentation window, then use
normal window scrolling and `q` to close it. Documentation also opens
automatically after the cursor rests on a symbol for three seconds in normal
mode. Configure or disable this with `lsp.documentation` in
`lua/config/settings.lua`. The floating-window title advertises `gd`
definition, `gD` declaration, and `gri` implementation navigation. After
pressing `K` again to focus the documentation window, those keys return to the
original source symbol and perform the advertised navigation; `q` closes the
window normally. Set `lsp.documentation.navigation_hints = false` for a plain
title.

Useful non-leader aliases are deliberately kept small:

| Key | Action |
| --- | --- |
| `Alt-Left` / `Alt-Right` (macOS: `Option`) | Previous/next buffer |
| `Shift-Arrow` | Focus the adjacent window |
| `Ctrl-Arrow` | Resize the current window |
| `F5` / `F10` / `F11` / `F12` | Continue, step over, step into, and step out |

`<leader>uk` toggles a bottom-right pressed-key overlay for demonstrations,
recordings, and keymap troubleshooting. It clears after three seconds of
inactivity and is disabled inside terminal and prompt buffers. Its appearance
and timing live under `ui.screenkey` in `lua/config/settings.lua`.

Snacks.image renders images referenced by Markdown and other supported
documents through the terminal's Kitty graphics protocol. Ghostty is supported
directly, and ImageMagick converts non-PNG formats. Inline rendering, fallback
floating previews, and size limits live under `ui.images` in
`lua/config/settings.lua`. Only the image module is enabled: Snacks does not
replace Telescope, nvim-tree, notifications, or the dashboard.

Bufferline shows real file buffers only; unnamed scratch buffers and
plugin-owned panels are excluded. `<leader>bq` and Bufferline's close button
use the same safe close operation: the most recently used file replaces the
closed file, and closing the last file leaves an unlabelled empty editor. A
sidebar such as nvim-tree is therefore never allowed to consume the entire
editing area merely because a tool buffer was closed. Use `<leader>bo` to
close all other files, `<leader>bh` / `<leader>bl` to close files to the left
or right, or `<leader>bx` to label the visible file tabs and pick one to close.

`<leader>q` quits the editor. With unmodified buffers it exits
immediately; otherwise it prompts once — `Yes` saves every modified buffer
(`:xa`), `No` (the default) discards them (`:qa!`).

Native `:q` still closes a window rather than deleting its buffer. When it
targets the last real editing window, a `QuitPre` guard first closes nvim-tree
and other auxiliary windows so the editor exits cleanly instead of leaving a
full-screen sidebar with stale-looking file tabs. Use `<leader>bq` when the
intent is to close the current file but keep the editing layout open.

Alt combinations require the terminal to forward rather than consume the key.
On macOS, Ghostty can reserve the left Option for terminal Alt while leaving
the right Option available for macOS character input. Ghostty also binds
Alt-Arrow to word movement by default, so override both bindings explicitly:

```ini
macos-option-as-alt = left
keybind = alt+arrow_left=csi:1;3D
keybind = alt+arrow_right=csi:1;3C
```

Reload the Ghostty configuration or restart Ghostty after changing it. The
leader-key equivalents remain available when terminal Alt handling is
unavailable.

### Code navigation and diagnostics

These mappings are available when an LSP client is attached:

| Key | Action |
| --- | --- |
| `gd` / `gD` | Go to definition/declaration |
| `<leader><Enter>` | On a definition: find references; otherwise go to definition (falls back to declaration) |
| `grr` / `gri` / `grt` | Find references/implementations/type definition |
| `gai` / `gao` | Incoming/outgoing calls |
| `K` | Hover documentation and inferred type information |
| `<leader>ca` / `<leader>cr` | Code action/rename |
| `<leader>xf` | Show the complete diagnostic under the cursor |
| `<leader>xd` / `<leader>xD` | Buffer/workspace diagnostics |
| `<leader>xi` | Show clangd status in a C/C++ buffer |
| `<leader>uh` | Toggle inlay hints |
| `<leader>um` | Toggle rendered/raw Markdown view |

`<leader>jb` and `<leader>jf` move backward and forward through jumps made in
the current session and current project. Cross-session entries restored by
ShaDa are cleared at startup, and project-external entries are skipped. Native
`Ctrl-o` and `Ctrl-i` retain access to Neovim's unrestricted jumplist. This is
also how to return after following a definition with `gd`. Configure the two
leader-key restrictions under `navigation.jump_history` in
`lua/config/settings.lua`.

clangd uses background indexing, clang-tidy, detailed completion, include
insertion, and a platform-restricted compiler query-driver. Accurate project
diagnostics still depend on `compile_commands.json`, `compile_flags.txt`, or a
project `.clangd` file. Neovim warns once per project when no compilation
database is found; it does not guess a C++ standard, macro set, or include path.

### Workspace panels

| Key | Panel/action |
| --- | --- |
| `<leader>e` | Reveal the current file in nvim-tree and toggle the explorer |
| `<leader>t` | Toggle the terminal; press `Esc Esc` to leave terminal mode. Prefix a count (`2<leader>t`) for a separate terminal; `:TermSelect` lists open terminals |
| `<leader>du` | Toggle the DAP UI |
| `<leader>lc` | Toggle the CodeCompanion (Copilot) chat sidebar |
| `<leader>lh` | Browse and restore saved chat history |
| `<leader>gg` | Open the Neogit status split |
| `<leader>gh` / `<leader>gH` | Current-file/repository history in Diffview |
| `<leader>gq` | Close the Diffview history/diff view |
| `<leader>rr` | Select and run an Overseer task |
| `<leader>rt` | Toggle the bottom task list |
| `<leader>rl` / `<leader>ro` | Restart/open output for the latest task |
| `<leader>rs` / `<leader>ra` | Stop the latest running task/select a task action |

Inside the CodeCompanion chat buffer, every chat action lives in the
`<leader>l` LLM group (buffer-local, so normal buffers are unaffected):
`<leader>lr` regenerate, `<leader>la` change adapter/model, `<leader>lx`
clear, `<leader>ly` yank code, `<leader>lb` code block, `<leader>lf` fold
code, `<leader>lp` toggle system prompt, `<leader>lS` Copilot stats,
`<leader>lR` clear rules, `<leader>lm` follow-up while streaming,
`<leader>li` debug info, `<leader>lba`/`<leader>lbd` sync pinned buffers
(all/diff), `<leader>ltx` reset tool approvals, `<leader>lty` toggle
auto-approval (YOLO) mode, `<leader>lG` generate a summary of the chat,
`<leader>lB` browse saved summaries. When the LLM proposes inline changes
in a normal buffer, review them with `<leader>l2` accept, `<leader>l3`
reject, `<leader>l1` always accept, `<leader>l4` cancel, and `<leader>lv`
view the diff. Navigation and control keys keep their plugin defaults:
`<C-s>` send, `q` stop, `?` options, `]]`/`[[` next/previous message,
`}`/`{` next/previous chat or diff hunk, `gR` open the file under the
cursor. Save the current chat manually with `<leader>ls`; auto-save is on,
so this is rarely needed.

Overseer discovers task definitions from supported project frameworks such as
Make, Cargo, npm, Just, and `.vscode/tasks.json`. Use `:OverseerShell <command>`
for an ad-hoc command. For reproducible cross-device builds, keep the build,
run, and test commands in a project task file instead of hard-coding them in
this Neovim configuration.

### Global settings and protected files

Edit `lua/config/settings.lua` to change user-facing global behavior. Its
`editor` and `files` sections control indentation, text width, line numbers,
clipboard integration, CursorHold timing, swap files, and backups.
`formatting` controls format-on-save and its timeout; `ui` controls the
WhichKey delay; `plugins.check_for_updates` controls Lazy's background update
check; and `lsp.documentation` controls automatic symbol documentation and
the hover window. Plugin startup options take effect after restarting Neovim;
editor, read-only, terminal, and LSP behavior can be refreshed with
`:SettingsReload`.

External changes made by an Agent or another process are checked on focus,
buffer entry, normal-mode idle, and return from a terminal. Clean buffers are
reloaded automatically. If both disk and Neovim changed, the native prompt
lets you keep the Neovim buffer (`OK`) or discard it and load the disk version
(`Load File`). An externally deleted file is kept in memory with a warning.
Configure this under `files.auto_reload_external_changes` and
`files.external_change_conflict`; the safe default is `"ask"`.

The
`terminal.shell` option sets the integrated terminal shell explicitly (for
example `"pwsh"`, `"powershell"`, `"cmd"`, or a Git Bash path such as
`"C:/Program Files/Git/bin/bash.exe"`); left unset, Windows auto-detects
PowerShell 7, then Windows PowerShell 5.1, then cmd, and other platforms use
`$SHELL`. Its
`explorer.show_git_ignored` option (default `true`) shows files ignored by
`.gitignore` (such as `.env`) in nvim-tree; set it to `false` to hide them,
and restart Neovim to apply. Its
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
