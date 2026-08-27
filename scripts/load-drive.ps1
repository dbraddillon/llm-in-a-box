param(
  [Parameter(Mandatory)][string[]]$Packs,
  [Parameter(Mandatory)][string]$Model,
  [Parameter(Mandatory)][string]$Output
)
. "$PSScriptRoot/_common.ps1"

node "$Root/scripts/node/gen-manifest.mjs" | Out-Null
$manifest = Get-Content "$Root/build/manifest.generated.json" -Raw | ConvertFrom-Json
$modelEntry = $manifest.models | Where-Object { $_.id -eq $Model }
if (-not $modelEntry) { throw "unknown model '$Model'" }
$modelFile = Join-Path $Root "models/cache/$($modelEntry.file)"
if (-not (Test-Path $modelFile)) { throw "model not fetched yet -- run fetch-model.ps1 -Model $Model first" }

if (Test-Path $Output) { Remove-Item $Output -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Output | Out-Null

Write-Host "copying runtime..."
Copy-Item "$Root/runtime/server" "$Output/server" -Recurse
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
Write-Host "NOTE: no llama-server binary bundled yet -- copy one into $Output/bin/ (see docs/01-architecture.md)"

$stamp = @{
  builtAt = (Get-Date).ToString('o')
  packs   = $Packs
  model   = $Model
} | ConvertTo-Json
Set-Content -Path "$Output/manifest.json" -Value $stamp

Write-Host "assembled box at $Output"
