local M = {}

M.is_windows = vim.fn.has "win32" == 1
M.is_macos = vim.fn.has "macunix" == 1
M.is_linux = vim.fn.has "linux" == 1
local cached_windows_toolchain
local toolchain_checked = false
local cached_windows_compiler
local compiler_checked = false
local cached_java_major
local java_checked = false
local clang_resource_dirs = {}
local compiler_families = {}
local gcc_versions = {}
local gcc_cpp_standards = {}
local standard_include_contexts
local type_support = {}

function M.join(...)
  return vim.fs.joinpath(...)
end

function M.is_absolute(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  if M.is_windows then
    return path:match "^%a:[/\\]" ~= nil or path:match "^[/\\][/\\]" ~= nil
  end
  return path:sub(1, 1) == "/"
end

function M.executable(path)
  if M.is_windows and not path:lower():match "%.exe$" then
    return path .. ".exe"
  end
  return path
end

function M.mason_package(name, ...)
  return M.join(vim.fn.stdpath "data", "mason", "packages", name, ...)
end

function M.mason_bin(name)
  return M.join(vim.fn.stdpath "data", "mason", "bin", M.executable(name))
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

local function canonical(path)
  path = vim.fs.normalize(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path):gsub("\\", "/")
end

local function contains(root, path)
  return path == root or vim.startswith(path, root .. "/")
end

local function compiler_include_paths(compiler, language)
  if not compiler or M.compiler_family(compiler) == nil then
    return {}
  end
  local result = vim
    .system({ compiler, "-v", "-E", "-x", language, "-" }, {
      stdin = "",
      text = true,
    })
    :wait()
  local output = (result.stderr or "") .. "\n" .. (result.stdout or "")
  local paths, seen, collecting = {}, {}, false
  for line in output:gmatch "[^\r\n]+" do
    if line:find("#include <...> search starts here:", 1, true) then
      collecting = true
    elseif collecting and line:find("End of search list.", 1, true) then
      break
    elseif collecting then
      local path = vim.trim(line):gsub(" %(framework directory%)$", "")
      if path ~= "" and vim.uv.fs_stat(path) then
        path = canonical(path)
        if not seen[path] then
          seen[path] = true
          paths[#paths + 1] = path
        end
      end
    end
  end
  return paths
end

local function latest_windows_sdk_include()
  local program_files = vim.env["ProgramFiles(x86)"] or vim.env.ProgramFiles
  local base = program_files and M.join(program_files, "Windows Kits", "10", "Include") or nil
  if not base or not vim.uv.fs_stat(base) then
    return nil
  end
  local versions = {}
  for name, kind in vim.fs.dir(base) do
    if kind == "directory" and vim.version.parse(name) then
      versions[#versions + 1] = name
    end
  end
  table.sort(versions, function(a, b)
    return vim.version.gt(vim.version.parse(a), vim.version.parse(b))
  end)
  return versions[1] and M.join(base, versions[1]) or nil
end

local function windows_target()
  local machine = (vim.uv.os_uname().machine or ""):lower()
  if machine:find("arm64", 1, true) or machine:find("aarch64", 1, true) then
    return "aarch64-pc-windows-msvc"
  end
  if machine:find("64", 1, true) then
    return "x86_64-pc-windows-msvc"
  end
  return "i686-pc-windows-msvc"
end

local function windows_msvc_context(path)
  local toolchain = M.windows_c_compiler()
  if not toolchain or toolchain.kind ~= "msvc" then
    return nil
  end
  local roots = {}
  local function append(pathname)
    if pathname and vim.uv.fs_stat(pathname) then
      roots[#roots + 1] = canonical(pathname)
    end
  end
  append(toolchain.include_root)
  local sdk = latest_windows_sdk_include()
  for _, name in ipairs { "ucrt", "shared", "um", "winrt", "cppwinrt" } do
    append(sdk and M.join(sdk, name) or nil)
  end

  local best_root
  for _, root in ipairs(roots) do
    if contains(root:lower(), path:lower()) and (not best_root or #root > #best_root) then
      best_root = root
    end
  end
  if not best_root then
    return nil
  end
  local basename = vim.fs.basename(path)
  local extension = basename:match "%.([^./]+)$"
  local explicit_cpp = extension and ({ hh = true, hpp = true, hxx = true, ["h++"] = true })[extension:lower()]
  local language = (best_root:lower():match "/cppwinrt$" or not extension or explicit_cpp) and "cpp" or "c"
  -- MSVC keeps C and C++ headers in the same include directory. Distinct
  -- workspace roots prevent one standalone client/compile command from
  -- forcing the first-opened language onto every later header in that root.
  local workspace_root = language == "cpp" and best_root or vim.fs.dirname(best_root)
  local target = windows_target()
  local fallback_flags = { "-x", language == "cpp" and "c++-header" or "c-header", "--target=" .. target }
  local compile_flags = { language == "cpp" and "/TP" or "/TC" }
  for _, root in ipairs(roots) do
    vim.list_extend(fallback_flags, { "-isystem", root })
    compile_flags[#compile_flags + 1] = "/I" .. root
  end
  return {
    root = workspace_root,
    filename = path,
    language = language,
    driver = canonical(toolchain.compiler),
    fallback_flags = fallback_flags,
    compile_flags = compile_flags,
  }
end

local function load_standard_include_contexts()
  if standard_include_contexts then
    return standard_include_contexts
  end
  standard_include_contexts = {}
  local toolchain = M.is_windows and M.windows_c_compiler() or M.c_toolchain()

  local candidates, seen = {}, {}
  local function append(c_compiler, cpp_compiler)
    c_compiler = c_compiler and canonical(c_compiler) or nil
    cpp_compiler = cpp_compiler and canonical(cpp_compiler) or c_compiler
    local key = (c_compiler or "") .. "\0" .. (cpp_compiler or "")
    if c_compiler and cpp_compiler and not seen[key] then
      seen[key] = true
      candidates[#candidates + 1] = { c = c_compiler, cpp = cpp_compiler }
    end
  end
  if toolchain and toolchain.kind ~= "msvc" then
    append(toolchain.compiler, toolchain.cxx_compiler or toolchain.compiler)
  end
  if M.is_windows then
    local gcc = executable_path "gcc.exe" or executable_path "gcc"
    local gxx = executable_path "g++.exe" or executable_path "g++"
    local target = gcc and run { gcc, "-dumpmachine" } or nil
    if gcc and gxx and target and target:lower():find("mingw", 1, true) then
      append(gcc, gxx)
    end
  end

  -- macOS intentionally keeps Apple Clang as its default, but Homebrew GCC
  -- installs versioned drivers. Discover trusted secondary GCC installations
  -- without changing the default project toolchain.
  for version = 30, 5, -1 do
    local gcc = executable_path("gcc-" .. version)
    local gxx = executable_path("g++-" .. version)
    if gcc and gxx and M.compiler_family(gcc) == "gcc" and M.compiler_family(gxx) == "gcc" then
      append(gcc, gxx)
    end
  end

  for _, candidate in ipairs(candidates) do
    local context = {
      compiler = candidate.c,
      cxx_compiler = candidate.cpp,
      c = compiler_include_paths(candidate.c, "c"),
      cpp = compiler_include_paths(candidate.cpp, "c++"),
      cpp_only = {},
      target = run { candidate.c, "-dumpmachine" },
    }
    local c_paths = {}
    for _, path in ipairs(context.c) do
      c_paths[path] = true
    end
    for _, path in ipairs(context.cpp) do
      if not c_paths[path] then
        context.cpp_only[path] = true
      end
    end
    standard_include_contexts[#standard_include_contexts + 1] = context
  end
  return standard_include_contexts
end

local function compiler_supports_type(compiler, target, type_name)
  local key = table.concat({ compiler or "", target or "", type_name }, "\0")
  if type_support[key] ~= nil then
    return type_support[key]
  end
  local command = { compiler, "-fsyntax-only", "-x", "c++", "-" }
  if target and target ~= "" then
    table.insert(command, 2, "--target=" .. target)
  end
  local result = vim.system(command, { stdin = type_name .. " value;\n", text = true }):wait()
  type_support[key] = result.code == 0
  return type_support[key]
end

-- Classify a directly opened compiler/SDK header using the actual include
-- search paths reported by the selected host C and C++ compiler drivers.
-- Shared .h directories default to ISO C; C++-only roots and explicit C++
-- suffixes retain C++ semantics.
function M.standard_header_context(filename)
  local path = canonical(filename)
  if M.is_windows then
    local msvc = windows_msvc_context(path)
    if msvc then
      return msvc
    end
  end

  local best_root, best_context, cpp_only
  for _, context in ipairs(load_standard_include_contexts()) do
    for _, roots in ipairs { context.c, context.cpp } do
      for _, root in ipairs(roots) do
        if contains(root, path) and (not best_root or #root > #best_root) then
          best_root = root
          best_context = context
          cpp_only = context.cpp_only[root] == true
        end
      end
    end
  end
  if not best_root then
    return nil
  end

  local basename = vim.fs.basename(path)
  local extension = basename:match "%.([^./]+)$"
  local explicit_cpp = extension and ({ hh = true, hpp = true, hxx = true, ["h++"] = true })[extension:lower()]
  local language = (cpp_only or explicit_cpp) and "cpp" or "c"
  local driver = language == "cpp" and best_context.cxx_compiler or best_context.compiler
  local include_paths = language == "cpp" and best_context.cpp or best_context.c
  local fallback_flags = { "-x", language == "cpp" and "c++-header" or "c-header" }
  local gcc_version = M.gcc_version(driver)
  if gcc_version then
    fallback_flags[#fallback_flags + 1] = "-fgnuc-version=" .. gcc_version
    fallback_flags[#fallback_flags + 1] = "-U__clang__"
    local standard = language == "cpp" and M.gcc_default_cpp_standard(driver) or nil
    if standard then
      fallback_flags[#fallback_flags + 1] = "-std=" .. standard
    end
  end
  if best_context.target and best_context.target ~= "" and M.compiler_family(driver) == "clang" then
    fallback_flags[#fallback_flags + 1] = "--target=" .. best_context.target
  end
  for _, include_path in ipairs(include_paths) do
    local flag = include_path:match "/System/Library/Frameworks$" and "-iframework" or "-isystem"
    fallback_flags[#fallback_flags + 1] = flag
    fallback_flags[#fallback_flags + 1] = include_path
  end
  local frontend = M.c_toolchain()
  frontend = frontend and frontend.cxx_compiler or nil
  if
    M.compiler_family(driver) == "gcc"
    and frontend
    and M.compiler_family(frontend) == "clang"
    and not compiler_supports_type(frontend, best_context.target, "__float128")
  then
    -- clangd always parses with a Clang frontend, even when the owning driver
    -- is GCC. Some GCC targets expose __float128 in their builtin headers when
    -- the corresponding Clang target cannot represent it. Keep standalone
    -- browsing usable with a layout-compatible approximation; real projects
    -- continue to use their untouched compilation database.
    fallback_flags[#fallback_flags + 1] = "-D__float128=long double"
  end
  return {
    root = best_root,
    filename = path,
    language = language,
    driver = driver,
    fallback_flags = fallback_flags,
  }
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
  cached_java_major = tonumber(output:match 'version%s+"(%d+)')
  return cached_java_major
end

function M.has_java_21()
  local major = M.java_major_version()
  return major ~= nil and major >= 21
end

local function vswhere_path()
  local path = executable_path "vswhere.exe" or executable_path "vswhere"
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

  local output = run {
    vswhere,
    "-products",
    "*",
    "-requires",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "-format",
    "json",
    "-utf8",
  }
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

  local cmake_help = cmake and (run { cmake, "--help" } or "") or nil
  local architecture, host_dir, target_dir = windows_architecture()

  for _, instance in ipairs(instances) do
    local major = tonumber((instance.installationVersion or ""):match "^(%d+)")
    local generator = major and visual_studio_generators[major] or nil
    local installation = instance.installationPath
    local generator_supported = not cmake or (generator and cmake_help:find(generator, 1, true))
    if installation and generator_supported then
      local version_file = M.join(installation, "VC", "Auxiliary", "Build", "Microsoft.VCToolsVersion.default.txt")
      local lines = vim.fn.filereadable(version_file) == 1 and vim.fn.readfile(version_file) or {}
      local tools_version = lines[1] and vim.trim(lines[1]) or nil
      local cl = tools_version
          and M.join(installation, "VC", "Tools", "MSVC", tools_version, "bin", host_dir, target_dir, "cl.exe")
        or nil

      if cl and vim.fn.executable(cl) == 1 then
        return {
          kind = "msvc",
          cmake = cmake,
          compiler = cl,
          installation = installation,
          generator = generator,
          architecture = architecture,
          tools_version = tools_version,
          include_root = M.join(installation, "VC", "Tools", "MSVC", tools_version, "include"),
        }
      end
    end
  end
end

local function find_mingw(cmake)
  local gcc = executable_path "gcc.exe" or executable_path "gcc"
  local gxx = executable_path "g++.exe" or executable_path "g++"
  local make = executable_path "mingw32-make.exe" or executable_path "mingw32-make"
  if not (gcc and gxx and make) then
    return nil
  end

  local target = run { gcc, "-dumpmachine" }
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

  local cmake = executable_path "cmake.exe" or executable_path "cmake"
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
  local clang = vim.fn.executable "/usr/bin/clang" == 1 and "/usr/bin/clang" or executable_path "clang"
  local clangxx = vim.fn.executable "/usr/bin/clang++" == 1 and "/usr/bin/clang++" or executable_path "clang++"
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
  local gcc = executable_path "gcc"
  local gxx = executable_path "g++"
  if gcc and gxx then
    return { kind = "gcc", compiler = gcc, cxx_compiler = gxx, debugger = "gdb" }
  end

  local clang = executable_path "clang"
  local clangxx = executable_path "clang++"
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
    return vim.fn.executable "/usr/bin/clang" == 1 and vim.fn.executable "/usr/bin/clang++" == 1
  end
  if M.is_linux then
    local gcc = executable_path "gcc" and executable_path "g++"
    local clang = executable_path "clang" and executable_path "clang++"
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

  local result, seen = {}, {}
  local function append(path)
    path = path and vim.fs.normalize(path) or nil
    if path and vim.fn.executable(path) == 1 and not seen[path] then
      seen[path] = true
      result[#result + 1] = path
    end
  end
  for _, path in ipairs { toolchain.compiler, toolchain.cxx_compiler } do
    append(path)
  end
  -- Compilation databases commonly spell the same host compiler as cc/c++.
  -- Allow only executable aliases discovered on the host, never arbitrary
  -- project-local drivers from an untrusted compilation database.
  if toolchain.kind == "apple-clang" then
    append(executable_path "cc")
    append(executable_path "c++")
  end
  return result
end

function M.clangd_path()
  return executable_path(M.is_windows and "clangd.exe" or "clangd") or "clangd"
end

function M.compiler_family(compiler)
  if compiler_families[compiler] ~= nil then
    return compiler_families[compiler] or nil
  end
  local basename = vim.fs.basename(compiler):lower():gsub("%.exe$", "")
  local family
  local gcc_name = basename:match "^g%+%+[%d%.%-]*$" or basename:match "^gcc[%d%.%-]*$"
  local clang_name = basename:match "^clang%+%+[%d%.%-]*$" or basename:match "^clang[%d%.%-]*$"
  if gcc_name or clang_name or basename == "cc" or basename == "c++" then
    -- Apple ships gcc/g++ compatibility stubs that are actually Clang. The
    -- executable name is therefore only a candidate; implementation identity
    -- comes from the driver's own version output.
    local version = (run { compiler, "--version" } or ""):lower()
    if version:find("clang", 1, true) then
      family = "clang"
    elseif version:find("gcc", 1, true) or version:find("free software foundation", 1, true) then
      family = "gcc"
    end
  end
  compiler_families[compiler] = family or false
  return family
end

function M.gcc_version(compiler)
  if not compiler or M.compiler_family(compiler) ~= "gcc" then
    return nil
  end
  if gcc_versions[compiler] ~= nil then
    return gcc_versions[compiler] or nil
  end
  local version = run { compiler, "-dumpfullversion", "-dumpversion" }
  version = version and version:match "^(%d+%.?%d*%.?%d*)" or nil
  gcc_versions[compiler] = version or false
  return gcc_versions[compiler] or nil
end

function M.gcc_default_cpp_standard(compiler)
  if not compiler or M.compiler_family(compiler) ~= "gcc" then
    return nil
  end
  if gcc_cpp_standards[compiler] ~= nil then
    return gcc_cpp_standards[compiler] or nil
  end
  local result = vim
    .system({ compiler, "-dM", "-E", "-x", "c++", "-" }, {
      stdin = "",
      text = true,
    })
    :wait()
  local output = result.code == 0 and result.stdout or ""
  local value = tonumber(output:match "#define%s+__cplusplus%s+(%d+)L?")
  local year
  if value and value >= 202400 then
    year = "26"
  elseif value and value >= 202100 then
    year = "23"
  elseif value and value >= 202002 then
    year = "20"
  elseif value and value >= 201703 then
    year = "17"
  elseif value and value >= 201402 then
    year = "14"
  elseif value and value >= 201103 then
    year = "11"
  elseif value and value >= 199711 then
    year = "98"
  end
  local strict = output:match "#define%s+__STRICT_ANSI__%s+1" ~= nil
  local standard = year and ((strict and "c++" or "gnu++") .. year) or nil
  gcc_cpp_standards[compiler] = standard or false
  return gcc_cpp_standards[compiler] or nil
end

function M.trusted_query_driver(compiler, project_root)
  if not compiler or not M.is_absolute(compiler) or vim.fn.executable(compiler) ~= 1 then
    return false
  end
  if project_root and require("config.project").contains(project_root, compiler) then
    return false
  end
  return M.compiler_family(compiler) ~= nil
end

function M.clang_resource_dir(compiler)
  if not compiler then
    local toolchain = M.c_toolchain()
    compiler = toolchain and toolchain.compiler or nil
  end
  if not compiler or M.compiler_family(compiler) ~= "clang" then
    return nil
  end
  if clang_resource_dirs[compiler] ~= nil then
    return clang_resource_dirs[compiler] or nil
  end
  local directory = run { compiler, "-print-resource-dir" }
  if directory and vim.uv.fs_stat(M.join(directory, "include")) then
    clang_resource_dirs[compiler] = vim.fs.normalize(directory)
  else
    clang_resource_dirs[compiler] = false
  end
  return clang_resource_dirs[compiler] or nil
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
      toolchain.cmake,
      "-S",
      source_dir,
      "-B",
      build_dir,
      "-G",
      toolchain.generator,
      "-A",
      toolchain.architecture,
      "-DCMAKE_GENERATOR_INSTANCE:PATH=" .. toolchain.installation,
    }
  else
    configure = {
      toolchain.cmake,
      "-S",
      source_dir,
      "-B",
      build_dir,
      "-G",
      "MinGW Makefiles",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_C_COMPILER:FILEPATH=" .. toolchain.compiler,
      "-DCMAKE_CXX_COMPILER:FILEPATH=" .. toolchain.cxx_compiler,
      "-DCMAKE_MAKE_PROGRAM:FILEPATH=" .. toolchain.make,
    }
  end

  checked_system(configure, source_dir)
  checked_system({
    toolchain.cmake,
    "--build",
    build_dir,
    "--config",
    "Release",
    "--target",
    "install",
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
