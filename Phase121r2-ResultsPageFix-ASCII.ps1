# Phase121r2-ResultsPageFix-ASCII.ps1  (ASCII only; no emojis, no smart quotes)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $root) { Set-Location $root }

# logging
New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG = ".\logs\phase121r2-$stamp.log"
function Log([string]$m){ $m | Tee-Object -FilePath $LOG -Append }

function ReadUtf8([string]$p){ [System.IO.File]::ReadAllText($p,[Text.Encoding]::UTF8) }
function WriteUtf8([string]$p,[string]$t){
  $dir = Split-Path $p -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($p,$t,[Text.Encoding]::UTF8)
}

Log "=== Phase121r2 start ==="

if (-not (Test-Path ".\package.json")) { Log "ERROR: package.json missing"; throw "package.json missing" }

# 1) Normalize bad searchParams typing across repo
$fixed = 0
$files = Get-ChildItem -Recurse -File -Include *.ts,*.tsx
foreach ($f in $files) {
  $src = ReadUtf8 $f.FullName
  $new = $src -replace 'searchParams\s*:\s*Promise\s*<\s*Record\s*<\s*string\s*,\s*string\s*>\s*>\s*',
                          'searchParams?: { [key: string]: string | string[] | undefined } '
  if ($new -ne $src) {
    WriteUtf8 $f.FullName $new
    $fixed++
    Log "Type signature normalized: $($f.FullName)"
  }
}
Log "Files updated for searchParams typing: $fixed"

# 2) Replace failing page with safe version
$pagePath = Join-Path $root "app\assessment\results\page.tsx"
if (Test-Path $pagePath) {
  Copy-Item $pagePath "$pagePath.bak-$stamp" -Force
  Log "Backup saved: $pagePath.bak-$stamp"
}

$pageTsx = @'
/* patched by Phase121r2 - safe typing for searchParams */
export type PageProps = {
  searchParams?: { [key: string]: string | string[] | undefined }
}

export default function ResultsPage({ searchParams }: PageProps) {
  const sp = searchParams ?? {};
  const getStr = (k: string) => {
    const v = (sp as any)[k] as string | string[] | undefined;
    return Array.isArray(v) ? (v[0] ?? "") : (v ?? "");
  };
  const q = getStr("q");
  const vendor = getStr("vendor");
  return (
    <main className="container py-8">
      <h1 className="text-2xl font-semibold mb-2">Assessment Results</h1>
      <p className="text-sm text-muted-foreground">Query: {q || "-"}</p>
      <p className="text-sm text-muted-foreground">Vendor: {vendor || "-"}</p>
      <div className="mt-6 rounded-xl border p-4">
        <p className="text-sm">Replace this with your real results table when ready.</p>
      </div>
    </main>
  );
}
'@
WriteUtf8 $pagePath $pageTsx
Log "Rewrote: $pagePath"

# 3) Prisma generate via cmd (avoids PS shim noise)
$prismaCmd = if (Test-Path ".\node_modules\.bin\prisma.cmd") { ".\node_modules\.bin\prisma.cmd" } else { "npx prisma" }
Log "Running prisma generate via cmd.exe..."
cmd /d /c "$prismaCmd generate" 2>&1 | Tee-Object -FilePath $LOG -Append
if ($LASTEXITCODE -ne 0) { Log "ERROR prisma generate exit $LASTEXITCODE"; throw "Prisma failed"; }

# 4) Deploy to Vercel (cloud build)
Log "Deploying: vercel --prod via cmd.exe"
$deployOut = cmd /d /c "vercel --prod" 2>&1 | Tee-Object -FilePath $LOG -Append
if ($LASTEXITCODE -ne 0) { Log "WARN vercel exit code $LASTEXITCODE (see log)"; }

# Parse deployment URL
$deploymentUrl = "(unknown)"
$matches = ($deployOut | Select-String -Pattern 'https?://[^\s]+' -AllMatches)
if ($matches -and $matches.Matches) {
  foreach ($m in $matches.Matches) { if ($m.Value -like "*.vercel.app*") { $deploymentUrl = $m.Value; break } }
}
Log ("Deployment URL: {0}" -f $deploymentUrl)

# 5) Verify public routes
$urls = @(
  "https://truvern.com/",
  "https://truvern.com/trust-network",
  "https://truvern.com/vendors",
  "https://truvern.com/reports/board"
)
Log "--- HTTP 200 verification ---"
$all200 = $true
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 25
    Log ("{0} -> {1}" -f $u, $r.StatusCode)
    if ($r.StatusCode -ne 200) { $all200 = $false }
  } catch {
    Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
    $all200 = $false
  }
}

Log "=== Summary ==="
Log ("Deployment URL: {0}" -f $deploymentUrl)
Log ("All key routes HTTP 200: {0}" -f ($(if($all200){"YES"}else{"NO"})))
Log ("Log saved: {0}" -f $LOG)
Write-Host ""
Write-Host ("Done. Full log: {0}" -f $LOG)
