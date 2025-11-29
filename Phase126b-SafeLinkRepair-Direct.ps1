# Phase126b-SafeLinkRepair-Direct.ps1
$ErrorActionPreference = 'Stop'

function Log([string]$msg,[string]$fg='Gray'){ Write-Host $msg -ForegroundColor $fg }

Log "=== Phase126b: Safe Link Repair (Direct Invocation) ===" Cyan

# 1️⃣ Validate working folder
$expected = Join-Path $env:USERPROFILE 'Downloads\truvern'
if ($PWD.Path -match '\\Windows\\System32($|\\)') {
    if (Test-Path $expected) { Set-Location $expected }
    else { Log "[!] Expected path not found: $expected" Red; exit 1 }
}

# 2️⃣ Paths and logs
$team   = 'nelson-ai-projects'
$proj   = 'truvern'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logs   = Join-Path $PWD 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$lnkLog = Join-Path $logs "phase126b-link-$stamp.txt"

# 3️⃣ Resolve node + vercel
$nodeCmd = (Get-Command node -ErrorAction SilentlyContinue)
if (-not $nodeCmd) {
    $nodeCmd = "$env:ProgramFiles\nodejs\node.exe"
    if (-not (Test-Path $nodeCmd)) { Log "[!] Node.js missing. Install Node 18+." Red; exit 1 }
}
Log "Node: $($nodeCmd.Source)" DarkGray
Log "Node version: $(& $nodeCmd.Source -v)" Green

$vercelCmd = (Get-Command vercel.cmd -ErrorAction SilentlyContinue)
if (-not $vercelCmd) {
    Log "Installing Vercel CLI..." Yellow
    npm install -g vercel | Out-Null
    $vercelCmd = (Get-Command vercel.cmd -ErrorAction SilentlyContinue)
}
if (-not $vercelCmd) { Log "[!] Vercel CLI missing even after install." Red; exit 1 }
$vercelPath = $vercelCmd.Source
Log "Using vercel shim: $vercelPath" DarkGray

# 4️⃣ Verify CLI safely
try {
    $proc = Start-Process -FilePath $vercelPath -ArgumentList "--version" -NoNewWindow -RedirectStandardOutput "$logs\vercel-version-$stamp.txt" -Wait -PassThru
    $version = Get-Content "$logs\vercel-version-$stamp.txt" -Raw
    if ($version) {
        Log "Vercel CLI: $($version.Trim())" Green
    } else {
        throw "empty output"
    }
} catch {
    Log "[!] Vercel CLI not responding; will attempt relink anyway..." Yellow
}

# 5️⃣ Backup any old .vercel
$vercelDir = Join-Path $PWD '.vercel'
if (Test-Path $vercelDir) {
    $backup = Join-Path $PWD (".vercel.bak-$stamp")
    Copy-Item $vercelDir $backup -Recurse -Force
    Remove-Item $vercelDir -Recurse -Force
    Log "Old .vercel removed and backed up to $backup" DarkGray
}

# 6️⃣ Run link directly
$arguments = @("link","--yes","--project",$proj,"--scope",$team)
Log "Running: vercel link --yes --project $proj --scope $team" Cyan
Start-Process -FilePath $vercelPath -ArgumentList $arguments -NoNewWindow -RedirectStandardOutput $lnkLog -Wait
$logData = Get-Content $lnkLog -Raw
Log $logData DarkGray

# 7️⃣ Verify new .vercel folder
if (Test-Path $vercelDir) {
    Log "✅ .vercel folder created successfully" Green
    $pj = Join-Path $vercelDir 'project.json'
    if (Test-Path $pj) {
        try {
            $json = Get-Content $pj -Raw | ConvertFrom-Json
            Log "Linked orgId=$($json.orgId) projectId=$($json.projectId)" Cyan
        } catch { Log "Linked OK (could not parse project.json)" Yellow }
    }
} else {
    Log "[!] No .vercel folder found, relink may have failed" Red
    Log "Check log: $lnkLog" Yellow
}

# 8️⃣ Optional whoami check
try {
    $whoLog = "$logs\vercel-whoami-$stamp.txt"
    Start-Process -FilePath $vercelPath -ArgumentList "whoami","--scope",$team -NoNewWindow -RedirectStandardOutput $whoLog -Wait
    $who = Get-Content $whoLog -Raw
    if ($who) { Log "Active scope: $($who.Trim())" DarkGray }
} catch {}

Log "=== Phase126b Complete: Safe relink finished ===" Cyan
