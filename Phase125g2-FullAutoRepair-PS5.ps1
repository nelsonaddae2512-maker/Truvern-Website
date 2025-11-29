# Phase125g2-FullAutoRepair-PS5.ps1
$ErrorActionPreference = 'Stop'

function Log([string]$msg, [string]$fg='Gray') { Write-Host $msg -ForegroundColor $fg }

Log "=== Full Auto Repair (PS5-compatible) ===" Cyan

# 1) Ensure npm global bin is on PATH (for vercel.cmd)
$npmPath = Join-Path $env:APPDATA 'npm'
if ($env:Path -notlike "*$npmPath*") {
  [Environment]::SetEnvironmentVariable('Path', ($env:Path + ";" + $npmPath), 'User')
  $env:Path += ";" + $npmPath
  Log "Added npm global path: $npmPath" Green
} else {
  Log "npm global path already present: $npmPath" DarkGray
}

# Helper: safe Get-Command returning Source string
function Resolve-CmdPath([string]$name) {
  try {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source } else { return $null }
  } catch { return $null }
}

# 2) Locate Node.js (prefer actual command, then common install dirs)
$nodeCmd = Resolve-CmdPath 'node'
if (-not $nodeCmd) {
  $cands = @(
    "$env:ProgramFiles\nodejs\node.exe",
    "$env:ProgramFiles(x86)\nodejs\node.exe"
  )
  foreach ($c in $cands) { if (Test-Path $c) { $nodeCmd = $c; break } }
}
if (-not $nodeCmd) {
  Log "[!] Node.js not found. Please install Node LTS (20+) and re-run." Red
  exit 1
}
Log "Using Node: $nodeCmd" DarkGray
$nodeVer = & $nodeCmd -v
Log "Node version: $nodeVer" Green

# 3) Ensure Vercel CLI present (global)
$vercelCmd = Resolve-CmdPath 'vercel.cmd'
if (-not $vercelCmd) {
  Log "Installing Vercel CLI globally..." Yellow
  npm install -g vercel | Out-Null
  $vercelCmd = Resolve-CmdPath 'vercel.cmd'
}
if (-not $vercelCmd) {
  Log "[!] Vercel CLI still not in PATH. Open a NEW 64-bit PowerShell window and re-run this script." Red
  exit 1
}
Log "Using vercel shim: $vercelCmd" DarkGray

# 4) Verify Vercel CLI really runs (bypass any alias/shim weirdness)
try {
  $ver = & $vercelCmd --version 2>$null | Out-String
  $ver = $ver.Trim()
  if ([string]::IsNullOrWhiteSpace($ver)) {
    throw "Vercel CLI not responding"
  }
  Log "Vercel CLI: $ver" Green
} catch {
  Log "[!] Vercel CLI not responding. Trying reinstall..." Yellow
  npm uninstall -g vercel | Out-Null
  npm install -g vercel | Out-Null
  $vercelCmd = Resolve-CmdPath 'vercel.cmd'
  if (-not $vercelCmd) {
    Log "[!] Vercel CLI still missing after reinstall. Open a NEW 64-bit PowerShell and re-run." Red
    exit 1
  }
  $ver = & $vercelCmd --version 2>$null | Out-String
  $ver = $ver.Trim()
  if ([string]::IsNullOrWhiteSpace($ver)) {
    Log "[!] Vercel CLI still not responding. Please open a NEW PowerShell window and run again." Red
    exit 1
  }
  Log "Vercel CLI: $ver" Green
}

# 5) Optional quick scope/auth sanity (non-fatal)
try {
  $who = & $vercelCmd whoami 2>$null | Out-String
  if ($who) { Log ("vercel whoami: " + $who.Trim()) DarkGray }
} catch {}

Log "=== Repair complete. You can continue with alias/link scripts. ===" Cyan
