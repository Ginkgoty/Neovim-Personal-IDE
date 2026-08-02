local project = require("config.project")
local settings = require("config.settings")

local function find_makefile(opts)
  -- Let Overseer's built-in provider handle in-tree builds. This prevents
  -- duplicate targets when Neovim itself was opened inside build/.
  if opts and vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1] then
    return
  end

  local root = project.root()
  local directories = (settings.tasks or {}).build_directories or {}

  for _, relative in ipairs(directories) do
    local makefile = vim.fs.joinpath(root, relative, "Makefile")
    if vim.uv.fs_stat(makefile) then
      return makefile
    end
  end
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_makefile(opts)
  end,
  generator = function(opts, callback)
    if vim.fn.executable("make") == 0 then
      return 'Command "make" not found'
    end

    local makefile = find_makefile(opts)
    if not makefile then
      return "No out-of-source Makefile found"
    end

    -- Reuse Overseer's maintained Make target parser, changing only its
    -- search directory to the configured out-of-source build directory.
    local build_opts = vim.tbl_extend("force", opts, {
      dir = vim.fs.dirname(makefile),
    })
    return require("overseer.template.make").generator(build_opts, callback)
  end,
}
