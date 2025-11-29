# Phase125f-FullAutoRepair.ps1 (robust vercel detection)
$ErrorActionPreference = 'Stop'

function Log([string]$m,[string]$c='Gray'){ try{Write-Host $m -ForegroundColor $c}catch{Write-Host $m} }

# 1) Ensure we are not in System32
if ((Get-Location).Path -match '\\Windows\\System32$'){
  Log "Do not run from System32. cd to your project folder and re-run." 'Red'; exit 1
}

# 2) Ensure npm global path exists in PATH (current session + persist for user)
$npm = "$env:USERPROFILE\AppData\Roaming\npm"
if ((Test-Path $npm) -and ($env:Path -notlike "*$npm*")) {
    $env:Path = "$env:Path;$npm"
    [Environment]::SetEnvironmentVariable('Path',$env:Path,'User')
    Log "Added npm path to PATH: $npm" 'Green'
} else {
    Log "npm path already in PATH." 'Yellow'
}

# 3) Resolve Vercel CLI reliably
$vercelExe = "$npm\vercel.cmd"
if (-not (Test-Path $vercelExe)) {
  Log "Installing Vercel CLI globally..." 'Yellow'
  cmd /c "npm install -g vercel"
}

# 4) Version check (prefer direct .cmd; fall back to Get-Command)
function Get-VercelVersion {
  try {
    if (Test-Path $vercelExe) {
      $o = & $vercelExe --version 2>&1 | Out-String
    } else {
      $o = (Get-Command vercel -ErrorAction SilentlyContinue | Select-Object -First 1).Path
      if ($o) { $o = (& vercel --version 2>&1 | Out-String) }
    }
    return $o.Trim()
  } catch { return "" }
}

$ver = Get-VercelVersion
if ([string]::IsNullOrWhiteSpace($ver)) {
  Log "ERROR: Vercel CLI not responding. Try: npm uninstall -g vercel; npm install -g vercel" 'Red'
  exit 1
}

Log "Detected: $ver" 'Green'
Log "Vercel CLI is ready." 'Cyan'
