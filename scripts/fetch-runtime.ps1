<#
.SYNOPSIS
  Download a prebuilt llama-server (CPU-only) binary for one platform.
.DESCRIPTION
  Pulls from the most recent ggml-org/llama.cpp release. llama.cpp ships build-numbered
  releases (e.g. "b10664") always marked as GitHub prereleases -- there is no
  semver "latest", so this walks /releases and takes the first (most recent) entry
  rather than /releases/latest.

  Asset naming verified against the live release list on 2026-08-27:
    win-x64      llama-<build>-bin-win-cpu-x64.zip
    win-arm64    llama-<build>-bin-win-cpu-arm64.zip
    macos-arm64  llama-<build>-bin-macos-arm64.tar.gz
    macos-x64    llama-<build>-bin-macos-x64.tar.gz
    linux-x64    llama-<build>-bin-ubuntu-x64.tar.gz
    linux-arm64  llama-<build>-bin-ubuntu-arm64.tar.gz
  If a suffix below 404s or stops matching, check
  https://github.com/ggml-org/llama.cpp/releases for the current names.
#>
param(
  [ValidateSet('win-x64', 'win-arm64', 'macos-arm64', 'macos-x64', 'linux-x64', 'linux-arm64')]
  [string]$Platform,
  [switch]$Force
)
. "$PSScriptRoot/_common.ps1"

if (-not $Platform) {
  $Platform = Get-CurrentPlatform
  Write-Host "auto-detected platform: $Platform"
}

$PlatformAssets = @{
  'win-x64'     = @{ suffix = 'bin-win-cpu-x64.zip';     binName = 'llama-server.exe' }
  'win-arm64'   = @{ suffix = 'bin-win-cpu-arm64.zip';   binName = 'llama-server.exe' }
  'macos-arm64' = @{ suffix = 'bin-macos-arm64.tar.gz';  binName = 'llama-server' }
  'macos-x64'   = @{ suffix = 'bin-macos-x64.tar.gz';    binName = 'llama-server' }
  'linux-x64'   = @{ suffix = 'bin-ubuntu-x64.tar.gz';   binName = 'llama-server' }
  'linux-arm64' = @{ suffix = 'bin-ubuntu-arm64.tar.gz'; binName = 'llama-server' }
}
$target = $PlatformAssets[$Platform]

$destDir = Join-Path $Root "runtime-bin/$Platform"
$binPath = Join-Path $destDir $target.binName
if ((Test-Path $binPath) -and -not $Force) {
  Write-Host "$Platform llama-server already cached at $binPath (use -Force to re-fetch)"
  return
}

Write-Host "looking up latest llama.cpp build..."
$releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/ggml-org/llama.cpp/releases' -Headers @{ 'User-Agent' = 'llm-in-a-box' }
$release = $releases | Select-Object -First 1
$asset = $release.assets | Where-Object { $_.name -like "llama-*-$($target.suffix)" } | Select-Object -First 1
if (-not $asset) {
  throw "no asset matching 'llama-*-$($target.suffix)' in release $($release.tag_name) -- check https://github.com/ggml-org/llama.cpp/releases and update this script"
}

Write-Host "downloading $($asset.name) from build $($release.tag_name)"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$tempDir = Get-TempDir
$archivePath = Join-Path $tempDir $asset.name
& (Get-CurlCommand) -L --fail --retry 3 -C - -o "$archivePath" $asset.browser_download_url
if ($LASTEXITCODE -ne 0) { throw "download failed for $($asset.name)" }

$stage = Join-Path $tempDir "llama-runtime-stage-$Platform"
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null
if ($asset.name -like '*.zip') {
  Expand-Archive -Path $archivePath -DestinationPath $stage -Force
} else {
  tar -xzf $archivePath -C $stage
  # Linux/macOS .so files ship as a chain of symlinks (libfoo.so -> libfoo.so.0 ->
  # libfoo.so.0.1.2, the real file) that the dynamic linker looks up by the shorter
  # names. Windows' tar.exe needs SeCreateSymbolicLinkPrivilege (admin, or Developer
  # Mode) to create them and otherwise silently drops those entries with an
  # "Invalid argument" error instead of failing the extraction -- so fetching a
  # non-Windows runtime *from a Windows machine* can produce a binary that's missing
  # the libraries it dlopen's by SONAME. Real symlink creation would hit the exact
  # same privilege wall, so fill the gap with plain file copies instead (harmless
  # no-ops on a platform where tar already created real symlinks, since those
  # already resolve and get skipped below).
  Get-ChildItem $stage -Recurse -File | Where-Object { $_.Name -match '^(lib.+?\.so)\.\d+(\.\d+)*$' } | ForEach-Object {
    $base = $Matches[1]
    $major = ($_.Name -split '\.so\.')[1].Split('.')[0]
    foreach ($alias in @($base, "$base.$major")) {
      $aliasPath = Join-Path $_.DirectoryName $alias
      if (-not (Test-Path $aliasPath)) { Copy-Item $_.FullName $aliasPath }
    }
  }
}

$found = Get-ChildItem $stage -Recurse -Filter $target.binName | Select-Object -First 1
if (-not $found) { throw "could not find $($target.binName) inside $($asset.name)" }
# llama-server is a thin launcher that dlopen's sibling ggml-cpu-*/llama*/mtmd DLLs at
# runtime (CPU-feature dispatch) -- copy the whole extracted dir alongside it, not just
# the one binary, or it fails to start with a missing-DLL error.
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item (Join-Path $found.DirectoryName '*') $destDir -Recurse -Force
if ($Platform -notlike 'win-*') {
  chmod +x $binPath 2>$null
}

Remove-Item $archivePath -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
Write-Host "llama-server ($Platform, build $($release.tag_name)) ready at $binPath"
