# Phase137 - Ultra Safe Vendor Placeholder Writer

Write-Host ""
Write-Host "=== Phase137 – Nuclear Safe Vendor Placeholder ===" -ForegroundColor Cyan
Write-Host ""

# Ensure correct folder
if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] Not project root." -ForegroundColor Red
    exit
}

# Ensure folder structure
$folder = "app/vendors/[id]"
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

$outfile = "app/vendors/[id]/page.tsx"

# Base64 payload (binary-safe)
$data = @"
aW1wb3J0IExpbmsgZnJvbSAibmV4dC9saW5rIjsKCmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9u
IFZlbmRvclBsYWNlaG9sZGVyKHsgcGFyYW1zIH0pIHsKICByZXR1cm4gKAogICAgPG1haW4g
Y2xhc3NOYW1lPSJtYXgtdy00eGwgbXgtYXV0byBweS0xMiI+CiAgICAgIDxoMSBjbGFzc05h
bWU9InRleHQtM2hsIGZvbnQtc2VtaWJvbGQgbWItNCI+VmVuZG9yIHByb2ZpbGUgY29taW5n
IHNvb24gPC9oMT4KICAgICAgPHA+VmVuZG9yICN7cGFyYW1zLmlkfSBkZXRhaWxzIHdpbGwg
YmUgaGVyZS48L3A+CiAgICAgIDxMaW5rIGhyZWY9Ii92ZW5kb3JzIiBjbGFzcz1cInRleHQt
c2t5LTQwMCBob3Zlcjp0ZXh0LXNreS0zMDAlXCI+QmFjayB0byBWZW5kb3JzPC9MaW5rPgog
ICAgPC9tYWluPgogICk7Cn0K
"@

# Decode Base64 to file
[System.IO.File]::WriteAllBytes($outfile, [Convert]::FromBase64String($data))

Write-Host "[OK] Vendor placeholder file written." -ForegroundColor Green

# Clean build
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[INFO] Running build..." -ForegroundColor Cyan
npm run build

Write-Host "[OK] Build finished." -ForegroundColor Green

Write-Host "[INFO] Deploying to Vercel..." -ForegroundColor Cyan
vercel deploy --prod --yes

Write-Host ""
Write-Host "=== Phase137 Completed ===" -ForegroundColor Green
