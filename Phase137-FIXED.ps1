Write-Host "Vendor Placeholder Test" -ForegroundColor Cyan

$path = "app/vendors/`[id`]/page.tsx"

"import Link from 'next/link';" | Out-File $path -Force
"export default function X(){return <div>OK</div>}" | Add-Content $path

Write-Host "DONE" -ForegroundColor Green
