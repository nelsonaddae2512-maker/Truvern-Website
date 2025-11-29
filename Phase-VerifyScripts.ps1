[CmdletBinding()]
param([switch]$OutJson = $false)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Always run from the script's folder
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Note($msg, $color="Gray") { Write-Host $msg -ForegroundColor $color }
function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$logs = Join-Path (Get-Location).Path "logs"
Ensure-Dir $logs
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$txtReport = Join-Path $logs "verify-scripts-$stamp.txt"
$jsonReport = Join-Path $logs "verify-scripts-$stamp.json"

$expected = @(
"Phase40A-RouteCache.ps1","Phase40B-RouteCache-Verify.ps1","Phase41-RouteCaching.ps1",
"Phase42-BundleInsight.ps1","Phase43-PerfBudgets.ps1","Phase44-StaticAssets.ps1",
"Phase45-HealthProbes.ps1","Phase46-CanaryDeploy.ps1","Phase47-UptimeAlerts.ps1",
"Phase48-CSP.ps1","Phase49-SecurityHeaders.ps1","Phase50-NeonBackups.ps1",
"Phase51-DriftCheck.ps1","Phase52-DevUX.ps1","Phase53-PipelineHardening.ps1",
"Phase54-RestoreWizard.ps1","Phase55-PromoteHelper.ps1","Phase56-ProdChecklist.ps1",
"Phase57-RBAC-OrgRoles.ps1","Phase58-AssessmentsEngine.ps1","Phase59-EvidenceStore.ps1",
"Phase60-RemediationFlows.ps1","Phase61-BoardReport.ps1","Phase61a-FixBoardReport.ps1",
"Phase61b-SeedDemoOrg.ps1"
)

function Get-NearMatches($target){
  $stem = [IO.Path]::GetFileNameWithoutExtension($target)
  $alts = @(
    $stem,
    ($stem -replace "[–—−‐]", "-"),
    ($stem -replace "\s+", "-"),
    ($stem -replace "_", "-"),
    ($stem -replace "[^0-9A-Za-z\-]", "-")
  ) | Select-Object -Unique
  $patterns = $alts | ForEach-Object { "$_*" }
  Get-ChildItem -File | Where-Object {
    $n = $_.Name
    ($patterns | Where-Object { $n -like $_ }).Count -gt 0
  } | Where-Object { $_.Name -ne $target } | Select-Object -ExpandProperty Name
}

$results = @()
foreach($name in $expected){
  $exists = Test-Path (Join-Path (Get-Location).Path $name)
  $cands = @()
  if(-not $exists){ $cands = Get-NearMatches $name }
  $results += [pscustomobject]@{
    Script = $name
    Exists = $exists
    NearMatches = [string]::Join(", ", $cands)
  }
}

$missing = $results | Where-Object { -not $_.Exists }
$present = $results | Where-Object { $_.Exists }

Note ""
Note "=== Phase Scripts Verification ===" "Cyan"
$present | Sort-Object Script | Format-Table -AutoSize | Out-String | Write-Host
if($missing.Count -gt 0){
  Note "`nMissing:" "Yellow"
  $missing | Sort-Object Script | Format-Table -AutoSize | Out-String | Write-Host
} else {
  Note "All expected scripts are present." "Green"
}

$txtPath = $txtReport.ToString()
$jsonPath = $jsonReport.ToString()
$lines = @()
$lines += "=== Phase Scripts Verification ==="
$lines += "Folder: $($PWD.Path)"
$lines += "Date  : $(Get-Date -Format u)"
$lines += ""
$lines += "Present:"
if($present.Count){ $present | ForEach-Object { $lines += "  + " + $_.Script } } else { $lines += "  (none)" }
$lines += ""
$lines += "Missing:"
if($missing.Count){
  foreach($m in $missing){
    $lines += "  - " + $m.Script
    if($m.NearMatches){ $lines += "      near: " + $m.NearMatches }
  }
} else { $lines += "  (none)" }
Set-Content -Path $txtPath -Value $lines -Encoding UTF8

if($OutJson){
  $results | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
  Note ("JSON report: " + $jsonPath) "DarkGray"
}
Note ("Text report: " + $txtPath) "DarkGray"

if($missing.Count -gt 0){ exit 1 } else { exit 0 }
