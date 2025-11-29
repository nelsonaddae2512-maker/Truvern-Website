<# =======================================================================
 Phase135-HealthCheck-Fixed.ps1
 Compatible with PowerShell 5.x
 Purpose: Verify production endpoints, CSS, and favicon after deploy.
 ======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- Config ----------
$ProjectScope = 'nelson-ai-projects'
$Targets = @(
  'https://truvern.com',
  'https://truvern-41d4tuc0v-nelson-ai-projects.vercel.app'
)

$Endpoints = @(
  '/',
  '/trust-network',
  '/api/health'
)

# ---------- Safety ----------
if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
$RepoRoot = (Resolve-Path $PSScriptRoot).Path
$badRoots = @('C:\Windows\System32','C:\WINDOWS\system32')
if ($badRoots -contains (Get-Location).Path) {
  Write-Error 'Refusing to run from system32. Run from your project folder.'
  exit 1
}

# ---------- Logging ----------
$stamp   = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logPath = Join-Path $RepoRoot ("Phase135-HealthCheck-{0}.log" -f $stamp)
$jsonOut = Join-Path $RepoRoot ("Phase135-HealthCheck-{0}.json" -f $stamp)
Start-Transcript -Path $logPath | Out-Null

Write-Host "=== Phase135: Health Check ===" -ForegroundColor Cyan
Write-Host ("Scope: {0}" -f $ProjectScope) -ForegroundColor DarkCyan

# ---------- HTTP helpers ----------
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $true
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds(20)

function Join-Url {
  param([string]$base,[string]$path)
  if ([string]::IsNullOrWhiteSpace($path)) { return $base }
  if ($path.StartsWith('http')) { return $path }
  if ($base.EndsWith('/')) { $base = $base.TrimEnd('/') }
  if (-not $path.StartsWith('/')) { $path = '/' + $path }
  return $base + $path
}

function Fetch-Url {
  param([string]$url)
  $result = @{
    url          = $url
    ok           = $false
    status       = 0
    reason       = ''
    contentType  = ''
    contentBytes = 0
    tookMs       = 0
    html         = $null
    error        = $null
  }
  try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = $client.GetAsync($url).GetAwaiter().GetResult()
    $sw.Stop()
    $result.tookMs = [int]$sw.Elapsed.TotalMilliseconds
    $result.status = [int]$resp.StatusCode
    $result.reason = $resp.ReasonPhrase
    $result.ok     = $resp.IsSuccessStatusCode
    $result.contentType = ($resp.Content.Headers.ContentType | ForEach-Object { $_.ToString() }) -join ','
    $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    $result.contentBytes = $bytes.Length
    if ($result.contentType -match 'text/html') {
      $enc = [System.Text.Encoding]::UTF8
      $text = $enc.GetString($bytes)
      if ($text.Length -gt 200000) { $text = $text.Substring(0,200000) }
      $result.html = $text
    }
  } catch {
    $result.ok = $false
    $result.error = $_.Exception.Message
  }
  return $result
}

function Extract-FirstCssUrl {
  param([string]$html,[string]$baseUrl)
  if (-not $html) { return $null }
  $m = [regex]::Match($html, '<link[^>]+rel=["'']?stylesheet["''][^>]+href=["''](?<u>[^"''>]+)["'']', 'IgnoreCase')
  if ($m.Success) {
    $u = $m.Groups['u'].Value.Trim()
    return (Join-Url -base $baseUrl -path $u)
  }
  return $null
}

function Has-FaviconTag {
  param([string]$html)
  if (-not $html) { return $false }
  return [regex]::IsMatch($html, '<link[^>]+rel=["''](?:icon|shortcut icon)["'']', 'IgnoreCase')
}

# ---------- Run checks ----------
$rows = @()

foreach ($base in $Targets) {
  Write-Host ("Checking base: {0}" -f $base) -ForegroundColor Yellow
  foreach ($ep in $Endpoints) {
    $full = Join-Url -base $base -path $ep
    $r = Fetch-Url -url $full

    $cssOk = $false
    $cssUrl = ''
    $faviOk = $false

    if ($r.html) {
      $cssUrl = Extract-FirstCssUrl -html $r.html -baseUrl $base
      if ($cssUrl) {
        $cssResp = Fetch-Url -url $cssUrl
        $cssOk = $cssResp.ok -and ($cssResp.contentType -match 'text/css')
      }
      $faviOk = Has-FaviconTag -html $r.html
    }

    $rows += [PSCustomObject]@{
      Base      = $base
      Endpoint  = $ep
      Url       = $full
      Status    = $r.status
      OK        = $r.ok
      TookMs    = $r.tookMs
      Type      = $r.contentType
      Bytes     = $r.contentBytes
      CssUrl    = ($cssUrl -ne $null) ? $cssUrl : ''
      CssOK     = $cssOk
      Favicon   = $faviOk
      Error     = ($r.error -ne $null) ? $r.error : ''
    }
  }
}

# ---------- Print table ----------
Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
$rows | Sort-Object Base, Endpoint | Format-Table -AutoSize Base,Endpoint,Status,OK,TookMs,Bytes,CssOK,Favicon

# ---------- Save JSON ----------
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonOut -Encoding UTF8

Write-Host ""
Write-Host ("JSON report: {0}" -f $jsonOut) -ForegroundColor DarkGray
Write-Host ("Log saved:   {0}" -f $logPath) -ForegroundColor DarkGray
Write-Host "Phase135 complete." -ForegroundColor Green
Stop-Transcript | Out-Null
