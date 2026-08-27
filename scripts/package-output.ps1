param([Parameter(Mandatory)][string]$Path)
. "$PSScriptRoot/_common.ps1"

$zip = "$Path.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$Path/*" -DestinationPath $zip
Write-Host "packaged $zip"
