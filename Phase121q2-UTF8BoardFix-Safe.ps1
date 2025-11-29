# Phase121q2-UTF8BoardFix-Safe.ps1  (regex fix)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $projectPath) { Set-Location $projectPath }

New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG = ".\logs\phase121q2-$stamp.log"
function Log([string]$m){ $m | Tee-Object -FilePath $LOG -Append }
function Ensure-Dir([string]$p){ if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Text([string]$path, [string[]]$lines){ Ensure-Dir (Split-Path $path -Parent); ($lines -join "`r`n") | Set-Content -Encoding UTF8 -Path $path; Log "Wrote: $path" }

Log "=== Phase121q2 start ==="

# 1) next.config.js (force UTF-8 headers)
$nextCfgPath = Join-Path $projectPath "next.config.js"
$nextCfg = @(
'/** @type {import(''next'').NextConfig} */'
'const nextConfig = {'
'  async headers() {'
'    return ['
'      {'
'        source: ''/:path*'','
'        headers: ['
'          { key: ''Content-Type'', value: ''text/html; charset=utf-8'' },'
'          { key: ''X-Content-Type-Options'', value: ''nosniff'' },'
'        ],'
'      },'
'    ];'
'  },'
'};'
'module.exports = nextConfig;'
)
Write-Text $nextCfgPath $nextCfg

# 2) layout.tsx -> ensure <meta charSet="utf-8" />
$layoutCandidates = @(
  (Join-Path $projectPath "app\layout.tsx"),
  (Join-Path $projectPath "app\(marketing)\layout.tsx")
) | Where-Object { Test-Path $_ }

if ($layoutCandidates.Count -eq 0) {
  $lp = Join-Path $projectPath "app\layout.tsx"
  $layout = @(
'import type { Metadata } from "next";'
'export const metadata: Metadata = {'
'  metadataBase: new URL("https://truvern.com"),'
'  title: "Truvern — Vendor Trust Network",'
'  description: "Build Trust. Simplify Risk.",'
'};'
'export default function RootLayout({ children }: { children: React.ReactNode }) {'
'  return ('
'    <html lang="en">'
'      <head><meta charSet="utf-8" /></head>'
'      <body className="min-h-screen antialiased">{children}</body>'
'    </html>'
'  );'
'}'
  )
  Write-Text $lp $layout
} else {
  foreach ($p in $layoutCandidates) {
    $t = Get-Content $p -Raw -Encoding UTF8
    if ($t -notmatch 'charSet' -and $t -match '<head>') {
      # Use Regex.Replace with a prebuilt replacement string
      $rep1 = '<head>' + "`r`n" + '<meta charSet="utf-8" />'
      $t = $t -replace '<head>',$rep1
      Set-Content -Path $p -Value $t -Encoding UTF8
      Log "Injected meta into: $p"
    } elseif ($t -notmatch 'charSet') {
      # Use Regex.Replace to avoid -replace concatenation issue
      $rep2 = '<html$1>' + "`r`n" + '<head><meta charSet="utf-8" /></head>'
      $t = [regex]::Replace($t,'<html([^>]*)>',$rep2)
      Set-Content -Path $p -Value $t -Encoding UTF8
      Log "Added head+meta to: $p"
    } else {
      Log "Meta already present: $p"
    }
  }
}

# 3) Mojibake cleanup via code points
$badCopy  = [string]::Concat([char]0x00C2, [char]0x00A9)  # Â©
$goodCopy = [string][char]0x00A9                           # ©
$badEllip = [string]::Concat([char]0x00E2, [char]0x0080, [char]0x00A6) # â€¦
$goodEllip= [string][char]0x2026                           # …
$src = Get-ChildItem -Path $projectPath -Recurse -Include *.tsx,*.ts,*.jsx,*.js -File
$changed = 0
foreach($f in $src){
  $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  $new = $raw.Replace($badCopy,$goodCopy).Replace($badEllip,$goodEllip)
  if($new -ne $raw){ Set-Content -Path $f.FullName -Encoding UTF8 -Value $new; $changed++; Log "Cleaned: $($f.FullName)" }
}
Log "Mojibake cleaned in $changed file(s)."

# 4) Normalize nav label
$navFix = 0
foreach($f in $src){
  $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  $new = $raw -replace 'label:\s*''Trust''','label: ''Trust Network''' -replace 'label:\s*"Trust"','label: "Trust Network"'
  if($new -ne $raw){ Set-Content -Path $f.FullName -Encoding UTF8 -Value $new; $navFix++; Log "Nav label fixed: $($f.FullName)" }
}
Log "Nav label updates in $navFix file(s)."

# 5) Vendors pages
$vendorsIndexPath = Join-Path $projectPath "app\vendors\page.tsx"
Ensure-Dir (Split-Path $vendorsIndexPath -Parent)
$vendorsIndex = @(
'import Link from "next/link";'
'export default function VendorsPage() {'
'  const vendors = ['
'    { slug: "vendor-alpha", name: "Vendor Alpha" },'
'    { slug: "vendor-beta", name: "Vendor Beta" },'
'  ];'
'  return ('
'    <main className="container py-8">'
'      <h1 className="text-2xl font-semibold mb-4">Vendors</h1>'
'      <ul className="space-y-2">'
'        {vendors.map(v => ('
'          <li key={v.slug}>'
'            <Link className="underline" href={`/vendors/${v.slug}`}>{v.name}</Link>'
'          </li>'
'        ))}'
'      </ul>'
'    </main>'
'  );'
'}'
)
Write-Text $vendorsIndexPath $vendorsIndex

$vendorSlugPath = Join-Path $projectPath "app\vendors\[slug]\page.tsx"
Ensure-Dir (Split-Path $vendorSlugPath -Parent)
$vendorSlug = @(
'type Props = { params: { slug: string } };'
'export default function VendorDetail({ params }: Props) {'
'  const title = params.slug.replace(/-/g, " ");'
'  return ('
'    <main className="container py-8">'
'      <h1 className="text-2xl font-semibold capitalize">{title}</h1>'
'      <p className="text-sm text-muted-foreground">Trust profile, evidence and assessments coming soon.</p>'
'    </main>'
'  );'
'}'
)
Write-Text $vendorSlugPath $vendorSlug

# 6) Board report
$boardPath = Join-Path $projectPath "app\reports\board\page.tsx"
Ensure-Dir (Split-Path $boardPath -Parent)
$board = @(
'export default function BoardReport() {'
'  const kpis = ['
'    { label: "Vendors", value: 42 },'
'    { label: "Open Risks", value: 5 },'
'    { label: "Criticals", value: 1 },'
'    { label: "Avg Trust Score", value: 87 },'
'  ];'
'  return ('
'    <main className="container py-8">'
'      <h1 className="text-2xl font-semibold mb-6">Board Report</h1>'
'      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">'
'        {kpis.map(k => ('
'          <div key={k.label} className="rounded-2xl border p-4">'
'            <div className="text-3xl font-bold">{k.value}</div>'
'            <div className="text-sm text-muted-foreground">{k.label}</div>'
'          </div>'
'        ))}'
'      </div>'
'      <p className="mt-6 text-sm text-muted-foreground">Sample data shown. Connect KPIs to your API when ready.</p>'
'    </main>'
'  );'
'}'
)
Write-Text $boardPath $board

# 7) Sanity
if (-not (Test-Path ".\package.json")) { Log "ERROR: package.json missing"; throw "package.json missing in $projectPath" }

# 8) Build + Deploy + Alias
$deployWrapper = Join-Path $projectPath "Phase121n-SafeForceDeploy.ps1"
$aliasFinalize = Join-Path $projectPath "Phase121o-SafeAliasFinalize.ps1"

if (-not (Test-Path $deployWrapper)) {
  Log "Wrapper not found -> local build only"
  if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm install --no-frozen-lockfile 2>&1 | Tee-Object -FilePath $LOG -Append
    pnpm run build 2>&1 | Tee-Object -FilePath $LOG -Append
  } else {
    npm install 2>&1 | Tee-Object -FilePath $LOG -Append
    npm run build 2>&1 | Tee-Object -FilePath $LOG -Append
  }
} else {
  Unblock-File $deployWrapper
  & $deployWrapper
}

if (Test-Path $aliasFinalize) {
  Unblock-File $aliasFinalize
  & $aliasFinalize
} else {
  Log "Alias finalize script not found; skipping"
}

Log "=== Phase121q2 complete ==="
Write-Host "✅ Done. Log: $LOG"
