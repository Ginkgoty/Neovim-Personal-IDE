-- Neovim already recognizes the usual C/C++ suffixes (.c, .h, .cc, .cpp,
-- .cxx, .hpp, .hxx, C++ module suffixes, and CUDA). Add only standard C++
-- suffixes that its built-in table currently leaves unset or misclassifies.
vim.filetype.add({
  extension = {
    cp = "cpp",
    ["h++"] = "cpp",
    hp = "cpp",
    ii = "cpp",
    tpp = "cpp",
    txx = "cpp",
    gotmpl = "gotmpl",
  },
  pattern = {
    [".*%.c%.doxygen"] = "c.doxygen",
    [".*%.cpp%.doxygen"] = "cpp.doxygen",
    [".*/%.vscode/tasks%.json"] = "jsonc",
  },
})
