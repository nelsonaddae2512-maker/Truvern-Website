Write-Host ""
Write-Host "=== Phase138c FIX Vendors Index Page ===" -ForegroundColor Cyan
Write-Host ""

# Absolute EXACT path
$root = "C:\Users\MR.NELSON\Downloads\truvern"
$folder = Join-Path $root "app\vendors"
$indexPath = Join-Path $folder "page.tsx"

Write-Host "[INFO] Ensuring folder exists: $folder" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $folder -Force | Out-Null

Write-Host "[INFO] Writing vendors index page to:" -ForegroundColor Yellow
Write-Host "       $indexPath" -ForegroundColor Cyan

$tsx = @"
import Link from 'next/link';

export default function VendorsIndex() {
  return (
    <div style={{ padding: '40px', fontFamily: 'sans-serif' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '20px' }}>Vendors</h1>
      <p>This is a restored vendors index page created by Phase138c.</p>
      <br />
      <Link href="/">Back to Home</Link>
    </div>
  );
}
"@

# Write using .NET for guaranteed success
[System.IO.File]::WriteAllText($indexPath, $tsx)

# Verify
if ([System.IO.File]::Exists($indexPath)) {
    Write-Host "[OK] vendors/page.tsx written successfully." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to create vendors/page.tsx" -ForegroundColor Red
}

Write-Host ""
Write-Host "[INFO] Listing folder contents:" -ForegroundColor Yellow
Get-ChildItem $folder

Write-Host ""
Write-Host "Phase138c completed."
