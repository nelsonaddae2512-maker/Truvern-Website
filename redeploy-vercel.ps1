param(
  [Parameter(Mandatory=$true)] [string]$Repo,
  [string]$Project = "",
  [string]$Org = "",
  [switch]$Prod
)

$ErrorActionPreference = "Stop"

if (-not $env:VERCEL_TOKEN -or [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
  Write-Error "VERCEL_TOKEN is not set. Run:  setx VERCEL_TOKEN ""<your-token>""  then reopen PowerShell."
}

if (-not (Test-Path $Repo)) { Write-Error "Repo path not found: $Repo" }
Set-Location $Repo

$vercelCmd = Get-Command vercel -ErrorAction SilentlyContinue
if (-not $vercelCmd) {
  Write-Host "Installing Vercel CLI globally..."
  npm i -g vercel | Out-Null
}

$projectJson = Join-Path $Repo ".vercel\project.json"
$needsLink = -not (Test-Path $projectJson)
if ($needsLink -and ($Project -and $Org)) {
  Write-Host "Linking local folder to Vercel project '$Project' (org: $Org)..."
  vercel link --yes --token $env:VERCEL_TOKEN --project $Project --org $Org | Write-Host
}

$deployArgs = @("--yes","--token",$env:VERCEL_TOKEN)
if ($Prod.IsPresent) {
  $deployArgs += "--prod"
  Write-Host "🚀 Triggering PRODUCTION deployment..."
} else {
  Write-Host "🚀 Triggering PREVIEW deployment..."
}

$out = vercel deploy @deployArgs 2>&1
$out | Write-Host

$urls = ($out | Select-String -Pattern "https://.*\.vercel\.app" -AllMatches).Matches.Value | Select-Object -Unique
if ($urls -and $urls.Count -gt 0) {
  Write-Host "`n✅ Deployed successfully: $($urls[-1])"
} else {
  Write-Host "`n⚠️ Deployment triggered but no URL captured. Check https://vercel.com/dashboard"
}
