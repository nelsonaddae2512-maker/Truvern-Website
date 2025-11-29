<# ======================================================================
 Phase152-SectionLayouts.ps1
 Purpose: Ensure per-section metadata layouts exist so OG + Canonical render
 Sections: /trust-network, /reports/board, /vendors
 Compatible: Windows PowerShell 5.x
 ====================================================================== #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

# Safety.
if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host 'Please cd into your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)' -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $root ("patch_backups\phase152-" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function BackupFile { param([string]$p)
  if (Test-Path $p) {
    $b = Join-Path $backupDir ((Split-Path $p -Leaf) + "." + $ts + ".bak")
    Copy-Item $p $b -Force
    Write-Host ("Backup -> " + $b)
  }
}

function EnsureDir { param([string]$p)
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# --- 0) Ensure public assets referenced by OG/icons exist ---
$public = Join-Path $root 'public'
EnsureDir $public
$ogImg = Join-Path $public 'opengraph-image.png'
if (-not (Test-Path $ogImg)) { Set-Content -Path $ogImg -Value "Truvern OG" -Encoding UTF8 }
$fav = Join-Path $public 'favicon.ico'
if (-not (Test-Path $fav)) {
  $tiny="AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  [IO.File]::WriteAllBytes($fav,[Convert]::FromBase64String($tiny))
}

# --- 1) trust-network layout ---
$tnDir = Join-Path $root 'app\trust-network'
$tnLayout = Join-Path $tnDir 'layout.tsx'
EnsureDir $tnDir
BackupFile $tnLayout
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Trust Network", template: "%s | Truvern" },
  description: "Discover and share vendor trust insights on Truvern.",
  alternates: { canonical: "/trust-network" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function TrustNetworkLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
'@ | Set-Content -Path $tnLayout -Encoding UTF8

# --- 2) reports/board layout ---
$repDir = Join-Path $root 'app\reports\board'
$repLayout = Join-Path $repDir 'layout.tsx'
EnsureDir (Join-Path $root 'app\reports')
EnsureDir $repDir
BackupFile $repLayout
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Board Reports", template: "%s | Truvern" },
  description: "Board-level risk dashboards and summaries powered by Truvern.",
  alternates: { canonical: "/reports/board" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function BoardReportsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
'@ | Set-Content -Path $repLayout -Encoding UTF8

# --- 3) vendors layout ---
$venDir = Join-Path $root 'app\vendors'
$venLayout = Join-Path $venDir 'layout.tsx'
EnsureDir $venDir
BackupFile $venLayout
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Vendors", template: "%s | Truvern" },
  description: "Manage vendors, evidence, remediation, and workflows.",
  alternates: { canonical: "/vendors" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function VendorsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
'@ | Set-Content -Path $venLayout -Encoding UTF8

# --- 4) Clean caches & build ---
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
  pnpm install --frozen-lockfile
  pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
  npm ci
  npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
  yarn install --frozen-lockfile
  yarn build
} else {
  Write-Host "No pnpm/npm/yarn found; skipping local build." -ForegroundColor Yellow
}

# --- 5) Verify OG + Canonical on prod ---
function GetHtml { param([string]$u) try { (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20) } catch { $null } }
function Match1 { param([string]$html,[string]$re)
  try { ([regex]::Match($html,$re,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim() } catch { "" }
}

$Base="https://truvern.com"
$paths=@("/","/trust-network","/reports/board","/vendors")
Write-Host "`nVerification Results:" -ForegroundColor Cyan
"{0,-18}{1,6}{2,-10}{3,-60}" -f "Path","HTTP","OG","Canonical"

foreach($p in $paths){
  $resp = GetHtml ($Base+$p)
  if($resp){
    $html=$resp.Content
    $og  = Match1 $html '<meta[^>]+property=["'']og:image["''][^>]+content=["''](.*?)["'']'
    $can = Match1 $html '<link[^>]+rel=["'']canonical["''][^>]+href=["''](.*?)["'']'
    "{0,-18}{1,6}{2,-10}{3,-60}" -f $p,$resp.StatusCode,($(if($og){"Found"}else{"Missing"})),$can | Write-Host
  } else {
    "{0,-18}{1,6}{2,-10}{3,-60}" -f $p,0,"Error","" | Write-Host
  }
}

Write-Host "`nPhase152 complete." -ForegroundColor Green
