Import-Module "$PSScriptRoot\integrity\HashEngine.psm1" -Force

$Root = "C:\Users\MR.NELSON\Downloads\truvern"

Write-Host "=== Phase203: Master Seal (SOURCE-ONLY FINAL FIX v4) ===" -ForegroundColor Cyan

$map = Compute-FileHashMap -Root $Root
$seal = Compute-Seal -Map $map

Write-Host "Master seal: $seal" -ForegroundColor Green

# Write baseline JSON
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$baselineFile = "$Root\scripts\logs\integrity\Phase203-Seal-$timestamp.json"
$map | ConvertTo-Json -Depth 10 | Out-File $baselineFile -Encoding utf8

# Update pointer
$pointerFile = "$Root\scripts\logs\integrity\master-seal-latest.json"
@{ masterSeal = $seal; baseline = $baselineFile } |
    ConvertTo-Json -Depth 5 | Out-File $pointerFile -Encoding utf8

Write-Host "=== Phase203 COMPLETE ==="
