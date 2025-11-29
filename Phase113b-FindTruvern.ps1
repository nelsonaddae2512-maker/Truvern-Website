<#  Phase113b-FindTruvern.ps1
    Finds any folder named "truvern" (case-insensitive) under common roots
    (including both "Nelson AI Projects" and "Nelson AI Projectss"), lets you
    pick one, switches there, and remembers it for next time.  Use -Deep to
    scan all drives if needed.
#>

[CmdletBinding()]
param([switch]$Deep)

$ErrorActionPreference = 'SilentlyContinue'

function Show-Header {
  Write-Host "`n=== Truvern workspace locator ===" -ForegroundColor Cyan
}

function Get-CandidateRoots {
  $user = Join-Path $env:USERPROFILE ''
  @(
    (Join-Path $user 'Downloads'),
    (Join-Path $user 'Documents'),
    (Join-Path $user 'Desktop'),
    (Join-Path $user 'source'),
    (Join-Path $user 'Projects'),
    (Join-Path $user 'Downloads\Nelson AI Projects'),
    (Join-Path $user 'Downloads\Nelson AI Projectss')
  ) | Where-Object { Test-Path $_ } | Sort-Object -Unique
}

function Find-TruvernUnder([string[]]$roots) {
  if (-not $roots) { return @() }
  $hits = @()
  foreach ($r in $roots) {
    try {
      Get-ChildItem -Path $r -Recurse -Directory |
        Where-Object { $_.Name -ieq 'truvern' } |
        ForEach-Object { $hits += $_.FullName }
    } catch { }
  }
  $hits | Sort-Object -Unique
}

function Find-TruvernEverywhere {
  $hits = @()
  foreach ($d in Get-PSDrive -PSProvider FileSystem) {
    try {
      Get-ChildItem -Path $d.Root -Recurse -Directory |
        Where-Object { $_.Name -ieq 'truvern' } |
        ForEach-Object { $hits += $_.FullName }
    } catch { }
  }
  $hits | Sort-Object -Unique
}

function Choose-Path([string[]]$paths) {
  if (-not $paths -or $paths.Count -eq 0) { return $null }
  if ($paths.Count -eq 1) { return $paths[0] }

  Write-Host ""
  for ($i=0; $i -lt $paths.Count; $i++) {
    "{0,2}) {1}" -f ($i+1), $paths[$i] | Write-Host
  }
  $choice = Read-Host "Pick a number (default 1)"
  if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 1 }
  $idx = [int]$choice - 1
  if ($idx -lt 0 -or $idx -ge $paths.Count) { return $paths[0] }
  return $paths[$idx]
}

function Remember([string]$path) {
  try {
    Set-Content -Path (Join-Path (Get-Location) 'last-truvern-path.txt') -Value $path -Encoding UTF8
  } catch { }
}

Show-Header

Write-Host "Searching common roots..." -ForegroundColor Yellow
$roots = Get-CandidateRoots
$found = Find-TruvernUnder -roots $roots

if (-not $found -and $Deep) {
  Write-Host "No hits in user roots. Deep scanning all drives..." -ForegroundColor DarkYellow
  $found = Find-TruvernEverywhere
}

if (-not $found -or $found.Count -eq 0) {
  Write-Host "No folder named 'truvern' was found. Re-run with -Deep or verify the folder exists." -ForegroundColor Red
  exit 1
}

$dest = Choose-Path -paths $found
if (-not $dest) {
  Write-Host "No selection made." -ForegroundColor Red
  exit 1
}

# Switch and show where we are
Set-Location $dest
Remember $dest

Write-Host "`nSwitched to: $dest" -ForegroundColor Green
Write-Host "`nTip: You are now in the correct workspace. Run:" -ForegroundColor Cyan
Write-Host "  dir; git status 2>`$null" -ForegroundColor Yellow
