$Domain = "truvern.com"
$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) {
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}

if ($deployed) {
  vercel alias set $deployed $Domain        | Out-Null
  vercel alias set $deployed ("www."+$Domain) | Out-Null
  Write-Host ("Aliased {0} to {1}" -f $Domain,$deployed) -ForegroundColor Green
}

$base = "https://$Domain"
[string[]]$urls = @(
  "$base/",
  "$base/trust-network",
  "$base/api/board",
  "$base/api/vendors"
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host ("OK {0} -> HTTP {1}" -f $u, $r.StatusCode) -ForegroundColor Green
  } catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow }
    else    { Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red }
  }
}
