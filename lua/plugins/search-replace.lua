local function project_root()
  return require("config.project").root(0)
end

local function apply_highlights()
  local ui = require("config.settings").ui or {}
  local settings = ui.search_replace or {}
  local highlights = settings.highlights or {}
  vim.api.nvim_set_hl(0, "GrugFarResultsMatch", {
    link = highlights.result_match or "Search",
  })
  vim.api.nvim_set_hl(0, "GrugFarCurrentMatch", {
    link = highlights.current_match or "IncSearch",
  })
  vim.api.nvim_set_hl(0, "GrugFarCurrentResultLine", {
    link = highlights.current_result_line or "Visual",
  })
end

local function sidebar_options()
  local ui = require("config.settings").ui or {}
  local settings = ui.search_replace or {}
  local help_width = math.min(tonumber(settings.help_width) or 100, math.max(20, vim.o.columns - 4))
  local help_height = math.min(tonumber(settings.help_height) or 30, math.max(8, vim.o.lines - 4))
  return {
    windowCreationCommand = "GrugFarSidebarWindow",
    -- A narrow search sidebar must keep every match on one visual line.
    wrap = settings.wrap_results == true,
    -- The built-in header truncates most actions in a narrow sidebar. A
    -- compact multi-line header is rendered by configure_sidebar instead.
    helpLine = {
      enabled = false,
    },
    -- Full help should use the editor canvas, not inherit the sidebar width.
    helpWindow = {
      relative = "editor",
      width = help_width,
      height = help_height,
      row = math.max(0, math.floor((vim.o.lines - help_height) / 2) - 1),
      col = math.max(0, math.floor((vim.o.columns - help_width) / 2)),
    },
    openTargetWindow = {
      preferredLocation = "prev",
    },
    prefills = {
      paths = project_root(),
    },
  }
end

local function configure_sidebar(instance)
  instance:when_ready(function()
    local target_win = require("config.sidebar").editor_window()
    if target_win and vim.api.nvim_win_is_valid(target_win) then
      -- The mapping may have been invoked while NvimTree had focus. Its window
      -- is closed to make room for this sidebar, so bind result navigation to
      -- the actual editor rather than grug-far's now-stale previous window.
      instance._context.prevWin = target_win
    end
    local win = vim.fn.bufwinid(instance:get_buf())
    if win == -1 then
      return
    end
    local ui = require("config.settings").ui or {}
    local settings = ui.search_replace or {}
    local namespace = vim.api.nvim_create_namespace("grug_far_sidebar_actions")
    vim.api.nvim_buf_clear_namespace(instance:get_buf(), namespace, 0, -1)
    vim.api.nvim_buf_set_extmark(instance:get_buf(), namespace, 0, 0, {
      virt_lines_above = true,
      virt_lines = {
        {
          { " Navigate ", "Title" },
          { "↑/↓ Preview  Enter Open", "Comment" },
        },
        {
          { " Replace  ", "Title" },
          { "\\r All  \\l Line  \\s Sync", "Comment" },
        },
        {
          { " Results  ", "Title" },
          { "\\q Quickfix  \\f Refresh", "Comment" },
        },
        {
          { " Session  ", "Title" },
          { "\\t History  \\c Close  g? Help", "Comment" },
        },
      },
    })
    if settings.wrap_results ~= true then
      vim.wo[win].wrap = false
      vim.wo[win].list = true
      vim.wo[win].listchars = "extends:…,precedes:…"
    end
    -- Keep the selected result visible after <count><Enter> transfers focus
    -- to the editor window.
    vim.wo[win].cursorline = true
    vim.wo[win].cursorlineopt = "line"
    local winhighlight = vim.wo[win].winhighlight
    local cursorline_hl = "CursorLine:GrugFarCurrentResultLine"
    if not winhighlight:find(cursorline_hl, 1, true) then
      vim.wo[win].winhighlight = winhighlight == "" and cursorline_hl
        or (winhighlight .. "," .. cursorline_hl)
    end
  end)
  return instance
end

local function find_sidebar_window(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(win).relative == ""
        and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "grug-far" then
      return win
    end
  end
end

local function create_sidebar_command()
  apply_highlights()
  local highlight_group = vim.api.nvim_create_augroup("grug_far_sidebar_highlights", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = highlight_group,
    callback = apply_highlights,
    desc = "Restore grug-far sidebar highlights after changing theme",
  })

  vim.api.nvim_create_user_command("GrugFarSidebarWindow", function()
    local ui = require("config.settings").ui or {}
    local settings = ui.search_replace or {}
    local sidebar_width = tonumber(settings.sidebar_width) or 48
    sidebar_width = math.max(30, math.floor(sidebar_width))
    local sidebar_win = require("config.sidebar").claim_window("search_replace", sidebar_width)
    if settings.wrap_results ~= true then
      vim.wo[sidebar_win].list = true
      vim.wo[sidebar_win].listchars = "extends:…,precedes:…"
    end
  end, {
    force = true,
    desc = "Use the shared sidebar slot for grug-far",
  })

  require("config.sidebar").register("search_replace", {
    find_window = find_sidebar_window,
    open = function(context)
      if context.visual then
        configure_sidebar(require("grug-far").with_visual_selection(sidebar_options()))
      else
        configure_sidebar(require("grug-far").open(sidebar_options()))
      end
    end,
    close = function(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local ok, instance = pcall(require("grug-far").get_instance, buf)
      if ok and instance then
        if instance._is_ready then
          instance:close()
        else
          -- grug-far cannot safely delete its buffer while its first render is
          -- pending. Hide the slot immediately, then clean up when ready.
          instance:hide()
          instance:when_ready(function()
            if instance:is_valid() then
              instance:close()
            end
          end)
        end
      elseif vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    init = create_sidebar_command,
    keys = {
      {
        "<leader>F",
        function()
          require("config.sidebar").toggle("search_replace")
        end,
        mode = "n",
        desc = "Find: search and replace in project",
      },
      {
        "<leader>F",
        function()
          require("config.sidebar").toggle("search_replace", { visual = true })
        end,
        mode = "v",
        desc = "Find: search and replace selected text in project",
      },
    },
    opts = {
      windowCreationCommand = "GrugFarSidebarWindow",
      wrap = false,
      -- Results always open in the editor that had focus before the sidebar.
      openTargetWindow = {
        preferredLocation = "prev",
      },
    },
  },
}
