Write-Host "=== Phase203: Master Seal (FINAL FIX v2) ===" -ForegroundColor Cyan

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$LogDir      = Join-Path $PSScriptRoot "logs\integrity"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$outJson    = Join-Path $LogDir "Phase203-MasterSeal-$timestamp.json"
$latestJson = Join-Path $LogDir "master-seal-latest.json"

# ---------- STRONG SKIP LOGIC ----------
function Get-RelativePath([string]$fullPath, [string]$root) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\','/')
    # normalize to forward slashes so -like patterns match
    return $rel.Replace('\','/')
}

function Should-SkipFile([string]$fullPath, [string]$root) {
    $rel = Get-RelativePath $fullPath $root

    $patterns = @(
        "node_modules/*",
        ".next/*",
        ".git/*",
        "scripts/logs/*",
        "*.map",
        "*.chunk.js",
        "*.chunk.css",
        "*.bak",
        "app/*/__generated__/*",
        "public/build/*",

        # dynamic / bundled API routes – unstable for hashing
        "app/api/*/route.ts",
        "app/api/*/*/route.ts",
        "app/api/*/*/*/route.ts"
    )

    foreach ($p in $patterns) {
        if ($rel -like $p) { return $true }
    }

    return $false
}

Write-Host "Collecting files..." -ForegroundColor Gray

$entries  = @()
$included = 0
$skipped  = 0

Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_

    if (Should-SkipFile $file.FullName $ProjectRoot) {
        $skipped++
        return
    }

    try {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction Stop
        if ($null -eq $hash) {
            $skipped++
            return
        }

        $relative = Get-RelativePath $file.FullName $ProjectRoot

        $entries += [pscustomobject]@{
            path = $relative
            hash = $hash.Hash.ToLower()
        }
        $included++
    }
    catch {
        # Do NOT spam warnings; just count as skipped
        $skipped++
    }
}

Write-Host "Included files: $included" -ForegroundColor Green
Write-Host "Skipped files : $skipped"  -ForegroundColor Yellow

# ---------- Compute master seal ----------
$sorted = $entries | Sort-Object path
$concat = ($sorted | ForEach-Object { "{0}|{1}" -f $_.path, $_.hash }) -join "`n"

$bytes = [System.Text.Encoding]::UTF8.GetBytes($concat)
$sha   = [System.Security.Cryptography.SHA256]::Create()
$seal  = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""

$sealObj = [pscustomobject]@{
    seal      = $seal
    createdAt = (Get-Date).ToString("o")
    entries   = $sorted
}

$sealObj | ConvertTo-Json -Depth 6 | Set-Content $outJson -Encoding UTF8
Copy-Item $outJson $latestJson -Force

Write-Host ""
Write-Host "Master seal: $seal" -ForegroundColor Cyan
Write-Host "Wrote seal JSON : $outJson" -ForegroundColor Green
Write-Host "Updated pointer : $latestJson" -ForegroundColor Green
Write-Host "=== Phase203 COMPLETE ===" -ForegroundColor Cyan
