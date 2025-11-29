Write-Host ""
Write-Host "=== Phase138 Rebuild Vendors Index Page ===" -ForegroundColor Cyan
Write-Host ""

# Project safety check
if (-not (Test-Path "package.json")) {
    Write-Host "ERROR: You are not in the project root." -ForegroundColor Red
    exit
}

$path = "app/vendors/page.tsx"

# Ensure folder exists
$folder = Split-Path $path
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

# New content for vendors index
$tsx = @"
import Link from 'next/link';

export default function VendorsIndex() {
  return (
    <div style={{ padding: '40px', fontFamily: 'sans-serif' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '20px' }}>Vendors</h1>
      <p>This is the restored Vendors index page for Truvern.</p>
      <br />
      <Link href="/trust-network">Go to Trust Network</Link>
    </div>
  );
}
"@

# Write using .NET to avoid PowerShell parsing bugs
[System.IO.File]::WriteAllText($path, $tsx)

Write-Host "Vendors index page restored successfully." -ForegroundColor Green
Write-Host "Phase138 completed."
