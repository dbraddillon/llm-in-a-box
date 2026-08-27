param([Parameter(Mandatory)][string]$Pack)
. "$PSScriptRoot/_common.ps1"
Assert-Node
node "$Root/scripts/node/gen-manifest.mjs" | Out-Null
node "$Root/scripts/node/build-pack.mjs" $Pack
