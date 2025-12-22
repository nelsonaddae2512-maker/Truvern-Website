[CmdletBinding()]
param([string]$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern")

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

function Write-File([string]$Path, [string]$Content) {
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$routeOld = Join-Path $ProjectRoot "app\api\activity\route.ts"
$routeNew = Join-Path $ProjectRoot "app\api\activity-feed\route.ts"
$panel    = Join-Path $ProjectRoot "components\activity-feed-panel.tsx"

if (-not (Test-Path $routeOld)) { throw "Missing: $routeOld" }
if (-not (Test-Path $panel))    { throw "Missing: $panel" }

# Copy route content to new endpoint
$routeContent = Get-Content $routeOld -Raw
Write-File $routeNew $routeContent

# Patch panel endpoint
$panelContent = Get-Content $panel -Raw
$panelContent = $panelContent -replace 'const base = "/api/activity";', 'const base = "/api/activity-feed";'
Write-File $panel $panelContent

Write-Host ""
Write-Host "✅ Hotfix complete:"
Write-Host " - Created: app/api/activity-feed/route.ts"
Write-Host " - Patched: components/activity-feed-panel.tsx"
Write-Host "Restart dev server: npm run dev"
