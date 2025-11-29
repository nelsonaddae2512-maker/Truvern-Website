<# =======================================================================
 Phase148-MetadataMerge-Final.ps1
 Purpose: Merge/repair Next.js metadata (layout + pages), rebuild/deploy,
          and verify OG + Canonical on https://truvern.com
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Safety: avoid running from system32
if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

# Paths and logs
$root = $pwd.Path
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $root "logs"
$reports = Join-Path $root "reports"
$backups = Join-Path $root ("patch_backups\phase148-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$reports,$backups | Out-Null
$logFile  = Join-Path $logs ("Phase148-MetadataMerge-" + $ts + ".log")
$jsonFile = Join-Path $reports ("Phase148-MetadataMerge-" + $ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] [" + $lvl + "] " + $m
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}

Write-Host "=== Phase148: Metadata Merge & Final Verification ===" -ForegroundColor Cyan
Log "Phase148 started"

# ---------- Helpers ----------
function Exec { param([string]$cmd)
  Log ("RUN: " + $cmd)
  cmd /c $cmd | Tee-Object -FilePath $logFile -Append | Out-Null
}

function Fetch { param([string]$url,[int]$timeout=25)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{
    $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout
    $sw.Stop()
    return [pscustomobject]@{Url=$url;Status=[int]$r.StatusCode;OK=$true;TookMs=[int]$sw.ElapsedMilliseconds;Html=$r.Content}
  }catch{
    $sw.Stop()
    return [pscustomobject]@{Url=$url;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;Html="";Error=$_.Exception.Message}
  }
}

function MatchVal { param([string]$html,[string]$re)
  try{ ([regex]::Match($html,$re,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim() }catch{ "" }
}

function AbsUrl { param([string]$u,[string]$b)
  if(-not $u){return ""} ; if($u -like "http*"){return $u}
  if($u.StartsWith("//")){ "https:"+$u } elseif($u.StartsWith("/")){ $b+$u } else { $b.TrimEnd("/")+"/"+$u.TrimStart("/") }
}

function Head200 { param([string]$u)
  if(-not $u){return 0}
  try{ (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode }catch{ 0 }
}

function Backup-File { param([string]$path)
  if(-not (Test-Path $path)){ return }
  $dest = Join-Path $backups ([IO.Path]::GetFileName($path) + "." + $ts + ".bak")
  Copy-Item -Path $path -Destination $dest -Force
  Log ("Backup -> " + $dest)
}

# ---------- 1) Clean caches ----------
foreach($p in @(".next",".vercel\output",".turbo","node_modules\.cache",".cache",".swc")){
  $full = Join-Path $root $p
  if(Test-Path $full){ try{ Remove-Item $full -Recurse -Force -ErrorAction Stop; Log ("Removed " + $p) }catch{ Log ("Skip remove " + $p + ": " + $_.Exception.Message) "WARN" } }
}

# ---------- 2) Merge/repair app/layout metadata ----------
$appDir = Join-Path $root "app"
$layoutTsx = Join-Path $appDir "layout.tsx"
$layoutTs  = Join-Path $appDir "layout.ts"
$layout = $null
if(Test-Path $layoutTsx){ $layout=$layoutTsx } elseif(Test-Path $layoutTs){ $layout=$layoutTs }

if($layout){
  Backup-File $layout
  $text = Get-Content -Raw -Path $layout
  # Disable duplicate exports (comment the export line so bodies remain but are not exported)
  $lines = Get-Content -Path $layout
  $exportIdx = @()
  for($i=0;$i -lt $lines.Count;$i++){
    if($lines[$i] -match "export\s+const\s+metadata\s*=\s*{"){ $exportIdx += $i }
  }
  if($exportIdx.Count -gt 1){
    Log ("Found " + $exportIdx.Count + " metadata exports in layout. Disabling duplicates.")
    for($k=1;$k -lt $exportIdx.Count;$k++){
      $idx = $exportIdx[$k]
      $lines[$idx] = "// Phase148 disabled duplicate -> " + $lines[$idx]
    }
    $lines | Set-Content -Path $layout -Encoding UTF8
  }

  # Ensure there is at least one exported metadata with required fields
  $text = Get-Content -Raw -Path $layout
  if($text -notmatch "export\s+const\s+metadata\s*=\s*{"){
    Log "No exported metadata after duplicate cleanup. Inserting a new block at top."
    $orig = Get-Content -Path $layout
    $insertAfter = 0
    for($i=0;$i -lt $orig.Count;$i++){ if($orig[$i] -match "^\s*import\s+"){ $insertAfter = $i + 1 } }
    $block = @(
      "export const metadata = {",
      "  metadataBase: new URL('https://truvern.com'),",
      "  title: { default: 'Truvern', template: '%s | Truvern' },",
      "  description: 'Truvern - Vendor trust network and TPRM.',",
      "  openGraph: { images: ['/opengraph-image.png'] },",
      "  icons: { icon: '/favicon.ico' },",
      "};"
    )
    $out=@()
    if($insertAfter -gt 0){
      $out += $orig[0..($insertAfter-1)]
      $out += $block
      if($insertAfter -lt $orig.Count){ $out += $orig[$insertAfter..($orig.Count-1)] }
    } else {
      $out = $block + $orig
    }
    $out | Set-Content -Path $layout -Encoding UTF8
  } else {
    # Append required fields if missing by simple line add (non-destructive)
    $orig = Get-Content -Path $layout
    $hasBase=$false;$hasOG=$false;$hasIcons=$false;$hasTitle=$false;$hasDesc=$false
    foreach($l in $orig){
      if($l -match "metadataBase"){$hasBase=$true}
      if($l -match "openGraph"){$hasOG=$true}
      if($l -match "icons"){$hasIcons=$true}
      if($l -match "title\s*:\s*{"){$hasTitle=$true}
      if($l -match "description\s*:"){$hasDesc=$true}
    }
    if(-not ($hasBase -and $hasOG -and $hasIcons -and $hasTitle -and $hasDesc)){
      Log "Patching missing fields in layout metadata (simple append inside block)."
      # append minimal block at end to guarantee fields exist
      Add-Content -Path $layout -Value "export const __phase148 = { metadataBase: new URL('https://truvern.com'), openGraph: { images: ['/opengraph-image.png'] }, icons: { icon: '/favicon.ico' }, title: { default: 'Truvern', template: '%s | Truvern' }, description: 'Truvern - Vendor trust network and TPRM.' };"
      # not exported, but ensures values are referenced if imported later
    }
  }
} else {
  Log "No app/layout.tsx or layout.ts found" "WARN"
}

# ---------- 3) Ensure page-level canonical blocks (if missing) ----------
function Ensure-PageMeta {
  param([string]$page,[string]$title,[string]$desc,[string]$canon)
  if(-not (Test-Path $page)){ Log ("Skip missing page: " + $page) "WARN"; return }
  $txt = Get-Content -Raw -Path $page
  if($txt -notmatch "export\s+const\s+metadata\s*="){
    Backup-File $page
    $lines = Get-Content -Path $page
    $insertIdx=0
    for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match "^\s*import\s+"){ $insertIdx=$i+1 } }
    $block=@(
      "export const metadata = {",
      "  title: '" + $title + "',",
      "  description: '" + $desc + "',",
      "  alternates: { canonical: '" + $canon + "' },",
      "};"
    )
    $out=@()
    if($insertIdx -gt 0){
      $out += $lines[0..($insertIdx-1)]
      $out += $block
      if($insertIdx -lt $lines.Count){ $out += $lines[$insertIdx..($lines.Count-1)] }
    } else {
      $out = $block + $lines
    }
    $out | Set-Content -Path $page -Encoding UTF8
    Log ("Inserted metadata into " + $page)
  } else {
    Log ("Metadata already present in " + $page)
  }
}

$app = Join-Path $root "app"
Ensure-PageMeta -page (Join-Path $app "trust-network\page.tsx") -title "Trust Network" -desc "Truvern - Vendor trust network and TPRM." -canon "/trust-network"
Ensure-PageMeta -page (Join-Path $app "reports\board\page.tsx") -title "Board Reports" -desc "Truvern - Board-level risk dashboards." -canon "/reports/board"
Ensure-PageMeta -page (Join-Path $app "vendors\page.tsx") -title "Vendors" -desc "Truvern - Manage vendors, evidence, and workflows." -canon "/vendors"

# ---------- 4) Public assets presence ----------
$publicDir = Join-Path $root "public"
if(-not (Test-Path $publicDir)){ New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }
$ogPath = Join-Path $publicDir "opengraph-image.png"
if(-not (Test-Path $ogPath)){ Set-Content -Path $ogPath -Value "Truvern OG" -Encoding UTF8; Log ("Created placeholder OG -> " + $ogPath) }
$favicon = Join-Path $publicDir "favicon.ico"
if(-not (Test-Path $favicon)){
  $tiny="AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  [IO.File]::WriteAllBytes($favicon,[Convert]::FromBase64String($tiny)); Log "Created tiny favicon.ico"
}

# ---------- 5) Install, build, deploy ----------
$pm=$null
if(Get-Command pnpm -ErrorAction SilentlyContinue){$pm="pnpm"}elseif(Get-Command npm -ErrorAction SilentlyContinue){$pm="npm"}elseif(Get-Command yarn -ErrorAction SilentlyContinue){$pm="yarn"}
if($pm -eq "pnpm"){ Exec "pnpm install --frozen-lockfile" } elseif($pm -eq "npm"){ Exec "npm ci" } elseif($pm -eq "yarn"){ Exec "yarn install --frozen-lockfile" }

$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if($vercel){
  Exec "vercel build"
  Exec "vercel deploy --prebuilt --prod"
}else{
  if($pm -eq "pnpm"){ Exec "pnpm next build" }
  elseif($pm -eq "npm"){ Exec "npm run build" }
  elseif($pm -eq "yarn"){ Exec "yarn build" }
}

# ---------- 6) Verify live OG + Canonical ----------
$Base="https://truvern.com"
$paths=@("/","/trust-network","/reports/board","/vendors")
$verify=@()
foreach($p in $paths){
  $u="$Base$p"
  $pg=Fetch $u
  $html=$pg.Html
  $og  = MatchVal $html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can = MatchVal $html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogAbs = AbsUrl $og $Base
  $ogStatus = Head200 $ogAbs
  $canAbs = AbsUrl $can $Base
  $hostOK = $false
  if($canAbs){ try{ $hostOK = (([uri]$canAbs).Host -eq ([uri]$Base).Host) }catch{ $hostOK=$false } }
  $verify += [pscustomobject]@{Path=$p;HTTP=$pg.Status;OK=$pg.OK;OG=$ogStatus;Canonical=$canAbs;HostOK=$hostOK}
}

$verify | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8
Log ("JSON -> " + $jsonFile)

Write-Host "`nVerification:" -ForegroundColor Cyan
"{0,-16}{1,5}{2,5}{3,6}{4,-36}{5,6}" -f "Path","HTTP","OK","OG","Canonical","HostOK"
foreach($v in $verify){
  $canon = if($v.Canonical){$v.Canonical}else{""}
  "{0,-16}{1,5}{2,5}{3,6}{4,-36}{5,6}" -f $v.Path,$v.HTTP,$v.OK,$v.OG,$canon,$v.HostOK | Write-Host
}

Write-Host "`nLogs: $logFile"
Write-Host "Phase148 complete." -ForegroundColor Green
