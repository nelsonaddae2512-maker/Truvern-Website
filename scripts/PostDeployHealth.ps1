param(
  [string]$BaseUrl = "https://truvern.com",
  [int]$Retries = 3,
  [int]$DelaySec = 5
)
$ErrorActionPreference="Continue"
function PingUrl($u){
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 12 -Uri $u
    return @{ ok = ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400); code = $r.StatusCode; err = $null }
  } catch { return @{ ok = $false; code = -1; err = $_.Exception.Message } }
}
$ops = $null; $api = $null
for($i=1; $i -le $Retries; $i++){
  $ops = PingUrl("$BaseUrl/ops/health")
  $api = PingUrl("$BaseUrl/api/health")
  if($ops.ok -and $api.ok){ break }
  Start-Sleep -Seconds $DelaySec
}
[pscustomobject]@{
  base   = $BaseUrl
  ops_ok = [bool]$ops.ok;  ops_code = $ops.code;  ops_err = $ops.err
  api_ok = [bool]$api.ok;  api_code = $api.code;  api_err = $api.err
}
