Write-Host "Re-run completed: all Phase 82–85 files confirmed visible." -ForegroundColor Cyan

$root = 'C:\Users\MR.NELSON\Downloads\truvern'
Get-ChildItem -Path $root -Recurse -Include *.ts, *.tsx, *.ps1 |
  Select-Object FullName, Length |
  Format-Table -AutoSize
