# Phase64-BoardRescue.ps1 — verifies that /reports/board is routed correctly

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn2($t){ Write-Warning $t }

function Resolve-AppDir {
  foreach ($p in @("app","apps\tprm\app","apps\website\app")) { if (Test-Path $p) { return $p } }
  throw "App directory not found (looked for app, apps\\tprm\\app, apps\\website\\app)."
}
$appDir = Resolve-AppDir
Ok "Using app dir: $appDir"

# 1. /reports smoke page
Sec "Writing /reports/page.tsx"
$reportsDir = Join-Path $appDir "reports"
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
Set-Content -Encoding UTF8 -Path (Join-Path $reportsDir "page.tsx") -Value @'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default function ReportsIndex() {
  return (
    <main style={{padding:"2rem",maxWidth:960,margin:"0 auto"}}>
      <h1>/reports route: ALIVE ✅</h1>
      <p>This proves the /reports segment renders properly.</p>
      <p><a href="/reports/board?org=demo-2128873b">Go to /reports/board</a></p>
    </main>
  );
}
'@

# 2. /reports/board smoke page
Sec "Writing /reports/board/page.tsx"
$boardDir = Join-Path $appDir "reports\board"
New-Item -ItemType Directory -Force -Path $boardDir | Out-Null
Set-Content -Encoding UTF8 -Path (Join-Path $boardDir "page.tsx") -Value @'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default function BoardSmoke() {
  return (
    <main style={{padding:"2rem",maxWidth:960,margin:"0 auto"}}>
      <h1>/reports/board route: ALIVE ✅</h1>
      <p>This confirms nested route works.</p>
      <ul>
        <li><a href="/api/reports/board?org=demo-2128873b">API JSON</a></li>
        <li><a href="/api/reports/board?org=demo-2128873b&format=csv">API CSV</a></li>
      </ul>
    </main>
  );
}
'@

# 3. Deploy
Sec "Deploy (remote build)"
vercel pull --environment=production --yes | Out-Host
iex "vercel deploy --prod --yes"
if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed ($LASTEXITCODE)" }
Ok "Deployment kicked off."

# 4. Confirm files exist
Sec "Verifying files"
Get-Item (Join-Path $reportsDir "page.tsx"), (Join-Path $boardDir "page.tsx") | Format-Table FullName, Length
