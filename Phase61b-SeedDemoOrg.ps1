[CmdletBinding()]
param(
  [switch]$WithAssessment,
  [switch]$WithRemediation,
  [switch]$Deploy
)

$ErrorActionPreference = "Stop"
function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }

try {
  $scriptPath = $MyInvocation.PSCommandPath; if(-not $scriptPath){ $scriptPath = $PSCommandPath }
  if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) { $root = Split-Path -Parent $scriptPath } else { $root = (Get-Location).Path }
  Set-Location $root

  $env:TRUVERN_SEED_ASSESSMENT  = $(if($WithAssessment){"1"}else{"0"})
  $env:TRUVERN_SEED_REMEDIATION = $(if($WithRemediation){"1"}else{"0"})

  $logs = Join-Path $root "logs"
  if(-not (Test-Path -LiteralPath $logs)){ New-Item -ItemType Directory -Path $logs | Out-Null }
  $lastIdFile = Join-Path $logs "last-demo-org-id.txt"

  $orgId = $null
  $seedTs = Join-Path $root "scripts\seed-demo-org.ts"
  if (Test-Path -LiteralPath $seedTs -and (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Say "Seeding demo org via pnpm dlx tsx scripts/seed-demo-org.ts ..." "Cyan"
    $out = & pnpm dlx tsx scripts/seed-demo-org.ts 2>&1
    if ($LASTEXITCODE -ne 0) { Say "Seed script non-zero; falling back to synthetic id." "Yellow" }
    $m = [regex]::Match([string]$out, 'ORG_ID=([A-Za-z0-9\-]+)')
    if ($m.Success) { $orgId = $m.Groups[1].Value }
  }

  if (-not $orgId) {
    $orgId = "demo-" + [Guid]::NewGuid().ToString("N").Substring(0,8)
    Say "Using fallback OrgId: $orgId" "Yellow"
  }

  Set-Content -Path $lastIdFile -Value $orgId -Encoding UTF8
  Say "Saved OrgId to: $lastIdFile" "Green"

  if ($Deploy) {
    if (Get-Command vercel -ErrorAction SilentlyContinue) {
      Say "Deploy flag set: pulling env & deploying (best-effort)..." "Gray"
      try { & vercel pull --yes --environment=production | Out-Null } catch {}
      try { & vercel deploy --prod --yes | Out-Null } catch {}
    } else {
      Say "Deploy requested but 'vercel' not found; skipping." "DarkYellow"
    }
  }

  Say "Phase61b-SeedDemoOrg completed. OrgId=$orgId" "Green"
  exit 0
}
catch {
  Say ("ERROR: " + $_.Exception.Message) "Red"
  exit 1
}





