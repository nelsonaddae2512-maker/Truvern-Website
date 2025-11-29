Write-Host "=== Phase140 FIX Vendors Index Routes ===" -ForegroundColor Cyan

# Find all TSX files that represent a Vendors index page:
# - app/vendors/page.tsx
# - app/(group)/vendors/page.tsx
# - pages/vendors.tsx
# - pages/vendors/index.tsx
$vendorsFiles = Get-ChildItem -Recurse -Path . -Include *.tsx |
    Where-Object {
        $_.FullName -match "\\vendors\\page\.tsx$" -or      # app/.../vendors/page.tsx
        $_.FullName -match "\\vendors\.tsx$" -or            # pages/vendors.tsx
        $_.FullName -match "\\vendors\\index\.tsx$"         # pages/vendors/index.tsx
    }

if (-not $vendorsFiles) {
    Write-Host "[WARN] No vendors index TSX files found." -ForegroundColor Yellow
    return
}

Write-Host "[INFO] Will replace the following files:" -ForegroundColor Yellow
$vendorsFiles | ForEach-Object { Write-Host "  - $($_.FullName)" }

# Unified Vendors index content
$tsx = @"
import Link from "next/link";

export default function VendorsIndex() {
  return (
    <div style={{ padding: "40px", fontFamily: "sans-serif" }}>
      <h1 style={{ fontSize: "32px", marginBottom: "20px" }}>Vendors</h1>

      <p>Welcome to the Truvern Vendor Directory.</p>
      <p>Select a demo vendor below to view KPI details.</p>

      <ul style={{ lineHeight: "2" }}>
        <li><Link href="/vendors/123">Vendor 123 (Demo)</Link></li>
        <li><Link href="/vendors/456">Vendor 456 (Demo)</Link></li>
        <li><Link href="/vendors/789">Vendor 789 (Demo)</Link></li>
      </ul>
    </div>
  );
}
"@

foreach ($file in $vendorsFiles) {
    Write-Host "[INFO] Overwriting $($file.FullName)..." -ForegroundColor Yellow
    [System.IO.File]::WriteAllText($file.FullName, $tsx)
    Write-Host "[OK] Replaced $($file.FullName)" -ForegroundColor Green
}

Write-Host "=== Phase140 completed ===" -ForegroundColor Cyan
