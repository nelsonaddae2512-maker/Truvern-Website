<# ===============================================================
 Phase150-FinalRouteRepair.ps1
 Purpose: Add a dashboard metadata bridge + evidence page so that
          OG + canonical render and Vercel build stops failing.
 Compatible: Windows PowerShell 5.x
 =============================================================== #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host 'Please cd into your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)' -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backups = Join-Path $root ("patch_backups\phase150-" + $ts)
New-Item -ItemType Directory -Force -Path $backups | Out-Null

function BackupIfExists { param([string]$p)
  if (Test-Path $p) {
    $b = Join-Path $backups ((Split-Path $p -Leaf) + "." + $ts + ".bak")
    Copy-Item $p $b -Force
    Write-Host ("Backup -> " + $b)
  }
}

# --- 1) Ensure app/dashboard/layout.tsx (metadata bridge) ---
$dashDir = Join-Path $root 'app\dashboard'
New-Item -ItemType Directory -Force -Path $dashDir | Out-Null

$dashLayout = Join-Path $dashDir 'layout.tsx'
if (-not (Test-Path $dashLayout)) {
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Dashboard", template: "%s | Truvern" },
  description: "Truvern dashboard workspace and evidence center.",
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
'@ | Set-Content -Path $dashLayout -Encoding UTF8
  Write-Host "Created app/dashboard/layout.tsx"
} else {
  Write-Host "app/dashboard/layout.tsx already exists (leaving as-is)."
}

# --- 2) Ensure app/dashboard/evidence/page.tsx (default export + metadata) ---
$evidenceDir  = Join-Path $dashDir 'evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$evidencePage = Join-Path $evidenceDir 'page.tsx'

if (-not (Test-Path $evidencePage)) {
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Evidence",
  description: "Upload and review evidence inside the Truvern dashboard.",
  alternates: { canonical: "/dashboard/evidence" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function EvidencePage() {
  return (
    <main className="p-6">
      <h1 className="text-xl font-semibold mb-2">Evidence Dashboard</h1>
      <p className="text-sm opacity-80">Placeholder page for /dashboard/evidence.</p>
    </main>
  );
}
'@ | Set-Content -Path $evidencePage -Encoding UTF8
  Write-Host "Created app/dashboard/evidence/page.tsx"
} else {
  BackupIfExists $evidencePage
  # Light touch: ensure it has a default export and metadata block
  $txt = Get-Content -Raw -Path $evidencePage
  $changed = $false
  if ($txt -notmatch "export\s+default\s+function\s+") {
    Add-Content -Path $evidencePage -Value @'
export default function EvidencePage() {
  return <main className="p-6"><h1>Evidence Dashboard</h1></main>;
}
'@
    $changed = $true
  }
  if ($txt -notmatch "export\s+const\s+metadata\s*=") {
    Add-Content -Path $evidencePage -Value @'
export const metadata = {
  title: "Evidence",
  description: "Upload and review evidence inside the Truvern dashboard.",
  alternates: { canonical: "/dashboard/evidence" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};
'@
    $changed = $true
  }
  if ($changed) { Write-Host "Patched existing evidence page to include default export + metadata." }
}

# --- 3) Clean caches and build locally ---
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

# --- 4) Verify OG + Canonical on prod (https://truvern.com) ---
function FetchHtml { param([string]$u)
  try { (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20).Content } catch { "" }
}
$Base="https://truvern.com"
$paths=@("/","/trust-network","/reports/board","/vendors","/dashboard/evidence")

Write-Host "`nVerification Results:" -ForegroundColor Cyan
"{0,-22}{1,6}{2,-10}{3,-60}" -f "Path","HTTP","OG","Canonical"

foreach($p in $paths){
  $u="$Base$p"
  try{
    $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    $html = $resp.Content
    $og  = [regex]::Match($html,'<meta[^>]+property=["'']og:image["''][^>]+content=["''](.*?)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase).Groups[1].Value
    $can = [regex]::Match($html,'<link[^>]+rel=["'']canonical["''][^>]+href=["''](.*?)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase).Groups[1].Value
    "{0,-22}{1,6}{2,-10}{3,-60}" -f $p,$resp.StatusCode,($(if($og){"Found"}else{"Missing"})),$can | Write-Host
  }catch{
    "{0,-22}{1,6}{2,-10}{3,-60}" -f $p,0,"Error","" | Write-Host
  }
}

Write-Host "`nPhase150 complete." -ForegroundColor Green
