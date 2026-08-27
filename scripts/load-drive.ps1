param(
  [Parameter(Mandatory)][string[]]$Packs,
  [Parameter(Mandatory)][string]$Model,
  [Parameter(Mandatory)][string]$Output,
  [ValidateSet('win-x64', 'win-arm64', 'macos-arm64', 'macos-x64', 'linux-x64', 'linux-arm64')]
  [string]$Platform
)
. "$PSScriptRoot/_common.ps1"

if (-not $Platform) { $Platform = Get-CurrentPlatform }

node "$Root/scripts/node/gen-manifest.mjs" | Out-Null
$manifest = Get-Content "$Root/build/manifest.generated.json" -Raw | ConvertFrom-Json
$modelEntry = $manifest.models | Where-Object { $_.id -eq $Model }
if (-not $modelEntry) { throw "unknown model '$Model'" }
$modelFile = Join-Path $Root "models/cache/$($modelEntry.file)"
if (-not (Test-Path $modelFile)) { throw "model not fetched yet -- run fetch-model.ps1 -Model $Model first" }

if (Test-Path $Output) { Remove-Item $Output -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Output | Out-Null

Write-Host "copying runtime..."
Copy-Item "$Root/runtime/server" "$Output/server" -Recurse -Exclude node_modules
# runtime/server's deps are hoisted into the repo root's node_modules by npm workspaces
# during dev -- that root won't exist wherever this output folder ends up, so give the
# output its own standalone install rather than relying on Node's upward module lookup.
Write-Host "installing runtime server deps into output (standalone, not a workspace)..."
Push-Location "$Output/server"
try { npm install --omit=dev --no-audit --no-fund | Out-Null } finally { Pop-Location }
if (Test-Path "$Root/runtime/chat-ui/dist") {
  Copy-Item "$Root/runtime/chat-ui/dist" "$Output/chat-ui/dist" -Recurse
} else {
  Write-Host "NOTE: runtime/chat-ui/dist missing -- run 'npm run build' in runtime/chat-ui first"
}
Copy-Item "$Root/runtime/launch.cmd" $Output
Copy-Item "$Root/runtime/launch.sh" $Output
Copy-Item "$Root/runtime/README.md" $Output

New-Item -ItemType Directory -Force -Path "$Output/index" | Out-Null
foreach ($pack in $Packs) {
  $src = Join-Path $Root "build/index/$pack.sqlite"
  if (-not (Test-Path $src)) { throw "pack '$pack' not built yet -- run build-pack.ps1 -Pack $pack first" }
  Copy-Item $src "$Output/index/$pack.sqlite"
}

New-Item -ItemType Directory -Force -Path "$Output/model" | Out-Null
Copy-Item $modelFile "$Output/model/model.gguf"

New-Item -ItemType Directory -Force -Path "$Output/bin" | Out-Null
$binName = if ($Platform -like 'win-*') { 'llama-server.exe' } else { 'llama-server' }
$binCacheDir = Join-Path $Root "runtime-bin/$Platform"
if (Test-Path (Join-Path $binCacheDir $binName)) {
  # llama-server depends on sibling DLLs (ggml-cpu-*, llama-server-impl, mtmd, ...) --
  # copy the whole cached directory, not just the exe, or it fails to start.
  Copy-Item (Join-Path $binCacheDir '*') "$Output/bin" -Recurse -Force
  Write-Host "bundled llama-server for $Platform"
} else {
  Write-Warning "no llama-server cached for $Platform -- run ./scripts/fetch-runtime.ps1 -Platform $Platform first"
}

$stamp = @{
  builtAt  = (Get-Date).ToString('o')
  packs    = $Packs
  model    = $Model
  platform = $Platform
} | ConvertTo-Json
Set-Content -Path "$Output/manifest.json" -Value $stamp

Write-Host "assembled box at $Output"
