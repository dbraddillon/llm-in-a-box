$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Assert-Node {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "node.js is required (https://nodejs.org) -- not found on PATH."
  }
}

# Works under both pwsh (PS7, where $IsWindows/$IsMacOS/$IsLinux exist) and Windows
# PowerShell 5.1 (where they don't -- 5.1 only ever runs on Windows).
function Get-CurrentPlatform {
  $isWin = ($env:OS -eq 'Windows_NT') -or $IsWindows
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  $isArm = $arch -like 'Arm*'
  if ($isWin) { return $(if ($isArm) { 'win-arm64' } else { 'win-x64' }) }
  if ($IsMacOS) { return $(if ($isArm) { 'macos-arm64' } else { 'macos-x64' }) }
  if ($IsLinux) { return $(if ($isArm) { 'linux-arm64' } else { 'linux-x64' }) }
  throw "could not auto-detect platform -- pass -Platform explicitly"
}

function Test-IsWindowsPlatform {
  return ($env:OS -eq 'Windows_NT') -or $IsWindows
}

# Windows PowerShell 5.1 aliases `curl` to Invoke-WebRequest, so scripts need the real
# curl.exe explicitly there. pwsh doesn't define that alias on any platform, and on
# Mac/Linux the binary itself is just `curl`, not `curl.exe` -- there's no .exe there.
function Get-CurlCommand {
  return $(if (Test-IsWindowsPlatform) { 'curl.exe' } else { 'curl' })
}

# $env:TEMP is a Windows-only environment variable -- macOS/Linux don't set it (Mac
# uses $env:TMPDIR, Linux conventionally just /tmp, neither guaranteed). .NET's
# GetTempPath() resolves the right one on every platform.
function Get-TempDir {
  return [System.IO.Path]::GetTempPath().TrimEnd('/', '\')
}
