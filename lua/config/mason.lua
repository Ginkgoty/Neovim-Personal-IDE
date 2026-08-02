local M = {}

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO, { title = "Mason Upgrade" })
  end)
end

function M.upgrade()
  local registry = require "mason-registry"
  notify "Refreshing the registry before checking installed tools…"
  registry.update(function(success)
    if not success then
      notify("Registry refresh failed. Check :MasonLog for details.", vim.log.levels.ERROR)
      return
    end

    local outdated = {}
    for _, package in ipairs(registry.get_installed_packages()) do
      if package:get_installed_version() ~= package:get_latest_version() then
        outdated[#outdated + 1] = package
      end
    end
    table.sort(outdated, function(a, b)
      return a.name < b.name
    end)

    if #outdated == 0 then
      notify "All installed tools are up to date."
      return
    end

    local names = vim.tbl_map(function(package)
      return package.name
    end, outdated)
    notify("Upgrading " .. #outdated .. " tool(s): " .. table.concat(names, ", "))

    local remaining = #outdated
    local upgraded, failed = {}, {}
    local function finished(package, ok)
      local result = ok and upgraded or failed
      result[#result + 1] = package.name
      remaining = remaining - 1
      if remaining ~= 0 then
        return
      end

      table.sort(upgraded)
      table.sort(failed)
      if #failed == 0 then
        notify("Upgraded: " .. table.concat(upgraded, ", "))
      else
        notify(
          "Upgraded: "
            .. (#upgraded > 0 and table.concat(upgraded, ", ") or "none")
            .. "\nFailed: "
            .. table.concat(failed, ", ")
            .. "\nSee :MasonLog for details.",
          vim.log.levels.ERROR
        )
      end
    end

    for _, package in ipairs(outdated) do
      package:install({}, function(ok)
        finished(package, ok)
      end)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("MasonUpgrade", M.upgrade, {
    desc = "Refresh the Mason registry and upgrade every installed tool",
    force = true,
  })
end

return M
