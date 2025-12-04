# ==============================================
# Phase182 - Evidence Snapshot & Audit
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logRoot     = "$projectRoot\scripts\logs\evidence"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"

if (-not (Test-Path $logRoot)) {
    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "===== Phase182: Evidence Snapshot & Audit START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Configure base URLs
# ------------------------------------------------------------------
$prodBase   = "https://truvern.com"
# Optional: set if you also want to snapshot the current Vercel preview
$vercelBase = ""    # e.g. "https://truvern-q36ed61xe-nelson-ai-projects.vercel.app"

# Targets: evidence list, single evidence, and vendor detail
$paths = @(
    "/api/evidence/list",
    "/api/evidence/1",
    "/vendors/1"
)

$targets = @()

foreach ($p in $paths) {
    if ($prodBase -ne "") {
        $targets += @{ Name = "prod"; Base = $prodBase; Path = $p }
    }
    if ($vercelBase -ne "") {
        $targets += @{ Name = "vercel"; Base = $vercelBase; Path = $p }
    }
}

if ($targets.Count -eq 0) {
    Write-Log "No targets configured. Set prodBase and/or vercelBase." "Red"
    exit 1
}

# ------------------------------------------------------------------
# Helper: safe slug from a path for filenames
# ------------------------------------------------------------------
function Get-SlugFromPath {
    param([string]$Path)
    $trimmed = $Path.Trim("/")
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return "root" }
    return ($trimmed -replace "[^a-zA-Z0-9\-]", "-")
}

$summary = @()

foreach ($t in $targets) {
    $fullUrl = $t.Base.TrimEnd("/") + $t.Path
    $slug    = Get-SlugFromPath -Path $t.Path
    $prefix  = "$($t.Name)-$slug-$timestamp"
    $outFile = Join-Path $logRoot ($prefix + ".txt")

    Write-Log "Requesting [$($t.Name)] $($t.Path) -> $fullUrl" "Gray"

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $fullUrl -Method GET -UseBasicParsing -TimeoutSec 20
        $sw.Stop()

        $status = [int]$response.StatusCode
        $elapsed = $sw.ElapsedMilliseconds

        # Save raw content
        $response.Content | Out-File -FilePath $outFile -Encoding UTF8

        # Try to parse JSON for API endpoints
        $extraInfo = ""
        if ($t.Path.StartsWith("/api/")) {
            try {
                $json = $response.Content | ConvertFrom-Json

                # Try a couple of likely shapes for the evidence list
                if ($t.Path -eq "/api/evidence/list") {
                    $items = $null

                    if ($null -ne $json.evidence -and $json.evidence -is [System.Collections.IEnumerable]) {
                        $items = $json.evidence
                    }
                    elseif ($null -ne $json.items -and $json.items -is [System.Collections.IEnumerable]) {
                        $items = $json.items
                    }

                    if ($items) {
                        $count = ($items | Measure-Object).Count
                        $extraInfo = " (evidence items: $count)"
                    }
                    else {
                        $extraInfo = " (evidence list shape unknown)"
                    }
                }
                elseif ($t.Path -eq "/api/evidence/1") {
                    if ($json.id -or $json.ok -or $json.evidence) {
                        $extraInfo = " (single evidence payload present)"
                    }
                }
            }
            catch {
                $extraInfo = " (JSON parse failed)"
            }
        }

        $msg = "[OK] $($t.Name) $($t.Path) - $status (${elapsed}ms)$extraInfo"
        Write-Log $msg "Green"
        $summary += $msg
    }
    catch {
        $msg = "[ERROR] $($t.Name) $($t.Path) - $($_.Exception.Message)"
        Write-Log $msg "Red"
        $summary += $msg
    }
}

Write-Log "--------------------------------------------" "Yellow"
Write-Log "Snapshot directory: $logRoot" "Yellow"
Write-Log "Summary:" "Yellow"
$summary | ForEach-Object { Write-Log $_ "Cyan" }

Write-Log "===== Phase182: Evidence Snapshot & Audit COMPLETE =====" "Yellow"
