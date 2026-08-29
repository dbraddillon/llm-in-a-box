<#
.SYNOPSIS
  Prove an assembled box can actually answer a question with zero network access.
.DESCRIPTION
  Assembles a box (via load-drive.ps1), builds a Docker image from it, runs that
  image with --network none, and sends it a real chat request. Confirms network
  isolation itself (checks /proc/net/dev for a non-loopback interface) rather than
  assuming --network none did what it says.

  This exists because "verified offline" claims made by hand-testing on normal dev
  machines are worthless -- every dev machine has live internet, which silently
  masks exactly the class of bug this catches (see docs/01-architecture.md's
  2026-08-29 entry: a shipped box needed internet on its first query, invisible in
  every previous test for this exact reason).

  Always targets a Linux container, matching the Docker daemon's own architecture
  (Docker Desktop runs a Linux VM regardless of host OS) -- not necessarily this
  machine's own platform. Requires that platform's llama-server already fetched
  (fetch-runtime.ps1 -Platform <that-platform>) and every requested pack already
  built (build-pack.ps1).
#>
param(
  [string[]]$Packs = @('survival-sample'),
  [Parameter(Mandatory)][string]$Model
)
. "$PSScriptRoot/_common.ps1"
Assert-Node

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "docker is required for this check (https://www.docker.com/products/docker-desktop) -- not found on PATH."
}

$dockerArch = (docker version --format '{{.Server.Arch}}').Trim()
$dockerPlatform = switch ($dockerArch) {
  'amd64' { 'linux-x64' }
  'arm64' { 'linux-arm64' }
  default { throw "unrecognized docker server arch '$dockerArch' -- don't know which llama-server build to bundle" }
}
Write-Host "docker server arch: $dockerArch -> targeting $dockerPlatform"

if (-not (Test-Path (Join-Path $Root "runtime-bin/$dockerPlatform/llama-server"))) {
  throw "no $dockerPlatform llama-server cached -- run ./scripts/fetch-runtime.ps1 -Platform $dockerPlatform first"
}
foreach ($pack in $Packs) {
  if (-not (Test-Path (Join-Path $Root "build/index/$pack.sqlite"))) {
    throw "pack '$pack' not built yet -- run ./scripts/build-pack.ps1 -Pack $pack first"
  }
}

$boxDir = Join-Path (Get-TempDir) 'llm-in-a-box-offline-verify-box'
Remove-Item -Recurse -Force $boxDir -ErrorAction SilentlyContinue
Write-Host "assembling $dockerPlatform box for offline verification..."
& "$PSScriptRoot/load-drive.ps1" -Packs $Packs -Model $Model -Output $boxDir -Platform $dockerPlatform
Copy-Item "$PSScriptRoot/offline-verify-query.mjs" $boxDir

$imageTag = 'llm-in-a-box-offline-verify'
Write-Host "building docker image (network available at build time; that's fine, the run below isn't)..."
docker build -f "$PSScriptRoot/offline-verify.Dockerfile" -t $imageTag $boxDir
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }

$containerName = 'llm-in-a-box-offline-verify-run'
# docker rm on a nonexistent container writes to stderr and exits non-zero, which
# PowerShell's stream redirection turns into a terminating error under
# $ErrorActionPreference='Stop' (see _common.ps1) even though this is a harmless
# best-effort cleanup -- try/catch instead of `2>$null`, which doesn't have that
# problem. Checking existence first also avoids printing a "no such container"
# error on the common case (no stale run from last time).
if (docker ps -aq --filter "name=$containerName") {
  try { docker rm -f $containerName | Out-Null } catch {}
}
Write-Host "starting container with --network none..."
docker run -d --name $containerName --network none $imageTag | Out-Null

try {
  $netDev = docker exec $containerName cat /proc/net/dev
  if ($netDev -match '^\s*\w*eth\d') {
    throw "container has a non-loopback network interface -- --network none isolation didn't take as expected:`n$netDev"
  }
  Write-Host "confirmed: only loopback visible inside the container"

  Write-Host "waiting for the box to answer (llama-server model load can take a while)..."
  $deadline = (Get-Date).AddSeconds(90)
  $answered = $false
  $lastAttempt = $null
  while ((Get-Date) -lt $deadline) {
    $lastAttempt = docker exec $containerName node /box/offline-verify-query.mjs
    try {
      $parsed = $lastAttempt | ConvertFrom-Json
      if ($parsed.status -eq 200 -and $parsed.text) {
        $answered = $true
        Write-Host "response: $($parsed.text)"
        Write-Host "sources:  $($parsed.sources)"
        break
      }
    } catch {
      # not valid JSON yet (server not up) -- keep polling
    }
    Start-Sleep -Seconds 3
  }

  if (-not $answered) {
    throw "box did not answer within 90s. last attempt: $lastAttempt"
  }

  Write-Host ""
  Write-Host "PASS: box answered a real question with zero network access ($dockerPlatform)."
} catch {
  # Same PowerShell-native-stderr gotcha as above -- no stream redirection here either.
  Write-Host "--- container logs ---"
  docker logs $containerName
  throw
} finally {
  try { docker rm -f $containerName | Out-Null } catch {}
}
