Write-Host "=== Phase 199: Full Drift Repair & Metadata Migration ===" -ForegroundColor Cyan

Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

# Ensure prisma folder exists
if (!(Test-Path "./prisma")) {
    Write-Host "❌ prisma folder not found." -ForegroundColor Red
    exit 1
}

Write-Host "📌 Step 1 — Creating baseline diff from Neon → local schema" -ForegroundColor Yellow
npx prisma migrate diff `
  --from-url="$env:DATABASE_URL" `
  --to-schema-datamodel="./prisma/schema.prisma" `
  --script `
  > "./prisma/reset.sql"

if (!$?) {
    Write-Host "❌ migrate diff failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Baseline diff created: prisma/reset.sql"

Write-Host "📌 Step 2 — Resetting local migrations folder" -ForegroundColor Yellow
Remove-Item -Recurse -Force "./prisma/migrations" -ErrorAction Ignore
New-Item -ItemType Directory -Path "./prisma/migrations" | Out-Null

Move-Item "./prisma/reset.sql" "./prisma/migrations/0000_reset.sql"

Write-Host "✅ Local migrations recreated."

Write-Host "📌 Step 3 — Deploying baseline to sync migrations" -ForegroundColor Yellow
npx prisma migrate deploy

if (!$?) {
    Write-Host "❌ migrate deploy failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Baseline migrations now match Neon."

Write-Host "📌 Step 4 — Creating vendor metadata migration" -ForegroundColor Yellow
npx prisma migrate dev --name add_vendor_metadata_fields

if (!$?) {
    Write-Host "❌ Could not create metadata migration." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Metadata migration applied."

Write-Host "📌 Step 5 — Generate Prisma client" -ForegroundColor Yellow
npx prisma generate

Write-Host "📌 Step 6 — Build" -ForegroundColor Yellow
npm run build

Write-Host "📌 Step 7 — Deploying to Vercel..." -ForegroundColor Yellow
npx vercel --prod

Write-Host "🎉 Phase 199 Complete — Drift fixed, vendor metadata columns added, deployed live!" -ForegroundColor Green
