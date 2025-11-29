# Phase61-Harness-NoExit.ps1 — runs 61 → 61a → 61b and keeps window open
$ErrorActionPreference = "Stop"
function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }

# Resolve root robustly (no ? : shorthand)
$scriptPath = $MyInvocation.PSCommandPath
if (-not $scriptPath) { $scriptPath = $PSCommandPath }
if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) {
  $root = Split-Path -Parent $scriptPath
} else {
  $root = (Get-Location).Path
}
Set-Location $root

Say "`n=== Phase 61 Harness (BoardReport → FixBoardReport → SeedDemoOrg) ===" "Cyan"

$phases = @(
  @{ Name = "Phase61-BoardReport.ps1";  Args = @("-Deploy","-SkipInstall","-SkipBuild") },
  @{ Name = "Phase61a-FixBoardReport.ps1"; Args = @() },
  @{ Name = "Phase61b-SeedDemoOrg.ps1";    Args = @("-WithAssessment","-WithRemediation","-Deploy") }
)},
  @{ Name = "Phase61a-FixBoardReport.ps1"; Args = @() },
  @{ Name = "Phase61b-SeedDemoOrg.ps1";    Args = @("-WithAssessment","-WithRemediation","-Deploy") }
)},
  @{ Name = "Phase61a-FixBoardReport.ps1"; Args = @() },
  @{ Name = "Phase61b-SeedDemoOrg.ps1";    Args = @("-WithAssessment","-WithRemediation","-Deploy") }
)

foreach ($p in $phases) {
  $path = Join-Path $root $p.Name
  if (Test-Path -LiteralPath $path) {
    Say "`n▶ Running $($p.Name)..." "Yellow"
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $path @($p.Args)
      Say "✔ Completed $($p.Name)" "Green"
    } catch {
      Say "✖ ERROR in $($p.Name): $($_.Exception.Message)" "Red"
    }
  } else {
    Say "⚠ Missing $($p.Name) at $path" "DarkYellow"
  }
}

Say "`nAll harness phases executed." "Cyan"
Read-Host "Press Enter to close"


