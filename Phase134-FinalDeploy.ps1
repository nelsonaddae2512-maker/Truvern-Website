<# =======================================================================
 Phase134-FinalDeploy.ps1
 Purpose: Final production deploy via Vercel cloud build
 ======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectName  = 'truvern'
$ProjectScope = 'nelson-ai-projects'

# Resolve repo root
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace([string]$PSScriptRoot)) { $PSScriptRoot = (Get-Location).Path }
$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
Set-Location $RepoRoot

# Log
$LogPath = Join-Path $RepoRoot "Phase134-FinalDeploy.log"
if (Test-Path $LogPath) { Remove-Item $LogPath -Force -EA SilentlyContinue }
Start-Transcript -Path $LogPath | Out-Null

Write-Host "=== Phase134: Final Production Deploy ===" -ForegroundColor Cyan
Write-Host ("Repo Root: {0}" -f $RepoRoot) -ForegroundColor DarkCyan

# Helper to run a CLI command (PS5-safe)
function Run-CLI {
  param([Parameter(Mandatory=$true)][string]$Cmd)
  Write-Host ("-> {0}" -f $Cmd) -ForegroundColor DarkYellow
  & cmd.exe /c $Cmd
  if ($LASTEXITCODE -ne 0) { throw ("Command failed (" + $LASTEXITCODE + "): " + $Cmd) }
}

# Read vercel/project.json if present
$VercelDir     = Join-Path $RepoRoot ".vercel"
$ProjectJson   = Join-Path $VercelDir "project.json"

# 1) Auth + link
Write-Host "Step 1/4: Verify auth and link ..." -ForegroundColor Cyan
Run-CLI "vercel whoami"
if (-not (Test-Path $ProjectJson)) {
  Write-Host "Link missing; running vercel link ..." -ForegroundColor Yellow
  Run-CLI ("vercel link --yes --project {0} --scope {1}" -f $ProjectName, $ProjectScope)
  if (-not (Test-Path $ProjectJson)) { throw ".vercel\project.json not found after link." }
}
Write-Host "Project link OK." -ForegroundColor Green

# 2) Pull prod env (safety)
Write-Host "Step 2/4: Pull production env ..." -ForegroundColor Cyan
Run-CLI ("vercel pull --environment=production --scope {0} --yes" -f $ProjectScope)

# 3) Deploy production (cloud build)
Write-Host "Step 3/4: Deploying to production (cloud build) ..." -ForegroundColor Cyan
# Capture output to extract URLs
$deployTmp = Join-Path $RepoRoot "Phase134-deploy-output.txt"
if (Test-Path $deployTmp) { Remove-Item $deployTmp -Force -EA SilentlyContinue }
& cmd.exe /c ("vercel deploy --prod --scope {0} --yes > `"{1}`" 2>&1" -f $ProjectScope, $deployTmp)
if ($LASTEXITCODE -ne 0) {
  Get-Content -LiteralPath $deployTmp | Write-Host -ForegroundColor Red
  throw ("vercel deploy failed (" + $LASTEXITCODE + ")")
}
Write-Host (Get-Content -LiteralPath $deployTmp -Raw) -ForegroundColor DarkGray

# 4) Extract URLs + summary
Write-Host "Step 4/4: Summary" -ForegroundColor Cyan
# Load project metadata (best-effort)
$orgId = "<unknown>"; $projId = "<unknown>"; $projNm = $ProjectName
try {
  $pj = Get-Content $ProjectJson -Raw | ConvertFrom-Json
  if ($pj.orgId)    { $orgId = $pj.orgId }
  if ($pj.projectId){ $projId = $pj.projectId }
  if ($pj.projectName) { $projNm = $pj.projectName }
} catch { }

Write-Host ("OrgId:   {0}" -f $orgId)  -ForegroundColor White
Write-Host ("Project: {0}" -f $projNm) -ForegroundColor White
Write-Host ("Scope:   {0}" -f $ProjectScope) -ForegroundColor White

# Parse URLs from deploy output
$urls = @()
if (Test-Path $deployTmp) {
  $txt = Get-Content -LiteralPath $deployTmp -Raw
  $matches = [regex]::Matches($txt, "https?://[^\s]+")
  foreach ($m in $matches) {
    $u = $m.Value
    if ($u -match "vercel\.app" -or $u -match "truvern\.com") { $urls += $u }
  }
}
$urls = @($urls | Select-Object -Unique)

if ($urls.Count -gt 0) {
  Write-Host "Deployment URLs:" -ForegroundColor White
  foreach ($u in $urls) { Write-Host (" - {0}" -f $u) -ForegroundColor Green }
  try {
    Start-Process $urls[0]
    Write-Host ("Opened {0} in browser." -f $urls[0]) -ForegroundColor DarkGray
  } catch {
    Write-Host "Could not auto-open browser." -ForegroundColor Yellow
  }
} else {
  Write-Host "Deployment succeeded, but no URL detected. Check Vercel dashboard Activity." -ForegroundColor Yellow
}

Write-Host ("Log saved to: {0}" -f $LogPath) -ForegroundColor DarkGray
Write-Host "Phase134 complete." -ForegroundColor Green
Stop-Transcript | Out-Null
