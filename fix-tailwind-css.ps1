# === Truvern Tailwind v4 CSS Fix & Redeploy ===
$ErrorActionPreference = "Stop"
$root   = "C:\Users\MR.NELSON\Downloads\truvern"
$layout = Join-Path $root "app\layout.tsx"
Set-Location $root

# Skip sensitive folders
$files = Get-ChildItem -Recurse -Include *.ts,*.tsx,*.js,*.jsx |
  Where-Object {
    $_.FullName -notmatch "\\node_modules\\" -and
    $_.FullName -notmatch "\\.next\\" -and
    $_.FullName -ne $layout
  }

foreach ($f in $files) {
  try {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    $patched = [Regex]::Replace($text, '^\s*import\s+["'']\.\/globals\.css["''];?\s*', "", [Text.RegularExpressions.RegexOptions]::Multiline)
    if ($patched -ne $text) {
      [System.IO.File]::WriteAllText($f.FullName, $patched, [System.Text.Encoding]::UTF8)
      Write-Host "[OK] Removed extra globals.css import from $($f.Name)" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "[SKIPPED] $($f.FullName) - access denied or locked" -ForegroundColor DarkGray
  }
}

# Clean build cache
if (Test-Path ".next") { Remove-Item -Recurse -Force ".next" }
Write-Host "[INFO] Rebuilding..." -ForegroundColor Cyan
npm run build

# Verify Tailwind CSS emitted
if (Test-Path ".next\static\css") {
  Write-Host "[OK] CSS assets emitted:" -ForegroundColor Green
  Get-ChildItem ".next\static\css" -Recurse | Select-Object FullName, Length
} else {
  Write-Warning "No CSS emitted to .next/static/css — Tailwind may still be misconfigured."
}

# Deploy
if (Test-Path ".\run-production-sync.ps1") {
  .\run-production-sync.ps1 -Deploy
} else {
  npx vercel --prod
}