$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

Write-Host "`n=== Truvern Phase13D: Unkillable Deploy Runner ===" -ForegroundColor Cyan
Write-Host "Project root: $PWD" -ForegroundColor Yellow
Write-Host "Session time: $(Get-Date)" -ForegroundColor DarkGray

if (-not $env:VERCEL_TOKEN) {
    Write-Host "❌ Missing VERCEL_TOKEN environment variable." -ForegroundColor Red
    Read-Host "Press Enter to close manually"
    exit
}
if (-not (Test-Path ".vercel")) {
    Write-Host "⚠️  No .vercel folder detected. Attempting to re-link project..." -ForegroundColor Yellow
    try {
        vercel link --yes --token $env:VERCEL_TOKEN
    } catch { Write-Host "Link failed: $($_.Exception.Message)" -ForegroundColor Red }
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = "logs\deploys"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$buildLog  = "$logDir\vercel-build-$ts.log"
$deployLog = "$logDir\vercel-deploy-$ts.log"
$auditFile = "$logDir\audit-$ts.json"

try {
    Write-Host "`n[1] Pulling production settings..." -ForegroundColor Cyan
    npx vercel pull --yes --environment=production --token $env:VERCEL_TOKEN 2>&1 | Tee-Object -FilePath $buildLog
    Write-Host "✅ Pulled project settings." -ForegroundColor Green
} catch {
    Write-Host "❌ vercel pull failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n[2] Building Next.js app..." -ForegroundColor Cyan
    npx vercel build --prod --token $env:VERCEL_TOKEN 2>&1 | Tee-Object -FilePath $buildLog -Append
    Write-Host "✅ Build completed (check $buildLog for details)" -ForegroundColor Green
} catch {
    Write-Host "❌ Build error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n[3] Deploying prebuilt output to production..." -ForegroundColor Cyan
    npx vercel deploy --prebuilt --prod --token $env:VERCEL_TOKEN 2>&1 | Tee-Object -FilePath $deployLog
    Write-Host "✅ Deploy complete (check $deployLog)" -ForegroundColor Green
} catch {
    Write-Host "❌ Deploy error: $($_.Exception.Message)" -ForegroundColor Red
}

function Test-Health($path) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri $path
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
            Write-Host "✔ $path -> $($r.StatusCode)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠ $path -> $($r.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ $path failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n[4] Verifying health endpoints..." -ForegroundColor Cyan
$ops = Test-Health "https://truvern.com/ops/health"
$api = Test-Health "https://truvern.com/api/health"

$audit = [ordered]@{
    time = (Get-Date).ToString("o")
    ops_health = $ops
    api_health = $api
    build_log = $buildLog
    deploy_log = $deployLog
}
$audit | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 -Force -FilePath $auditFile
Write-Host "🗒 Audit log written: $auditFile" -ForegroundColor Green

Write-Host "`n=== Phase13D run complete. Window will remain open. ===" -ForegroundColor Cyan
Read-Host "Press Enter to finish manually (window stays open)"
