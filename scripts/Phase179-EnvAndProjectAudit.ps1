# ===============================
# Phase179 - Env & Project Audit
# ===============================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logFile = "$projectRoot\scripts\logs\phase179-env-audit.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date), $Message)
}

Write-Log "===== Phase179: Environment & Project Audit START =====" "Yellow"

# -------------------------------------------
# 1. Confirm correct working directory
# -------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root..." "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# -------------------------------------------
# 2. Check required environment variables
# -------------------------------------------

$requiredVars = @(
    "DATABASE_URL",
    "NEXTAUTH_SECRET",
    "NEXTAUTH_URL",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_REGION",
    "S3_BUCKET_NAME"
)

Write-Log "Checking environment variables..." "Yellow"

foreach ($var in $requiredVars) {
    # PowerShell cannot do $env:$var; use the Environment class instead
    $value = [Environment]::GetEnvironmentVariable($var, "Process")

    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Log "[MISSING] $var" "Red"
    } else {
        Write-Log "[OK] $var is set" "Green"
    }
}

# -------------------------------------------
# 3. Check repo status
# -------------------------------------------
Write-Log "Checking Git status..." "Yellow"

$gitStatus = git status 2>&1
Write-Log $gitStatus "Gray"

# -------------------------------------------
# 4. Check Prisma schema and migrations
# -------------------------------------------
Write-Log "Running Prisma format check..." "Yellow"
try {
    npx prisma format
    Write-Log "Prisma schema formatted successfully." "Green"
}
catch {
    Write-Log "Prisma format error: $_" "Red"
}

Write-Log "Running Prisma validate..." "Yellow"
try {
    npx prisma validate
    Write-Log "Prisma validation OK." "Green"
}
catch {
    Write-Log "Prisma validation failure: $_" "Red"
}

# -------------------------------------------
# 5. Completed
# -------------------------------------------

Write-Log "===== Phase179: Environment & Project Audit COMPLETE =====" "Yellow"
