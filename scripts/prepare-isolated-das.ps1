#requires -Version 7.0
<#
.SYNOPSIS
  Prepare a disposable DAS-Testing checkout and register it in a dedicated,
  loopback-only ephemeral PostgreSQL container. Does NOT start any worker,
  provider, release, or real autonomous task.
.EXAMPLE
  pwsh -File .\scripts\prepare-isolated-das.ps1 -DASPath 'D:\path\to\DAS' -TestingPath 'D:\DAS-Testing'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $DASPath,
  [string] $TestingPath = (Join-Path $HOME 'DAS-Testing'),
  [string] $ContainerName = 'das-testing-qualification-db',
  [ValidateRange(1025,65535)][int] $HostPort = 55437
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedRemote = 'https://github.com/abhijithsuresh700/DAS-Testing.git'
$DASPath = [System.IO.Path]::GetFullPath($DASPath)
$TestingPath = [System.IO.Path]::GetFullPath($TestingPath)

function Assert-Command([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required command '$name' missing from PATH. No runtime changes were made."
  }
}
function Invoke-Checked([string]$program, [string[]]$arguments) {
  & $program @arguments
  if ($LASTEXITCODE -ne 0) { throw "$program exited with code $LASTEXITCODE" }
}
foreach ($command in @('git','docker','node','pnpm')) { Assert-Command $command }
if (-not (Test-Path (Join-Path $DASPath 'src/cli/index.ts'))) {
  throw "DASPath must point to your actual DAS source checkout."
}
if ((& docker info --format '{{.ServerVersion}}' 2>$null | Out-String).Trim().Length -eq 0 -or $LASTEXITCODE -ne 0) {
  throw "Docker daemon is not available. Start Docker Desktop first."
}

if (-not (Test-Path $TestingPath)) {
  Write-Host "Cloning only the disposable fixture into $TestingPath"
  Invoke-Checked 'git' @('clone','--branch','main','--single-branch',$expectedRemote,$TestingPath)
}
$origin = (& git -C $TestingPath remote get-url origin 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -ne $expectedRemote) {
  throw "Refusing to register checkout with unexpected origin: '$origin'"
}
if (-not (Test-Path (Join-Path $TestingPath '.das/project.yaml'))) {
  throw "Missing .das/project.yaml. Pull the fixture's merged main branch first."
}
$branch = (& git -C $TestingPath branch --show-current | Out-String).Trim()
if ($branch -ne 'main') { throw "Expected test checkout on main, got '$branch'." }
Write-Host 'Verifying the disposable fixture baseline...'
Push-Location $TestingPath
try {
  Invoke-Checked 'node' @('--test')
  Invoke-Checked 'node' @('--check','src/slug.js')
} finally { Pop-Location }

$runtimeDir = Join-Path $env:LOCALAPPDATA 'DAS-Testing-Qualification'
$connectionFile = Join-Path $runtimeDir 'connection.ps1'
$existing = (& docker container inspect --format '{{.State.Running}}' $ContainerName 2>$null | Out-String).Trim()
if ($existing) {
  throw "Container '$ContainerName' already exists. Refusing to replace or attach to an unverified database. Investigate and remove manually if it is disposable."
}
if (Test-Path $connectionFile) {
  throw "Previous local test connection file exists at $connectionFile. Refusing to overwrite it."
}

$password = [guid]::NewGuid().ToString('N')
$portBinding = "127.0.0.1:${HostPort}:5432"
Write-Host "Creating a NEW disposable PostgreSQL instance bound only to $portBinding"
Invoke-Checked 'docker' @(
  'run','--detach','--rm','--name',$ContainerName,
  '--publish',$portBinding,
  '--env','POSTGRES_USER=das_qualification',
  '--env',("POSTGRES_PASSWORD="+$password),
  '--env','POSTGRES_DB=das_qualification',
  'postgres:16'
)
try {
  $ready = $false
  for ($i = 0; $i -lt 45; $i++) {
    & docker exec $ContainerName pg_isready -U das_qualification -d das_qualification *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $ready) { throw 'Disposable PostgreSQL did not become ready.' }
  # Set the DB URL only for this PowerShell process and its child CLI processes.
  # Never reuse any ambient DAS_DATABASE_URL (which might target production).
  $env:DAS_DATABASE_URL = "postgres://das_qualification:${password}@127.0.0.1:${HostPort}/das_qualification"
  $env:SUPABASE_DAS_TEST_DATABASE_URL = ''
  Push-Location $DASPath
  try {
    Invoke-Checked 'pnpm' @('exec','tsx','src/cli/index.ts','db','migrate')
    Invoke-Checked 'pnpm' @('exec','tsx','src/cli/index.ts','project','add','--name','das-testing','--repo',$TestingPath)
    Invoke-Checked 'pnpm' @('exec','tsx','src/cli/index.ts','project','remote','set','das-testing',$expectedRemote)
    Invoke-Checked 'pnpm' @('exec','tsx','src/cli/index.ts','project','checkout','set','das-testing',$TestingPath)
    Invoke-Checked 'pnpm' @('exec','tsx','src/cli/index.ts','project','doctor','das-testing')
  } finally { Pop-Location }
  New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
  # This file remains outside Git, in your Windows LOCALAPPDATA folder.
  # It contains a password for the disposable loopback test DB only.
  $scriptLine = '$env:DAS_DATABASE_URL = ' + "'" + $env:DAS_DATABASE_URL + "'"
  Set-Content -Path $connectionFile -Value $scriptLine -Encoding utf8 -NoNewline
  Write-Host "Isolated DAS project registration completed."
  Write-Host "Connection file (local only): $connectionFile"
  Write-Host "To run a later local test command: . '$connectionFile'"
  Write-Host "To stop and discard the test database: docker stop $ContainerName"
} catch {
  Write-Warning 'Setup failed. The disposable container is stopped; no production database was targeted.'
  & docker stop $ContainerName *> $null
  throw
}
