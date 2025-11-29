Write-Host ""
Write-Host "=== Phase138b Rebuild Vendors Index Page ===" -ForegroundColor Cyan
Write-Host ""

$folder = "app/vendors"
$indexPath = "app/vendors/page.tsx"

# Ensure folder exists
if (-not (Test-Path $folder)) {
    Write-Host "[INFO] Creating vendors folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

Write-Host "[INFO] Writing new vendors index page..." -ForegroundColor Yellow

# TSX content
$tsx = @"
import Link from 'next/link';

export default function VendorsIndex() {
  return (
    <div style={{ padding: '40px', fontFamily: 'sans-serif' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '20px' }}>Vendors</h1>
      <p>This is a restored vendors index page created by Phase138b.</p>
      <br />
      <Link href="/">Back to Home</Link>
    </div>
  );
}
"@

# Write using .NET (compatible with PS 5.1)
[System.IO.File]::WriteAllText($indexPath, $tsx)

if ([System.IO.File]::Exists($indexPath)) {
    Write-Host "[OK] vendors/page.tsx recreated successfully." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to create vendors/page.tsx" -ForegroundColor Red
}

Write-Host ""
Write-Host "Phase138b completed."
