# Phase-CSS-Tailwindcss-Repair.ps1
# Ensure tailwindcss + postcss + autoprefixer are present as dependencies
# and then run npm install.

Write-Host "== Truvern Tailwind dependency repair ==" -ForegroundColor Cyan

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

$pkgPath = Join-Path $projectPath "package.json"
if (-not (Test-Path $pkgPath)) {
    Write-Host "ERROR: package.json not found at $pkgPath" -ForegroundColor Red
    exit 1
}

Write-Host "Loading package.json..." -ForegroundColor Yellow
$pkgJson = Get-Content $pkgPath -Raw
$pkg = $pkgJson | ConvertFrom-Json

# Make sure dependencies object exists
if (-not $pkg.PSObject.Properties.Name.Contains("dependencies")) {
    $pkg | Add-Member -MemberType NoteProperty -Name dependencies -Value (@{})
}

$desiredDeps = @{
    "tailwindcss"  = "^3.4.14"
    "postcss"      = "^8.4.47"
    "autoprefixer" = "^10.4.20"
}

foreach ($name in $desiredDeps.Keys) {
    $version = $desiredDeps[$name]

    $alreadyInDeps = $pkg.dependencies.PSObject.Properties.Name -contains $name
    $alreadyInDev  = $false
    if ($pkg.PSObject.Properties.Name -contains "devDependencies") {
        $alreadyInDev = $pkg.devDependencies.PSObject.Properties.Name -contains $name
    }

    if ($alreadyInDeps) {
        Write-Host "Dependency '$name' already in dependencies ($($pkg.dependencies.$name))." -ForegroundColor DarkGray
    } elseif ($alreadyInDev) {
        Write-Host "Dependency '$name' is in devDependencies; leaving it there." -ForegroundColor DarkGray
    } else {
        Write-Host "Adding '$name@$version' to dependencies..." -ForegroundColor Green
        $pkg.dependencies | Add-Member -MemberType NoteProperty -Name $name -Value $version
    }
}

Write-Host "Writing updated package.json..." -ForegroundColor Yellow
$pkg | ConvertTo-Json -Depth 10 | Set-Content -Path $pkgPath -Encoding utf8

Write-Host "Reinstalling node_modules (this may take a few minutes)..." -ForegroundColor Yellow
# Fresh install using the updated package.json
Remove-Item -Recurse -Force ".\node_modules" -ErrorAction SilentlyContinue
npm install

Write-Host "Verifying tailwindcss in node_modules..." -ForegroundColor Yellow
if (Test-Path ".\node_modules\tailwindcss\package.json") {
    Write-Host "OK: tailwindcss is present in node_modules ✅" -ForegroundColor Green
} else {
    Write-Host "ERROR: tailwindcss is STILL missing in node_modules ❌" -ForegroundColor Red
    Write-Host "Check the npm output above for any errors and share a screenshot." -ForegroundColor Red
}
