# --- Phase125g: Force Vercel CLI Repair & Verify (Windows) ---
$ErrorActionPreference = 'Stop'

$npmPath    = Join-Path $env:APPDATA 'npm'
$vercelCmd  = Join-Path $npmPath     'vercel.cmd'
$nodeHome   = Join-Path $env:ProgramFiles 'nodejs'
$nodeExe    = Join-Path $nodeHome      'node.exe'

Write-Host "[1/5] Ensuring Node & npm global bin are on PATH..."
$needPersist = $false
if ($env:Path -notlike "*$nodeHome*") { $env:Path = "$env:Path;$nodeHome"; $needPersist = $true }
if ($env:Path -notlike "*$npmPath*")  { $env:Path = "$env:Path;$npmPath";  $needPersist = $true }
if ($needPersist) {
  [Environment]::SetEnvironmentVariable('Path', $env:Path, 'User')
  Write-Host "      PATH updated for current session and user." -ForegroundColor Green
} else {
  Write-Host "      PATH already OK." -ForegroundColor Yellow
}

if (-not (Test-Path $nodeExe)) {
  Write-Host "[!] Node.js not found at $nodeExe. Install Node 18+ and re-run." -ForegroundColor Red
  exit 1
}

Write-Host "[2/5] Reinstalling Vercel CLI globally..."
try { npm -v | Out-Null } catch { Write-Host "npm not available on PATH." -ForegroundColor Red; exit 1 }

try { npm uninstall -g vercel | Out-Null } catch { }
npm cache verify | Out-Null
npm install -g vercel

Write-Host "[3/5] Verifying Vercel CLI..."
if (-not (Test-Path $vercelCmd)) {
  Write-Host "[!] vercel.cmd not found at $vercelCmd" -ForegroundColor Red
  Get-ChildItem $npmPath -Filter *vercel* | ForEach-Object { $_.FullName }
  exit 1
}

$ver = & $vercelCmd --version 2>&1 | Out-String
$ver = $ver.Trim()
if ([string]::IsNullOrWhiteSpace($ver)) {
  Write-Host "[!] Vercel CLI still not responding." -ForegroundColor Red
  exit 1
} else {
  Write-Host "[OK] Vercel CLI detected: $ver" -ForegroundColor Green
}

try {
  $who = & $vercelCmd whoami 2>&1 | Out-String
  if ($who) { Write-Host "[info] vercel whoami: $($who.Trim())" -ForegroundColor DarkGray }
} catch { }

Write-Host "=== Repair complete. You can now run your Phase125 alias script ===" -ForegroundColor Cyan
Read-Host "Press Enter to close..."
