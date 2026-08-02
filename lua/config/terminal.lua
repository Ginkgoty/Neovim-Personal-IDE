-- Integrated terminal shell resolution.
-- Priority: the explicit `terminal.shell` setting wins; otherwise Windows
-- auto-detects PowerShell 7 (pwsh) > Windows PowerShell 5.1 > cmd. Other
-- platforms keep the toggleterm default ($SHELL via vim.o.shell).
--
-- toggleterm passes the shell as a plain string to termopen(), which runs it
-- through &shell (cmd.exe /c on Windows). A full path containing spaces such
-- as "C:\Program Files\PowerShell\7\pwsh.EXE" would be split at the space and
-- fail to start, so bare command names are returned when they resolve on
-- PATH, and full paths are quoted.
local platform = require("config.platform")

local M = {}

local function executable(name)
  return vim.fn.executable(name) == 1
end

-- Quote a resolved path when cmd.exe would split it at a space.
local function quote_if_needed(path)
  if path:find(" ") and not path:match('^".*"$') then
    return '"' .. path .. '"'
  end
  return path
end

local function detect()
  if not platform.is_windows then
    return vim.o.shell
  end
  for _, name in ipairs({ "pwsh", "powershell", "cmd" }) do
    if executable(name) then
      return name
    end
  end
  -- Never return nil to toggleterm: it inspects the configured shell before
  -- spawning the terminal process. &shell is Neovim's last-resort fallback.
  return vim.o.shell
end

function M.shell()
  local settings = require("config.settings").terminal or {}
  local configured = settings.shell
  if configured and configured ~= "" then
    if executable(configured) then
      return quote_if_needed(vim.fn.exepath(configured))
    end
    vim.notify(
      ("Configured terminal.shell %q is not executable; falling back to auto-detection"):format(configured),
      vim.log.levels.WARN,
      { title = "Settings" }
    )
  end
  return detect()
end

return M
