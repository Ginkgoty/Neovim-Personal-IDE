# Neovim Personal IDE

A modern, cross-platform Neovim configuration for C/C++, C#/.NET, Python,
Go, Rust, Java, JavaScript/TypeScript, React, Vue, SQL, JSON, and Lua.

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

- LSP and completion for C/C++, C#/.NET, Python, Go, Rust, Java,
  JavaScript/TypeScript, React, Vue, SQL, JSON, and Lua
- GitHub Copilot inline suggestions (accept with `Ctrl-J`) plus a
  CodeCompanion chat sidebar (`<leader>ac`); sign in once with
  `:Copilot auth` and both pick it up. Chats are auto-saved and can be
  browsed and restored with `<leader>ah`
- Ruff and ty for modern Python projects, with per-workspace interpreter
  discovery, selection, caching, terminal activation, and DAP synchronization
- DAP debugging with CodeLLDB, GDB, NetCoreDbg, debugpy, Delve, Java Debug,
  and the VS Code JavaScript debugger
- Formatting through Conform: Ruff, clang-format, CSharpier,
  goimports/gofmt, rustfmt, Prettier, and StyLua
- Telescope search, grug-far project search/replace, nvim-tree,
  Neogit/Diffview, Gitsigns, WhichKey, and ToggleTerm
- Overseer task management for build, run, test, and project task output
- In-buffer Markdown rendering for headings, lists, tables, links, and code blocks
- Read-only protection for SDK, toolchain, package-manager, and custom paths
- Platform-aware C/C++ toolchain, clangd, formatter, and debugger selection
- Predictable coding input with automatic pairs, language-native indentation,
  semantic completion, signature help, and native snippets
- GitHub Light by default; PaperColor, Paper, and Xcode are light alternatives,
  while PaperColor Dark, Oxocarbon, and Ayu are dark alternatives

## Useful commands

```vim
:Lazy sync          " Install/update plugins
:Mason              " Manage LSP/DAP/formatter tools
:MasonUpdate        " Refresh the Mason registry (does not upgrade tools)
:MasonUpgrade       " Refresh registry and upgrade every installed Mason tool
:TSUpdate           " Update Treesitter parsers
:checkhealth        " Diagnose the installation
:ConformInfo        " Show the formatter for the current buffer
:FormatToggle       " Toggle format-on-save globally
:FormatToggle!      " Toggle format-on-save for the current buffer
:ThemeGithub        " Use GitHub Light
:ThemePaperColor    " Use PaperColor Light
:ThemePaperColorDark " Use PaperColor Dark
:ThemePaper         " Use Paper
:ThemeXcode         " Use Xcode Light
:ThemeOxocarbon     " Use Oxocarbon Dark
:ThemeAyu           " Use Ayu Dark
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
:VenvSelect          " Discover and select the current Python interpreter
:Copilot auth       " Sign in to GitHub Copilot (first use)
:Copilot status     " Show Copilot sign-in and service status
:CodeCompanionChat Toggle " Toggle the Copilot chat sidebar
:CodeCompanionHistory " Browse saved chat sessions
:CodeCompanionSummaries " Browse generated chat summaries
```

`Lazy sync` updates Neovim plugins, not Mason packages. Mason 2.3 refreshes a
stale registry automatically after its 24-hour cache expires, while
`MasonUpdate` forces only the registry metadata to refresh. Use
`MasonUpgrade` for the complete operation: it refreshes the registry, compares
every installed package with the new index, and upgrades all outdated tools.

Press `<Space>` and pause briefly to discover configured shortcuts with which-key.
Press `<Space>,` to edit the centralized `lua/config/settings.lua` file.

### Shortcut model

Each prefix has one responsibility:

| Prefix | Responsibility |
| --- | --- |
| `g...` (no leader) | Navigate code relationships: definitions, references, implementations, and calls |
| `<leader>a` | AI and Agent features |
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
previous/next diagnostic, error, or Git hunk. `K` or `<leader>fd` shows the
LSP signature, inferred type, and documentation for the symbol under the
cursor. Diagnostics on the current line are merged into that same window. If
an LSP server offers a Quick Fix, the title also advertises `<leader>xq`.
Press the same key again to focus the context window, then use normal window
scrolling and `q` to close it. It also opens automatically after the configured
idle delay in normal mode. Configure or disable documentation, diagnostics,
and Quick Fix detection with `lsp.documentation` in
`lua/config/settings.lua`. The floating-window title advertises `gd`
definition, `gD` declaration, and `gri` implementation navigation. After
pressing `K` again to focus the documentation window, those keys return to the
original source symbol and perform the advertised navigation. `<leader>xq`
does the same before opening the Quick Fix picker; `q` closes the window
normally. Set `lsp.documentation.navigation_hints = false` for a plain title.

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

Coding completion is shared by every enabled language. Type normally to open
semantic LSP suggestions, or press `<C-Space>` to request them manually.
`<Tab>` / `<S-Tab>` select completion items and move through snippet fields;
`<CR>` confirms only an explicitly selected item and otherwise inserts a normal
newline. `<C-n>` / `<C-p>` are alternative selection keys, `<C-e>` closes the
menu, `<C-b>` / `<C-f>` scroll its documentation, and `<C-k>` toggles signature
help. Parentheses, brackets, braces, and quotes are paired automatically;
pressing Enter between a pair creates an indented line.

Completion ranks semantic LSP results ahead of snippets, paths, and buffer
words. Buffer words require at least three characters and never outrank API
recommendations. Diagnostics keep signs and underlines for every severity but
show inline text only for errors; complete current-line details and Quick Fix
availability remain in the automatic documentation float.

These mappings are available when an LSP client is attached:

| Key | Action |
| --- | --- |
| `gd` / `gD` | Go to definition/declaration |
| `<leader><Enter>` | Follow an include; uses go to definitions, definitions (including macros) list references |
| `grr` / `gri` / `grt` | Find references/implementations/type definition |
| `gai` / `gao` | Incoming/outgoing calls |
| `K` | Hover documentation and inferred type information |
| `<leader>ca` | Contextual Code Actions (also works on a visual selection) |
| `<leader>cr` | Rename the symbol under the cursor |
| Visual `<leader>ce` | Extract the selected code when supported by the LSP |
| `<leader>ci` | Inline refactor at the cursor or for the selection |
| `<leader>co` / `<leader>cF` | Organize imports/fix all issues in the current file |
| `<leader>xc` | Show the complete diagnostic under the cursor |
| `<leader>xq` | Apply a Quick Fix at the cursor |
| `<leader>xf` | Current-file diagnostics |
| `<leader>xa` | Diagnostics from all loaded buffers |
| `<leader>xt` / `<leader>xT` | Current-buffer/all-buffer diagnostic table |
| `<leader>xi` | Show clangd status in a C/C++ buffer |
| `<leader>uh` | Toggle inlay hints |
| `<leader>um` | Toggle rendered/raw Markdown view |

When an attached language server implements `textDocument/documentColor`,
hovering a reported color with `K` (or waiting for automatic documentation)
adds an exact swatch plus Hex and RGB/RGBA values to the context window. The
result is cached until the buffer changes and can be disabled with
`lsp.documentation.color_preview` in `lua/config/settings.lua`.
The source buffer uses nvim-highlight-colors to place one colored `■` before
Hex/RGB/HSL literals—including Vue/HTML attributes that LSP providers often
omit—and Tailwind palette classes without painting over the literal itself.
Neovim's native document-color decoration is disabled to prevent duplicate
swatches. Configure or disable the
single provider with `lsp.document_colors`; its `tailwind` option controls
Tailwind palette recognition.
Markdown images returned by an LSP are rendered through snacks.image;
base64-embedded PNG, JPEG, GIF, WebP, and SVG images are materialized in a
size-limited, session-local Neovim cache first. It is removed on normal exit;
crash leftovers expire after 24 hours. Inside a focused hover window, move onto an
HTTP(S) Markdown link and press `Enter` or `gx` to open it externally. These
behaviors are controlled by `lsp.documentation.render_images` and
`max_data_image_bytes`, `max_data_image_cache_bytes`, and
`stale_image_cache_hours` in the same settings section.
Hover rendering is offline-safe by default: HTTP(S) images are not downloaded
implicitly and appear as ordinary openable links instead. Set
`lsp.documentation.render_remote_images = true` only when automatic remote
image fetching is explicitly desired. Embedded data images and local images
never require network access.
`file://` links use the same keys but open inside the existing Neovim editor
window. The hover title advertises `<CR> Open Link` only when the rendered
content contains a supported link. Image dimensions preserve the source's
intrinsic pixel size and are converted to terminal cells without upscaling;
`ui.images.max_width` and `max_height` are proportional shrink-only caps.
An inline badge followed by an emphasized status (such as MDN Baseline) stays
on one visual row; the badge source is concealed and the status is rendered as
plain text so terminals do not substitute an underline for italic text.

### Project-wide search and replace

Use `<leader>F` in normal mode to open a grug-far search/replace buffer rooted
at the current project. The same mapping in visual mode pre-fills the search
field with the selected text. It does not create a dedicated editor split:
like VSCode's Search view, it temporarily replaces NvimTree in the left
sidebar. Configure the temporary sidebar width
under `ui.search_replace` in `lua/config/settings.lua`. Matches use one compact
visual line in the sidebar, with `…` indicating content outside the visible
width; set `wrap_results = true` there to restore wrapped lines. Enter the replacement
and inspect the inline diff before applying it; the panel displays its
common actions in a compact multi-line header; `g?` opens the complete action
reference in a wide window over the editor. The selected result remains
highlighted after a numbered jump transfers focus to the editor, and match
highlight groups are configurable under `ui.search_replace.highlights`.
Opening or visiting a result always reuses
the editor window that was active before the search panel opened, while the
search panel remains available on the left. Press `<leader>F` again to close
it, or `<leader>e` to replace it with NvimTree in the same sidebar slot.
File globs, paths, ripgrep flags, individual-result editing, and search history
are available in the same panel. `<leader>fg` remains the faster read-only text
search and navigation entry point. This configuration's local leader is `\`:
use `\r` to apply Replace, `\s` to sync edited result lines, `\c` to close the
panel, `Enter` to visit a result, and `g?` for full help.

Code Actions are supplied by the attached language server and remain
context-sensitive. Extract and inline entries appear only when the server can
safely transform the cursor position or exact visual selection; rename uses the
separate LSP rename operation. Source-wide actions such as organize imports and
fix all are requested explicitly because many servers do not include them in a
generic contextual-action response.

The `xf` and `xa` diagnostic pickers are actionable lists. Pressing
`Enter` opens the selected diagnostic and immediately requests a Quick Fix at
that location. If the attached language server offers no fix, Neovim keeps the
cursor at the diagnostic and reports that no action is available. Telescope's
other open mappings remain unchanged.

For a denser, persistent table view, `xt` opens diagnostics for the current
buffer and `xT` aggregates diagnostics from all loaded buffers. Their UI titles
use “Current Buffer Diagnostics” and “All Buffers Diagnostics” instead of Vim's
implementation terms “location list” and “quickfix list”. In these tables,
columns are display-width aligned and `Enter` performs the native jump; use
`<leader>xq` at the destination to apply a Quick Fix. Press `a`, `e`, `w`, `i`,
or `h` inside the table to show All, Error, Warn, Info, or Hint diagnostics.

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
clangd itself remains PATH/Mason-managed. For a detected Clang toolchain, its
builtin resource directory is queried from the compiler rather than hard-coded;
safe host compiler aliases are allow-listed through `--query-driver` so target
and implicit system include paths follow the driver named by the compilation
database. Non-Clang toolchains retain clangd's own builtin headers.
Include paths that clangd resolves through LSP document links are underlined;
place the cursor on one and press `<leader><Enter>` or `gx` to open it inside
Neovim. The buffer-local `gx` deliberately replaces Neovim's external
application handler for LSP-enabled buffers. Macro names are underlined only
when clangd resolves them to a source `#define` with a non-empty replacement
body: the same leader action jumps from a use to its definition, or lists
references from the definition. Empty feature flags, compiler builtins, and
command-line `-D` macros remain unadorned. Configure this with
`lsp.document_links.underline_macros`.
Protected SDK, toolchain, and package headers never start an independent
unconstrained clangd: when reached from project code through an include, symbol,
declaration, or macro jump, they inherit that tab's originating project clangd
and translation-unit context, provided that project has a compilation database.
Without one there is no translation-unit context to inherit — clangd's generic
fallback would parse .h and extensionless headers as Objective-C++ — so the
header uses the controlled standalone clangd instead. When opened directly
without project context, headers inside the selected compiler's dynamically
queried include paths use a controlled standalone clangd. C++-only standard-library roots use C++; shared
system `.h` roots use ISO C, avoiding an invented Objective-C++ context. On
macOS, trusted versioned GCC/G++ drivers found on PATH are also queried without
displacing Apple Clang as the default; directly opened GCC/libstdc++ headers
receive a generated cache-local compilation database whose command names their
owning GCC driver. clangd then uses QueryDriver for the GCC target and include
search paths; clangd's parser itself necessarily remains Clang-based.
For GCC-owned standalone headers and GCC entries in an argument-array
`compile_commands.json`, the detected `-dumpfullversion` is supplied to clangd
as `-fgnuc-version=<version>` through its in-memory compilation-command
extension; `__clang__` is undefined in that same confirmed-GCC branch so
conditional compilation does not simultaneously select Clang behavior.
Generated project databases are never modified.
For G++ commands without an explicit `-std=`, the default dialect is queried
from that driver's `__cplusplus` and `__STRICT_ANSI__` predefined macros and
translated for clangd (for example GCC 16 currently yields `gnu++20`). Explicit
project standards remain untouched; GCC C, Clang, and MSVC are unaffected.
On Windows, the same standalone mechanism dynamically discovers MinGW include
roots through GCC/G++, or builds an MSVC-style command from the `cl.exe`
toolset selected by `vswhere` plus the newest installed Windows SDK (UCRT,
shared, UM, WinRT, and C++/WinRT roots). MSVC and MinGW locations and versions
are not hard-coded; MSVC remains preferred when both toolchains are installed.
The leader key remains the unified smart-navigation entry for links and
symbols. Configure link rendering under `lsp.document_links` in
`lua/config/settings.lua`.

### Python environments

uv.nvim is limited to uv project/package commands. Interpreter discovery and
activation are owned by venv-selector.nvim so that uv, standard venv, Poetry,
Pipenv, Conda, Pyenv, Hatch, and other common layouts share one workflow.

| Key | Action |
| --- | --- |
| `<leader>pe` | Discover and select an interpreter for the current workspace |
| `<leader>pE` | Show the selected interpreter, environment, and attached Python LSPs |
| `<leader>pr` | Run the current file through uv |
| `<leader>ps` | Run the visual selection through uv |
| `<leader>pf` | Select and run a Python function through uv |
| `<leader>pa` / `<leader>pd` | Add/remove a project dependency |
| `<leader>pc` | Synchronize the uv project environment |

The first selection is cached per workspace and restored automatically on
later visits. Selecting another interpreter updates Neovim's environment,
restarts Python-specific LSP clients such as ty and Ruff with the new
environment, updates nvim-dap-python, and affects terminals opened afterwards.
Configure cache restoration, notifications, and the picker backend under
`python.environment` in `lua/config/settings.lua`. Existing terminals and
already-running external shells are intentionally not modified.

The complete selected environment is also added to the read-only protection
set for the current Neovim session. This protects installed packages on both
Unix (`lib/python*/site-packages`) and Windows (`Lib/site-packages`) without
locking editable source trees outside the environment.

### Workspace panels

| Key | Panel/action |
| --- | --- |
| `<leader>e` | Toggle NvimTree, replacing another active sidebar panel |
| `<leader>t` | Toggle the terminal; press `Esc Esc` to leave terminal mode. Prefix a count (`2<leader>t`) for a separate terminal; `:TermSelect` lists open terminals |
| `<leader>wh/j/k/l` | Move focus between windows |
| `<leader>wH/L` | Increase/decrease the current window width |
| `<leader>wJ/K` | Increase/decrease the current window height |
| `<leader>w=` | Equalize all window sizes |
| `<leader>du` | Toggle the DAP UI |
| `<leader>ac` | Toggle the CodeCompanion (Copilot) chat sidebar |
| `<leader>ah` | Browse and restore saved chat history |
| `<leader>gg` | Open the Neogit status split |
| `<leader>gh` / `<leader>gH` | Current-file/repository history in Diffview |
| `<leader>gq` | Close the Diffview history/diff view |
| `<leader>rr` | Fuzzy-search and run a project task (`Ctrl-A` adds temporary Make arguments; cancel returns to the picker) |
| `<leader>rt` | Toggle the bottom task list |
| `<leader>rl` / `<leader>ro` | Restart/open output for the latest task |
| `<leader>rs` / `<leader>ra` | Stop the latest running task/select a task action |

NvimTree, grug-far, and the DAP UI share one managed sidebar slot. Repeating a
panel's key closes it; pressing another panel key replaces the current occupant
without changing the editor window — `<leader>e` or `<leader>F` therefore also
closes the debug layout. Starting a debug session makes the DAP UI take over
the slot. Additional sidebar plugins can register the same
`find_window`, `open`, and `close` provider interface in
`lua/config/sidebar.lua`.

Inside the CodeCompanion chat buffer, every chat action uses LocalLeader
(`\`, buffer-local, so normal buffers are unaffected): `\r` regenerate,
`\a` change adapter/model, `\x` clear, `\y` yank code, `\b` code block,
`\f` fold code, `\p` toggle system prompt, `\S` Copilot stats, `\R` clear
rules, `\m` follow-up while streaming, `\i` debug info, `\ba`/`\bd` sync
pinned buffers (all/diff), `\tx` reset tool approvals, `\ty` toggle
auto-approval (YOLO) mode, `\G` generate a summary of the chat, and `\B`
browse saved summaries. When the LLM proposes inline changes in a normal
buffer, review them with `\2` accept, `\3` reject, `\1` always accept,
`\4` cancel, and `\v` view the diff. Navigation and control keys keep their plugin defaults:
`<C-s>` send, `q` stop, `?` options, `]]`/`[[` next/previous message,
`}`/`{` next/previous chat or diff hunk, `gR` open the file under the
cursor. Save the current chat manually with `\s`; auto-save is on,
so this is rarely needed.

Overseer discovers task definitions from supported project frameworks such as
Make, Cargo, npm, Just, and `.vscode/tasks.json`. Use `:OverseerShell <command>`
for an ad-hoc command. For reproducible cross-device builds, keep the build,
run, and test commands in a project task file instead of hard-coding them in
this Neovim configuration.

Out-of-source Make builds are also discovered from the project-root directories
listed in `settings.tasks.build_directories`. This covers workflows such as
running `../configure` inside `build/`, where the source root has no Makefile.
When `settings.tasks.make.use_bear` is enabled (the default), Overseer wraps
Make build targets with Bear so compiler invocations update the build
directory's `compile_commands.json`; an existing database is appended to, and
clean targets bypass Bear. Bear is a system build tool rather than a Mason
package. Install it through the host package manager; unavailable Bear falls
back to ordinary Make with a warning and the official installation URL.

JSON and JSONC files use jsonls with SchemaStore completion and validation.
For `.vscode/tasks.json`, `<leader>rc` opens the existing file or creates a
build, run, CMake build-and-run, or empty template. jsonls and SchemaStore
supply VS Code task completion, documentation, and validation; `<leader>rr`
then discovers and runs the saved tasks.

The VS Code tasks Schema is pinned locally at `schemas/vscode-tasks.json`, so
task completion works offline and remains identical across devices. Its
authoritative source is `https://www.schemastore.org/task.json`; update it only
when desired with `:VSCodeTasksSchemaUpdate`, restart Neovim, and review the
resulting Git diff. SchemaStore.nvim continues to provide schemas for other
JSON files.

### Global settings and protected files

Edit `lua/config/settings.lua` to change user-facing global behavior. Its
`editor` and `files` sections control indentation, text width, line numbers,
clipboard integration, CursorHold timing, swap files, and backups.
`editing.completion` controls documentation, signature help, ghost text, and
buffer-word noise; `diagnostics` controls live diagnostic presentation;
`formatting` controls format-on-save and its timeout; `ui` controls the
WhichKey delay; `python.environment` controls interpreter restoration and its
picker; `plugins.check_for_updates` controls Lazy's background update check;
`ui.codecompanion.chat_width` controls the right-side AI chat width; and
`lsp.workspace_file_watching` controls Neovim-side recursive workspace
watching (disabled by default to protect large projects), while
`lsp.documentation` controls the automatic symbol context window, including
documentation, line diagnostics, and Quick Fix detection. Plugin startup
options take effect after restarting Neovim;
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
`protect_python_environments` controls protection for environments selected by
venv-selector.nvim. Bufferline prefixes locked file buffers with ``.

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
prerequisite: a C/C++ compiler, `dotnet`, `go`, `rustc` + `cargo`, a JDK,
or Node.js with npm. JavaScript, TypeScript, React, and Vue share the
`javascript` profile. React JSX/TSX uses vtsls, ESLint, Treesitter, Prettier,
and the JavaScript debug adapter. Vue 3 additionally uses vue-language-server;
its HTML/CSS sections are handled by `vue_ls`, while its JavaScript/TypeScript
sections are delegated to vtsls through the matching bundled Vue plugin.
Tailwind projects additionally use tailwindcss-language-server for class-name
completion and project-aware color metadata; Blink renders that metadata as a
single colored completion icon.
Install the toolchain, restart Neovim, and the integrations become active.
Neovim displays one startup warning per session for enabled languages whose
toolchains are missing. The warning includes the official installation URL;
`:LanguageInstall cpp|csharp|go|rust|java|javascript` opens the same page on
demand.

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
