local languages = require("config.languages")

if not languages.enabled("java") or not languages.available("java") then
  return {}
end

return {
  {
    "nvim-java/nvim-java",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "mfussenegger/nvim-dap",
      {
        "JavaHello/spring-boot.nvim",
        commit = "218c0c26c14d99feca778e4d13f5ec3e8b1b60f0",
      },
    },
    config = function()
      require("java").setup({
        jdk = {
          -- The shared language prerequisite already verifies a system JDK 21+.
          auto_install = false,
        },
        spring_boot_tools = {
          -- Keep the base Java profile lean; enable per configuration if needed.
          enable = false,
          auto_install = false,
        },
      })

      vim.lsp.enable("jdtls")

      vim.keymap.set("n", "<leader>dj", "<cmd>JavaTestDebugCurrentMethod<cr>", {
        desc = "Debug Java: current test method",
      })
      vim.keymap.set("n", "<leader>dJ", "<cmd>JavaTestDebugCurrentClass<cr>", {
        desc = "Debug Java: current test class",
      })
    end,
  },
}
