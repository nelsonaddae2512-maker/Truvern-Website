$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') { Write-Host "cd into your project folder first." -ForegroundColor Red; exit 1 }

# Clean caches, build locally
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

if (Get-Command pnpm -ErrorAction SilentlyContinue) { pnpm install --frozen-lockfile; pnpm run build }
elseif (Get-Command npm -ErrorAction SilentlyContinue) { npm ci; npm run build }
elseif (Get-Command yarn -ErrorAction SilentlyContinue) { yarn install --frozen-lockfile; yarn build }

# Deploy prebuilt to prod
vercel build
vercel deploy --prebuilt --prod

# Quick OG/Canonical verification on prod
$Base="https://truvern.com"
$paths=@("/","/trust-network","/reports/board","/vendors")
"{0,-16}{1,6}{2,-12}{3,-60}" -f "Path","HTTP","OG","Canonical"
foreach($p in $paths){
  $u="$Base$p"
  try{
    $h=(Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 20)
    $html=$h.Content
    $og=[regex]::Match($html,'<meta[^>]+property=["'']og:image["''][^>]+content=["''](.*?)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase).Groups[1].Value
    $can=[regex]::Match($html,'<link[^>]+rel=["'']canonical["''][^>]+href=["''](.*?)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase).Groups[1].Value
    "{0,-16}{1,6}{2,-12}{3,-60}" -f $p,$h.StatusCode,($(if($og){"Found"}else{"Missing"})),$can
  }catch{
    "{0,-16}{1,6}{2,-12}{3,-60}" -f $p,0,"Error",""
  }
}
