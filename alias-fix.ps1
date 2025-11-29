# === Truvern Alias Fix Script ===
Write-Host "`n🔧 Starting Truvern alias repair..." -ForegroundColor Cyan

# === Paths ===
$nodePath   = "C:\\nvm4w\\nodejs\\node.exe"
$vercelPath = "$env:APPDATA\\npm\\node_modules\\vercel\\dist\\vc.js"

# === Project details ===
$org = "nelson-addaes-projects"
$domain = "truvern.com"

# === Check Node.js ===
if (!(Test-Path $nodePath)) {
    throw "Node.js not found at $nodePath"
}

# === Check Vercel CLI ===
if (!(Test-Path $vercelPath)) {
    throw "Vercel CLI not found at $vercelPath"
}

# === Get latest ready deployment ===
Write-Host "`n📡 Checking latest READY deployment..." -ForegroundColor Yellow
$rawList = & $nodePath $vercelPath "ls" "truvern" "--scope" $org "--prod" "--confirm"
$readyLine = $rawList | Select-String -Pattern "https://truvern-[\w-]+\.vercel\.app" | Select-Object -Last 1

if (-not $readyLine) {
    throw "No READY deployment found. Check your Vercel dashboard."
}

$prodUrl = ($readyLine.Matches[0].Value).Trim()
Write-Host "`n✅ Using READY deployment: $prodUrl" -ForegroundColor Green

# === Alias to domain ===
Write-Host "`n🌍 Aliasing truvern.com to $prodUrl ..." -ForegroundColor Yellow
cmd.exe /c "node `"$vercelPath`" alias set $prodUrl $domain --scope $org"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n🚀 Done! https://$domain now points to: $prodUrl" -ForegroundColor Green
    Write-Host "✅ Visit https://truvern.com and press Ctrl+F5 to refresh styles." -ForegroundColor Cyan
} else {
    throw "Alias command failed."
}
