# Phase125g3-FullAutoRepair-Final.ps1
$ErrorActionPreference = 'Stop'

function Log([string]$msg, [string]$fg='Gray') { Write-Host $msg -ForegroundColor $fg }

Log "=== Full Auto Repair (Final - Stable) ===" Cyan

# 1. Ensure npm global bin is on PATH
$npmPath = Join-Path $env:APPDATA 'npm'
if ($env:Path -notlike "*$npmPath*") {
  [Environment]::SetEnvironmentVariable('Path', ($env:Path + ";" + $npmPath), 'User')
  $env:Path += ";" + $npmPath
  Log "Added npm global path: $npmPath" Green
} else {
  Log "npm global path already present: $npmPath" DarkGray
}

# Helper: safe command resolver
function Resolve-CmdPath([string]$name) {
  try {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source } else { return $null }
  } catch { return $null }
}

# 2. Locate Node.js
$nodeCmd = Resolve-CmdPath 'node'
if (-not $nodeCmd) {
  $cands = @(
    "$env:ProgramFiles\nodejs\node.exe",
    "$env:ProgramFiles(x86)\nodejs\node.exe"
  )
  foreach ($c in $cands) { if (Test-Path $c) { $nodeCmd = $c; break } }
}
if (-not $nodeCmd) {
  Log "[!] Node.js not found. Install Node LTS (20+) and re-run." Red
  exit 1
}
Log "Using Node: $nodeCmd" DarkGray
$nodeVer = & $nodeCmd -v
Log "Node version: $nodeVer" Green

# 3. Ensure Vercel CLI exists
$vercelCmd = Resolve-CmdPath 'vercel.cmd'
if (-not $vercelCmd) {
  Log "Installing Vercel CLI globally..." Yellow
  npm install -g vercel | Out-Null
  $vercelCmd = Resolve-CmdPath 'vercel.cmd'
}
if (-not $vercelCmd) {
  Log "[!] Vercel CLI still missing after reinstall. Open NEW 64-bit PowerShell and re-run." Red
  exit 1
}
Log "Using Vercel shim: $vercelCmd" DarkGray

# 4. Verify Vercel CLI (non-fatal capture)
try {
  $ver = cmd /c "vercel --version" 2>$null
  $ver = $ver.Trim()
  if ([string]::IsNullOrWhiteSpace($ver)) {
    Log "[!] Vercel CLI not responding correctly." Red
    exit 1
  } else {
    Log "[OK] Vercel CLI detected: $ver" Green
  }
} catch {
  Log "[!] Could not query Vercel version." Yellow
}

# 5. Optional whoami check
try {
  $who = cmd /c "vercel whoami" 2>$null
  if ($who) { Log ("vercel whoami: " + $who.Trim()) DarkGray }
} catch {}

Log "=== Repair Complete. You may now run Phase126-SafeLinkRepair.ps1 ===" Cyan
