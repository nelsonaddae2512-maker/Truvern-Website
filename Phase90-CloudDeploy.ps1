$ErrorActionPreference='Stop'
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"
vercel link --yes --project truvern --scope nelson-addaes-projects | Out-Null
npx prisma generate | Out-Null
vercel deploy --prod --yes
