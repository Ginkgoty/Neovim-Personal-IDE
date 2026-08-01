return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function highlight(name)
        return vim.api.nvim_get_hl(0, { name = name, link = false })
      end

      local function channel(value, shift)
        return math.floor(value / (2 ^ shift)) % 256 / 255
      end

      local function luminance(color)
        local function linear(value)
          return value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
        end

        return 0.2126 * linear(channel(color, 16))
          + 0.7152 * linear(channel(color, 8))
          + 0.0722 * linear(channel(color, 0))
      end

      local function contrast(first, second)
        local lighter = math.max(luminance(first), luminance(second))
        local darker = math.min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
      end

      local function as_hex(color)
        return color and string.format("#%06x", color) or nil
      end

      local function theme_from_highlights()
        local normal = highlight("Normal")
        local statusline = highlight("StatusLine")
        local foreground = normal.fg or statusline.fg
        local normal_background = normal.bg or statusline.bg
        local background = statusline.bg or normal_background

        -- Prefer quiet surfaces already defined by the active colorscheme.
        -- A candidate must remain readable and visibly distinct from Normal.
        for _, name in ipairs({ "CursorLine", "Visual", "Pmenu", "NormalFloat", "StatusLine" }) do
          local candidate = highlight(name).bg
          if candidate
            and foreground
            and normal_background
            and contrast(foreground, candidate) >= 4.5
            and contrast(normal_background, candidate) >= 1.05
          then
            background = candidate
            break
          end
        end

        local inactive_foreground = foreground
        for _, name in ipairs({ "Comment", "LineNr", "StatusLineNC" }) do
          local candidate = highlight(name).fg
          if candidate and background and contrast(candidate, background) >= 3 then
            inactive_foreground = candidate
            break
          end
        end

        local surface = { fg = as_hex(foreground), bg = as_hex(background) }
        local inactive_surface = { fg = as_hex(inactive_foreground), bg = as_hex(background) }
        return {
          normal = { a = surface, b = surface, c = surface },
          insert = { a = surface, b = surface, c = surface },
          visual = { a = surface, b = surface, c = surface },
          replace = { a = surface, b = surface, c = surface },
          command = { a = surface, b = surface, c = surface },
          terminal = { a = surface, b = surface, c = surface },
          inactive = { a = inactive_surface, b = inactive_surface, c = inactive_surface },
        }
      end

      local function setup()
        require("lualine").setup({
        options = {
          theme = theme_from_highlights(),
          globalstatus = true,
          section_separators = "",
          component_separators = "",
          always_divide_middle = true,
        },
        sections = {
          -- Keep everything on the neutral C/X backgrounds. Avoiding the
          -- coloured A/B/Y/Z blocks gives the statusline a quiet, flat look.
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            {
              "mode",
              fmt = function(mode)
                return mode:upper()
              end,
              padding = { left = 1, right = 2 },
            },
            {
              "branch",
              icon = "",
              padding = { left = 0, right = 2 },
            },
            {
              "diff",
              symbols = { added = "+", modified = "~", removed = "-" },
              padding = { left = 0, right = 2 },
            },
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              symbols = { error = "E ", warn = "W ", info = "I ", hint = "H " },
              padding = { left = 0, right = 2 },
            },
            {
              "filename",
              path = 1,
              symbols = {
                modified = " ●",
                readonly = " ",
                unnamed = "[No Name]",
                newfile = "[New]",
              },
            },
          },
          lualine_x = {
            { "filetype", icon_only = false, padding = { left = 1, right = 2 } },
            {
              function()
                local encoding = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
                local line_ending = ({ unix = "LF", dos = "CRLF", mac = "CR" })[vim.bo.fileformat]
                  or vim.bo.fileformat:upper()
                return ("%s · %s"):format(encoding:upper(), line_ending)
              end,
              padding = { left = 0, right = 2 },
            },
            { "progress", padding = { left = 0, right = 2 } },
            { "location", padding = { left = 0, right = 1 } },
            {
              function()
                return os.date("%H:%M")
              end,
              icon = "",
              padding = { left = 1, right = 1 },
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        })
      end

      setup()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("LualineThemeSync", { clear = true }),
        desc = "Rebuild Lualine colors from the active colorscheme",
        callback = function()
          vim.schedule(function()
            if package.loaded.lualine then
              setup()
            end
          end)
        end,
      })
    end,
  },
}
