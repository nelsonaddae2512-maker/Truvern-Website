# ===================== Phase121r4-VercelDeployFix.ps1 =====================
$ErrorActionPreference = "Stop"
Write-Host "=== Phase121r4: Truvern Vercel Safe Deploy Start ==="

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

# Ensure logs directory exists
if (-not (Test-Path ".\logs")) { New-Item -ItemType Directory -Path ".\logs" | Out-Null }

# Step 1: Check Vercel CLI installation
$vercelPath = (Get-Command vercel -ErrorAction SilentlyContinue)?.Source
if (-not $vercelPath) {
    Write-Host "Vercel CLI not found. Installing globally..."
    npm install -g vercel | Out-Null
    $vercelPath = (Get-Command vercel).Source
}
Write-Host "Vercel CLI found at: $vercelPath"

# Step 2: Verify authentication
$who = vercel whoami 2>$null
if (-not $who) {
    Write-Host "You are not logged in. Please log in to Vercel..."
    vercel login
    $who = vercel whoami
}
Write-Host "Logged in as: $who"

# Step 3: Verify project linkage
$vercelDir = Join-Path $projectPath ".vercel"
if (-not (Test-Path $vercelDir)) {
    Write-Host "Linking project to truvern..."
    vercel link --yes --project truvern --scope nelson-addaes-projects
}

# Step 4: Run production deploy safely and capture output
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$vercelLog = ".\logs\vercel-deploy-$timestamp.txt"

Write-Host "`nRunning deployment, please wait..."
$cmd = "vercel --prod --yes"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd > `"$vercelLog`" 2>&1" -Wait

Write-Host "`n=== Deployment complete ==="
if (Test-Path $vercelLog) {
    Write-Host "Vercel log saved: $vercelLog"
    Write-Host "`nLast 10 lines of log:"
    Get-Content $vercelLog -Tail 10
} else {
    Write-Warning "No deployment log found. Check Vercel output manually."
}

Write-Host "`n=== Phase121r4 complete ==="
# ========================================================================
