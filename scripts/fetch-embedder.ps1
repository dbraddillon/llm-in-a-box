param([switch]$Force)
. "$PSScriptRoot/_common.ps1"
Assert-Node

$cacheDir = Join-Path $Root 'runtime/server/.model-cache'
$modelFile = Join-Path $cacheDir 'Xenova/all-MiniLM-L6-v2/onnx/model.onnx'

if ((Test-Path $modelFile) -and -not $Force) {
  Write-Host "embedding model already cached at $cacheDir (use -Force to re-fetch)"
  return
}

node "$Root/scripts/node/fetch-embedder.mjs"
