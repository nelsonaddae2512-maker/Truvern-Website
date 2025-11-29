# ============================
# Phase 198 – Drift Repair + Metadata Migration
# ============================

Write-Host "⚙️ Phase 198: Starting Drift Repair + Vendor Metadata Migration..." -ForegroundColor Cyan

# Ensure we are in the project directory
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

# 1. Generate a new baseline migration matching the LIVE Neon schema
Write-Host "📌 Step 1: Rebuilding migrations folder using prisma migrate diff..." -ForegroundColor Yellow

npx prisma migrate diff `
  --from-url="$env:DATABASE_URL" `
  --to-schema-datamodel="./prisma/schema.prisma" `
  --script > "./prisma/migrations/0000_reset.sql"

if (!$?) {
    Write-Host "❌ Failed to generate baseline migration diff." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Baseline migration (0000_reset.sql) created."

# 2. Reset local migration folder safely
Write-Host "📌 Step 2: Resetting local prisma/migrations folder..." -ForegroundColor Yellow

Remove-Item -Recurse -Force "./prisma/migrations"
New-Item -ItemType Directory -Path "./prisma/migrations" | Out-Null

Move-Item "./prisma/0000_reset.sql" "./prisma/migrations/0000_reset.sql"

Write-Host "✅ Local migrations folder rebuilt."

# 3. Apply the baseline migration to sync local → Neon
Write-Host "📌 Step 3: Applying baseline migration to Neon..." -ForegroundColor Yellow

npx prisma migrate deploy
if (!$?) {
    Write-Host "❌ migrate deploy failed." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Baseline migration deployed."

# 4. NOW we generate the missing metadata migration cleanly
Write-Host "📌 Step 4: Creating vendor metadata migration..." -ForegroundColor Yellow

npx prisma migrate dev --name add_vendor_metadata_fields
if (!$?) {
    Write-Host "❌ Could not create metadata migration." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Metadata migration applied."

# 5. Generate Prisma Client
Write-Host "📌 Step 5: Generating Prisma Client..." -ForegroundColor Yellow
npx prisma generate

Write-Host "✅ Prisma client generated."

# 6. Build the project
Write-Host "📌 Step 6: Running Next.js production build..." -ForegroundColor Yellow
npm run build

if (!$?) {
    Write-Host "❌ Build failed." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build succeeded."

# 7. Deploy to Vercel
Write-Host "📌 Step 7: Deploying to Vercel..." -ForegroundColor Yellow
npx vercel --prod

Write-Host "🎉 Phase 198 Complete — Drift repaired, metadata schema applied, deployed live!" -ForegroundColor Green
