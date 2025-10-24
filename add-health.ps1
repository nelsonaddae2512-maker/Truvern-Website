param([switch]$Deploy)

# Truvern Health Endpoint Creator + Optional Deploy
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location -Path $projectPath
Write-Host "`nWorking directory: $(Get-Location)"

$ErrorActionPreference = "Stop"
function Step($msg){ Write-Host "`n=== $msg ===" }
function Ok($msg){ Write-Host "[OK] $msg" }
function Warn($msg){ Write-Host "[WARN] $msg" }

# Step 1: Create /app/api/health/route.ts
Step "Creating /app/api/health/route.ts"

$folder = Join-Path $projectPath "app/api/health"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Ok "Created folder $folder"
} else {
    Ok "Folder already exists"
}

$enc = New-Object System.Text.UTF8Encoding($false)
$code = @'
import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    ok: true,
    ts: new Date().toISOString(),
    uptimeSec: Math.round(process.uptime()),
  });
}
'@

$filePath = Join-Path $folder "route.ts"
[System.IO.File]::WriteAllText($filePath, $code, $enc)
Ok "Health endpoint created at $filePath"

# Step 2: Build the project
Step "Building Next.js"
$env:NODE_OPTIONS="--max-old-space-size=4096"
npm run build
Ok "Build complete"

# Step 3: Optional deploy
if ($Deploy) {
    Step "Deploying to Vercel (prod)"
    $cmd = Get-Command vercel -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        npx vercel --prod --confirm
    } else {
        vercel --prod --confirm
    }
    Ok "Deploy triggered"
} else {
    Warn "Skipping deploy (use -Deploy to push live)"
}
