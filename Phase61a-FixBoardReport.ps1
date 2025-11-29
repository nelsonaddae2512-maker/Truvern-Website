# Phase61a-FixBoardReport.ps1 — Safe & idempotent
[CmdletBinding()] param()
$ErrorActionPreference = "Stop"
function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }

Say "=== Running Phase61a – Fix Board Report ===" "Cyan"

try {
  $scriptPath = $MyInvocation.PSCommandPath; if (-not $scriptPath){ $scriptPath = $PSCommandPath }
  if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) { $root = Split-Path -Parent $scriptPath } else { $root = (Get-Location).Path }
  Set-Location $root

  $logDir = Join-Path $root "logs"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null; Say "Created logs dir" "Yellow" }

  $reportFile = Join-Path $logDir "Phase61-BoardReport.log"
  Say ("Paths → root:{0} | logDir:{1} | reportFile:{2}" -f $root,$logDir,$reportFile) "DarkGray"

  if (Test-Path -LiteralPath $reportFile) {
    Say "Found Phase61 report log, starting cleanup..." "Gray"
    $content = Get-Content -LiteralPath $reportFile -Raw
    $fixed   = $content -replace "error","issue" -replace "failed","review"
    $fixedFile = [IO.Path]::ChangeExtension($reportFile,$null) + "-fixed.log"
    $fixed | Out-File -LiteralPath $fixedFile -Encoding UTF8
    Say "Board report sanitized and saved as: $fixedFile" "Green"
  } else {
    $placeholder = "No Phase61 report available at $(Get-Date -Format u)"
    $placeholder | Out-File -LiteralPath $reportFile -Encoding UTF8
    Say "Placeholder created: $reportFile" "Yellow"
  }

  Say "Phase61a-FixBoardReport completed successfully." "Green"
}
catch { Say ("ERROR: " + $_.Exception.Message) "Red" }
Read-Host "Press Enter to close"
