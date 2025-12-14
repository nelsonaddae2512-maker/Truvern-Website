# ============================
# HashEngine.psm1 (FINAL V1)
# ============================

function Get-SourceFiles {
    param(
        [string]$Root
    )

    $exclude = @(
    '.git',
    '.next',
    'node_modules',
    '.vercel',
    '.vercel-tools',
    'scripts\logs\badges',
    'scripts\logs\integrity',
    'backup',
    '.DS_Store',
    'Thumbs.db'
)

    return Get-ChildItem -Path $Root -Recurse -File -Force |
        Where-Object {
            $full = $_.FullName.ToLower()
            -not ($exclude | Where-Object { $full -like "*$_*" })
        } |
        Sort-Object FullName -CaseSensitive
}

function Compute-FileHashMap {
    param(
        [string]$Root
    )

    $files = Get-SourceFiles -Root $Root
    $sha = [System.Security.Cryptography.SHA256]::Create()

    $map = @{}
    $i = 0
    $total = $files.Count

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Root.Length).Replace("\", "/")

        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""

        $map[$relative] = $hash

        $i++
        if ($i % 200 -eq 0) {
            Write-Host "Hashed $i / $total files..."
        }
    }

    return $map
}

function Compute-Seal {
    param(
        [hashtable]$Map
    )

    # Ensure stable JSON by sorting keys
    $json = ($Map.GetEnumerator() | Sort-Object Name) |
        ConvertTo-Json -Compress -Depth 10

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
}

Export-ModuleMember -Function * -Alias *
