Import-Module "$PSScriptRoot\integrity\HashEngine.psm1" -Force

$Root = "C:\Users\MR.NELSON\Downloads\truvern"
$pointerFile = "$Root\scripts\logs\integrity\master-seal-latest.json"

Write-Host "=== Phase204: Master Seal Verification (SOURCE-ONLY FINAL v4) ===" -ForegroundColor Cyan

$ptr = Get-Content $pointerFile | ConvertFrom-Json
$expected = $ptr.masterSeal
Write-Host "Expected seal: $expected" -ForegroundColor Green

$map = Compute-FileHashMap -Root $Root
$seal = Compute-Seal -Map $map

Write-Host "`nComputed seal: $seal" -ForegroundColor Blue

if ($seal -eq $expected) {
    Write-Host "✔ MATCH — Integrity verified!" -ForegroundColor Green
}
else {
    Write-Host "✖ FAILURE — Seal mismatch" -ForegroundColor Red
}
