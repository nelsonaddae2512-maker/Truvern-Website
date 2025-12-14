<#
.SYNOPSIS
  Phase190 - Production Launch Readiness Gate

.DESCRIPTION
  Checks critical env vars (.env), git cleanliness, Prisma validity,
  and (optionally) build + prod deploy via Vercel. Produces a Markdown
  report in /logs.
#>

param(
    [switch]$RunBuild,
    [switch]$DeployProd
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
$logsDir   = Join-Path $repoRoot 'logs'
$envFile   = Join-Path $repoRoot '.env'

if (-not (Test-Path $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}

$timestamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$reportFile = Join-Path $logsDir "Phase190-ProdLaunchReadiness-$timestamp.md"

function Write-PhaseStatus {
    param(
        [string]$Message,
        [string]$Color = 'Cyan'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Append-Report {
    param(
        [string]$Line
    )
    Add-Content -Path $script:reportFile -Value $Line
}

function Append-CodeBlock {
    param(
        [string]$Title,
        [string]$Content
    )

    Append-Report "### $Title"
    Append-Report ""
    Append-Report '```'
    if ($Content) {
        Append-Report $Content.TrimEnd()
    }
    Append-Report '```'
    Append-Report ""
}

# -----------------------------
# 1) .env parsing + env checks
# -----------------------------
Write-PhaseStatus 'Checking .env and critical environment variables...' 'Cyan'

$envMap = @{}

if (Test-Path $envFile) {
    foreach ($line in Get-Content -Path $envFile) {
        if ($line -match '^\s*#') { continue }
        if (-not $line.Contains('=')) { continue }

        $parts = $line.Split('=', 2)
        $key   = $parts[0].Trim()
        $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }

        if ($key) {
            $envMap[$key] = $value
        }
    }
}
else {
    Write-PhaseStatus 'WARNING: .env file not found at repo root.' 'Yellow'
}

# Critical vars for Truvern prod
$requiredEnvVars = @(
    'DATABASE_URL'
    'NEXTAUTH_SECRET'
    'NEXTAUTH_URL'
    'AWS_ACCESS_KEY_ID'
    'AWS_SECRET_ACCESS_KEY'
    'AWS_REGION'
    'S3_BUCKET_NAME'
    'STRIPE_SECRET_KEY'
    'STRIPE_WEBHOOK_SECRET'
    'VERCEL_PROJECT_ID'
    'VERCEL_ORG_ID'
)

$envIssues = @()
foreach ($name in $requiredEnvVars) {
    $value = $null

    if ($envMap.ContainsKey($name)) {
        $value = $envMap[$name]
    }
    elseif (Test-Path Env:\$name) {
        $value = (Get-Item Env:\$name).Value
    }

    if (-not $value) {
        $envIssues += "MISSING or empty: $name"
    }
}

Append-Report "# Truvern Production Launch Readiness"
Append-Report ""
Append-Report "> Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Append-Report ""
Append-Report "## Environment variable check"
Append-Report ""

if ($envIssues.Count -gt 0) {
    foreach ($issue in $envIssues) {
        Append-Report "- ❌ $issue"
    }
    Write-PhaseStatus "Env check: issues found ($($envIssues.Count))" 'Yellow'
}
else {
    Append-Report "- ✅ All required env vars are present (in .env or process environment)."
    Write-PhaseStatus 'Env check: all required vars present.' 'Green'
}

# -----------------------------
# 2) Git status / cleanliness
# -----------------------------
Write-PhaseStatus 'Checking git status...' 'Cyan'

$gitClean    = $false
$branchName  = ''
$gitSummary  = ''

try {
    $branchName = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
}
catch {
    $branchName = '(unable to determine branch)'
}

try {
    $gitRaw = & git status --short 2>&1 | Out-String
    $gitSummary = $gitRaw
    if ([string]::IsNullOrWhiteSpace($gitRaw)) {
        $gitClean = $true
    }
    else {
        $gitClean = $false
    }
}
catch {
    $gitSummary = "Error running git status: $($_.Exception.Message)"
}

Append-Report "## Git status"
Append-Report ""
Append-Report "- Branch: **$branchName**"
if ($gitClean) {
    Append-Report "- Working tree: ✅ clean"
    Write-PhaseStatus 'Git: clean working tree.' 'Green'
}
else {
    Append-Report "- Working tree: ❌ dirty (uncommitted changes)"
    Write-PhaseStatus 'Git: uncommitted changes present.' 'Yellow'
}
Append-Report ""
Append-CodeBlock -Title 'git status --short' -Content $gitSummary

# -----------------------------
# 3) Prisma validate
# -----------------------------
# -----------------------------
# 3) Prisma validate
# -----------------------------
# -----------------------------
# 3) Prisma schema check
# -----------------------------
Write-PhaseStatus 'Running Prisma validate...' 'Cyan'

$prismaOk = $false
$prismaOutput = ''

# Some versions of Prisma/Node print "Environment variables loaded from .env"
# to STDERR, which PowerShell treats as a NativeCommandError when
# $ErrorActionPreference = 'Stop'. Here we temporarily relax that and
# run through cmd so we only care about the exit code.
$oldEAP = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    Push-Location $repoRoot

    # Use cmd /c so npx runs as a plain external command
    $prismaOutput = & cmd /c "npx prisma validate" 2>&1 | Out-String

    if ($LASTEXITCODE -eq 0) {
        $prismaOk = $true
        Write-PhaseStatus 'Prisma validate: OK' 'Green'
    }
    else {
        $prismaOk = $false
        Write-PhaseStatus "Prisma validate: FAILED (exit $LASTEXITCODE)" 'Red'
    }
}
catch {
    $prismaOutput = "Error running prisma validate: $($_.Exception.Message)"
    $prismaOk = $false
    Write-PhaseStatus 'Prisma validate: FAILED (exception)' 'Red'
}
finally {
    Pop-Location
    $ErrorActionPreference = $oldEAP
}

Append-Report "## Prisma schema check"
Append-Report ""
if ($prismaOk) {
    Append-Report "- ✅ Prisma schema validated successfully."
}
else {
    Append-Report "- ❌ Prisma validation failed. See output below."
}
Append-Report ""
Append-CodeBlock -Title 'npx prisma validate' -Content $prismaOutput

# -----------------------------
# 4) Optional build step
# -----------------------------
$buildOk = $false
$buildRan = $false
$buildOutput = ''

if ($RunBuild) {
    Write-PhaseStatus 'Running npm run build (this may take a while)...' 'Cyan'
    $buildRan = $true
    try {
        Push-Location $repoRoot
        $buildOutput = & npm run build 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $buildOk = $true
            Write-PhaseStatus 'Build: OK' 'Green'
        }
        else {
            $buildOk = $false
            Write-PhaseStatus "Build: FAILED (exit $LASTEXITCODE)" 'Red'
        }
    }
    catch {
        $buildOutput = "Error running npm run build: $($_.Exception.Message)"
        $buildOk = $false
        Write-PhaseStatus 'Build: FAILED (exception)' 'Red'
    }
    finally {
        Pop-Location
    }

    Append-Report "## Build step"
    Append-Report ""
    if ($buildOk) {
        Append-Report "- ✅ npm run build succeeded."
    }
    else {
        Append-Report "- ❌ npm run build failed."
    }
    Append-Report ""
    Append-CodeBlock -Title 'npm run build' -Content $buildOutput
}
else {
    Append-Report "## Build step"
    Append-Report ""
    Append-Report "- ⏭ Build skipped (run with \`-RunBuild\` to execute \`npm run build\`)."
}

# -----------------------------
# 5) Optional Vercel prod deploy
# -----------------------------
$deployOk = $false
$deployRan = $false
$deployOutput = ''

if ($DeployProd) {
    Write-PhaseStatus 'Running Vercel production deploy (npx vercel --prod --confirm)...' 'Cyan'
    $deployRan = $true
    try {
        Push-Location $repoRoot
        $deployOutput = & npx vercel --prod --confirm 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $deployOk = $true
            Write-PhaseStatus 'Prod deploy: OK' 'Green'
        }
        else {
            $deployOk = $false
            Write-PhaseStatus "Prod deploy: FAILED (exit $LASTEXITCODE)" 'Red'
        }
    }
    catch {
        $deployOutput = "Error running vercel deploy: $($_.Exception.Message)"
        $deployOk = $false
        Write-PhaseStatus 'Prod deploy: FAILED (exception)' 'Red'
    }
    finally {
        Pop-Location
    }

    Append-Report "## Production deploy"
    Append-Report ""
    if ($deployOk) {
        Append-Report "- ✅ Vercel production deploy succeeded."
    }
    else {
        Append-Report "- ❌ Vercel production deploy failed."
    }
    Append-Report ""
    Append-CodeBlock -Title 'npx vercel --prod --confirm' -Content $deployOutput
}
else {
    Append-Report "## Production deploy"
    Append-Report ""
    Append-Report "- ⏭ Prod deploy skipped (run with \`-DeployProd\` to trigger Vercel)."
}

# -----------------------------
# 6) Final gate decision
# -----------------------------
$blockingReasons = @()

if ($envIssues.Count -gt 0) {
    $blockingReasons += "Env issues: $($envIssues.Count)"
}
if (-not $prismaOk) {
    $blockingReasons += 'Prisma validation failed'
}
if ($RunBuild -and -not $buildOk) {
    $blockingReasons += 'Build failed'
}

$gateOk = ($blockingReasons.Count -eq 0)

Append-Report ""
Append-Report "## Launch gate decision"
Append-Report ""

if ($gateOk) {
    Append-Report "- ✅ Launch gate PASSED. No blocking issues detected."
    Write-PhaseStatus '===== Phase190: Launch gate PASSED =====' 'Green'
}
else {
    Append-Report "- ❌ Launch gate BLOCKED by:"
    foreach ($reason in $blockingReasons) {
        Append-Report "  - $reason"
    }
    Write-PhaseStatus '===== Phase190: Launch gate BLOCKED (see report) =====' 'Red'
}

Append-Report ""
Append-Report "## Notes"
Append-Report ""
Append-Report "- This report was generated by **Phase190-ProdLaunchReadiness.ps1**."
Append-Report "- Use \`-RunBuild\` and/or \`-DeployProd\` switches when you are ready to build/deploy from this gate."
Append-Report ""

Write-Host "Report written to: $reportFile" -ForegroundColor 'Cyan'
