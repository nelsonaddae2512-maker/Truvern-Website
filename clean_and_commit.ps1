# clean_and_commit.ps1
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

Write-Host "🧹 Cleaning old Prisma backup files..." -ForegroundColor Cyan
Get-ChildItem -Path ".\prisma\" -Include "*.bak", "*.bak_*", "*.broken" -Recurse | ForEach-Object {
    Remove-Item $_.FullName -Force
}

git add -A
$pending = git diff --cached --name-only

if (-not $pending) {
    Write-Host "✅ Nothing new to commit." -ForegroundColor Green
} else {
    Write-Host "💾 Committing cleaned schema and configs..." -ForegroundColor Cyan
    git commit -m "Cleanup Prisma backup files and confirm build state"
    Write-Host "✅ Commit completed successfully." -ForegroundColor Green
}

git status
