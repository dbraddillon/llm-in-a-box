param(
  [Parameter(Mandatory)][string]$Model,
  [switch]$Force
)
. "$PSScriptRoot/_common.ps1"
Assert-Node

node "$Root/scripts/node/gen-manifest.mjs" | Out-Null
$manifest = Get-Content "$Root/build/manifest.generated.json" -Raw | ConvertFrom-Json
$entry = $manifest.models | Where-Object { $_.id -eq $Model }
if (-not $entry) {
  throw "no model '$Model' in models/manifest.yaml. Known: $(($manifest.models | ForEach-Object { $_.id }) -join ', ')"
}

$cacheDir = Join-Path $Root 'models/cache'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
$dest = Join-Path $cacheDir $entry.file

if ((Test-Path $dest) -and -not $Force) {
  Write-Host "$($entry.file) already cached at $dest (use -Force to re-download)"
  return
}

$url = "https://huggingface.co/$($entry.repo)/resolve/main/$($entry.file)"
Write-Host "downloading $url"
Write-Host "NOTE: this URL is a best-effort pointer -- if it 404s, check the repo on huggingface.co and update models/manifest.yaml"
Invoke-WebRequest -Uri $url -OutFile $dest

if ($entry.sha256) {
  $hash = (Get-FileHash $dest -Algorithm SHA256).Hash
  if ($hash -ne $entry.sha256) {
    Remove-Item $dest
    throw "sha256 mismatch for $($entry.file): expected $($entry.sha256), got $hash"
  }
} else {
  Write-Host "no sha256 pinned in manifest for $Model -- skipping checksum verification"
}

Write-Host "model '$Model' ready at $dest"
