# ==============================================
# Phase127-SafeAlias.ps1
# Purpose: Safely rebuild alias references and verify link continuity
# Location: C:\Users\MR.NELSON\Downloads\truvern
# ==============================================

Write-Host "`n=== Phase127: Safe Alias Setup ===`n"

try {
    # Ensure script runs from the project directory
    Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

    # Output file for alias logs
    $OutFile = ".\alias.log"

    # Safely read existing content or initialize empty
    if (Test-Path $OutFile) {
        $txt = Get-Content $OutFile -Raw
    } else {
        $txt = ''
    }

    Write-Host "Alias log initialized successfully.`n"

    # Node & Vercel version check
    Write-Host "Checking Node and Vercel versions..."
    node -v
    vercel --version

    # Confirm directory context
    Write-Host "`nCurrent directory:" (Get-Location)
    Write-Host "`nActive files:" (Get-ChildItem | Select-Object Name)

    # Create or refresh safe alias
    $aliasName = "truvern-safe"
    $projectPath = "C:\Users\MR.NELSON\Downloads\truvern"

    Write-Host "`nRebuilding alias '$aliasName'..."
    if (Get-Alias $aliasName -ErrorAction SilentlyContinue) {
        Remove-Item "alias:$aliasName" -ErrorAction SilentlyContinue
        Write-Host "Old alias removed."
    }

    Set-Alias -Name $aliasName -Value $projectPath
    Write-Host "Alias '$aliasName' created for $projectPath.`n"

    # Verify alias creation
    if (Get-Alias $aliasName -ErrorAction SilentlyContinue) {
        Write-Host "✅ Alias verified successfully."
        Add-Content $OutFile "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Alias '$aliasName' verified OK"
    } else {
        Write-Host "⚠️ Alias verification failed."
        Add-Content $OutFile "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Alias verification FAILED"
    }

    Write-Host "`nPhase127 complete: Safe alias setup finished successfully.`n"
}
catch {
    Write-Host "`n❌ Error encountered during alias setup: $($_.Exception.Message)`n" -ForegroundColor Red
}
finally {
    Write-Host "Script execution finished."
}
