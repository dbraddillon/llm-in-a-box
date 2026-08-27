. "$PSScriptRoot/scripts/_common.ps1"
Assert-Node

Push-Location $Root
try {
  npm install
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "JS deps installed. Next steps:"
Write-Host "  1. cd runtime/chat-ui; npm run build   (produces chat-ui/dist for load-drive to bundle)"
Write-Host "  2. ./scripts/fetch-content.ps1 -Pack survival-sample"
Write-Host "  3. ./scripts/build-pack.ps1 -Pack survival-sample"
Write-Host "  4. cd builder; npm run dev             (build wizard UI, http://127.0.0.1:5173)"
