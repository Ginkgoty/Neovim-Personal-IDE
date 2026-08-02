local languages = require("config.languages")
local dap_dependencies = {
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
  },
}
if languages.enabled("python") then dap_dependencies[#dap_dependencies + 1] = "mfussenegger/nvim-dap-python" end
if languages.enabled("go") then dap_dependencies[#dap_dependencies + 1] = "leoluz/nvim-dap-go" end
dap_dependencies[#dap_dependencies + 1] = {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "mason-org/mason.nvim" },
  opts = { ensure_installed = languages.mason_tools() },
}

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = dap_dependencies,
    config = function()
      local platform = require("config.platform")
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.before.attach.dapui_config = dapui.open
      dap.listeners.before.launch.dapui_config = dapui.open
      dap.listeners.before.event_terminated.dapui_config = dapui.close
      dap.listeners.before.event_exited.dapui_config = dapui.close

      if languages.enabled("python") then
        -- Keep the adapter isolated from project/global Python environments.
        require("dap-python").setup(platform.debugpy_python())
      end
      if languages.enabled("go") and languages.available("go") then
        require("dap-go").setup({
          delve = {
            path = platform.executable(platform.mason_package("delve", "dlv")),
          },
        })
      end

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = platform.mason_bin("codelldb"),
          args = { "--port", "${port}" },
        },
      }

      -- GDB 14.1+ includes a native DAP adapter.
      dap.adapters.gdb = {
        type = "executable",
        command = platform.gdb_path() or "gdb",
        args = { "--interpreter=dap", "--quiet" },
      }

      local codelldb_config = {
        name = "Launch executable (codelldb)",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Executable: ", platform.join(vim.fn.getcwd(), ""), "file")
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
      local toolchain = platform.c_toolchain()
      local preferred_debugger = toolchain and toolchain.debugger
        or (platform.is_macos and "codelldb" or "gdb")
      local cpp_configurations
      if preferred_debugger == "codelldb" then
        -- macOS/Apple Clang and Windows/MSVC prefer CodeLLDB. On MSVC this is
        -- the portable Neovim option for PDB debugging; cppvsdbg is omitted.
        cpp_configurations = { codelldb_config }
        if not platform.is_windows and platform.gdb_path() then
          table.insert(cpp_configurations, gdb_config)
        end
      else
        -- MinGW and Linux use the debugger matching their native toolchain.
        cpp_configurations = { gdb_config, codelldb_config }
      end
      if languages.enabled("cpp") and languages.available("cpp") then
        dap.configurations.c = cpp_configurations
        dap.configurations.cpp = cpp_configurations
      end
      if languages.enabled("rust") and languages.available("rust") then
        dap.configurations.rust = {
          vim.tbl_extend("force", codelldb_config, { name = "Launch Rust executable" }),
        }
      end

      if languages.enabled("csharp") and languages.available("csharp") then
        dap.adapters.coreclr = {
          type = "executable",
          command = platform.mason_bin("netcoredbg"),
          args = { "--interpreter=vscode" },
        }
        dap.configurations.cs = {
          {
            name = "Launch .NET assembly",
            type = "coreclr",
            request = "launch",
            program = function()
              return vim.fn.input("Path to DLL: ", platform.join(vim.fn.getcwd(), "bin", "Debug", ""), "file")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end

      if languages.enabled("javascript") and languages.available("javascript") then
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = platform.mason_bin("js-debug-adapter"),
            args = { "${port}" },
          },
        }

        local attach_node = {
          name = "Attach to Node.js process",
          type = "pwa-node",
          request = "attach",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        }
        local launch_compiled = {
          name = "Launch compiled JavaScript",
          type = "pwa-node",
          request = "launch",
          program = function()
            return vim.fn.input("JavaScript entry point: ", platform.join(vim.fn.getcwd(), "dist", ""), "file")
          end,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        }
        local launch_current = {
          name = "Launch current JavaScript file",
          type = "pwa-node",
          request = "launch",
          program = "${file}",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        }

        dap.configurations.javascript = { launch_current, attach_node }
        dap.configurations.javascriptreact = { launch_current, attach_node }
        dap.configurations.typescript = { launch_compiled, attach_node }
        dap.configurations.typescriptreact = { launch_compiled, attach_node }
      end

      if languages.enabled("go") and languages.available("go") then
        vim.keymap.set("n", "<leader>dg", function()
          require("dap-go").debug_test()
        end, { desc = "Debug Go: nearest test" })
        vim.keymap.set("n", "<leader>dG", function()
          require("dap-go").debug_last_test()
        end, { desc = "Debug Go: last test" })
      end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual" })

      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: continue/start" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      -- Leader-key equivalents make the core controls discoverable in
      -- which-key; keep the conventional function keys for fast use.
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: continue/start" })
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug: step out" })
      vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "Debug: pause" })
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

      if languages.enabled("python") then
        vim.keymap.set("n", "<leader>dn", function()
          require("dap-python").test_method()
        end, { desc = "Debug Python: nearest test" })
        vim.keymap.set("n", "<leader>df", function()
          require("dap-python").test_class()
        end, { desc = "Debug Python: test class" })
      end
    end,
  },
}
