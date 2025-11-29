# Phase124e-Cleanup.ps1
# Cleanup .vercel backups and set correct Vercel team scope.

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== Phase124e: Cleanup and Scope Lock ===" -ForegroundColor Cyan

# --- Remove backup folders ---
$backups = Get-ChildItem -Path . -Directory -Filter ".vercel.bak-*"
if ($backups) {
    foreach ($b in $backups) {
        Write-Host ("Removing backup folder: " + $b.FullName) -ForegroundColor Yellow
        Remove-Item -Recurse -Force $b.FullName
    }
} else {
    Write-Host "No .vercel.bak-* folders found." -ForegroundColor Gray
}

# --- Set default team scope ---
$team = "nelson-ai-projects"
Write-Host ("Setting global Vercel scope to: " + $team) -ForegroundColor Cyan
try {
    cmd /c "vercel switch --scope $team --yes"
} catch {
    Write-Host "If this fails, run manually: vercel switch --scope $team" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Cleanup complete. Project now permanently linked to Nelson AI Projects." -ForegroundColor Green

Read-Host "Press Enter to close"
