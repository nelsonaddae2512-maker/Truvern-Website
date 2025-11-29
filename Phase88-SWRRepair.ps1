Write-Host "== Phase 88 already complete. Re-verifying Stripe endpoints ==" -ForegroundColor Cyan
Invoke-WebRequest https://truvern.com/api/stripe/checkout -UseBasicParsing
Invoke-WebRequest https://truvern.com/api/stripe/portal?cid=fake -UseBasicParsing
Write-Host "Verification run done." -ForegroundColor Green
