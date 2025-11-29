<# =======================================================================
 Phase146-SEO-MetaRestore.ps1
 Purpose: Restore Open Graph + Canonical metadata for Truvern (Next.js App Router),
          rebuild/deploy, and verify on https://truvern.com
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts   = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $root "logs"
$reports = Join-Path $root "reports"
$backups = Join-Path $root ("patch_backups\phase146-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$reports,$backups | Out-Null
$logFile  = Join-Path $logs ("Phase146-SEO-MetaRestore-" + $ts + ".log")
$jsonFile = Join-Path $reports ("Phase146-SEO-MetaRestore-" + $ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] [" + $lvl + "] " + $m
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}
Log "=== Phase146: SEO Meta Restore ==="

# ---------- Helpers ----------
function Fetch {
  param([string]$url,[int]$timeout=25)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{ $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout; $sw.Stop();
       return [pscustomobject]@{Url=$url;Status=[int]$r.StatusCode;OK=$true;TookMs=[int]$sw.ElapsedMilliseconds;Html=$r.Content} }
  catch{ $sw.Stop(); return [pscustomobject]@{Url=$url;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;Html="";Error=$_.Exception.Message} }
}
function MatchVal { param([string]$html,[string]$re)
  try{ ([regex]::Match($html,$re,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim() }catch{ "" }
}
function AbsUrl { param([string]$u,[string]$b)
  if(-not $u){return ""} ; if($u -like "http*"){return $u}
  if($u.StartsWith("//")){ "https:"+$u } elseif($u.StartsWith("/")){ $b+$u } else { $b.TrimEnd("/")+"/"+$u.TrimStart("/") }
}
function Head200 { param([string]$u)
  if(-not $u){return 0} ; try{ (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode }catch{ 0 }
}
function Backup-File { param([string]$path)
  $dest = Join-Path $backups ([IO.Path]::GetFileName($path) + "." + $ts + ".bak")
  Copy-Item -Path $path -Destination $dest -Force
  Log ("Backup -> " + $dest)
}
function Exec {
  param([string]$cmd)
  Log ("RUN: " + $cmd)
  cmd /c $cmd | Tee-Object -FilePath $logFile -Append | Out-Null
}

# ---------- Ensure public assets ----------
$publicDir = Join-Path $root "public"
if(-not (Test-Path $publicDir)){ New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }
$ogImg = Join-Path $publicDir "opengraph-image.png"
if(-not (Test-Path $ogImg)){ Set-Content -Path $ogImg -Value "Truvern OG" -Encoding UTF8; Log ("Created placeholder OG -> " + $ogImg) }
$favicon = Join-Path $publicDir "favicon.ico"
if(-not (Test-Path $favicon)){
  $tinyIcoB64="AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  [IO.File]::WriteAllBytes($favicon,[Convert]::FromBase64String($tinyIcoB64))
  Log "Created tiny favicon.ico"
}

# ---------- Patch layout metadata ----------
$appDir = Join-Path $root "app"
$layoutTsx = Join-Path $appDir "layout.tsx"
$layoutTs  = Join-Path $appDir "layout.ts"
$layout = $null
if(Test-Path $layoutTsx){ $layout=$layoutTsx } elseif(Test-Path $layoutTs){ $layout=$layoutTs }
if(-not $layout){ Log "No app/layout.tsx or layout.ts found" "WARN"; Write-Host "Missing root layout file in /app." -ForegroundColor Yellow; }

if($layout){
  $txt = Get-Content -Raw -Path $layout
  # Comment duplicate exports
  $mAll = [regex]::Matches($txt,"export\s+const\s+metadata\s*=\s*{")
  if($mAll.Count -gt 1){
    $lines = Get-Content -Path $layout
    $seen = 0
    for($i=0;$i -lt $lines.Count;$i++){
      if($lines[$i] -match "export\s+const\s+metadata\s*=\s*{"){
        $seen++
        if($seen -gt 1){ $lines[$i] = "// Phase146 duplicate removed -> " + $lines[$i] }
      }
    }
    Backup-File $layout
    $lines | Set-Content -Path $layout -Encoding UTF8
    Log ("Commented duplicates in layout (count " + $mAll.Count + ")")
    $txt = Get-Content -Raw -Path $layout
  }

  $hasExport = $txt -match "export\s+const\s+metadata\s*=\s*{"
  if(-not $hasExport){
    Backup-File $layout
    $lines = Get-Content -Path $layout
    $insertIdx = 0
    for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match "^\s*import\s+"){ $insertIdx = $i + 1 } }
    $block = @(
      "export const metadata = {",
      "  metadataBase: new URL('https://truvern.com'),",
      "  title: { default: 'Truvern', template: '%s | Truvern' },",
      "description: 'Truvern - Vendor trust network and TPRM.',",
      "  openGraph: { images: ['/opengraph-image.png'] },",
      "  icons: { icon: '/favicon.ico' },",
      "};"
    )
    $new=@()
    if($insertIdx -gt 0){ $new += $lines[0..($insertIdx-1)]; $new += $block; if($insertIdx -lt $lines.Count){ $new += $lines[$insertIdx..($lines.Count-1)] } }
    else{ $new = $block + $lines }
    $new | Set-Content -Path $layout -Encoding UTF8
    Log "Inserted metadata export into layout"
  } else {
    # Ensure required fields exist in existing block
    $pattern = "export\s+const\s+metadata\s*=\s*{([\s\S]*?)};"
    $m = [regex]::Match($txt,$pattern)
    if($m.Success){
      $body = $m.Groups[1].Value
      $changed = $false
      $req = @(
        "metadataBase: new URL('https://truvern.com'),",
        "openGraph: {",
        "  images: ['/opengraph-image.png'],",
        "},",
        "icons: { icon: '/favicon.ico' },"
      )
      foreach($l in $req){ if($body -notmatch [regex]::Escape($l.Trim())){ $body = $body.TrimEnd() + "`r`n  " + $l.Trim(); $changed=$true } }
      if($body -notmatch "description\s*:\s*"){ $body = $body.TrimEnd() + "`r`n  "description: 'Truvern - Vendor trust network and TPRM.',"
; $changed=$true }
      if($body -notmatch "title\s*:\s*{"){ $body = $body.TrimEnd() + "`r`n  title: { default: 'Truvern', template: '%s | Truvern' },"; $changed=$true }
      if($changed){
        Backup-File $layout
        $pre = $txt.Substring(0,$m.Groups[1].Index)
        $postStart = $m.Groups[1].Index + $m.Groups[1].Length
        $post = $txt.Substring($postStart)
        $patched = $pre + $body + $post
        $patched | Set-Content -Path $layout -Encoding UTF8
        Log "Patched layout metadata with required fields"
      } else { Log "Layout metadata already has required fields" }
    } else {
      Backup-File $layout
      Add-Content -Path $layout -Value "`r`nexport const metadata = { metadataBase: new URL('https://truvern.com'), openGraph: { images: ['/opengraph-image.png'] }, icons: { icon: '/favicon.ico' } };`r`n"
      Log "Could not parse layout metadata; appended minimal block" "WARN"
    }
  }
}

# ---------- Patch canonicals on pages ----------
function Ensure-Page-Meta {
  param([string]$pagePath,[string]$canonical,[string]$title,[string]$desc)
  if(-not (Test-Path $pagePath)){ Log ("Page missing (skip): " + $pagePath) "WARN"; return }
  $text = Get-Content -Raw -Path $pagePath
  if($text -notmatch "export\s+const\s+metadata\s*="){
    Backup-File $pagePath
    $lines = Get-Content -Path $pagePath
    $insertIdx = 0
    for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match "^\s*import\s+"){ $insertIdx = $i + 1 } }
    $block = @(
      "export const metadata = {",
      "  title: '" + $title + "',",
      "  description: '" + $desc + "',",
      "  alternates: { canonical: '" + $canonical + "' },",
      "};"
    )
    $new=@()
    if($insertIdx -gt 0){ $new += $lines[0..($insertIdx-1)]; $new += $block; if($insertIdx -lt $lines.Count){ $new += $lines[$insertIdx..($lines.Count-1)] } }
    else{ $new = $block + $lines }
    $new | Set-Content -Path $pagePath -Encoding UTF8
    Log ("Inserted metadata block into " + $pagePath)
    return
  }
  # Patch existing
  $pattern = "export\s+const\s+metadata\s*=\s*{([\s\S]*?)};"
  $m = [regex]::Match($text,$pattern)
  if($m.Success){
    $body = $m.Groups[1].Value
    $changed = $false
    if($body -notmatch "alternates\s*:\s*{"){ $body = $body.TrimEnd() + "`r`n  alternates: { canonical: '" + $canonical + "' },"; $changed=$true }
    elseif($body -notmatch "canonical\s*:\s*'"+[regex]::Escape($canonical)+"'"){
      $body = [regex]::Replace($body,"alternates\s*:\s*{","alternates: { canonical: '" + $canonical + "', ",1); $changed=$true
    }
    if($body -notmatch "title\s*:\s*"){ $body = $body.TrimEnd() + "`r`n  title: '" + $title + "',"; $changed=$true }
    if($body -notmatch "description\s*:\s*"){ $body = $body.TrimEnd() + "`r`n  description: '" + $desc + "',"; $changed=$true }
    if($changed){
      Backup-File $pagePath
      $pre = $text.Substring(0,$m.Groups[1].Index)
      $postStart = $m.Groups[1].Index + $m.Groups[1].Length
      $post = $text.Substring($postStart)
      $patched = $pre + $body + $post
      $patched | Set-Content -Path $pagePath -Encoding UTF8
      Log ("Patched metadata in " + $pagePath)
    } else { Log ("Metadata already OK in " + $pagePath) }
  } else {
    Backup-File $pagePath
    Add-Content -Path $pagePath -Value "`r`nexport const metadata = { title: '" + $title + "', description: '" + $desc + "', alternates: { canonical: '" + $canonical + "' } };`r`n"
    Log ("Appended minimal metadata in " + $pagePath) "WARN"
  }
}

Ensure-Page-Meta -pagePath (Join-Path $appDir "trust-network\page.tsx") -canonical "/trust-network" -title "Trust Network" -desc "Discover vendor trust signals and TPRM insights."
Ensure-Page-Meta -pagePath (Join-Path $appDir "reports\board\page.tsx") -canonical "/reports/board" -title "Board Reports" -desc "Board-level risk dashboards and summaries."
Ensure-Page-Meta -pagePath (Join-Path $appDir "vendors\page.tsx") -canonical "/vendors" -title "Vendors" -desc "Manage vendors, evidence, and remediation workflows."

# ---------- Rebuild + (optional) deploy ----------
$pm = $null
if(Get-Command pnpm -ErrorAction SilentlyContinue){ $pm="pnpm" } elseif(Get-Command npm -ErrorAction SilentlyContinue){ $pm="npm" } elseif(Get-Command yarn -ErrorAction SilentlyContinue){ $pm="yarn" }

if($pm -eq "pnpm"){ Exec "pnpm install --frozen-lockfile" }
elseif($pm -eq "npm"){ Exec "npm ci" }
elseif($pm -eq "yarn"){ Exec "yarn install --frozen-lockfile" }

$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if($vercel){
  # Newer Vercel CLI: just build, then deploy prebuilt
  Exec "vercel build"
  Exec "vercel deploy --prebuilt --prod"
}else{
  if($pm -eq "pnpm"){ Exec "pnpm next build" }
  elseif($pm -eq "npm"){ Exec "npm run build" }
  elseif($pm -eq "yarn"){ Exec "yarn build" }
}

# ---------- Verify live ----------
$Base="https://truvern.com"
$paths=@("/","/trust-network","/reports/board","/vendors")
$verify=@()
foreach($p in $paths){
  $u="$Base$p"
  $pg=Fetch $u
  $html=$pg.Html
  $ogi=MatchVal $html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can=MatchVal $html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogiAbs=AbsUrl $ogi $Base
  $ogStatus=Head200 $ogiAbs
  $canAbs=AbsUrl $can $Base
  $canOK=$false
  if($canAbs){ try{ $canOK = (([uri]$canAbs).Host -eq ([uri]$Base).Host) }catch{ $canOK=$false } }
  $verify += [pscustomobject]@{ Path=$p; HTTP=$pg.Status; OK=$pg.OK; OG=$ogStatus; Canonical=$canAbs; HostOK=$canOK }
}

$summary=[pscustomobject]@{
  Phase="Phase146-SEO-MetaRestore"
  Timestamp=(Get-Date).ToString("s")
  Verify=$verify
  Backups=(Get-ChildItem $backups -File | Select-Object -ExpandProperty FullName)
}
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
Log ("JSON -> " + $jsonFile)

Write-Host "`nVerification:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,6} {4,-36} {5,6}" -f "Path","HTTP","OK","OG","Canonical","HostOK"
foreach($v in $verify){
  $canon = if($v.Canonical){$v.Canonical}else{""}
  "{0,-16} {1,5} {2,5} {3,6} {4,-36} {5,6}" -f $v.Path,$v.HTTP,$v.OK,$v.OG,$canon,$v.HostOK | Write-Host
}
Write-Host "`nBackups: $backups"
Write-Host "JSON:    $jsonFile"
Write-Host "Log:     $logFile`n"
Write-Host "Phase146 complete." -ForegroundColor Green
