# scripts/Phase325A-ActivityFeedBackend.ps1
# Phase 325A — Global Activity Feed (Prisma model + migrate + generate)
# - Refuses to run from system32
# - Ensures project root
# - Backs up prisma/schema.prisma
# - Runs prisma migrate dev + prisma generate + prisma validate
# - Logs to .\logs

[CmdletBinding()]
param(
  [string]$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern",
  [string]$MigrationName = "activity-events"
)

$ErrorActionPreference = "Stop"

function New-LogFile {
  param([string]$Root)
  $logsDir = Join-Path $Root "logs"
  if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  return Join-Path $logsDir "Phase325A-ActivityFeedBackend-$stamp.log"
}

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts][$Level] $Message"
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line
}

function Assert-NotSystem32 {
  $cwd = (Get-Location).Path
  if ($cwd -match '\\WINDOWS\\system32$' -or $cwd -match '\\Windows\\System32$') {
    throw "Refusing to run from $cwd. Change directory to your project root first."
  }
}

function Assert-ProjectRoot {
  param([string]$Root)
  if (-not (Test-Path $Root)) { throw "ProjectRoot not found: $Root" }

  $pkg = Join-Path $Root "package.json"
  $prismaDir = Join-Path $Root "prisma"
  $schema = Join-Path $prismaDir "schema.prisma"

  if (-not (Test-Path $pkg)) { throw "package.json not found in $Root" }
  if (-not (Test-Path $prismaDir)) { throw "prisma folder not found in $Root" }
  if (-not (Test-Path $schema)) { throw "prisma/schema.prisma not found in $Root" }

  return $schema
}

function Backup-File {
  param([string]$Path, [string]$Root, [string]$Tag)
  $bkDir = Join-Path $Root "backups\Phase325A"
  if (-not (Test-Path $bkDir)) { New-Item -ItemType Directory -Path $bkDir -Force | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $leaf = Split-Path $Path -Leaf
  $dest = Join-Path $bkDir "$leaf.$Tag.$stamp.bak"
  Copy-Item -Path $Path -Destination $dest -Force
  return $dest
}

function Run-Cmd {
  param(
    [string]$Exe,
    [string[]]$CmdArgs,
    [string]$WorkingDir
  )

  $argStr = ($CmdArgs -join " ")
  Write-Log "RUN: $Exe $argStr" "CMD"

  # Use cmd.exe so PATH resolution works for npx/npm/node on Windows
  $cmdLine = "$Exe $argStr"

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c $cmdLine"
  $psi.WorkingDirectory = $WorkingDir
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($stdout) { $stdout.TrimEnd().Split("`n") | ForEach-Object { Write-Log $_ "OUT" } }
  if ($stderr) { $stderr.TrimEnd().Split("`n") | ForEach-Object { Write-Log $_ "ERR" } }

  if ($p.ExitCode -ne 0) {
    throw "Command failed (exit $($p.ExitCode)): $cmdLine"
  }
}

try {
  Assert-NotSystem32

  if (-not (Test-Path $ProjectRoot)) {
    throw "ProjectRoot does not exist: $ProjectRoot"
  }

  $script:LogFile = New-LogFile -Root $ProjectRoot
  Write-Log "Phase 325A starting" "START"
  Write-Log "ProjectRoot: $ProjectRoot"
  Write-Log "MigrationName: $MigrationName"
  Write-Log "CurrentDir: $((Get-Location).Path)"

  $schemaPath = Assert-ProjectRoot -Root $ProjectRoot
  Write-Log "Found schema: $schemaPath"

  Set-Location -Path $ProjectRoot
  Write-Log "Changed directory to project root: $ProjectRoot"

  $backup = Backup-File -Path $schemaPath -Root $ProjectRoot -Tag "pre-migrate"
  Write-Log "Backed up schema.prisma to: $backup"

  $envPath = Join-Path $ProjectRoot ".env"
  if (-not $env:DATABASE_URL -and -not (Test-Path $envPath)) {
    Write-Log "Warning: DATABASE_URL env var is not set and .env not found at project root. Prisma may fail to connect." "WARN"
  } else {
    Write-Log "Environment looks OK (DATABASE_URL or .env present)."
  }

Run-Cmd -Exe "npx" -CmdArgs @("prisma","migrate","dev","-n",$MigrationName) -WorkingDir $ProjectRoot
Run-Cmd -Exe "npx" -CmdArgs @("prisma","generate") -WorkingDir $ProjectRoot
Run-Cmd -Exe "npx" -CmdArgs @("prisma","validate") -WorkingDir $ProjectRoot


  Write-Log "Phase 325A complete ✅" "DONE"
  Write-Host ""
  Write-Host "✅ Phase 325A complete. Log: $script:LogFile"
}
catch {
  if (-not $script:LogFile) {
    $script:LogFile = Join-Path $PWD "Phase325A-FAILED.log"
    try { New-Item -ItemType File -Path $script:LogFile -Force | Out-Null } catch {}
  }
  Write-Log $_.Exception.Message "FAIL"
  Write-Host ""
  Write-Host "❌ Phase 325A failed. See log: $script:LogFile"
  throw
}
