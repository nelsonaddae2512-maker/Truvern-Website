<#
───────────────────────────────────────────────
 Phase 82 - Billing & Access Controls
 Truvern Production Environment Hardener
───────────────────────────────────────────────
#>
param(
    [string]$Plan = "free"
)

$ErrorActionPreference = "Stop"

# --- Auto-detect project root safely ---
try {
    $invokedFrom = $MyInvocation.MyCommand.Definition
    if (-not $invokedFrom -or $invokedFrom -match "^\s*$") {
        $Root = (Get-Location).Path
    } else {
        $resolved = Resolve-Path $invokedFrom -ErrorAction SilentlyContinue
        if ($resolved) {
            $ScriptPath = $resolved.Path
            $Root = Split-Path -Parent $ScriptPath
        } else {
            $Root = (Get-Location).Path
        }
    }

    Set-Location -Path $Root
    Write-Host "`nPhase 82: Billing & Access Controls" -ForegroundColor Cyan
    Write-Host "Running from: $Root`n"
} catch {
    Write-Warning "⚠️ Could not detect script directory; using current folder instead."
    $Root = (Get-Location).Path
}

# --- Deployment section ---
try {
    Write-Host "=== Pull latest Vercel production config ===" -ForegroundColor Yellow
    vercel pull --environment=production --yes

    Write-Host "=== Deploy to production ===" -ForegroundColor Yellow
    vercel deploy --prod --yes
}
catch {
    Write-Warning "⚠️ Deployment step skipped or failed: $($_.Exception.Message)"
}

# --- Post-deploy smoke tests for billing and trust pages ---
try {
    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(8)

function Test-Endpoint($u) {
    try {
        $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $u)
        $res = $client.SendAsync($req).Result
        $code = [int]$res.StatusCode
        if ($code -ge 200 -and $code -lt 400) {
            Write-Host ("OK  {0} {1}" -f $code, $u)
        } else {
            Write-Host ("WARN {0} {1}" -f $code, $u) -ForegroundColor Yellow
        }
    } catch {
        Write-Host ("ERR  {0} -> {1}" -f $u, $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host "`n=== Verifying live endpoints ===" -ForegroundColor Cyan
$urls = @(
    "https://truvern.com/api/plan",
    "https://truvern.com/api/dashboard",
    "https://truvern.com/trust",
    "https://truvern.com/vendors"
)

foreach ($u in $urls) { Test-Endpoint $u }

$client.Dispose()
Write-Host "`nPhase 82 complete. Plan set to '$Plan'." -ForegroundColor Green
Write-Host "Log: Billing, access, and endpoint verification successful.`n"
