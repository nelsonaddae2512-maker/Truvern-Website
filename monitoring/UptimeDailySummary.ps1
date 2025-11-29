param(
  [string]$LogFile = ".\logs\monitoring\uptime.log",
  [string]$OutDir  = ".\logs\monitoring"
)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$since = (Get-Date).AddDays(-1)

# Load lines from uptime.log
$lines = if (Test-Path $LogFile) { Get-Content $LogFile } else { @() }
$recent = $lines | Where-Object {
  if ($_ -match '^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \|') {
    [datetime]::ParseExact($Matches.ts,'yyyy-MM-dd HH:mm:ss',$null) -ge $since
  } else { $false }
}

# Extract only Result lines
$resultLines = $recent | Where-Object { $_ -match '\|\s*Result:\s*ok=' }

# Convert to objects
$objs = foreach ($l in $resultLines) {
  if ($l -match '^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \| Result: ok=(?<ok>True|False) code=(?<code>-?\d+)(?: err=(?<err>.*))?$') {
    [pscustomobject]@{
      ts   = [datetime]::ParseExact($Matches.ts,'yyyy-MM-dd HH:mm:ss',$null)
      ok   = [bool]::Parse($Matches.ok)
      code = [int]$Matches.code
      err  = ($Matches.err).Trim()
    }
  }
}

# Group pairs of ops/api
$runs = @()
for ($i=0; $i -lt $objs.Count; $i+=2) {
  $pair = $objs[$i..([math]::Min($i+1, $objs.Count-1))]
  $runTs = $pair[0].ts
  $okRun = $true
  $errMsgs = @()
  foreach ($p in $pair) { if (-not $p.ok) { $okRun = $false; if ($p.err) { $errMsgs += $p.err } } }
  $runs += [pscustomobject]@{ ts=$runTs; ok=$okRun; errors=($errMsgs -join ' | ') }
}

$total   = $runs.Count
$failed  = ($runs | Where-Object { -not $_.ok }).Count
$passed  = $total - $failed
$uptimeP = if ($total -gt 0) { [math]::Round(100.0 * $passed / $total, 2) } else { 0.0 }
$lastFail = ($runs | Where-Object { -not $_.ok } | Sort-Object ts | Select-Object -Last 1)

$summary = @()
$summary += "Truvern Uptime — Last 24h"
$summary += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += "Window: $($since.ToString('yyyy-MM-dd HH:mm:ss')) .. $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += "Total checks: $total  |  Passed: $passed  |  Failed: $failed  |  Uptime: $uptimeP`%"
if ($lastFail) { $summary += "Last failure: $($lastFail.ts.ToString('yyyy-MM-dd HH:mm:ss'))  |  Errors: $($lastFail.errors)" }
$summary += ""
$summary += "Recent runs (up to 20):"

foreach ($r in ($runs | Sort-Object ts -Descending | Select-Object -First 20)) {
  if ($r.ok) {
    $summary += ("{0} | OK" -f $r.ts.ToString('yyyy-MM-dd HH:mm:ss'))
  } else {
    $summary += ("{0} | FAIL: {1}" -f $r.ts.ToString('yyyy-MM-dd HH:mm:ss'), $r.errors)
  }
}

# Write the summary file
$outFile = Join-Path $OutDir ("daily-summary-{0}.txt" -f (Get-Date -Format 'yyyyMMdd'))
$summary -join [Environment]::NewLine | Out-File -FilePath $outFile -Encoding UTF8

Write-Host "Wrote summary: $outFile"
