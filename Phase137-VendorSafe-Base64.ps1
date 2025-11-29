# Phase137 - Vendor Placeholder using Base64 (PowerShell-safe)

Write-Host ""
Write-Host "=== Phase137 – Vendor Placeholder (Base64 Safe Method) ===" -ForegroundColor Cyan
Write-Host ""

# Ensure correct directory
if ($PWD.Path -match "System32") {
    Write-Host "[ERROR] Do NOT run from System32." -ForegroundColor Red
    exit
}

if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] Not project root." -ForegroundColor Red
    exit
}

# Ensure folder exists
$dir = "app/vendors/[id]"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Output file
$page = "app/vendors/[id]/page.tsx"

# Backup old file
if (Test-Path $page) {
    Copy-Item $page "$page.bak-phase137" -Force
}

# Base64 encoded TSX content
$base64 = @"
aW1wb3J0IExpbmsgZnJvbSAibmV4dC9saW5rIjsKCmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9u
IFZlbmRvclBsYWNlaG9sZGVyKHsgcGFyYW1zIH0pIHsKICByZXR1cm4gKAogICAgPG1haW4g
Y2xhc3NOYW1lPSJtYXgtdy00eGwgbXgtYXV0byBweS0xMiI+CiAgICAgIDxoMSBjbGFzc05h
bWU9InRleHQtM2hsIGZvbnQtc2VtaWJvbGQgbWItNCI+VmVuZG9yIHByb2ZpbGUgY29taW5n
IHNvb24gPC9oMT4KICAgICAgPHA+VmVuZG9yICN7cGFyYW1zLmlkfSBkZXRhaWxzIHdpbGwg
YmUgaGVyZS48L3A+CiAgICAgIDxMaW5rIGhyZWY9Ii92ZW5kb3JzIiBjbGFzcz1cInRleHQt
c2t5LTQwMCBob3Zlcjp0ZXh0LXNreS0zMDAlXCI+QmFjayB0byBWZW5kb3JzPC9MaW5rPgog
ICAgPC9tYWluPgogICk7Cn0K
"@

# Decode Base64 → TSX
[System.IO.File]::WriteAllBytes($page, [System.Convert]::FromBase64String($base64))

Write-Host "[OK] Vendor placeholder written safely." -ForegroundColor Green

# Clean & build
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[INFO] Building..." -ForegroundColor Cyan
npm run build

Write-Host "[OK] Build done." -ForegroundColor Green

# Deploy
Write-Host "[INFO] Deploying to Vercel..." -ForegroundColor Cyan
vercel deploy --prod --yes

Write-Host ""
Write-Host "=== Phase137 Completed Successfully ===" -ForegroundColor Green
