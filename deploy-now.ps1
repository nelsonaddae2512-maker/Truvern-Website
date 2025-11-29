# =========================================================
# deploy-now.ps1 — Final Clean Version (ASCII-safe)
# =========================================================

$ErrorActionPreference = "Stop"

# 1. Always run from the project folder
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

# 2. Verify Vercel token
if (-not $env:VERCEL_TOKEN -or [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
    throw "VERCEL_TOKEN not set. Example: `$env:VERCEL_TOKEN = '<your-vercel-token>'"
}

# 3. Ensure Vercel CLI exists
$vercel = Join-Path $env:APPDATA "npm\vercel.cmd"
if (!(Test-Path $vercel)) {
    Write-Host "Installing Vercel CLI globally..." -ForegroundColor Yellow
    npm install -g vercel
    if (!(Test-Path $vercel)) { throw "vercel.cmd not found after install." }
}

# 4. Build project if needed
if (!(Test-Path ".next")) {
    Write-Host "Running npm install and build..." -ForegroundColor Yellow
    $env:CI = "1"
    $env:HUSKY = "0"
    $env:NEXT_TELEMETRY_DISABLED = "1"
    npm install
    npm run build
}

# 5. Deploy to production
Write-Host ""
Write-Host "Deploying production build to Vercel..." -ForegroundColor Cyan
cmd.exe /d /c "`"$vercel`" deploy --yes --prod --scope nelson-addaes-projects --cwd ."
Write-Host ""

# 6. Get latest production URL
$urls = & $vercel list truvern --scope nelson-addaes-projects | Select-String "https://.*\.vercel\.app"
$prodUrl = $urls.Matches.Value | Select-Object -Last 1

if (-not $prodUrl -or $prodUrl.Trim() -eq "") {
    Write-Host "⚠ Could not auto-detect production URL. Check your Vercel dashboard." -ForegroundColor Yellow
} else {
    Write-Host ("✅ Production URL: " + $prodUrl) -ForegroundColor Green
    "PRODUCTION_URL=$prodUrl" | Out-File -FilePath ".\last-deploy.txt" -Encoding utf8 -Force
}

# 7. Alias truvern.com
if ($prodUrl) {
    Write-Host ""
    Write-Host ("Linking truvern.com → " + $prodUrl) -ForegroundColor Yellow
    cmd.exe /d /c "`"$vercel`" alias set `"$prodUrl`" truvern.com"
    Write-Host ("✅ truvern.com now points to: " + $prodUrl) -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Done. Visit https://truvern.com and press Ctrl+F5 to refresh." -ForegroundColor Cyan
