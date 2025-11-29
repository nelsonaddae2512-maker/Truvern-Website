# Phase114-DirectRun.ps1
# Workspace locator + switcher + smoke tests
# Compatible with Windows PowerShell 5.1 (no $PSStyle)

$ErrorActionPreference = 'Stop'

function Write-Section($t) { Write-Host "`n=== $t ===" -ForegroundColor Yellow }

function Choose-Path([string[]]$paths) {
    for ($i = 0; $i -lt $paths.Count; $i++) {
        Write-Host ("[{0}] {1}" -f $i, $paths[$i]) -ForegroundColor Cyan
    }
    do {
        $sel = Read-Host "Enter number for the correct 'truvern' workspace"
    } until ($sel -match '^\d+$' -and [int]$sel -ge 0 -and [int]$sel -lt $paths.Count)
    return $paths[[int]$sel]
}

function Find-TruvernUnder([string[]]$roots) {
    $hits = @()
    foreach ($root in $roots) {
        try {
            if (-not (Test-Path $root)) { continue }
            Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ieq 'truvern' } |
                ForEach-Object { $hits += $_.FullName }
        } catch { }
    }
    $hits | Sort-Object -Unique
}

function Get-CandidateRoots {
    $u = $env:USERPROFILE
    @(
        Join-Path $u 'Downloads'
        Join-Path $u 'Documents'
        Join-Path $u 'Desktop'
        Join-Path $u 'Nelson AI Projects'
        Join-Path $u 'Nelson AI Projectss'
        'C:\Users\MR.NELSON\Downloads'
        'C:\'
    ) | Where-Object { Test-Path $_ } | Sort-Object -Unique
}

# === 1) Locate workspaces ===
Write-Section "Searching for 'truvern' workspaces"
$roots = Get-CandidateRoots
$found = Find-TruvernUnder -roots $roots

if (-not $found -or $found.Count -eq 0) {
    Write-Host "No quick hits. Deep scanning all drives..." -ForegroundColor DarkYellow
    $fixed = (Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Free -ge 0}).Root
    $found = Find-TruvernUnder -roots $fixed
}

if (-not $found -or $found.Count -eq 0) {
    Write-Host "Could not find any 'truvern' folder." -ForegroundColor Red
    exit 1
}

# === 2) Choose correct one ===
Write-Section "Select correct 'truvern' workspace"
$dest = Choose-Path -paths $found

# === 3) Switch there ===
Set-Location $dest
Write-Section "Switched to"
Write-Host (Get-Location).Path -ForegroundColor Green

# === 4) Check essentials ===
Write-Section "Sanity checks"
$checks = @(
    @{Name='package.json'; Path='package.json'},
    @{Name='app folder';   Path='app'},
    @{Name='prisma folder';Path='prisma'}
)
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Host ("OK  {0}" -f $c.Name) -ForegroundColor Green
    } else {
        Write-Host ("MISS {0}" -f $c.Name) -ForegroundColor DarkYellow
    }
}

# === 5) Node & pnpm presence ===
Write-Section "Checking Node & pnpm"
$node = Get-Command node.exe -ErrorAction SilentlyContinue
$pnpm = Get-Command pnpm.ps1 -ErrorAction SilentlyContinue
if ($node) { & $node.Source --version } else { Write-Host "Node not found" -ForegroundColor Red }
if ($pnpm) { & $pnpm.Source --version } else { Write-Host "pnpm not found" -ForegroundColor Red }

# === 6) Optional local build ===
Write-Section "Optional local build"
$doBuild = Read-Host "Type 'y' to run 'pnpm install && pnpm build', Enter to skip"
if ($doBuild -eq 'y') {
    try {
        if ($pnpm) {
            & $pnpm.Source install
            & $pnpm.Source build
            Write-Host "Local build finished." -ForegroundColor Green
        } else {
            Write-Host "pnpm not found; skipping build." -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host ("Build error: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

# === 7) Cloud smoke tests ===
Write-Section "Checking live URLs"
$urls = @(
    "https://truvern.com/",
    "https://truvern.com/trust-network",
    "https://truvern.com/vendors",
    "https://truvern.com/pricing",
    "https://truvern.com/contact",
    "https://truvern.com/api/vendors",
    "https://truvern.com/api/board",
    "https://truvern.com/api/trust-network"
)
foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri $u
        Write-Host ("OK   {0} -> HTTP {1}" -f $u, $r.StatusCode) -ForegroundColor Green
    } catch {
        $c = $_.Exception.Response.StatusCode.value__ 2>$null
        if ($c) {
            Write-Host ("WARN {0} -> HTTP {1}" -f $u, $c) -ForegroundColor DarkYellow
        } else {
            Write-Host ("FAIL {0} -> {1}" -f $u, $_.Exception.Message) -ForegroundColor Red
        }
    }
}

Write-Section "All checks complete"
Write-Host "Next typical steps:" -ForegroundColor Cyan
Write-Host "  1) Verify .env and Vercel settings" -ForegroundColor Cyan
Write-Host "  2) pnpm install" -ForegroundColor Cyan
Write-Host "  3) pnpm run build or vercel --prod" -ForegroundColor Cyan
