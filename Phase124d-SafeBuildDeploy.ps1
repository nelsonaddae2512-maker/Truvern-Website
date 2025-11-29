# Phase124d-SafeBuildDeploy.ps1
# Final safe build + deploy now that project is linked to correct team.

$ErrorActionPreference = 'Stop'

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path (Get-Location) "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase124d-main-$ts.log"
$depLog  = Join-Path $logDir "phase124d-deploy-$ts.txt"
$vrfLog  = Join-Path $logDir "route-verify-$ts.txt"

Function Log($msg, $color='Gray') {
  Write-Host $msg -ForegroundColor $color
  Add-Content -Path $mainLog -Value $msg
}

Log "=== Phase124d: Final Safe Build + Deploy ===" 'Cyan'

# Verify correct .vercel link
if (-not (Test-Path ".vercel")) {
  Write-Host "❌ No .vercel link found. Please rerun Phase124c-TeamRebind2.ps1 first." -ForegroundColor Red
  exit 1
}

$vercelInfo = Get-Content ".vercel/project.json" -Raw | ConvertFrom-Json
Log "Project: $($vercelInfo.name)" 'Yellow'
Log "Team:    $($vercelInfo.orgId)" 'Yellow'

# --- Build safely in PowerShell context (no cmd redirection)
try {
  Log "Running Prisma Generate + Build..." 'Cyan'
  pnpm exec prisma generate | Tee-Object -FilePath $mainLog -Append | Out-Host
  pnpm run build | Tee-Object -FilePath $mainLog -Append | Out-Host
  Log "✅ Build completed successfully." 'Green'
} catch {
  Log "❌ Build failed: $($_.Exception.Message)" 'Red'
  exit 1
}

# --- Deploy to production (uses linked .vercel automatically)
Log "Deploying to Vercel production..." 'Cyan'
vercel --prod --yes | Tee-Object -FilePath $depLog -Append | Out-Host

# --- Parse production URL
$prodUrl = (Select-String -Path $depLog -Pattern 'https://[^\s]+' | Select-Object -Last 1).Matches.Value
if (-not $prodUrl) { $prodUrl = 'https://truvern.com' }
Log "Production URL: $prodUrl" 'Green'

# --- Verify public routes
$routes = @('/', '/pricing', '/login', '/subscribe', '/api/health', '/favicon.ico', '/manifest.json')
$okAll = $true
foreach ($r in $routes) {
  $u = ($prodUrl.TrimEnd('/')) + $r
  try {
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 20
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200) {
      Write-Host "OK  $u ($ms ms)" -ForegroundColor Green
    } else {
      Write-Host "ERR $u ($($res.StatusCode))" -ForegroundColor Yellow
      $okAll = $false
    }
  } catch {
    Write-Host "ERR $u ($($_.Exception.Message))" -ForegroundColor Red
    $okAll = $false
  }
}

if ($okAll) {
  Log "✅ All routes returned HTTP 200." 'Green'
} else {
  Log "⚠️ Some routes failed. Check $vrfLog" 'Yellow'
}

Read-Host "Press Enter to close"
