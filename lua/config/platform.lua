local M = {}

M.is_windows = vim.fn.has("win32") == 1
M.is_macos = vim.fn.has("macunix") == 1
M.is_linux = vim.fn.has("linux") == 1
local cached_windows_toolchain
local toolchain_checked = false
local cached_windows_compiler
local compiler_checked = false
local cached_java_major
local java_checked = false

function M.join(...)
  return vim.fs.joinpath(...)
end

function M.executable(path)
  if M.is_windows and not path:lower():match("%.exe$") then
    return path .. ".exe"
  end
  return path
end

function M.mason_package(name, ...)
  return M.join(vim.fn.stdpath("data"), "mason", "packages", name, ...)
end

function M.mason_bin(name)
  return M.join(vim.fn.stdpath("data"), "mason", "bin", M.executable(name))
end

function M.debugpy_python()
  if M.is_windows then
    return M.mason_package("debugpy", "venv", "Scripts", "python.exe")
  end
  return M.mason_package("debugpy", "venv", "bin", "python")
end

local function executable_path(name)
  local path = vim.fn.exepath(name)
  return path ~= "" and path or nil
end

local function run(command)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout or "")
end

function M.java_major_version()
  if java_checked then
    return cached_java_major
  end
  java_checked = true

  local java = executable_path(M.is_windows and "java.exe" or "java")
  local javac = executable_path(M.is_windows and "javac.exe" or "javac")
  if not (java and javac) then
    return nil
  end

  local result = vim.system({ java, "-version" }, { text = true }):wait()
  local output = (result.stderr or "") .. (result.stdout or "")
  cached_java_major = tonumber(output:match('version%s+"(%d+)'))
  return cached_java_major
end

function M.has_java_21()
  local major = M.java_major_version()
  return major ~= nil and major >= 21
end

local function vswhere_path()
  local path = executable_path("vswhere.exe") or executable_path("vswhere")
  if path then
    return path
  end

  local program_files = vim.env["ProgramFiles(x86)"] or vim.env.ProgramFiles
  if not program_files then
    return nil
  end

  path = M.join(program_files, "Microsoft Visual Studio", "Installer", "vswhere.exe")
  return vim.uv.fs_stat(path) and path or nil
end

local function windows_architecture()
  local machine = (vim.uv.os_uname().machine or ""):lower()
  if machine:find("arm64", 1, true) or machine:find("aarch64", 1, true) then
    return "ARM64", "Hostarm64", "arm64"
  end
  if machine:find("64", 1, true) then
    return "x64", "Hostx64", "x64"
  end
  return "Win32", "Hostx86", "x86"
end

local visual_studio_generators = {
  [18] = "Visual Studio 18 2026",
  [17] = "Visual Studio 17 2022",
  [16] = "Visual Studio 16 2019",
  [15] = "Visual Studio 15 2017",
}

local function find_msvc(cmake)
  local vswhere = vswhere_path()
  if not vswhere then
    return nil
  end

  local output = run({
    vswhere,
    "-products", "*",
    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "-format", "json",
    "-utf8",
  })
  if not output or output == "" then
    return nil
  end

  local ok, instances = pcall(vim.json.decode, output)
  if not ok or type(instances) ~= "table" then
    return nil
  end

  table.sort(instances, function(a, b)
    local av = vim.version.parse(a.installationVersion or "0") or { major = 0, minor = 0, patch = 0 }
    local bv = vim.version.parse(b.installationVersion or "0") or { major = 0, minor = 0, patch = 0 }
    if av.major ~= bv.major then
      return av.major > bv.major
    end
    if av.minor ~= bv.minor then
      return av.minor > bv.minor
    end
    return av.patch > bv.patch
  end)

  local cmake_help = cmake and (run({ cmake, "--help" }) or "") or nil
  local architecture, host_dir, target_dir = windows_architecture()

  for _, instance in ipairs(instances) do
    local major = tonumber((instance.installationVersion or ""):match("^(%d+)"))
    local generator = major and visual_studio_generators[major] or nil
    local installation = instance.installationPath
    local generator_supported = not cmake or (generator and cmake_help:find(generator, 1, true))
    if installation and generator_supported then
      local version_file = M.join(installation, "VC", "Auxiliary", "Build", "Microsoft.VCToolsVersion.default.txt")
      local lines = vim.fn.filereadable(version_file) == 1 and vim.fn.readfile(version_file) or {}
      local tools_version = lines[1] and vim.trim(lines[1]) or nil
      local cl = tools_version and M.join(
        installation, "VC", "Tools", "MSVC", tools_version, "bin", host_dir, target_dir, "cl.exe"
      ) or nil

      if cl and vim.fn.executable(cl) == 1 then
        return {
          kind = "msvc",
          cmake = cmake,
          compiler = cl,
          installation = installation,
          generator = generator,
          architecture = architecture,
        }
      end
    end
  end
end

local function find_mingw(cmake)
  local gcc = executable_path("gcc.exe") or executable_path("gcc")
  local gxx = executable_path("g++.exe") or executable_path("g++")
  local make = executable_path("mingw32-make.exe") or executable_path("mingw32-make")
  if not (gcc and gxx and make) then
    return nil
  end

  local target = run({ gcc, "-dumpmachine" })
  if not target or not target:lower():find("mingw", 1, true) then
    return nil
  end

  return {
    kind = "mingw",
    cmake = cmake,
    compiler = gcc,
    cxx_compiler = gxx,
    make = make,
  }
end

function M.windows_c_toolchain()
  if toolchain_checked then
    return cached_windows_toolchain
  end
  toolchain_checked = true

  if not M.is_windows then
    return nil
  end

  local cmake = executable_path("cmake.exe") or executable_path("cmake")
  if not cmake then
    return nil
  end

  -- An installed MSVC toolset always wins, even when MinGW is also on PATH.
  cached_windows_toolchain = find_msvc(cmake) or find_mingw(cmake)
  return cached_windows_toolchain
end

function M.windows_c_compiler()
  if compiler_checked then
    return cached_windows_compiler
  end
  compiler_checked = true
  if not M.is_windows then
    return nil
  end

  -- Compiler discovery does not require CMake. vswhere still locates MSVC
  -- outside a Developer Command Prompt, with MinGW as the fallback.
  cached_windows_compiler = find_msvc(nil) or find_mingw(nil)
  return cached_windows_compiler
end

local function macos_c_toolchain()
  -- /usr/bin/clang is Apple's Xcode command-line tool shim. Prefer it
  -- explicitly so a Homebrew LLVM directory placed first on PATH cannot win.
  local clang = vim.fn.executable("/usr/bin/clang") == 1 and "/usr/bin/clang" or executable_path("clang")
  local clangxx = vim.fn.executable("/usr/bin/clang++") == 1 and "/usr/bin/clang++" or executable_path("clang++")
  if not (clang and clangxx) then
    return nil
  end
  return {
    kind = "apple-clang",
    compiler = clang,
    cxx_compiler = clangxx,
    debugger = "codelldb",
  }
end

local function linux_c_toolchain()
  local gcc = executable_path("gcc")
  local gxx = executable_path("g++")
  if gcc and gxx then
    return { kind = "gcc", compiler = gcc, cxx_compiler = gxx, debugger = "gdb" }
  end

  local clang = executable_path("clang")
  local clangxx = executable_path("clang++")
  if clang and clangxx then
    return { kind = "clang", compiler = clang, cxx_compiler = clangxx, debugger = "gdb" }
  end
end

function M.c_toolchain()
  if M.is_windows then
    local toolchain = M.windows_c_toolchain()
    if toolchain then
      toolchain.debugger = toolchain.kind == "mingw" and "gdb" or "codelldb"
    end
    return toolchain
  end
  if M.is_macos then
    return macos_c_toolchain()
  end
  if M.is_linux then
    return linux_c_toolchain()
  end
end

function M.has_c_compiler()
  if M.is_windows then
    return M.windows_c_compiler() ~= nil
  end
  if M.is_macos then
    return vim.fn.executable("/usr/bin/clang") == 1
      and vim.fn.executable("/usr/bin/clang++") == 1
  end
  if M.is_linux then
    local gcc = executable_path("gcc") and executable_path("g++")
    local clang = executable_path("clang") and executable_path("clang++")
    return gcc ~= nil or clang ~= nil
  end
  return false
end

-- clangd may execute only these explicitly detected GCC-compatible drivers to
-- discover their target and system include paths. MSVC's cl.exe is not a
-- query-driver; clangd learns its flags from the compilation database instead.
function M.clangd_query_drivers()
  local toolchain = M.c_toolchain()
  if not toolchain or toolchain.kind == "msvc" then
    return {}
  end

  local result = {}
  for _, path in ipairs({ toolchain.compiler, toolchain.cxx_compiler }) do
    if path and vim.fn.executable(path) == 1 then
      result[#result + 1] = vim.fs.normalize(path)
    end
  end
  return result
end

function M.gdb_path()
  return executable_path(M.is_windows and "gdb.exe" or "gdb")
end

local function checked_system(command, cwd)
  local result = vim.system(command, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    error((result.stderr and vim.trim(result.stderr) ~= "" and result.stderr) or result.stdout or "build failed")
  end
end

function M.build_windows_cmake(source_dir)
  local toolchain = assert(M.windows_c_toolchain(), "No usable MSVC or MinGW C/C++ toolchain was detected")
  local build_dir = M.join(source_dir, "build-" .. toolchain.kind)
  local configure

  if toolchain.kind == "msvc" then
    configure = {
      toolchain.cmake, "-S", source_dir, "-B", build_dir,
      "-G", toolchain.generator,
      "-A", toolchain.architecture,
      "-DCMAKE_GENERATOR_INSTANCE:PATH=" .. toolchain.installation,
    }
  else
    configure = {
      toolchain.cmake, "-S", source_dir, "-B", build_dir,
      "-G", "MinGW Makefiles",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_C_COMPILER:FILEPATH=" .. toolchain.compiler,
      "-DCMAKE_CXX_COMPILER:FILEPATH=" .. toolchain.cxx_compiler,
      "-DCMAKE_MAKE_PROGRAM:FILEPATH=" .. toolchain.make,
    }
  end

  checked_system(configure, source_dir)
  checked_system({
    toolchain.cmake, "--build", build_dir, "--config", "Release", "--target", "install",
  }, source_dir)

  -- telescope-fzf-native loads this exact path. Keep separate CMake caches for
  -- MSVC and MinGW, then publish only the resulting DLL to the expected folder.
  local built_library = M.join(build_dir, "libfzf.dll")
  if vim.fn.filereadable(built_library) ~= 1 then
    error("CMake succeeded but did not produce " .. built_library)
  end
  local runtime_dir = M.join(source_dir, "build")
  vim.fn.mkdir(runtime_dir, "p")
  local ok, copy_error = vim.uv.fs_copyfile(built_library, M.join(runtime_dir, "libfzf.dll"))
  if not ok then
    error("Failed to install libfzf.dll: " .. tostring(copy_error))
  end
end

return M
