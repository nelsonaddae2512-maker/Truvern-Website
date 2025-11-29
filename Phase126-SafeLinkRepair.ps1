# Phase126-SafeLinkRepair.ps1
$ErrorActionPreference = 'Stop'

function Log([string]$msg,[string]$fg='Gray'){ Write-Host $msg -ForegroundColor $fg }

# --- Guard: make sure we're not in System32 ---
$expected = Join-Path $env:USERPROFILE 'Downloads\truvern'
if ($PWD.Path -match '\\Windows\\System32($|\\)') {
  if (Test-Path $expected) { Set-Location $expected } else {
    Log "[!] Not in project folder and expected path missing: $expected" Red; exit 1
  }
}

# --- Settings ---
$team   = 'nelson-ai-projects'   # Vercel team slug
$proj   = 'truvern'              # Vercel project name
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logs   = Join-Path $PWD 'logs'
$mainLog = Join-Path $logs "phase126-main-$stamp.log"
$lnkLog  = Join-Path $logs "phase126-link-$stamp.txt"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

# --- Resolve CLI prerequisites (no version parsing quirks) ---
$npmPath = Join-Path $env:APPDATA 'npm'
if ($env:Path -notlike "*$npmPath*") {
  [Environment]::SetEnvironmentVariable('Path', ($env:Path + ';' + $npmPath), 'User')
  $env:Path += ';' + $npmPath
  Log "Added npm global path: $npmPath" DarkGray
}

# Check Node
$nodeCmd = (Get-Command node -ErrorAction SilentlyContinue)
if (-not $nodeCmd) {
  $cands = @("$env:ProgramFiles\nodejs\node.exe","$env:ProgramFiles(x86)\nodejs\node.exe")
  foreach($c in $cands){ if(Test-Path $c){ $nodeCmd = $c; break } }
}
if (-not $nodeCmd) { Log "[!] Node.js not found. Install Node 18+ and re-run." Red; exit 1 }
Log ("Node: " + ($(if($nodeCmd -is [string]){$nodeCmd}else{$nodeCmd.Source}))) DarkGray

# Check Vercel CLI (shim path)
$vercelCmd = (Get-Command vercel.cmd -ErrorAction SilentlyContinue)
if (-not $vercelCmd) {
  Log "Installing Vercel CLI..." Yellow
  npm install -g vercel | Out-Null
  $vercelCmd = (Get-Command vercel.cmd -ErrorAction SilentlyContinue)
}
if (-not $vercelCmd) { Log "[!] Vercel CLI not available after reinstall." Red; exit 1 }
$vercelShim = $vercelCmd.Source
Log "Vercel shim: $vercelShim" DarkGray

# Verify CLI responds (avoid NativeCommandError by using cmd)
try {
  $v = cmd /c "vercel --version" 2>$null
  if ([string]::IsNullOrWhiteSpace($v)) { throw "no version" }
  Log ("Vercel: " + $v.Trim()) Green
} catch { Log "[!] Vercel CLI not responding correctly." Red; exit 1 }

# --- Backup & relink ---
$vercelDir = Join-Path $PWD '.vercel'
$backupDir = Join-Path $PWD (".vercel.bak-$stamp")

if (Test-Path $vercelDir) {
  Copy-Item $vercelDir $backupDir -Recurse -Force
  Log ("Backed up .vercel -> " + $backupDir) DarkGray
  Remove-Item $vercelDir -Recurse -Force
  Log "Removed existing .vercel to force a clean link." DarkGray
}

# Non-interactive link to the correct team + project
$cmd = "vercel link --yes --project $proj --scope $team"
Log "Linking: $cmd" Cyan
$lnkOut = cmd /c $cmd
$lnkOut | Tee-Object -FilePath $lnkLog | Out-Host

# --- Verify link result ---
if (-not (Test-Path $vercelDir)) {
  Log "[!] .vercel folder not created. Restoring previous link." Red
  if(Test-Path $backupDir){ Copy-Item $backupDir $vercelDir -Recurse -Force }
  Log "See link log: $lnkLog" Yellow
  exit 1
}

# Try to read project.json for a friendly confirmation
$projJsonPath = Join-Path $vercelDir 'project.json'
if (Test-Path $projJsonPath) {
  try {
    $pj = Get-Content $projJsonPath -Raw | ConvertFrom-Json
    $orgId = $pj.orgId; $projectId = $pj.projectId
    Log "Linked OK. orgId=$orgId projectId=$projectId" Green
  } catch {
    Log "Linked OK. (project.json present)" Green
  }
} else {
  Log "[!] project.json missing in .vercel (unexpected). Link may still be valid, but please re-run if deploys fail." Yellow
}

# Extra: confirm identity within the chosen scope (non-fatal)
try {
  $who = cmd /c "vercel whoami --scope $team" 2>$null
  if ($who) { Log ("Scope whoami: " + $who.Trim()) DarkGray }
} catch {}

# Done
Log "=== Phase126 complete: Project is linked to '$team' / '$proj' ===" Cyan
Log ("Main log: " + $mainLog) DarkGray
Log ("Link log: " + $lnkLog) DarkGray
"[$(Get-Date -Format o)] Completed" | Out-File -FilePath $mainLog -Encoding UTF8 -Append
