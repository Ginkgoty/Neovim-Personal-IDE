local M = {}

local function highlight(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function channels(color)
  return {
    math.floor(color / 0x10000) % 0x100,
    math.floor(color / 0x100) % 0x100,
    color % 0x100,
  }
end

local function luminance(color)
  local rgb = channels(color)
  local function linear(value)
    value = value / 255
    return value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
  end

  return 0.2126 * linear(rgb[1]) + 0.7152 * linear(rgb[2]) + 0.0722 * linear(rgb[3])
end

local function contrast(first, second)
  local lighter = math.max(luminance(first), luminance(second))
  local darker = math.min(luminance(first), luminance(second))
  return (lighter + 0.05) / (darker + 0.05)
end

local function mix(first, second, amount)
  local a, b = channels(first), channels(second)
  local result = {}
  for index = 1, 3 do
    result[index] = math.floor(a[index] + (b[index] - a[index]) * amount + 0.5)
  end
  return result[1] * 0x10000 + result[2] * 0x100 + result[3]
end

local function readable_foreground(preferred, target, background, minimum)
  if contrast(preferred, background) >= minimum then
    return preferred
  end

  -- Move only as far toward Normal.fg as necessary. This preserves the
  -- colorscheme's intended subtlety while meeting the configured contrast.
  for step = 1, 100 do
    local candidate = mix(preferred, target, step / 100)
    if contrast(candidate, background) >= minimum then
      return candidate
    end
  end
  return target
end

local function distinct_background(preferred, normal, surface_minimum)
  if preferred and contrast(preferred, normal) >= surface_minimum then
    return preferred
  end

  -- Reuse quiet surfaces from the colorscheme before considering stronger
  -- selection colors. This keeps hints distinct without inventing a palette.
  for _, name in ipairs { "CursorLine", "Pmenu", "NormalFloat", "Visual", "StatusLine" } do
    local candidate = highlight(name).bg
    if candidate and contrast(candidate, normal) >= surface_minimum then
      return candidate
    end
  end
  return preferred or normal
end

local function refresh_inlay_hints()
  local options = require("config.settings").ui or {}
  local minimum = options.inlay_hint_min_contrast or 4.5
  local background_minimum = options.inlay_hint_background_contrast or 1.05
  local normal = highlight "Normal"
  local inlay = highlight "LspInlayHint"
  local comment = highlight "Comment"
  local background = normal.bg and normal.fg and distinct_background(inlay.bg, normal.bg, background_minimum)
    or inlay.bg
  local preferred = inlay.fg or comment.fg or normal.fg

  if not (background and preferred and normal.fg) then
    return
  end

  -- Choose whichever achromatic endpoint has the stronger contrast with the
  -- selected theme surface. This is an accessibility calculation, not a
  -- colorscheme-specific palette value.
  local accessible_endpoint = contrast(0, background) >= contrast(0xffffff, background) and 0 or 0xffffff
  inlay.fg = readable_foreground(preferred, accessible_endpoint, background, minimum)
  inlay.bg = background
  inlay.nocombine = true
  inlay.default = nil
  vim.api.nvim_set_hl(0, "LspInlayHint", inlay)
end

function M.setup()
  refresh_inlay_hints()
  require("config.macro_links").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ReadableLspHighlights", { clear = true }),
    desc = "Keep LSP inlay hints readable with the active colorscheme",
    callback = function()
      vim.schedule(function()
        refresh_inlay_hints()
        vim.api.nvim_set_hl(0, "LspMacroLink", { underline = true })
      end)
    end,
  })
end

return M
