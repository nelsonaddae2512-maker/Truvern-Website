# === Truvern Alias Fix & CSS Refresh ===
$ErrorActionPreference = "Stop"
Write-Host "`n[INFO] Re-linking truvern.com to latest verified build..." -ForegroundColor Cyan

# 1️⃣ Ensure logged in
npx vercel logout | Out-Null
npx vercel login

# 2️⃣ Switch to correct project scope
npx vercel switch nelson-addaes-projects

# 3️⃣ Find latest successful deployment for truvern
$deployments = npx vercel ls truvern --scope nelson-addaes-projects | Select-String "https"
$latest = ($deployments | ForEach-Object { $_ -match "https.*vercel\.app" | Out-Null; $matches[0] })[-1]

if (-not $latest) {
  Write-Host "❌ Could not find latest deployment. Check project name or scope." -ForegroundColor Red
  exit 1
}

Write-Host "`n✅ Latest deployment found: $latest" -ForegroundColor Green

# 4️⃣ Force alias re-link to truvern.com
Write-Host "[INFO] Re-linking alias to truvern.com..." -ForegroundColor Cyan
npx vercel alias $latest truvern.com --scope nelson-addaes-projects --yes

# 5️⃣ Clear cache / redeploy if needed
Write-Host "[INFO] Flushing cache..." -ForegroundColor Yellow
npx vercel --prod --force --confirm

Write-Host "`n✅ Done. Visit https://truvern.com and refresh with Ctrl+F5" -ForegroundColor Green