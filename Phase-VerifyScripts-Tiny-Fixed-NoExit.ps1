# Phase-VerifyScripts-Tiny-Fixed-NoExit.ps1 — auto-verifier (wired)
try {
    if ($PSCommandPath) { $root = Split-Path -Parent $PSCommandPath }
    elseif ($MyInvocation.MyCommand.Definition) { $root = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Definition) }
    else { $root = (Get-Location).Path }
} catch { $root = (Get-Location).Path }
Set-Location $root
function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }
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
$present,@($present=@();$missing=@())
foreach($n in $expected){if(Test-Path (Join-Path $root $n)){$present+=$n}else{$missing+=$n}}
Say "";Say "=== Phase Scripts Verification (AutoRun) ===" "Cyan"
if($present){Say "Present:" "Green";$present|sort|%{Say("  + "+$_)"DarkGray"}}
if($missing){Say "";Say "Missing:" "Yellow";$missing|sort|%{Say("  - "+$_)"Yellow"}}
else{Say "";Say "✅ All expected scripts are present." "Green"}
Read-Host "`nPress Enter to close"
