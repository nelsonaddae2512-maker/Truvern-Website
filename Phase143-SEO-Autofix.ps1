<# =======================================================================
 Phase143-SEO-Autofix.ps1
 Purpose: Auto-inject OG image, favicon, metadataBase, canonical into
          Next.js App Router files, optional Vercel deploy, then verify.
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

#region Safety & Setup
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder (e.g., C:\Users\MR.NELSON\Downloads\truvern) and rerun." -ForegroundColor Red
  exit 1
}

$root   = $pwd.Path
$ts     = Get-Date -Format "yyyyMMdd-HHmmss"
$logs   = Join-Path $root "logs"
$reports= Join-Path $root "reports"
$backups= Join-Path $root ("patch_backups\phase143-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$reports,$backups | Out-Null

$logFile = Join-Path $logs ("Phase143-SEO-Autofix-" + $ts + ".log")
$jsonFile= Join-Path $reports ("Phase143-SEO-Autofix-" + $ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$lvl,$m
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}
Log "=== Phase143: SEO Autofix ==="
#endregion

#region Paths & assets
$appDir     = Join-Path $root "app"
$layoutTsx  = Join-Path $appDir "layout.tsx"
$layoutTs   = Join-Path $appDir "layout.ts"
$layoutFile = if (Test-Path $layoutTsx) { $layoutTsx } elseif (Test-Path $layoutTs) { $layoutTs } else { $null }

if (-not $layoutFile) {
  Log "Root layout not found (app/layout.tsx or app/layout.ts)." "WARN"
  Write-Host "Root layout missing. Create app/layout.tsx and rerun." -ForegroundColor Yellow
  exit 2
}

$publicDir = Join-Path $root "public"
if (-not (Test-Path $publicDir)) { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }

$ogImgPath = Join-Path $publicDir "opengraph-image.png"
if (-not (Test-Path $ogImgPath)) {
  Set-Content -Path $ogImgPath -Value "Truvern OG Image" -Encoding UTF8
  Log "Created placeholder $ogImgPath"
}

$faviconPath = Join-Path $publicDir "favicon.ico"
if (-not (Test-Path $faviconPath)) {
  $tinyIcoB64 = "AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  [IO.File]::WriteAllBytes($faviconPath, [Convert]::FromBase64String($tinyIcoB64))
  Log "Created tiny favicon placeholder $faviconPath"
}

function Backup-File { param([string]$path)
  $dest = Join-Path $backups ([IO.Path]::GetFileName($path) + "." + $ts + ".bak")
  Copy-Item -Path $path -Destination $dest -Force
  Log "Backup -> $dest"
}
#endregion

#region Patch: layout metadata (metadataBase, OG images, icons)
function Ensure-In-Block {
  param([string]$filePath,[string[]]$needLines)

  $text = Get-Content -Raw -Path $filePath
  $hasExport = $text -match "export\s+const\s+metadata\s*=\s*{"
  if (-not $hasExport) {
    Backup-File $filePath
    $lines = Get-Content -Path $filePath
    $insertIdx = 0
    for ($i=0;$i -lt $lines.Count;$i++){ if ($lines[$i] -match "^\s*import\s+") { $insertIdx = $i + 1 } }

    $metaBlock = @(
      "export const metadata = {",
      "  metadataBase: new URL('https://truvern.com'),",
      "  openGraph: {",
      "    images: ['/opengraph-image.png'],",
      "  },",
      "  icons: { icon: '/favicon.ico' },",
      "};"
    )

    $newLines = @()
    if ($insertIdx -gt 0) {
      $newLines += $lines[0..($insertIdx-1)]
      $newLines += $metaBlock
      if ($insertIdx -lt ($lines.Count)) { $newLines += $lines[$insertIdx..($lines.Count-1)] }
    } else { $newLines = $metaBlock + $lines }

    $newLines | Set-Content -Path $filePath -Encoding UTF8
    Log "Inserted metadata export in $filePath"
    return
  }

  $pattern = "export\s+const\s+metadata\s*=\s*{([\s\S]*?)};"
  $m = [regex]::Match($text,$pattern)
  if ($m.Success) {
    $body = $m.Groups[1].Value
    $changed = $false
    foreach ($l in $needLines) {
      if ($body -notmatch [regex]::Escape($l.Trim())) {
        $body = $body.TrimEnd() + "`r`n  " + $l.Trim()
        $changed = $true
      }
    }
    if ($changed) {
      Backup-File $filePath
      $patched = $text.Substring(0,$m.Groups[1].Index) + $body + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length)
      Set-Content -Path $filePath -Value $patched -Encoding UTF8
      Log "Patched metadata fields in $filePath"
    } else {
      Log "Metadata already contains required fields in $filePath"
    }
  } else {
    Backup-File $filePath
    Add-Content -Path $filePath -Value "`r`nexport const metadata = {`r`n  metadataBase: new URL('https://truvern.com'),`r`n  openGraph: { images: ['/opengraph-image.png'] },`r`n  icons: { icon: '/favicon.ico' },`r`n};`r`n"
    Log "Could not parse metadata; appended new block in $filePath" "WARN"
  }
}

Ensure-In-Block -filePath $layoutFile -needLines @(
  "metadataBase: new URL('https://truvern.com'),",
  "openGraph: {",
  "  images: ['/opengraph-image.png'],",
  "},",
  "icons: { icon: '/favicon.ico' },"
)
#endregion

#region Patch: page-level canonicals
function Ensure-Canonical-On-Page {
  param([string]$pagePath,[string]$canonical)

  if (-not (Test-Path $pagePath)) { Log "Page missing (skip): $pagePath" "WARN"; return }

  $text = Get-Content -Raw -Path $pagePath
  if ($text -notmatch "export\s+const\s+metadata\s*=") {
    Backup-File $pagePath
    $lines = Get-Content -Path $pagePath
    $insertIdx = 0
    for ($i=0;$i -lt $lines.Count;$i++){ if ($lines[$i] -match "^\s*import\s+") { $insertIdx = $i + 1 } }
    $block = @(
      "export const metadata = {",
      "  alternates: { canonical: '$canonical' },",
      "};"
    )
    $newLines=@()
    if ($insertIdx -gt 0) {
      $newLines += $lines[0..($insertIdx-1)]
      $newLines += $block
      if ($insertIdx -lt $lines.Count) { $newLines += $lines[$insertIdx..($lines.Count-1)] }
    } else { $newLines = $block + $lines }
    $newLines | Set-Content -Path $pagePath -Encoding UTF8
    Log "Inserted canonical into $pagePath"
    return
  }

  $pattern = "export\s+const\s+metadata\s*=\s*{([\s\S]*?)};"
  $m = [regex]::Match($text,$pattern)
  if ($m.Success) {
    $body = $m.Groups[1].Value
    if ($body -match "alternates\s*:\s*{") {
      if ($body -notmatch "canonical\s*:\s*'$([regex]::Escape($canonical))'") {
        Backup-File $pagePath
        $body = [regex]::Replace($body,"alternates\s*:\s*{","alternates: { canonical: '$canonical', ",1)
        $patched = $text.Substring(0,$m.Groups[1].Index) + $body + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length)
        Set-Content -Path $pagePath -Value $patched -Encoding UTF8
        Log "Patched canonicals inside alternates for $pagePath"
      } else { Log "Canonical already present in $pagePath" }
    } else {
      Backup-File $pagePath
      $body = $body.TrimEnd() + "`r`n  alternates: { canonical: '$canonical' },"
      $patched = $text.Substring(0,$m.Groups[1].Index) + $body + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length)
      Set-Content -Path $pagePath -Value $patched -Encoding UTF8
      Log "Added alternates.canonical to $pagePath"
    }
  } else {
    Backup-File $pagePath
    Add-Content -Path $pagePath -Value "`r`nexport const metadata = { alternates: { canonical: '$canonical' } };`r`n"
    Log "Appended minimal metadata with canonical to $pagePath" "WARN"
  }
}

Ensure-Canonical-On-Page -pagePath (Join-Path $appDir "trust-network\page.tsx") -canonical "/trust-network"
Ensure-Canonical-On-Page -pagePath (Join-Path $appDir "reports\board\page.tsx") -canonical "/reports/board"
Ensure-Canonical-On-Page -pagePath (Join-Path $appDir "vendors\page.tsx") -canonical "/vendors"
#endregion

#region Optional: Vercel build + deploy
$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if ($vercel) {
  try {
    Log "Vercel CLI detected. Running prebuilt deploy…"
    cmd /c "vercel build"              | Tee-Object -FilePath $logFile -Append | Out-Null
    cmd /c "vercel deploy --prebuilt --prod" | Tee-Object -FilePath $logFile -Append | Out-Null
    Log "Vercel deploy attempted."
  } catch {
    Log ("Vercel deploy failed: " + $_.Exception.Message) "WARN"
  }
} else {
  Log "Vercel CLI not found; skipping deploy." "WARN"
}
#endregion

#region Verify (inline Phase142 signals)
$Base="https://truvern.com"
function Fetch-Page { param([string]$url)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{$r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25;$sw.Stop();[pscustomobject]@{Url=$url;Status=[int]$r.StatusCode;OK=$true;TookMs=[int]$sw.ElapsedMilliseconds;Html=$r.Content}}catch{$sw.Stop();[pscustomobject]@{Url=$url;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;Error=$_.Exception.Message;Html=""}}
}
function MatchVal { param($h,$re) ; try{([regex]::Match($h,$re,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim()}catch{""}}
function AbsUrl  { param($u,$b); if(-not $u){return""}; if($u -like"http*"){$u}elseif($u.StartsWith("//")){"https:"+$u}elseif($u.StartsWith("/")){$b+$u}else{$b.TrimEnd('/')+"/"+$u.TrimStart('/')} }
function Head200 { param($u); if(-not $u){return 0}; try{(Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode}catch{0} }

$paths=@("/","/trust-network","/reports/board","/vendors")
$verify=@()
foreach($p in $paths){
  $url="$Base$p"; $pg=Fetch-Page $url
  $ogi=MatchVal $pg.Html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $ogiAbs=AbsUrl $ogi $Base; $ogStatus=Head200 $ogiAbs
  $can=MatchVal $pg.Html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $canAbs=AbsUrl $can $Base
  $canOK=$false; if($canAbs){ try{$canHost=([uri]$canAbs).Host;$baseHost=([uri]$Base).Host;$canOK=($canHost -eq $baseHost)}catch{$canOK=$false} }
  $verify += [pscustomobject]@{Path=$p;HTTP=$pg.Status;OK=$pg.OK;OGImage=$ogiAbs;OGHTTP=$ogStatus;Canonical=$canAbs;HostOK=$canOK}
}
#endregion

#region Save report + console output
$summary=[pscustomobject]@{
  Phase="Phase143-SEO-Autofix"
  Timestamp=(Get-Date).ToString("s")
  Base=$Base
  LayoutPatched=$layoutFile
  FilesBackedUp=(Get-ChildItem $backups -File | Select-Object -ExpandProperty FullName)
  Verify=$verify
}
$summary|ConvertTo-Json -Depth 6|Out-File -FilePath $jsonFile -Encoding UTF8
Log "JSON report -> $jsonFile"

Write-Host "`nVerification:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f "Path","HTTP","OK","OG Image","OG","Canonical","HostOK"
foreach ($v in $verify) {
  $ogImg = if ($v.OGImage) { $v.OGImage } else { "" }
  $canVal = if ($v.Canonical) { $v.Canonical } else { "" }
  "{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f $v.Path, $v.HTTP, $v.OK, $ogImg, $v.OGHTTP, $canVal, $v.HostOK | Write-Host
}

Write-Host "`nBackups: $backups"
Write-Host "JSON:    $jsonFile"
Write-Host "Log:     $logFile`n"
Write-Host "Phase143 complete." -ForegroundColor Green
#endregion
