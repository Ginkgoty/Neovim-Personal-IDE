local M = {}
local color_cache = {}
local image_cache_directory
local image_cache_bytes = 0
local hover_images = {}
local hover_buffer_links = {}
local hover_link_namespace = vim.api.nvim_create_namespace "symbol_documentation_links"

local defaults = {
  auto_show = true,
  delay_ms = 3000,
  border = "rounded",
  max_width = 0.8,
  max_height = 0.5,
  navigation_hints = true,
  include_diagnostics = true,
  detect_quick_fixes = true,
  language = "auto",
  collapse_i18n_links = true,
  color_preview = true,
  render_images = true,
  render_remote_images = false,
  max_data_image_bytes = 2 * 1024 * 1024,
  max_data_image_cache_bytes = 16 * 1024 * 1024,
  stale_image_cache_hours = 24,
}

local language_names = {
  en = "English",
  ["zh-cn"] = "Simplified Chinese",
  ["zh-hk"] = "Traditional Chinese",
  ["zh-tw"] = "Traditional Chinese",
  ja = "Japanese",
  ua = "Ukrainian",
  uk = "Ukrainian",
  fr = "French",
  ko = "Korean",
  pt = "Portuguese",
  bn = "Bengali",
  it = "Italian",
  cs = "Czech",
  ru = "Russian",
  fa = "Persian",
  de = "German",
  es = "Spanish",
}

local function settings()
  local lsp = require("config.settings").lsp or {}
  return vim.tbl_deep_extend("force", defaults, lsp.documentation or {})
end

local function has_floating_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return true
    end
  end
  return false
end

local function line_diagnostics(bufnr, lnum)
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })
  table.sort(diagnostics, function(left, right)
    if left.severity ~= right.severity then
      return (left.severity or vim.diagnostic.severity.ERROR)
        < (right.severity or vim.diagnostic.severity.ERROR)
    end
    return (left.col or 0) < (right.col or 0)
  end)
  return diagnostics
end

local function diagnostic_lines(diagnostics)
  local lines = {}
  for _, diagnostic in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diagnostic.severity] or "INFO"
    severity = severity:sub(1, 1) .. severity:sub(2):lower()
    local origin = diagnostic.source or "LSP"
    if diagnostic.code ~= nil then
      origin = origin .. ":" .. tostring(diagnostic.code)
    end
    origin = origin:gsub("`", "'")

    local message = vim.split(diagnostic.message or "", "\n", { plain = true })
    lines[#lines + 1] = ("- **%s** `%s` — %s"):format(severity, origin, message[1] or "")
    for index = 2, #message do
      lines[#lines + 1] = "  " .. message[index]
    end
  end
  return lines
end

local function position_before_or_equal(left, right)
  return left.line < right.line or (left.line == right.line and left.character <= right.character)
end

local function range_contains(range, position)
  return range
    and position_before_or_equal(range.start, position)
    and not position_before_or_equal(range["end"], position)
end

local function request_document_colors(bufnr, clients, callback)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  color_cache[bufnr] = color_cache[bufnr] or {}
  local results, pending = {}, 0
  for _, client in ipairs(clients) do
    local cached = color_cache[bufnr][client.id]
    if cached and cached.changedtick == changedtick then
      results[client.id] = cached.colors
    else
      pending = pending + 1
      client:request("textDocument/documentColor", {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
      }, function(err, colors)
        if not err and vim.api.nvim_buf_is_valid(bufnr) then
          color_cache[bufnr][client.id] = {
            changedtick = changedtick,
            colors = colors or {},
          }
          results[client.id] = colors or {}
        end
        pending = pending - 1
        if pending == 0 then
          callback(results)
        end
      end, bufnr)
    end
  end
  if pending == 0 then
    callback(results)
  end
end

local function color_under_cursor(results, clients, source_win)
  for _, client in ipairs(clients) do
    local position = vim.lsp.util.make_position_params(source_win, client.offset_encoding).position
    for _, information in ipairs(results[client.id] or {}) do
      if range_contains(information.range, position) then
        return information.color
      end
    end
  end
end

local function color_preview(color)
  if not color then
    return
  end
  local function channel(value)
    return math.max(0, math.min(255, math.floor((value or 0) * 255 + 0.5)))
  end
  local red, green, blue, alpha = channel(color.red), channel(color.green), channel(color.blue), channel(color.alpha)
  local hex = ("#%02X%02X%02X"):format(red, green, blue)
  local alpha_value = math.max(0, math.min(1, color.alpha == nil and 1 or color.alpha))
  if alpha_value < 1 then
    hex = hex .. ("%02X"):format(alpha)
  end
  local description = alpha_value < 1
      and ("%s · rgba(%d, %d, %d, %.2f)"):format(hex, red, green, blue, alpha_value)
    or ("%s · rgb(%d, %d, %d)"):format(hex, red, green, blue)
  return {
    line = "Color:  " .. description:gsub(" · ", "  ■  ", 1),
    hex = ("#%02X%02X%02X"):format(red, green, blue),
  }
end

local function highlight_color_preview(bufnr, preview)
  if not preview then
    return
  end
  local group = "LspHoverColor" .. preview.hex:sub(2)
  vim.api.nvim_set_hl(0, group, {
    fg = preview.hex,
    nocombine = true,
  })
  local square_col = assert(preview.line:find("■", 1, true)) - 1
  local namespace = vim.api.nvim_create_namespace "symbol_documentation_colors"
  -- Use the same quiet, theme-derived surface as inferred types for the
  -- descriptive text. Only the compact square carries the literal color.
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    end_col = square_col,
    hl_group = "LspInlayHint",
    priority = 100,
  })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, square_col, {
    end_col = square_col + #"■",
    hl_group = group,
    priority = 200,
  })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, square_col + #"■", {
    end_col = #preview.line,
    hl_group = "LspInlayHint",
    priority = 100,
  })
end

local function normalize_language(language)
  language = type(language) == "string" and language:lower() or ""
  language = language:gsub("%..*$", ""):gsub("@.*$", ""):gsub("_", "-")
  return language
end

local function preferred_language(opts)
  local configured = normalize_language(opts.language)
  if configured ~= "" and configured ~= "auto" then
    return configured
  end
  for _, value in ipairs({ vim.env.LC_ALL, vim.env.LC_MESSAGES, vim.env.LANG }) do
    local language = normalize_language(value)
    if language ~= "" and language ~= "c" and language ~= "posix" then
      return language
    end
  end
  return "en"
end

local function collapse_i18n_navigation(line, opts)
  if opts.collapse_i18n_links == false then
    return line
  end

  local links = {}
  for label, url in line:gmatch "%[([^%]]+)%]%(([^%)]+)%)" do
    local language = normalize_language(vim.trim(label))
    if not language_names[language] then
      return line
    end
    links[#links + 1] = { language = language, url = url }
  end
  local remainder = line:gsub("%[[^%]]+%]%([^%)]+%)", ""):gsub("[%s|]", "")
  if #links < 3 or remainder ~= "" then
    return line
  end

  local preferred = preferred_language(opts)
  local base = preferred:match "^[^-]+"
  local selected
  for _, link in ipairs(links) do
    if link.language == preferred then
      selected = link
      break
    end
    if not selected and link.language == base then
      selected = link
    end
  end
  if not selected then
    for _, link in ipairs(links) do
      if link.language == "en" then
        selected = link
        break
      end
    end
  end
  selected = selected or links[1]
  return ("Documentation language: [%s](%s)"):format(language_names[selected.language], selected.url)
end

local image_extensions = {
  ["image/svg+xml"] = "svg",
  ["image/png"] = "png",
  ["image/jpeg"] = "jpg",
  ["image/gif"] = "gif",
  ["image/webp"] = "webp",
}

local function hover_image_cache(opts)
  if image_cache_directory then
    return image_cache_directory
  end
  local root = vim.fs.joinpath(vim.fn.stdpath "cache", "lsp-hover-images")
  vim.fn.mkdir(root, "p")

  -- A crash cannot run VimLeavePre. Remove only directories matching our
  -- pid-timestamp naming scheme, and only after the configured grace period.
  local stale_after = math.max(1, tonumber(opts.stale_image_cache_hours) or defaults.stale_image_cache_hours) * 3600
  local handle = vim.uv.fs_scandir(root)
  if handle then
    while true do
      local name, kind = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if kind == "directory" and name:match "^%d+%-%d+$" then
        local path = vim.fs.joinpath(root, name)
        local stat = vim.uv.fs_stat(path)
        local modified = stat and stat.mtime and stat.mtime.sec or os.time()
        if os.time() - modified >= stale_after then
          pcall(vim.fs.rm, path, { recursive = true, force = true })
        end
      end
    end
  end

  image_cache_directory = vim.fs.joinpath(root, ("%d-%d"):format(vim.fn.getpid(), os.time()))
  vim.fn.mkdir(image_cache_directory, "p")
  local group = vim.api.nvim_create_augroup("symbol_documentation_image_cache", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      if image_cache_directory then
        pcall(vim.fs.rm, image_cache_directory, { recursive = true, force = true })
      end
    end,
    desc = "Remove session-local LSP hover images",
  })
  return image_cache_directory
end

local function materialize_data_images(line, opts)
  if opts.render_images == false or not vim.base64 then
    return line
  end
  return line:gsub("(!%[[^%]]*%])%((data:(image/[%w%+%.%-]+);base64,([A-Za-z0-9+/=]+))%)", function(label, uri, mime, data)
    local extension = image_extensions[mime:lower()]
    local estimated_size = math.floor(#data * 3 / 4)
    local max_size = tonumber(opts.max_data_image_bytes) or defaults.max_data_image_bytes
    if not extension or estimated_size > max_size then
      return label .. "(" .. uri .. ")"
    end
    local ok, decoded = pcall(vim.base64.decode, data)
    if not ok or type(decoded) ~= "string" or #decoded > max_size then
      return label .. "(" .. uri .. ")"
    end

    local total_limit = tonumber(opts.max_data_image_cache_bytes) or defaults.max_data_image_cache_bytes
    if image_cache_bytes + #decoded > total_limit then
      return label .. "(" .. uri .. ")"
    end
    local directory = hover_image_cache(opts)
    local digest = vim.fn.sha256(uri)
    local path = vim.fs.joinpath(directory, digest .. "." .. extension)
    if vim.fn.filereadable(path) ~= 1 then
      local fd = vim.uv.fs_open(path, "w", 384)
      if not fd then
        return label .. "(" .. uri .. ")"
      end
      local written = vim.uv.fs_write(fd, decoded, 0)
      vim.uv.fs_close(fd)
      if written ~= #decoded then
        pcall(vim.uv.fs_unlink, path)
        return label .. "(" .. uri .. ")"
      end
      image_cache_bytes = image_cache_bytes + #decoded
    end
    local source = "hover-image://" .. digest:sub(1, 16) .. "." .. extension
    hover_images[source] = path
    return label .. "(" .. source .. ")"
  end)
end

local function demote_remote_images(line, opts)
  if opts.render_remote_images ~= false then
    return line
  end
  return line:gsub("!%[([^%]]*)%]%((https?://[^%s%)]+)%)", function(alt, url)
    alt = vim.trim(alt)
    return ("Remote image: [%s](%s)"):format(alt ~= "" and alt or "Open image", url)
  end)
end

function M.resolve_hover_image(source)
  return hover_images[source]
end

function M.sanitize_markdown(lines, opts)
  opts = opts or settings()
  local sanitized = {}
  local in_fence = false
  for _, line in ipairs(lines) do
    local fence = line:match "^%s*```" or line:match "^%s*~~~"
    if not in_fence and not fence then
      line = collapse_i18n_navigation(line, opts)
      line = materialize_data_images(line, opts)
      line = demote_remote_images(line, opts)
    end
    local image, caption = line:match "^(%s*!%[[^%]]*%]%([^%)]+%))%s+_([^_]+)_%s*$"
    if not in_fence and image and caption then
      -- Keep small badges and their status on one visual row. The image source
      -- is concealed in Hover windows, so only its intrinsic cell width
      -- participates in the rendered layout. Drop emphasis because terminals
      -- commonly degrade italic text into a distracting underline.
      sanitized[#sanitized + 1] = image .. " " .. caption
    else
      sanitized[#sanitized + 1] = line
    end
    if fence then
      in_fence = not in_fence
    end
  end
  return sanitized
end

local function matching_delimiter(line, start, opening, closing)
  local depth = 0
  local escaped = false
  for index = start, #line do
    local character = line:sub(index, index)
    if escaped then
      escaped = false
    elseif character == "\\" then
      escaped = true
    elseif character == opening then
      depth = depth + 1
    elseif character == closing then
      depth = depth - 1
      if depth == 0 then
        return index
      end
    end
  end
end

local function markdown_links(line)
  local links = {}
  local offset = 1
  while offset <= #line do
    local first, bracket = line:find("!?%[", offset)
    if not first then
      break
    end
    local label_end = matching_delimiter(line, bracket, "[", "]")
    if not label_end or line:sub(label_end + 1, label_end + 1) ~= "(" then
      offset = bracket + 1
    else
      local destination_end = matching_delimiter(line, label_end + 1, "(", ")")
      if not destination_end then
        offset = bracket + 1
      else
        local destination = vim.trim(line:sub(label_end + 2, destination_end - 1))
        local target = destination:match "^<([^>]+)>" or destination:match "^(%S+)" or ""
        links[#links + 1] = {
          first = first,
          last = destination_end,
          label = line:sub(bracket + 1, label_end - 1),
          target = target,
          image = line:sub(first, first) == "!",
        }
        offset = destination_end + 1
      end
    end
  end
  return links
end

local function collapse_display_blank_lines(lines)
  local result = {}
  for _, line in ipairs(lines) do
    if line ~= "" or (#result > 0 and result[#result] ~= "") then
      result[#result + 1] = line
    end
  end
  while result[1] == "" do
    table.remove(result, 1)
  end
  while result[#result] == "" do
    result[#result] = nil
  end
  return result
end

local function link_icon(target)
  if target:match "^https?://" then
    return "󰖟 "
  elseif target:match "^file://" then
    return "󰈔 "
  end
  return "󰌹 "
end

function M.render_hover_links(lines)
  local rendered = {}
  local metadata = {}
  local in_fence = false
  for row, line in ipairs(collapse_display_blank_lines(lines)) do
    local fence = line:match "^%s*```" or line:match "^%s*~~~"
    if in_fence or fence then
      rendered[row] = line
    else
      local chunks = {}
      local byte_length = 0
      local offset = 1
      local function append(value)
        chunks[#chunks + 1] = value
        byte_length = byte_length + #value
      end
      for _, link in ipairs(markdown_links(line)) do
        append(line:sub(offset, link.first - 1))
        if link.image then
          append(line:sub(link.first, link.last))
        else
          local first = byte_length
          append(link_icon(link.target))
          append(link.label)
          metadata[#metadata + 1] = {
            row = row - 1,
            first = first,
            last = byte_length,
            label = link.label,
            target = link.target,
            openable = link.target:match "^https?://" ~= nil or link.target:match "^file://" ~= nil,
          }
        end
        offset = link.last + 1
      end
      append(line:sub(offset))
      rendered[row] = table.concat(chunks)
    end
    if fence then
      in_fence = not in_fence
    end
  end
  return rendered, metadata
end

local function visible_markdown_line(line)
  local visible = {}
  local offset = 1
  for _, link in ipairs(markdown_links(line)) do
    visible[#visible + 1] = line:sub(offset, link.first - 1)
    -- A Markdown link renders its label, not its destination or syntax. For
    -- an image, alt text is a conservative fallback for intrinsic rendering.
    visible[#visible + 1] = link.label
    offset = link.last + 1
  end
  visible[#visible + 1] = line:sub(offset)
  return table.concat(visible)
end

function M.markdown_layout_lines(lines)
  local result = {}
  local in_fence = false
  for _, line in ipairs(lines) do
    local fence = line:match "^%s*```" or line:match "^%s*~~~"
    result[#result + 1] = (in_fence or fence) and line or visible_markdown_line(line)
    if fence then
      in_fence = not in_fence
    end
  end
  return result
end

local function is_loading_placeholder(lines)
  return #lines == 3
    and lines[1]:match "^```"
    and lines[2] == "(loading...) any"
    and lines[3] == "```"
end

local function append_hover(results, lines, opts)
  local seen = {}
  for _, response in pairs(results or {}) do
    if response.result and response.result.contents then
      local converted = vim.lsp.util.convert_input_to_markdown_lines(response.result.contents)
      converted = vim.split(table.concat(converted, "\n"), "\n", {
        plain = true,
        trimempty = true,
      })
      converted = M.sanitize_markdown(converted, opts)
      if is_loading_placeholder(converted) then
        converted = {}
      end
      local key = table.concat(converted, "\n")
      if key ~= "" and not seen[key] then
        if #lines > 0 then
          lines[#lines + 1] = "---"
        end
        vim.list_extend(lines, converted)
        seen[key] = true
      end
    end
  end
end

local function title_for(has_documentation, has_diagnostics, has_quick_fix, opts)
  if opts.navigation_hints ~= false then
    local hints = { "gd Definition", "gD Declaration", "gri Implementation" }
    if has_quick_fix then
      hints[#hints + 1] = "<leader>xq Quick Fix"
    end
    return " " .. table.concat(hints, " · ") .. " "
  end

  local content = has_documentation and has_diagnostics and "Documentation + Diagnostics"
    or has_documentation and "Documentation"
    or "Diagnostics"
  if has_quick_fix then
    content = content .. " · <leader>xq Quick Fix"
  end
  return " " .. content .. " "
end

local function configure_hover_window(float_buf, float_win, source_buf, source_win)
  if vim.b[float_buf].symbol_documentation_mapped then
    return
  end
  vim.b[float_buf].symbol_documentation_mapped = true

  local function metadata_link_under_cursor()
    if not vim.api.nvim_win_is_valid(float_win) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(float_win)
    for _, link in ipairs(hover_buffer_links[float_buf] or {}) do
      if link.openable
          and cursor[1] - 1 == link.row
          and cursor[2] >= link.first
          and cursor[2] < link.last then
        return link
      end
    end
  end

  local function update_link_footer()
    if not vim.api.nvim_win_is_valid(float_win) then
      return
    end
    local links = vim.tbl_filter(function(link)
      return link.openable
    end, hover_buffer_links[float_buf] or {})
    if #links == 0 then
      return
    end
    local link = metadata_link_under_cursor()
    local width = vim.api.nvim_win_get_width(float_win)
    if not link then
      vim.api.nvim_win_set_config(float_win, { footer = "" })
      return
    end
    local suffix = " · <CR> Open "
    local room = math.max(0, width - vim.fn.strdisplaywidth(suffix) - 2)
    local target = link.target
    if vim.fn.strdisplaywidth(target) > room then
      target = room > 1 and (vim.fn.strcharpart(target, 0, room - 1) .. "…") or ""
    end
    vim.api.nvim_win_set_config(float_win, {
      footer = " " .. target .. suffix,
      footer_pos = "center",
    })
  end

  local function navigate(action)
    return function()
      if not vim.api.nvim_buf_is_valid(source_buf) then
        vim.notify("The source buffer is no longer available", vim.log.levels.WARN)
        return
      end

      if not vim.api.nvim_win_is_valid(source_win)
          or vim.api.nvim_win_get_buf(source_win) ~= source_buf then
        source_win = vim.fn.win_findbuf(source_buf)[1]
      end
      if not source_win or not vim.api.nvim_win_is_valid(source_win) then
        vim.notify("The source window is no longer available", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(source_win)
      if vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
      end
      action()
    end
  end

  local function link_under_cursor()
    local metadata = metadata_link_under_cursor()
    if metadata then
      return metadata.target
    end
    local cursor = vim.api.nvim_win_get_cursor(float_win)
    local line = vim.api.nvim_buf_get_lines(float_buf, cursor[1] - 1, cursor[1], false)[1] or ""
    local byte = cursor[2] + 1
    for _, link in ipairs(markdown_links(line)) do
      if byte >= link.first and byte <= link.last
          and (link.target:match "^https?://" or link.target:match "^file://") then
        return link.target
      end
    end
  end

  local function open_link()
    local url = link_under_cursor()
    if not url then
      vim.notify("No HTTP(S) or file link under the cursor", vim.log.levels.INFO)
      return
    end
    if url:match "^file://" then
      local ok, path = pcall(vim.uri_to_fname, url)
      local stat = ok and path and vim.uv.fs_stat(path) or nil
      if not stat then
        vim.notify("Linked file does not exist: " .. url, vim.log.levels.ERROR)
        return
      end
      navigate(function()
        vim.cmd.edit(vim.fn.fnameescape(path))
      end)()
      return
    end
    vim.ui.open(url)
  end

  vim.keymap.set("n", "gd", navigate(function()
    require("telescope.builtin").lsp_definitions()
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: go to definition",
  })
  vim.keymap.set("n", "gD", navigate(vim.lsp.buf.declaration), {
    buffer = float_buf,
    silent = true,
    desc = "Context: go to declaration",
  })
  vim.keymap.set("n", "gri", navigate(function()
    require("telescope.builtin").lsp_implementations()
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: find implementations",
  })
  vim.keymap.set("n", "<leader>xq", navigate(function()
    vim.lsp.buf.code_action({
      context = { only = { vim.lsp.protocol.CodeActionKind.QuickFix } },
    })
  end), {
    buffer = float_buf,
    silent = true,
    desc = "Context: apply a quick fix",
  })
  vim.keymap.set("n", "<CR>", open_link, {
    buffer = float_buf,
    silent = true,
    desc = "Context: open documentation link",
  })
  vim.keymap.set("n", "gx", open_link, {
    buffer = float_buf,
    silent = true,
    desc = "Context: open documentation link",
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = float_buf,
    callback = update_link_footer,
  })
  vim.schedule(update_link_footer)
end

local function setup_hover_window_mappings()
  if vim.g.symbol_documentation_window_mappings then
    return
  end
  vim.g.symbol_documentation_window_mappings = true

  local group = vim.api.nvim_create_augroup("symbol_documentation_windows", { clear = true })
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local ok, source_buf = pcall(vim.api.nvim_win_get_var, win, "textDocument/hover")
          if ok and source_buf then
            local float_buf = vim.api.nvim_win_get_buf(win)
            local source_win
            for _, candidate in ipairs(vim.fn.win_findbuf(source_buf)) do
              if vim.api.nvim_win_get_config(candidate).relative == "" then
                source_win = candidate
                break
              end
            end
            if source_win then
              configure_hover_window(float_buf, win, source_buf, source_win)
            end
          end
        end
      end)
    end,
    desc = "Add source navigation mappings to LSP context windows",
  })
end

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  local source_win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(source_win)
  local opts = settings()
  local diagnostics = opts.include_diagnostics == false and {} or line_diagnostics(bufnr, cursor[1] - 1)
  local hover_clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
  local color_clients = opts.color_preview == false and {}
    or vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentColor" })
  local action_clients = {}
  if opts.detect_quick_fixes ~= false and #diagnostics > 0 then
    action_clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })
  end

  if #hover_clients == 0 and #color_clients == 0 and #diagnostics == 0 then
    return
  end

  vim.b[bufnr].symbol_documentation_request =
    (vim.b[bufnr].symbol_documentation_request or 0) + 1
  local request = vim.b[bufnr].symbol_documentation_request
  local hover_results = {}
  local color
  local has_quick_fix = false
  local pending = (#hover_clients > 0 and 1 or 0)
    + (#color_clients > 0 and 1 or 0)
    + (#action_clients > 0 and 1 or 0)

  local function render()
    if not vim.api.nvim_buf_is_valid(bufnr)
        or vim.b[bufnr].symbol_documentation_request ~= request
        or not vim.api.nvim_win_is_valid(source_win)
        or vim.api.nvim_win_get_buf(source_win) ~= bufnr then
      return
    end
    local current = vim.api.nvim_win_get_cursor(source_win)
    if current[1] ~= cursor[1] or current[2] ~= cursor[2] then
      return
    end

    local preview = color_preview(color)
    local lines = preview and { preview.line } or {}
    append_hover(hover_results, lines, opts)
    local has_documentation = #lines > (preview and 1 or 0)
    if #diagnostics > 0 then
      if #lines > 0 then
        lines[#lines + 1] = "---"
      end
      -- This float is rendered as Markdown. Using an H3 here makes
      -- render-markdown.nvim prepend its circled level-3 heading icon, which
      -- is useful in documents but visually noisy in a compact LSP popup.
      lines[#lines + 1] = "**Diagnostics**"
      vim.list_extend(lines, diagnostic_lines(diagnostics))
    end
    if #lines == 0 then
      return
    end

    vim.api.nvim_set_current_win(source_win)
    local max_width = tonumber(opts.max_width) or defaults.max_width
    local max_height = tonumber(opts.max_height) or defaults.max_height
    local width_limit = math.max(1, math.floor(vim.o.columns * max_width))
    local height_limit = math.max(1, math.floor(vim.o.lines * max_height))
    local title = title_for(
      has_documentation,
      #diagnostics > 0,
      has_quick_fix,
      opts
    )
    local float_options = {
      border = opts.border,
      title = title,
      title_pos = "center",
      max_width = width_limit,
      max_height = height_limit,
      focus_id = "symbol_documentation",
    }
    -- Keep the original Markdown/URL in `lines` as the model, but materialize
    -- ordinary links as icon + label in the view. Neovim's conceal-aware soft
    -- wrapping can otherwise break at a hidden URL byte boundary and strand
    -- the word after a link on the next screen line.
    local display_lines, display_links = M.render_hover_links(lines)
    if type(vim.lsp.util._make_floating_popup_size) == "function" then
      local width, height = vim.lsp.util._make_floating_popup_size(display_lines, {
        border = opts.border,
        title = title,
        max_width = width_limit,
        max_height = height_limit,
        wrap_at = width_limit,
      })
      float_options.width = width
      float_options.height = height
      float_options.wrap_at = width
    end
    local float_buf, float_win = vim.lsp.util.open_floating_preview(display_lines, "markdown", float_options)
    hover_buffer_links[float_buf] = display_links
    for _, link in ipairs(display_links) do
      if link.row < vim.api.nvim_buf_line_count(float_buf) then
        vim.api.nvim_buf_set_extmark(float_buf, hover_link_namespace, link.row, link.first, {
          end_col = link.last,
          hl_group = { "RenderMarkdownLink", "Underlined" },
          priority = 9000,
        })
      end
    end
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = float_buf,
      once = true,
      callback = function()
        hover_buffer_links[float_buf] = nil
      end,
    })
    highlight_color_preview(float_buf, preview)
    if opts.render_images ~= false then
      local ok, image_doc = pcall(require, "snacks.image.doc")
      if ok then
        -- The image itself replaces its Markdown source in this compact LSP
        -- window. Keeping alt text and an absolute cache path visible would
        -- distort wrapping even though the rendered icon is only a few cells.
        vim.b[float_buf].snacks_image_conceal = true
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(float_buf) then
            image_doc.attach(float_buf)
          end
        end)
      end
    end
    if vim.api.nvim_win_is_valid(float_win) then
      -- render-markdown derives code blocks from ColorColumn. Some themes
      -- (notably PaperColor) use the same surface for ColorColumn and
      -- CursorLine, which is also a natural inlay-hint background. Keep code
      -- in this LSP float on the theme's original NormalFloat surface. The
      -- remap is window-local, so regular Markdown buffers remain unchanged.
      local code_background = table.concat({
        "RenderMarkdownCode:NormalFloat",
        "RenderMarkdownCodeBorder:NormalFloat",
        "RenderMarkdownCodeInline:NormalFloat",
      }, ",")
      local window_highlights = vim.wo[float_win].winhighlight
      vim.wo[float_win].winhighlight = window_highlights ~= ""
          and (window_highlights .. "," .. code_background)
        or code_background

      vim.api.nvim_win_set_var(float_win, "textDocument/hover", bufnr)
      configure_hover_window(float_buf, float_win, bufnr, source_win)
    end
  end

  local function complete()
    pending = pending - 1
    if pending == 0 then
      render()
    end
  end

  if #hover_clients > 0 then
    vim.lsp.buf_request_all(bufnr, "textDocument/hover", function(client)
      return vim.lsp.util.make_position_params(source_win, client.offset_encoding)
    end, function(results)
      hover_results = results or {}
      complete()
    end)
  end


  if #color_clients > 0 then
    request_document_colors(bufnr, color_clients, function(results)
      color = color_under_cursor(results, color_clients, source_win)
      complete()
    end)
  end

  if #action_clients > 0 then
    vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", function(client)
      local params = vim.lsp.util.make_range_params(source_win, client.offset_encoding)
      local lsp_diagnostics = {}
      for _, diagnostic in ipairs(diagnostics) do
        local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
        if lsp_diagnostic then
          lsp_diagnostics[#lsp_diagnostics + 1] = lsp_diagnostic
        end
      end
      params.context = {
        only = { vim.lsp.protocol.CodeActionKind.QuickFix },
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        diagnostics = lsp_diagnostics,
      }
      return params
    end, function(results)
      for _, response in pairs(results or {}) do
        for _, action in ipairs(response.result or {}) do
          if not action.disabled then
            has_quick_fix = true
            break
          end
        end
        if has_quick_fix then
          break
        end
      end
      complete()
    end)
  end

  if pending == 0 then
    render()
  end
end

function M.setup(bufnr)
  setup_hover_window_mappings()
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if vim.b[bufnr].symbol_documentation_configured then
    return
  end
  vim.b[bufnr].symbol_documentation_configured = true
  vim.b[bufnr].symbol_documentation_generation = 0

  local function cancel()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr].symbol_documentation_generation =
        (vim.b[bufnr].symbol_documentation_generation or 0) + 1
      vim.b[bufnr].symbol_documentation_request =
        (vim.b[bufnr].symbol_documentation_request or 0) + 1
    end
  end

  local function schedule()
    cancel()
    local opts = settings()
    local delay_ms = tonumber(opts.delay_ms) or defaults.delay_ms
    if opts.auto_show == false or delay_ms < 0 then
      return
    end

    local generation = vim.b[bufnr].symbol_documentation_generation
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr)
          or vim.api.nvim_get_current_buf() ~= bufnr
          or vim.b[bufnr].symbol_documentation_generation ~= generation
          or vim.api.nvim_get_mode().mode ~= "n"
          or vim.bo[bufnr].buftype ~= ""
          or vim.fn.pumvisible() == 1
          or has_floating_window() then
        return
      end

      local current_cursor = vim.api.nvim_win_get_cursor(0)
      if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
        return
      end
      local has_hover = #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" }) > 0
      local has_color = opts.color_preview ~= false
        and #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentColor" }) > 0
      local has_diagnostics = opts.include_diagnostics ~= false
        and #line_diagnostics(bufnr, cursor[1] - 1) > 0
      if not has_hover and not has_color and not has_diagnostics then
        return
      end
      M.show()
    end, delay_ms)
  end

  local group = vim.api.nvim_create_augroup("symbol_documentation_" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = bufnr,
    callback = schedule,
    desc = "Show symbol context after the cursor rests",
  })
  vim.api.nvim_create_autocmd({ "CursorMovedI", "InsertEnter", "BufLeave" }, {
    group = group,
    buffer = bufnr,
    callback = cancel,
    desc = "Cancel pending symbol context",
  })

  schedule()
end

return M
