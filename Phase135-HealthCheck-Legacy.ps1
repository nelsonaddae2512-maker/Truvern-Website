<# =======================================================================
 Phase135-HealthCheck-Legacy.ps1
 Compatible with PowerShell 5.1 and older syntax.
 Purpose: Verify production endpoints, CSS, and favicon.
 ======================================================================= #>

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

# ---------- Config ----------
$ProjectScope = 'nelson-ai-projects'
$Targets = @(
  'https://truvern.com',
  'https://truvern-41d4tuc0v-nelson-ai-projects.vercel.app'
)
$Endpoints = @('/', '/trust-network', '/api/health')

# ---------- Safety ----------
if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
$RepoRoot = (Resolve-Path $PSScriptRoot).Path
if ($RepoRoot -match 'system32') { Write-Error 'Run from project folder.'; exit 1 }

# ---------- Logging ----------
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logPath = Join-Path $RepoRoot ("Phase135-HealthCheck-{0}.log" -f $stamp)
$jsonOut = Join-Path $RepoRoot ("Phase135-HealthCheck-{0}.json" -f $stamp)
Start-Transcript -Path $logPath | Out-Null
Write-Host "=== Phase135: Health Check (Legacy) ===" -ForegroundColor Cyan

# ---------- HTTP helpers ----------
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $true
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds(20)

function Join-Url($base,$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $base }
  if ($path.StartsWith('http')) { return $path }
  if ($base.EndsWith('/')) { $base = $base.TrimEnd('/') }
  if (-not $path.StartsWith('/')) { $path = '/' + $path }
  return $base + $path
}

function Fetch-Url($url) {
  $r = @{
    url=$url; ok=$false; status=0; reason=''; contentType='';
    contentBytes=0; tookMs=0; html=$null; error=$null
  }
  try {
    $sw=[System.Diagnostics.Stopwatch]::StartNew()
    $resp=$client.GetAsync($url).GetAwaiter().GetResult()
    $sw.Stop()
    $r.tookMs=[int]$sw.Elapsed.TotalMilliseconds
    $r.status=[int]$resp.StatusCode
    $r.reason=$resp.ReasonPhrase
    $r.ok=$resp.IsSuccessStatusCode
    $r.contentType=($resp.Content.Headers.ContentType|ForEach-Object{$_.ToString()}) -join ','
    $bytes=$resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    $r.contentBytes=$bytes.Length
    if ($r.contentType -match 'text/html') {
      $enc=[System.Text.Encoding]::UTF8
      $text=$enc.GetString($bytes)
      if ($text.Length -gt 200000){$text=$text.Substring(0,200000)}
      $r.html=$text
    }
  } catch {
    $r.ok=$false; $r.error=$_.Exception.Message
  }
  return $r
}

function Extract-FirstCssUrl($html,$baseUrl){
  if (-not $html){return $null}
  $m=[regex]::Match($html,'<link[^>]+rel=["'']?stylesheet["''][^>]+href=["''](?<u>[^"''>]+)["'']','IgnoreCase')
  if($m.Success){$u=$m.Groups['u'].Value.Trim();return (Join-Url $baseUrl $u)}
  return $null
}

function Has-FaviconTag($html){
  if(-not $html){return $false}
  return [regex]::IsMatch($html,'<link[^>]+rel=["''](?:icon|shortcut icon)["'']','IgnoreCase')
}

# ---------- Run ----------
$rows=@()
foreach($base in $Targets){
  Write-Host "Checking base: $base" -ForegroundColor Yellow
  foreach($ep in $Endpoints){
    $full=Join-Url $base $ep
    $r=Fetch-Url $full

    $cssUrl=''; $cssOk=$false; $faviOk=$false
    if($r.html){
      $cssUrl=Extract-FirstCssUrl $r.html $base
      if($cssUrl){
        $resp=Fetch-Url $cssUrl
        if($resp.ok -and ($resp.contentType -match 'text/css')){$cssOk=$true}
      }
      $faviOk=Has-FaviconTag $r.html
    }

    $err=''
    if($r.error){$err=$r.error}

    $rows+=New-Object PSObject -Property @{
      Base=$base; Endpoint=$ep; Url=$full;
      Status=$r.status; OK=$r.ok; TookMs=$r.tookMs;
      Type=$r.contentType; Bytes=$r.contentBytes;
      CssUrl=$cssUrl; CssOK=$cssOk; Favicon=$faviOk; Error=$err
    }
  }
}

# ---------- Display ----------
Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
$rows|Sort-Object Base,Endpoint|Format-Table -AutoSize Base,Endpoint,Status,OK,TookMs,Bytes,CssOK,Favicon

# ---------- Save ----------
$rows|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $jsonOut -Encoding UTF8
Write-Host ""
Write-Host "JSON report: $jsonOut" -ForegroundColor DarkGray
Write-Host "Log saved:   $logPath" -ForegroundColor DarkGray
Write-Host "Phase135 complete." -ForegroundColor Green
Stop-Transcript|Out-Null
