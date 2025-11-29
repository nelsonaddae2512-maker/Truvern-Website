param(
  [string]$LogFile = ".\logs\monitoring\uptime.log",
  [string]$OutDir  = ".\logs\monitoring",
  [int]$CheckIntervalMinutes = 5  # matches your scheduled task cadence
)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$now   = Get-Date
$since = $now.AddDays(-7)

# --- Load and filter last 7 days of logs ---
$lines = if (Test-Path $LogFile) { Get-Content $LogFile } else { @() }
$recent = $lines | Where-Object {
  if ($_ -match '^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \|') {
    [datetime]::ParseExact($Matches.ts,'yyyy-MM-dd HH:mm:ss',$null) -ge $since
  } else { $false }
}

# Only "Result:" lines; each run writes two lines (ops + api)
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

# Group into runs (pair of lines per check)
$runs = @()
for ($i=0; $i -lt $objs.Count; $i+=2) {
  $pair = $objs[$i..([math]::Min($i+1, $objs.Count-1))]
  $runTs = $pair[0].ts
  $okRun = $true
  $errMsgs = @()
  foreach ($p in $pair) { if (-not $p.ok) { $okRun = $false; if ($p.err) { $errMsgs += $p.err } else { $errMsgs += "HTTP $($p.code)" } } }
  $runs += [pscustomobject]@{
    ts     = $runTs
    day    = $runTs.ToString('yyyy-MM-dd')
    ok     = $okRun
    errors = ($errMsgs -join ' | ')
  }
}

# Summaries per day
$dayGroups = $runs | Group-Object day | Sort-Object Name
$perDay = foreach ($g in $dayGroups) {
  $total   = $g.Count
  $failed  = ($g.Group | Where-Object { -not $_.ok }).Count
  $passed  = $total - $failed
  $uptimeP = if ($total -gt 0) { [math]::Round(100.0 * $passed / $total, 2) } else { 0.0 }
  $downtimeMin = $failed * $CheckIntervalMinutes
  [pscustomobject]@{
    day          = $g.Name
    total_checks = $total
    passed       = $passed
    failed       = $failed
    uptime_pct   = $uptimeP
    est_downtime_min = $downtimeMin
  }
}

# Overall tallies
$tt = $runs.Count
$tf = ($runs | Where-Object { -not $_.ok }).Count
$tp = $tt - $tf
$overallPct = if ($tt -gt 0) { [math]::Round(100.0 * $tp / $tt, 3) } else { 0.0 }
$overallDownMin = $tf * $CheckIntervalMinutes

# Top error snippets
$topErrors = ($runs | Where-Object { -not $_.ok -and $_.errors }) |
             Group-Object errors | Sort-Object Count -Descending | Select-Object -First 5

# Build report text
$report = @()
$report += "Truvern Uptime — Weekly Roll-Up"
$report += "Generated : $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += "Window    : $($since.ToString('yyyy-MM-dd HH:mm:ss')) .. $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += ""
$report += "Overall   : checks=$tt  passed=$tp  failed=$tf  uptime=$overallPct`%  est_downtime=${overallDownMin}m"
$report += ""
$report += "Per-day:"
$report += "  Day         Checks  Passed  Failed  Uptime%   EstDown(m)"
foreach ($d in $perDay) {
  $report += ("  {0}  {1,6}  {2,6}  {3,6}  {4,7}  {5,11}" -f $d.day, $d.total_checks, $d.passed, $d.failed, $d.uptime_pct, $d.est_downtime_min)
}
$report += ""
$report += "Top errors:"
if ($topErrors.Count -gt 0) {
  foreach ($e in $topErrors) { $report += ("  x{0}  {1}" -f $e.Count, $e.Name) }
} else {
  $report += "  (no errors recorded)"
}

# Write file
$outFile = Join-Path $OutDir ("weekly-summary-{0}.txt" -f $now.ToString('yyyy-ww'))
$report -join [Environment]::NewLine | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Wrote weekly summary: $outFile"

# Optional email
$smtpHost  = $env:SMTP_HOST
$port  = if ($env:SMTP_PORT) { [int]$env:SMTP_PORT } else { 587 }
$user  = $env:SMTP_USER
$pass  = $env:SMTP_PASS
$from  = $env:SMTP_FROM
$to    = $env:SMTP_TO
$ssl   = if ($env:SMTP_SSL -and $env:SMTP_SSL.ToLower() -in @('1','true','yes')) { $true } else { $true }

if ($smtpHost -and $from -and $to) {
  try {
    $secure = if ($pass) { ConvertTo-SecureString $pass -AsPlainText -Force } else { $null }
    $cred   = if ($user -and $secure) { New-Object System.Management.Automation.PSCredential($user,$secure) } else { $null }
    Send-MailMessage -From $from -To $to -SmtpServer $smtpHost -Port $port -UseSsl:$ssl `
      -Subject ("Truvern Uptime — Weekly {0}" -f $now.ToString('yyyy-ww')) `
      -Body ([System.IO.File]::ReadAllText($outFile)) -BodyAsHtml:$false -Credential $cred
  } catch {
    Add-Content -Path (Join-Path $OutDir "email-errors.log") -Value "$(Get-Date) | Weekly email failed: $($_.Exception.Message)"
  }
}
