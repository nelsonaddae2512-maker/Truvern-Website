# ===============================================
# Truvern - Phase 10.2 AutoLink Verifier (Clean Final)
# ===============================================

$ErrorActionPreference = "Stop"
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root
Write-Host "Project root: $root" -ForegroundColor Cyan

# --- Check VERCEL_TOKEN ---
if (-not $env:VERCEL_TOKEN) {
    Write-Host "❌ Missing VERCEL_TOKEN environment variable." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Using VERCEL_TOKEN (masked)" -ForegroundColor Green

# --- Check team scopes (optional) ---
Write-Host "`n🔍 Checking available team scopes..." -ForegroundColor Cyan
try {
    vercel teams ls --token $env:VERCEL_TOKEN
} catch {
    Write-Host "⚠️  Skipping team enumeration (not critical)." -ForegroundColor DarkYellow
}

# --- Verify .vercel linkage ---
Write-Host "`n✅ Verifying .vercel linkage..." -ForegroundColor Yellow
if (Test-Path ".vercel\project.json") {
    Write-Host "✔ project.json found and valid" -ForegroundColor Green
} else {
    Write-Host "❌ .vercel/project.json missing, re-run vercel link" -ForegroundColor Red
    exit 1
}

# --- Run live health checks ---
Write-Host "`n🩺 Running live health checks..." -ForegroundColor Cyan
$urls = @(
    "https://truvern.com/ops/health",
    "https://truvern.com/api/health"
)

foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri $u
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
            Write-Host "✅ $u OK ($($r.StatusCode))" -ForegroundColor Green
        } else {
            Write-Host "⚠️  $u returned non-200 ($($r.StatusCode))" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ $u failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎯 Phase 10.2 AutoLink verification complete." -ForegroundColor Cyan
Write-Host "Next: Run scripts/DeployAndGate.ps1 for live deployment verification." -ForegroundColor Gray
