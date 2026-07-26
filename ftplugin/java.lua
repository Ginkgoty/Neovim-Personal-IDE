local jdtls = require("jdtls")
local data = vim.fn.stdpath("data")
local mason = data .. "/mason/packages"
local root_dir = vim.fs.root(0, { "gradlew", "mvnw", "pom.xml", "build.gradle", ".git" })
  or vim.fn.getcwd()
local project_name = vim.fn.fnamemodify(root_dir, ":t")
local project_id = project_name .. "-" .. vim.fn.sha256(root_dir):sub(1, 8)
local workspace_dir = data .. "/jdtls-workspace/" .. project_id

local bundles = {
  vim.fn.glob(mason .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar", true),
}

for _, jar in ipairs(vim.split(vim.fn.glob(mason .. "/java-test/extension/server/*.jar", true), "\n")) do
  local name = vim.fn.fnamemodify(jar, ":t")
  if name ~= "com.microsoft.java.test.runner-jar-with-dependencies.jar"
      and name ~= "jacocoagent.jar"
      and jar ~= "" then
    table.insert(bundles, jar)
  end
end

jdtls.start_or_attach({
  cmd = { vim.fn.exepath("jdtls"), "-data", workspace_dir },
  root_dir = root_dir,
  init_options = { bundles = bundles },
  on_attach = function()
    jdtls.setup_dap({ hotcodereplace = "auto" })
  end,
})

vim.keymap.set("n", "<leader>dj", jdtls.test_nearest_method, {
  buffer = true,
  desc = "Debug Java: nearest test",
})
vim.keymap.set("n", "<leader>dJ", jdtls.test_class, {
  buffer = true,
  desc = "Debug Java: test class",
})
