[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Install,
  [switch]$Yes,
  [switch]$WithOptional,
  [switch]$SkipEditorBootstrap
)

$ErrorActionPreference = "Stop"
$MinimumNeovim = [version]"0.12.0"
$MinimumGit = [version]"2.19.0"
$MinimumTreeSitter = [version]"0.26.1"

if ($Check -and $Install) {
  throw "Use either -Check or -Install, not both."
}
if ($Yes -and -not $Install) {
  throw "-Yes is only valid together with -Install."
}

function Test-Command {
  param([Parameter(Mandatory)][string[]]$Name)
  foreach ($candidate in $Name) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
      return $true
    }
  }
  return $false
}

function Get-CommandVersion {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string[]]$Arguments
  )
  if (-not (Test-Command @($Name))) {
    return $null
  }
  try {
    $text = (& $Name @Arguments 2>&1 | Out-String)
    if ($text -match '(\d+\.\d+(?:\.\d+)?)') {
      return [version]$Matches[1]
    }
  }
  catch {
    return $null
  }
  return $null
}

function Test-MsvcBuildTools {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
  )
  foreach ($candidate in $candidates) {
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate)) {
      continue
    }
    $installation = & $candidate -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -eq 0 -and $installation) {
      return $true
    }
  }
  return $false
}

function Test-CCompiler {
  return (Test-Command @("cl", "clang", "clang-cl", "gcc")) -or (Test-MsvcBuildTools)
}

function Test-PythonVenv {
  foreach ($candidate in @("python", "python3")) {
    if (-not (Get-Command $candidate -ErrorAction SilentlyContinue)) {
      continue
    }
    try {
      & $candidate -c "import venv" 2>$null
      if ($LASTEXITCODE -eq 0) {
        return $true
      }
    }
    catch {
      continue
    }
  }
  return $false
}

function New-Dependency {
  param(
    [Parameter(Mandatory)][string]$Level,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][bool]$Available,
    [Parameter(Mandatory)][string]$Purpose,
    [string]$InstallHint = ""
  )
  [PSCustomObject]@{
    Level = $Level
    Name = $Name
    Available = $Available
    Purpose = $Purpose
    InstallHint = $InstallHint
  }
}

function Get-DependencyReport {
  $nvimVersion = Get-CommandVersion -Name "nvim" -Arguments @("--version")
  $gitVersion = Get-CommandVersion -Name "git" -Arguments @("--version")
  $treeSitterVersion = Get-CommandVersion -Name "tree-sitter" -Arguments @("--version")
  $python = Test-PythonVenv

  @(
    New-Dependency "required" "Neovim >= $MinimumNeovim" ($null -ne $nvimVersion -and $nvimVersion -ge $MinimumNeovim) "Run this configuration" "winget install -e --id Neovim.Neovim"
    New-Dependency "required" "Git >= $MinimumGit" ($null -ne $gitVersion -and $gitVersion -ge $MinimumGit) "Clone Lazy.nvim and plugins" "winget install -e --id Git.Git"
    New-Dependency "required" "ripgrep (rg)" (Test-Command @("rg")) "Telescope and project search/replace" "winget install -e --id BurntSushi.ripgrep.MSVC"
    New-Dependency "required" "curl" (Test-Command @("curl", "curl.exe")) "Download Tree-sitter parsers" "Install a current Windows curl or Git for Windows"
    New-Dependency "required" "tar" (Test-Command @("tar", "tar.exe")) "Extract Tree-sitter and Mason packages" "Install a current Windows tar or Git for Windows"
    New-Dependency "required" "7-Zip-compatible extractor" (Test-Command @("7z", "7za", "unzip", "WinRAR")) "Extract Mason packages" "winget install -e --id 7zip.7zip"
    New-Dependency "required" "PowerShell" (Test-Command @("pwsh", "powershell")) "Mason package installation" "winget install -e --id Microsoft.PowerShell"
    New-Dependency "required" "C/C++ compiler" (Test-CCompiler) "Compile Tree-sitter parsers" "Install Visual Studio Build Tools with Desktop development with C++"
    New-Dependency "required" "CMake" (Test-Command @("cmake")) "Use MSVC/MinGW and build telescope-fzf-native" "winget install -e --id Kitware.CMake"
    New-Dependency "required" "tree-sitter CLI >= $MinimumTreeSitter" ($null -ne $treeSitterVersion -and $treeSitterVersion -ge $MinimumTreeSitter) "Install the configured parsers" "Download the official tree-sitter CLI release"

    New-Dependency "needed" "fd/fdfind" (Test-Command @("fd", "fdfind")) "Python environment discovery" "winget install -e --id sharkdp.fd"
    New-Dependency "needed" "Node.js + npm" ((Test-Command @("node")) -and (Test-Command @("npm", "npm.cmd"))) "JSON/JavaScript tools and Copilot" "winget install -e --id OpenJS.NodeJS.LTS"
    New-Dependency "needed" "Python 3 + venv" $python "Python LSP, formatter, and debugger tools" "Install a current Python 3 release with pip and venv"

    New-Dependency "optional" "uv" (Test-Command @("uv")) "Python project/package commands" "winget install -e --id astral-sh.uv"
    New-Dependency "optional" "ImageMagick" (Test-Command @("magick")) "Non-PNG image conversion in Snacks" "winget install -e --id ImageMagick.ImageMagick"
    New-Dependency "optional" "Nerd Font" $false "File and UI icons (not automatically detectable)" "Install one Nerd Font and select it in the terminal"
  )
}

function Show-DependencyReport {
  param([Parameter(Mandatory)][object[]]$Report)
  foreach ($level in @("required", "needed", "optional")) {
    Write-Host ""
    Write-Host ("{0}:" -f $level.ToUpperInvariant()) -ForegroundColor Cyan
    foreach ($item in $Report | Where-Object Level -eq $level) {
      $mark = if ($item.Available) { "OK" } else { "MISSING" }
      $color = if ($item.Available) { "Green" } elseif ($level -eq "required") { "Red" } else { "Yellow" }
      Write-Host ("  [{0,-7}] {1} - {2}" -f $mark, $item.Name, $item.Purpose) -ForegroundColor $color
      if (-not $item.Available -and $item.InstallHint) {
        Write-Host ("            {0}" -f $item.InstallHint) -ForegroundColor DarkGray
      }
    }
  }
}

function Confirm-Action {
  param([Parameter(Mandatory)][string]$Prompt)
  if ($Yes) {
    return $true
  }
  $answer = Read-Host "$Prompt [y/N]"
  return $answer -match '^(?i:y|yes)$'
}

function Refresh-ProcessPath {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = @($machine, $user) -join ";"
}

function Invoke-WingetInstall {
  param(
    [Parameter(Mandatory)][string]$Id,
    [string[]]$ExtraArguments = @()
  )
  Write-Host "Installing $Id..." -ForegroundColor Cyan
  & winget install --exact --id $Id --accept-package-agreements --accept-source-agreements @ExtraArguments
  if ($LASTEXITCODE -ne 0) {
    throw "winget failed while installing $Id (exit code $LASTEXITCODE)."
  }
}

function Add-UserPath {
  param([Parameter(Mandatory)][string]$Directory)
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @($current -split ';' | Where-Object { $_ })
  if ($parts -notcontains $Directory) {
    [Environment]::SetEnvironmentVariable("Path", (($parts + $Directory) -join ";"), "User")
  }
  if (($env:Path -split ';') -notcontains $Directory) {
    $env:Path = "$Directory;$env:Path"
  }
}

function Install-TreeSitterCli {
  $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "x64" }
    "ARM64" { "arm64" }
    "x86" { "x86" }
    default { throw "Unsupported Windows architecture: $env:PROCESSOR_ARCHITECTURE" }
  }
  $asset = "tree-sitter-cli-windows-$architecture.zip"
  $url = "https://github.com/tree-sitter/tree-sitter/releases/latest/download/$asset"
  $installDirectory = Join-Path $env:LOCALAPPDATA "Programs\tree-sitter\bin"
  $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("nvim-bootstrap-" + [guid]::NewGuid().ToString("N"))

  Write-Host "Installing the official Tree-sitter CLI release..." -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
  New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
  try {
    $archive = Join-Path $temporaryDirectory $asset
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $temporaryDirectory -Force
    $binary = Get-ChildItem -LiteralPath $temporaryDirectory -Recurse -Filter "tree-sitter.exe" | Select-Object -First 1
    if (-not $binary) {
      throw "The Tree-sitter archive did not contain tree-sitter.exe."
    }
    Copy-Item -LiteralPath $binary.FullName -Destination (Join-Path $installDirectory "tree-sitter.exe") -Force
    Add-UserPath $installDirectory
  }
  finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
      $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
      $resolvedTemporary = [IO.Path]::GetFullPath($temporaryDirectory)
      if ($resolvedTemporary.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
          (Split-Path -Leaf $resolvedTemporary) -like "nvim-bootstrap-*") {
        Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
      }
      else {
        Write-Warning "Refusing to remove unexpected temporary path: $resolvedTemporary"
      }
    }
  }
}

function Install-Dependencies {
  if (-not (Test-Command @("winget"))) {
    throw "winget is unavailable. Install Microsoft's App Installer, reopen PowerShell, and run this script again."
  }

  $packages = @(
    "Neovim.Neovim",
    "Git.Git",
    "BurntSushi.ripgrep.MSVC",
    "7zip.7zip",
    "Kitware.CMake",
    "Microsoft.PowerShell",
    "sharkdp.fd",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.14"
  )
  foreach ($package in $packages) {
    Invoke-WingetInstall $package
  }

  if (-not (Test-CCompiler)) {
    Invoke-WingetInstall "Microsoft.VisualStudio.2022.BuildTools" @(
      "--override",
      "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
    )
  }

  Refresh-ProcessPath
  $treeSitterVersion = Get-CommandVersion -Name "tree-sitter" -Arguments @("--version")
  if ($null -eq $treeSitterVersion -or $treeSitterVersion -lt $MinimumTreeSitter) {
    Install-TreeSitterCli
  }
  if ($WithOptional) {
    foreach ($package in @("astral-sh.uv", "ImageMagick.ImageMagick")) {
      Invoke-WingetInstall $package
    }
  }
  Refresh-ProcessPath
}

function Invoke-EditorBootstrap {
  Write-Host ""
  Write-Host "Installing Neovim plugins..." -ForegroundColor Cyan
  $previousBootstrap = $env:NVIM_BOOTSTRAP
  $env:NVIM_BOOTSTRAP = "1"
  try {
    & nvim --headless "+Lazy! sync" "+qa"
    if ($LASTEXITCODE -ne 0) {
      throw "Lazy.nvim bootstrap failed (exit code $LASTEXITCODE)."
    }
    Write-Host "Installing Mason tools and Tree-sitter parsers..." -ForegroundColor Cyan
    & nvim --headless "+BootstrapInstall" "+qa"
    if ($LASTEXITCODE -ne 0) {
      throw "Editor tool bootstrap failed (exit code $LASTEXITCODE)."
    }
  }
  finally {
    $env:NVIM_BOOTSTRAP = $previousBootstrap
  }
}

Write-Host "ginko.nvim bootstrap (Windows)" -ForegroundColor Cyan
$report = @(Get-DependencyReport)
Show-DependencyReport $report

$missingHost = @($report | Where-Object { $_.Level -in @("required", "needed") -and -not $_.Available })
$systemInstallWanted = $Install -or (-not $Check -and ($missingHost.Count -gt 0 -or $WithOptional))
$shouldInstall = $false
if ($systemInstallWanted) {
  if (-not (Test-Command @("winget"))) {
    Write-Error "winget is unavailable. Install Microsoft's App Installer; this script will not guess or install a package manager."
    exit 2
  }
  $shouldInstall = Confirm-Action "Use winget to install required and needed dependencies?"
}

if ($shouldInstall) {
  Install-Dependencies
  $report = @(Get-DependencyReport)
  Show-DependencyReport $report
}

$missingRequired = @($report | Where-Object { $_.Level -eq "required" -and -not $_.Available })
if ($missingRequired.Count -gt 0) {
  Write-Error "Required dependencies are still missing. Neovim bootstrap was not started."
  exit 2
}

if (-not $Check -and -not $SkipEditorBootstrap) {
  if ($Install -or (Confirm-Action "Install plugins, Mason tools, and Tree-sitter parsers now?")) {
    Invoke-EditorBootstrap
  }
}

Write-Host ""
Write-Host "Bootstrap checks passed. Start Neovim with: nvim" -ForegroundColor Green
