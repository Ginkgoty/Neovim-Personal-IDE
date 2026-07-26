# Neovim Personal IDE

A modern Neovim configuration for C/C++, Python, Go, Rust, Java, SQL, and Lua.

## Requirements

- Neovim 0.12+
- Git, ripgrep, fd, and a C compiler
- A Nerd Font for file icons

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Language servers, debug adapters, and command-line tools are managed by Mason where possible.

## Install

Back up an existing configuration, then clone this repository:

```sh
git clone https://github.com/Ginkgoty/Neovim-Personal-IDE.git ~/.config/nvim
nvim
```

On first launch, lazy.nvim installs plugins and Mason installs configured development tools.

## Main features

- LSP and completion for C/C++, Python, Go, Rust, Java, SQL, and Lua
- Ruff and ty for modern Python projects
- DAP debugging with CodeLLDB, GDB, debugpy, Delve, and Java Debug
- Formatting through Conform: Ruff, clang-format, goimports/gofmt, rustfmt, and StyLua
- Telescope search, nvim-tree, gitsigns, which-key, and ToggleTerm
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
```

Press `<Space>` and pause briefly to discover configured shortcuts with which-key.

## Updating

Run `:Lazy sync`, update installed tools from `:Mason`, then run `:TSUpdate` and `:checkhealth`.
