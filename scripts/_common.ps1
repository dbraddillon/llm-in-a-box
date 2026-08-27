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
