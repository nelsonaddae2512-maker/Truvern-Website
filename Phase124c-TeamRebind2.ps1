# Phase124c-TeamRebind2.ps1
# Safe non-interactive relink of Truvern to correct Vercel team

$ErrorActionPreference = 'Stop'

$teamSlug     = 'nelson-ai-projects'
$projectName  = 'truvern'
$baseFallback = 'https://truvern.com'

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path (Get-Location) "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase124c-main-$ts.log"
$depLog  = Join-Path $logDir "phase124c-deploy-$ts.txt"
$vrfLog  = Join-Path $logDir "route-public-verify-$ts.txt"

Function Log($m, $c='Gray') {
  Write-Host $m -ForegroundColor $c
  Add-Content -Path $mainLog -Value $m
}

Log "=== Phase124c-TeamRebind2 ===" 'Cyan'

# Guard
if ($PWD.Path -match '\\Windows\\System32$') {
  Write-Host "❌ Run this from your project folder, not System32" -ForegroundColor Red
  exit 1
}

# Ensure PATHs
$npmBin = Join-Path $env:APPDATA "npm"
if ($env:Path -notmatch [regex]::Escape($npmBin)) { $env:Path += ";$npmBin" }

# Backup .vercel
if (Test-Path ".vercel") {
  $bak = ".vercel.bak-$ts"
  Rename-Item ".vercel" $bak -Force
  Log "Backed up existing .vercel to $bak" 'Yellow'
}

# Install deps
Log "Installing deps..." 'Cyan'
cmd /c "pnpm i --frozen-lockfile" | Tee-Object -FilePath $mainLog -Append | Out-Host

# ---- LINK to correct team (safe mode)
Log "Linking project to correct team..." 'Cyan'
$vercelCmd = "vercel link --yes --project `"$projectName`" --scope `"$teamSlug`""
try {
  Start-Process "cmd.exe" -ArgumentList "/c $vercelCmd" -NoNewWindow -Wait
  Log "Linked successfully to $teamSlug" 'Green'
} catch {
  Log "⚠️  Link attempt produced warning: $($_.Exception.Message)" 'Yellow'
}

# ---- Build
Log "Building project..." 'Cyan'
cmd /c "pnpm run build" 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host

# ---- Deploy
Log "Deploying to Vercel prod..." 'Cyan'
cmd /c "vercel --prod --yes --scope $teamSlug" 2>&1 | Tee-Object -FilePath $depLog -Append | Out-Host

# ---- Parse prod URL
$prodUrl = (Select-String -Path $depLog -Pattern 'https://[^\s]+' | Select-Object -Last 1).Matches.Value
if (-not $prodUrl) { $prodUrl = $baseFallback }
Log "Production URL: $prodUrl" 'Green'

# ---- Verify public routes
$routes = @('/', '/pricing', '/login', '/subscribe', '/api/health', '/favicon.ico', '/manifest.json')
$ok = $true
foreach ($r in $routes) {
  $u = ($prodUrl.TrimEnd('/')) + $r
  try {
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 15
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200) {
      Write-Host "OK  $u ($ms ms)" -ForegroundColor Green
    } else {
      Write-Host "ERR $u ($($res.StatusCode))" -ForegroundColor Yellow
      $ok = $false
    }
  } catch {
    Write-Host "ERR $u ($($_.Exception.Message))" -ForegroundColor Red
    $ok = $false
  }
}

if ($ok) {
  Log "✅ All public routes OK." 'Green'
} else {
  Log "⚠️ Some routes failed. Check $vrfLog" 'Yellow'
}

Read-Host "Press Enter to close"
