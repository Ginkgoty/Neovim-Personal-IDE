return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
      "mfussenegger/nvim-jdtls",
      {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
          ensure_installed = {
            "debugpy",
            "codelldb",
            "java-debug-adapter",
            "java-test",
            "delve",
            "goimports",
            "stylua",
          },
        },
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local mason = vim.fn.stdpath("data") .. "/mason/packages"

      dapui.setup()

      dap.listeners.before.attach.dapui_config = dapui.open
      dap.listeners.before.launch.dapui_config = dapui.open
      dap.listeners.before.event_terminated.dapui_config = dapui.close
      dap.listeners.before.event_exited.dapui_config = dapui.close

      require("dap-python").setup(mason .. "/debugpy/venv/bin/python")
      require("dap-go").setup({
        delve = {
          path = mason .. "/delve/dlv",
        },
      })

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = mason .. "/codelldb/extension/adapter/codelldb",
          args = { "--port", "${port}" },
        },
      }

      -- GDB 14.1+ includes a native DAP adapter. Keep it alongside codelldb so
      -- GCC/GDB projects can select the matching debugger with F5.
      dap.adapters.gdb = {
        type = "executable",
        command = vim.fn.exepath("gdb") ~= "" and vim.fn.exepath("gdb") or "gdb",
        args = { "--interpreter=dap", "--quiet" },
      }

      local codelldb_config = {
        name = "Launch executable (codelldb)",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      }
      local gdb_config = {
        name = "Launch executable (GDB)",
        type = "gdb",
        request = "launch",
        program = codelldb_config.program,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      }
      dap.configurations.c = { codelldb_config, gdb_config }
      dap.configurations.cpp = { codelldb_config, gdb_config }
      dap.configurations.rust = {
        vim.tbl_extend("force", codelldb_config, { name = "Launch Rust executable" }),
      }

      vim.keymap.set("n", "<leader>dg", function()
        require("dap-go").debug_test()
      end, { desc = "Debug Go: nearest test" })
      vim.keymap.set("n", "<leader>dG", function()
        require("dap-go").debug_last_test()
      end, { desc = "Debug Go: last test" })

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual" })

      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: continue/start" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: conditional breakpoint" })
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: run last" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: open REPL" })
      vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: terminate" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: toggle UI" })
      vim.keymap.set({ "n", "v" }, "<leader>de", function()
        dapui.eval()
      end, { desc = "Debug: evaluate expression" })

      vim.keymap.set("n", "<leader>dn", function()
        require("dap-python").test_method()
      end, { desc = "Debug Python: nearest test" })
      vim.keymap.set("n", "<leader>df", function()
        require("dap-python").test_class()
      end, { desc = "Debug Python: test class" })
    end,
  },
}
