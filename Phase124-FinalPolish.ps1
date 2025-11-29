<# ================================================================
 Phase124-FinalPolish.ps1
 Clean caches → build → deploy → verify → release zip
 ================================================================ #>

$ErrorActionPreference = 'Stop'
# --- ANSI/Color compatibility (PowerShell 5 vs 7+) ---
try {
  if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSStyle -and `
      $PSStyle.PSObject.Properties['OutputRendering']) {
    $PSStyle.OutputRendering = 'Ansi'
  }
} catch { }  # ignore on PS 5.x

function Log {
    param (
        [string]$msg,
        [string]$color = 'White'
    )

    # ✅ Fallback if invalid color
    $validColors = @(
        'Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta',
        'DarkYellow','Gray','DarkGray','Blue','Green','Cyan','Red',
        'Magenta','Yellow','White'
    )

    if (-not ($validColors -contains $color)) {
        $color = 'White'
    }

    try {
        Write-Host $msg -ForegroundColor $color
    }
    catch {
        Write-Host $msg
    }
}

# ----- Guard -----
$PWDPath = (Get-Location).Path
if ($PWDPath -match '\\Windows\\System32') {
  Write-Host "❌ Do not run from System32. cd into your project folder and rerun." -ForegroundColor Red
  exit 1
}

# ----- Setup -----
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $PWDPath "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog  = Join-Path $logDir "phase124-main-$ts.log"
$buildLog = Join-Path $logDir "phase124-build-$ts.txt"
$deployLog = Join-Path $logDir "phase124-deploy-$ts.txt"
$verifyLog = Join-Path $logDir "route-verify-$ts.txt"

# Ensure pnpm + vercel available
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
  $pnpmPath = Get-ChildItem "$env:APPDATA\npm\pnpm*.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pnpmPath) { $env:Path += ";$($pnpmPath.DirectoryName)" }
}
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  $vercelPath = Get-ChildItem "$env:APPDATA\npm\vercel*.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($vercelPath) { $env:Path += ";$($vercelPath.DirectoryName)" }
}

function Run-Tool($exe, $args, $logFile) {
  Log "→ $exe $($args -join ' ')" 'DarkGray'
  & $exe @args 2>&1 | Tee-Object -FilePath $logFile -Append | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $exe (exit $LASTEXITCODE). See $logFile" }
}

# ----- 1. Snapshot -----
if (Test-Path ".next") {
  $snap = Join-Path $logDir "snapshot-$ts.zip"
  Log "📦 Creating snapshot -> $snap" 'Cyan'
  if (Test-Path $snap) { Remove-Item $snap -Force }
  Compress-Archive -Path ".next" -DestinationPath $snap -Force
} else {
  Log "ℹ No .next folder found. Skipping snapshot." 'Yellow'
}

# ----- 2. Clean caches -----
$clean = @(".next",".turbo")
foreach ($item in $clean) {
  if (Test-Path $item) {
    Log "🧹 Removing $item ..." 'DarkCyan'
    try { Remove-Item $item -Recurse -Force -ErrorAction Stop } catch { Log "Skip: $($_.Exception.Message)" 'Yellow' }
  }
}

# ----- 3. Build -----
try {
  Log "`n=== Phase124: Build + Deploy + Verify ===" 'Cyan'
  Run-Tool pnpm @('install','--frozen-lockfile') $mainLog
  Run-Tool pnpm @('exec','prisma','generate') $mainLog
  Log "✅ Prisma client generated." 'Green'
  Run-Tool pnpm @('run','build') $buildLog
  Log "✅ Build succeeded." 'Green'
}
catch {
  Log "❌ Build failed: $($_.Exception.Message)" 'Red'
  Read-Host "Press Enter to close"
  exit 2
}

# ----- 4. Deploy -----
try {
  Log "🚀 Deploying to Vercel (prod) ..." 'Cyan'
  Run-Tool vercel @('--prod','--yes') $deployLog
  $prodUrl = (Select-String -Path $deployLog -Pattern 'Production:\s+(https?://\S+)' | Select-Object -Last 1).Matches.Groups[1].Value
  if ($prodUrl) { Log "✅ Production URL: $prodUrl" 'Green' }
}
catch {
  Log "❌ Deploy failed: $($_.Exception.Message)" 'Red'
  Read-Host "Press Enter to close"
  exit 3
}

# ----- 5. Verify Routes -----
$allGood = Verify-Routes -Base $baseUrl -LogFile $verifyLog

if ($allGood) {
    Log "✅ All public routes verified successfully." 'Green'
} else {
    Log "⚠️ Some routes failed. See $verifyLog" 'Yellow'
}

# ----- 6. Release bundle -----
try {
    $releaseDir = Join-Path $logDir "releases"
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
    $releaseZip = Join-Path $releaseDir "release-$ts.zip"

    $include = @(
        "app","prisma","public","scripts","lib",
        "next.config.*","package.json","pnpm-lock.yaml",
        "tsconfig*.json",".env.example","README*","vercel.json"
    ) | Where-Object { Test-Path $_ }

    if ($include.Count -gt 0) {
        Log "📦 Creating release bundle -> $releaseZip" 'Cyan'
        if (Test-Path $releaseZip) { Remove-Item $releaseZip -Force }
        Compress-Archive -Path $include -DestinationPath $releaseZip -Force
    } else {
        Log "ℹ Nothing to include in release zip." 'Yellow'
    }
}
catch {
    Log ("⚠️ Release zip warning: {0}" -f $_.Exception.Message) 'Yellow'
}

# ----- 7. Completion Summary -----
Log "`n=== Phase124 complete ===" 'Cyan'
Log ("Main log:   {0}" -f $mainLog) 'DarkGray'
Log ("Build log:  {0}" -f $buildLog) 'DarkGray'
Log ("Deploy log: {0}" -f $deployLog) 'DarkGray'
Log ("Verify log: {0}" -f $verifyLog) 'DarkGray'

Read-Host "Press Enter to close"
exit 0
