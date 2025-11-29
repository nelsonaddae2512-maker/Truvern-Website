param(
  [string]$DailyGlob = ".\logs\monitoring\daily-summary-*.txt",
  [string]$WeeklyGlob = ".\logs\monitoring\weekly-summary-*.txt",
  [string]$UptimeLog = ".\logs\monitoring\uptime.log",
  [string]$OutFile = ".\reports\index.html"
)

function Get-LatestFileContent([string]$glob){
  $f = Get-ChildItem $glob -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
  if ($null -eq $f) { return $null }
  return [System.IO.File]::ReadAllText($f.FullName)
}

# Build a tiny 24h sparkline (last 24 checks) from uptime.log (OK=█, Fail=░)
function Get-Sparkline([string]$logPath){
  if (-not (Test-Path $logPath)) { return "(no data)" }
  $lines = Get-Content $logPath
  # take last 48 "Result:" lines → 24 runs (ops+api), success only if both lines say ok=True
  $res = $lines | Where-Object { $_ -match '\|\s*Result:\s*ok=' } | Select-Object -Last 48
  if ($res.Count -lt 2) { return "(no data)" }
  $blocks = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $res.Count; $i+=2) {
    $pair = $res[$i..([math]::Min($i+1,$res.Count-1))]
    $okA = ($pair[0] -match 'ok=True')
    $okB = ($pair.Count -gt 1 -and $pair[1] -match 'ok=True')
    if ($okA -and $okB) { $blocks.Add("█") } else { $blocks.Add("░") }
  }
  return ($blocks -join "")
}

$daily   = Get-LatestFileContent $DailyGlob
$weekly  = Get-LatestFileContent $WeeklyGlob
$spark   = Get-Sparkline $UptimeLog
$nowTs   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

if (-not $daily)  { $daily  = "No daily summary found yet." }
if (-not $weekly) { $weekly = "No weekly summary found yet." }

# Basic CSS + HTML (light, offline)
$css = @"
:root{--bg:#0b1020;--card:#11182b;--text:#e9eefc;--muted:#b4c0df;--ok:#23d18b;--bad:#ff5c5c;--accent:#7aa2f7}
*{box-sizing:border-box} body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Arial,sans-serif;background:var(--bg);color:var(--text)}
.wrap{max-width:1100px;margin:40px auto;padding:0 16px}
h1{font-size:22px;margin:0 0 8px} .sub{color:var(--muted);margin-bottom:18px}
.card{background:var(--card);border:1px solid #1c2540;border-radius:12px;padding:16px;margin:14px 0}
pre{white-space:pre-wrap;word-break:break-word;margin:0;font-family:ui-monospace,Consolas,Menlo,monospace}
.section-title{font-weight:600;color:var(--accent);letter-spacing:.3px;margin-bottom:10px}
.kv{display:flex;gap:12px;align-items:center;margin-bottom:10px}
.badge{padding:3px 8px;border-radius:6px;background:#0e233f;border:1px solid #1f335a;color:var(--muted);font-size:12px}
.spark{font-family:ui-monospace,Consolas,Menlo,monospace;font-size:18px;letter-spacing:1px}
.footer{color:#8ea0c6;font-size:12px;margin-top:16px}
"@

$html = @"
<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Truvern Health Dashboard</title>
<style>$css</style>
<body>
  <div class="wrap">
    <h1>Truvern Health Dashboard</h1>
    <div class="sub">Last generated: $nowTs</div>

    <div class="card">
      <div class="section-title">24h Sparkline</div>
      <div class="kv">
        <span class="badge">█ OK</span><span class="badge">░ FAIL</span>
      </div>
      <div class="spark">$spark</div>
    </div>

    <div class="card">
      <div class="section-title">Daily Summary</div>
      <pre>$([System.Net.WebUtility]::HtmlEncode($daily))</pre>
    </div>

    <div class="card">
      <div class="section-title">Weekly Roll-Up</div>
      <pre>$([System.Net.WebUtility]::HtmlEncode($weekly))</pre>
    </div>

    <div class="footer">Data source: logs/monitoring (uptime.log, daily-summary-*.txt, weekly-summary-*.txt)</div>
  </div>
</body></html>
"@

# Ensure System.Web for HtmlEncode
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
[System.IO.File]::WriteAllText($OutFile, $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote dashboard: $OutFile"
