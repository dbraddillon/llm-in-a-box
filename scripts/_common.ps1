$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Assert-Node {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "node.js is required (https://nodejs.org) -- not found on PATH."
  }
}
