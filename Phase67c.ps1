# Phase67c.ps1 - Board Summary Final Fix
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

Sec "Reading .vercel/project.json"
$projFile = ".vercel\project.json"
if (!(Test-Path $projFile)) {
    throw "Missing .vercel\project.json — run: ver
