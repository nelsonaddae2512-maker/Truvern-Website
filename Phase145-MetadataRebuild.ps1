<# =======================================================================
 Phase145-MetadataRebuild-Fix.ps1
 Purpose: Fix pages showing no content by clearing caches, deduping metadata,
 rebuilding, deploying, and verifying.
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $root "logs"
$reports = Join-Path $root "reports"
$artifacts = Join-Path $root ("artifacts\\phase145-" + $ts)
New-Item -ItemType Directory -Force -Path $logs, $reports, $artifacts | Out-Null

$logFile = Join-Path $logs ("Phase145-MetadataRebuild-" + $ts + ".log")
$jsonFile = Join-Path $reports ("Phase145-MetadataRebuild-" + $ts + ".json")

function Write-Log { param([string]$msg, [string]$lvl = "INFO")
  $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] [" + $lvl + "] " + $msg
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}

Write-Log "=== Phase145: Metadata Rebuild & Verify ==="

# --- Helpers ---
function Exec {
  param([string]$cmd)
  Write-Log ("RUN: " + $cmd)
  cmd /c $cmd | Tee-Object -FilePath $logFile -Append | Out-Null
}

function Fetch {
  param([string]$url, [int]$timeout = 25)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout
    $sw.Stop()
    return [pscustomobject]@{
      Url = $url; Status = [int]$r.StatusCode; OK = $true
      TookMs = [int]$sw.ElapsedMilliseconds; Html = $r.Content
    }
  } catch {
    $sw.Stop()
    return [pscustomobject]@{
      Url = $url; Status = 0; OK = $false
      TookMs = [int]$sw.ElapsedMilliseconds; Html = ""; Error = $_.Exception.Message
    }
  }
}

function MatchVal { param([string]$html, [string]$re)
  try { ([regex]::Match($html, $re, [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim() } catch { "" }
}

function AbsUrl { param([string]$u, [string]$b)
  if (-not $u) { return "" }
  if ($u -like "http*") { return $u }
  elseif ($u.StartsWith("//")) { return "https:" + $u }
  elseif ($u.StartsWith("/")) { return $b + $u }
  else { return ($b.TrimEnd("/") + "/" + $u.TrimStart("/")) }
}

function Head200 { param([string]$u)
  if (-not $u) { return 0 }
  try { (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode } catch { 0 }
}

# --- Cache Cleanup ---
Write-Log "Clearing caches..."
$pathsToRemove = @(".next", ".turbo", ".vercel\\output", ".cache", "node_modules\\.cache", ".swc")
foreach ($p in $pathsToRemove) {
  $full = Join-Path $root $p
  if (Test-Path $full) {
    try {
      Remove-Item $full -Recurse -Force -ErrorAction Stop
      Write-Log ("Removed " + $p)
    } catch {
      Write-Log ("Skip remove " + $p + ": " + $_.Exception.Message) "WARN"
    }
  }
}

# --- Dedup layout metadata ---
$appDir = Join-Path $root "app"
$layoutTsx = Join-Path $appDir "layout.tsx"
$layoutTs = Join-Path $appDir "layout.ts"
$layout = $null
if (Test-Path $layoutTsx) { $layout = $layoutTsx } elseif (Test-Path $layoutTs) { $layout = $layoutTs }

if ($layout) {
  $txt = Get-Content -Raw -Path $layout
  $matches = [regex]::Matches($txt, "export\s+const\s+metadata\s*=\s*{")
  if ($matches.Count -gt 1) {
    Write-Log ("Multiple 'export const metadata' found in layout: " + $matches.Count)
    $lines = Get-Content -Path $layout
    $seen = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match "export\s+const\s+metadata\s*=\s*{") {
        $seen++
        if ($seen -gt 1) { $lines[$i] = "// Phase145: duplicate removed -> " + $lines[$i] }
      }
    }
    $backup = Join-Path $artifacts ("layout.tsx." + $ts + ".bak")
    Copy-Item $layout $backup -Force
    $lines | Set-Content -Path $layout -Encoding UTF8
    Write-Log ("Duplicates commented. Backup -> " + $backup)
  } else {
    Write-Log ("Layout metadata export count OK (" + $matches.Count + ")")
  }
} else {
  Write-Log "No layout.tsx or layout.ts found" "WARN"
}

# --- Public assets ---
$publicDir = Join-Path $root "public"
if (-not (Test-Path $publicDir)) { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }
$ogPath = Join-Path $publicDir "opengraph-image.png"
if (-not (Test-Path $ogPath)) {
  Set-Content -Path $ogPath -Value "Truvern OpenGraph" -Encoding UTF8
  Write-Log ("Created OG placeholder " + $ogPath)
}
$favicon = Join-Path $publicDir "favicon.ico"
if (-not (Test-Path $favicon)) {
  $tinyIcoB64 = "AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  [IO.File]::WriteAllBytes($favicon, [Convert]::FromBase64String($tinyIcoB64))
  Write-Log "Created tiny favicon."
}

# --- Build + Deploy ---
$pm = $null
if (Get-Command pnpm -ErrorAction SilentlyContinue) { $pm = "pnpm" }
elseif (Get-Command npm -ErrorAction SilentlyContinue) { $pm = "npm" }
elseif (Get-Command yarn -ErrorAction SilentlyContinue) { $pm = "yarn" }

if ($pm -eq "pnpm") { Exec "pnpm install --frozen-lockfile" }
elseif ($pm -eq "npm") { Exec "npm ci" }
elseif ($pm -eq "yarn") { Exec "yarn install --frozen-lockfile" }

$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if ($vercel) {
  Exec "vercel build --force"
  Exec "vercel deploy --prebuilt --prod"
} else {
  if ($pm -eq "pnpm") { Exec "pnpm next build" }
  elseif ($pm -eq "npm") { Exec "npm run build" }
  elseif ($pm -eq "yarn") { Exec "yarn build" }
}

# --- Verification ---
$Base = "https://truvern.com"
$paths = @("/", "/trust-network", "/reports/board", "/vendors")
$verify = @()
foreach ($p in $paths) {
  $url = "$Base$p"
  $pg = Fetch $url
  $html = $pg.Html
  $bodyLen = if ($html) { [int][Text.Encoding]::UTF8.GetByteCount($html) } else { 0 }
  $hasHtml = $false
  if ($html) { if ($html -match "<html") { $hasHtml = $true } }

  $title = MatchVal $html "<title>(.*?)</title>"
  $ogi = MatchVal $html "<meta\s+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can = MatchVal $html "<link\s+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogiAbs = AbsUrl $ogi $Base
  $ogStatus = Head200 $ogiAbs
  $canAbs = AbsUrl $can $Base
  $canOK = $false
  if ($canAbs) {
    try {
      $canOK = (([uri]$canAbs).Host -eq ([uri]$Base).Host)
    } catch { $canOK = $false }
  }

  $verify += [pscustomobject]@{
    Path = $p; HTTP = $pg.Status; OK = $pg.OK;
    Bytes = $bodyLen; Html = $hasHtml;
    Title = $title; OG = $ogStatus; Canonical = $canAbs; HostOK = $canOK
  }
}

$summary = [pscustomobject]@{
  Phase = "Phase145-MetadataRebuild-Fix"
  Timestamp = (Get-Date).ToString("s")
  Verify = $verify
}
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log ("JSON saved to " + $jsonFile)

Write-Host "`nResults:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,8} {4,7} {5,6} {6,6} {7,6}" -f "Path","HTTP","OK","Bytes","<html>","OG","Canon","HostOK"
foreach ($v in $verify) {
  "{0,-16} {1,5} {2,5} {3,8} {4,7} {5,6} {6,6} {7,6}" -f $v.Path,$v.HTTP,$v.OK,$v.Bytes,$v.Html,$v.OG,([string]([bool]$v.Canonical)),$v.HostOK | Write-Host
}

Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile"
Write-Host "`nPhase145 complete." -ForegroundColor Green
