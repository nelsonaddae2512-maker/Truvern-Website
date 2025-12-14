# SealCore.ps1
# Shared hashing engine for Phase203 / Phase204
# Model: SOURCE-ONLY seal (ignores build + noise directories)

function Get-TruvernSourceFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    # Directories we NEVER want in the seal
    $excludePatterns = @(
        '\.git\',
        '\.next\',
        '\.vercel\',
        '\.vercel-tools\',
        '\node_modules\',
        '\scripts\logs\',
        '\backup\',
        '\backups\',
        '\dist\',
        '\out\'
    )

    Write-Host "Enumerating source files from: $RootPath" -ForegroundColor DarkCyan

    $files = Get-ChildItem -Path $RootPath -Recurse -File -Force |
        Where-Object {
            $full = $_.FullName.ToLower()
            -not ($excludePatterns | Where-Object { $full -like "*$($_.ToLower())*" })
        } |
        Sort-Object FullName

    Write-Host ("Included source files: {0}" -f $files.Count) -ForegroundColor Cyan
    return $files
}

function Get-TruvernSeal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        # Optional: pass in an existing hashtable to be filled with { relativePath -> hash }
        [hashtable]$HashMapOutput
    )

    $files = Get-TruvernSourceFiles -RootPath $RootPath
    $total = $files.Count

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashList = @{}

    $counter = 0
    foreach ($file in $files) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hashBytes = $sha256.ComputeHash($bytes)
            $hex = [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()

            # store as path relative to project root
            $relative = $file.FullName.Substring($RootPath.Length).TrimStart('\')
            $hashList[$relative] = $hex
        }
        catch {
            Write-Host "Failed to read $($file.FullName), skipping..." -ForegroundColor DarkYellow
        }

        $counter++
        if ($counter % 200 -eq 0) {
            Write-Host (" Hashed {0} / {1} files..." -f $counter, $total)
        }
    }

    # For callers that want the full map
    if ($HashMapOutput) {
        $HashMapOutput.Clear()
        foreach ($k in $hashList.Keys) {
            $HashMapOutput[$k] = $hashList[$k]
        }
    }

    # Deterministic JSON: sort by file path
    $json = ($hashList.GetEnumerator() | Sort-Object Name) | ConvertTo-Json -Depth 5

    # Compute final seal over the JSON
    $finalSha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes2 = $finalSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($json))
    $seal = [BitConverter]::ToString($hashBytes2).Replace("-", "").ToLower()

    return [pscustomobject]@{
        Seal      = $seal
        FileCount = $hashList.Count
        Json      = $json
    }
}
