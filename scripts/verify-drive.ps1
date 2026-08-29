param([Parameter(Mandatory)][string]$Path)
. "$PSScriptRoot/_common.ps1"

$required = @(
  'server/index.mjs',
  'server/.model-cache/Xenova/all-MiniLM-L6-v2/onnx/model.onnx',
  'chat-ui/dist/index.html',
  'model/model.gguf',
  'manifest.json'
)
$missing = $required | Where-Object { -not (Test-Path (Join-Path $Path $_)) }
if ($missing) {
  Write-Warning "missing: $($missing -join ', ')"
} else {
  Write-Host "all expected files present"
}

$indexFiles = Get-ChildItem (Join-Path $Path 'index') -Filter *.sqlite -ErrorAction SilentlyContinue
if (-not $indexFiles) {
  Write-Warning "no .sqlite index files found under $Path/index"
} else {
  Write-Host "found $($indexFiles.Count) index file(s): $($indexFiles.Name -join ', ')"
}

$hasBin = (Test-Path (Join-Path $Path 'bin/llama-server.exe')) -or (Test-Path (Join-Path $Path 'bin/llama-server'))
if (-not $hasBin) {
  Write-Warning "no llama-server binary in $Path/bin -- launch.cmd/launch.sh will fail until one is added"
}
