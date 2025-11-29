# Phase91k-ScanJson.ps1
$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

$bad = @()
Get-ChildItem -Recurse -File -Filter *.json |
  Where-Object { $_.FullName -notmatch '\\.next\\|\\node_modules\\|\\.turbo\\|\\.vercel\\output\\' } |
  ForEach-Object {
    try {
      $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
      $null = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      $first = ($raw -replace '\s+', ' ').Substring(0, [Math]::Min(200, $raw.Length))
      $bad += [PSCustomObject]@{ File = $_.FullName; Preview = $first; Error = $_.Exception.Message }
    }
  }

if ($bad.Count) {
  Write-Host "`nFound invalid JSON files:" -ForegroundColor Yellow
  $bad | Format-Table -AutoSize
} else {
  Write-Host "`n✅ All JSON files look valid." -ForegroundColor Green
}
