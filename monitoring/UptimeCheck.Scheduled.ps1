param(
  [string]$BaseUrl = "https://truvern.com",
  [string]$LogDir = ".\logs\monitoring"
)

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

function Log-Line($msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "$ts | $msg"
  Write-Host $line
  Add-Content -Path (Join-Path $LogDir "uptime.log") -Value $line
}

function Ping($url) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri $url
    return @{ ok = ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400); code = $r.StatusCode }
  } catch {
    return @{ ok = $false; code = -1; err = $_.Exception.Message }
  }
}

$health1 = "$BaseUrl/ops/health"
$health2 = "$BaseUrl/api/health"

Log-Line "Checking $health1"
$a = Ping $health1
Log-Line "Result: ok=$($a.ok) code=$($a.code) err=$($a.err)"

Log-Line "Checking $health2"
$b = Ping $health2
Log-Line "Result: ok=$($b.ok) code=$($b.code) err=$($b.err)"

$ok = ($a.ok -and $b.ok)

if (-not $ok) {
  try {
    Write-EventLog -LogName Application -Source "Windows PowerShell" -EntryType Error -EventId 3000 `
      -Message "Truvern uptime failed: $BaseUrl (ops=$($a.ok), api=$($b.ok))" -ErrorAction SilentlyContinue
  } catch {}
  exit 2
}
exit 0