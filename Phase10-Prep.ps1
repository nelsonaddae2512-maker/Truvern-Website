$ErrorActionPreference = "Stop"
Write-Host "== Phase10 Prep ==" -ForegroundColor Cyan

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectRoot
Write-Host "PWD: $PWD" -ForegroundColor Yellow

$env:CI = "1"
$env:FORCE_COLOR = "0"

Get-Process node,npm,vercel -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host ".vercel\project.json exists: $([IO.File]::Exists('.vercel\project.json'))" -ForegroundColor Gray
if (-not $env:VERCEL_TOKEN) {
    Write-Host "Missing VERCEL_TOKEN" -ForegroundColor Red
} else {
    Write-Host "VERCEL_TOKEN found (masked)" -ForegroundColor Green
}
