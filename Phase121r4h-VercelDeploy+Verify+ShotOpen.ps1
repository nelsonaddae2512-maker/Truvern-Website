# ========== Phase121r4h-VercelDeploy+Verify+ShotOpen.ps1 ==========
$ErrorActionPreference = "Stop"

function Log($msg){$ts=Get-Date -Format "HH:mm:ss";Write-Host "[$ts] $msg"}
function Ensure-LogsFolder{if(-not(Test-Path ".\logs")){New-Item -ItemType Directory -Path ".\logs"|Out-Null}}

function Get-BrowserPath{
  $candidates=@(
    "$Env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$Env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$Env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$Env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
  )
  foreach($p in $candidates){if(Test-Path $p){return $p}}
  return $null
}

function Capture-Screenshot($url,$outPath,$width=1440,$height=900){
  $browser=Get-BrowserPath
  if(-not$browser){Write-Warning "No Edge/Chrome found. Skipping screenshot.";return $false}
  $args="--headless --disable-gpu --hide-scrollbars --window-size=$width,$height --screenshot=`"$outPath`" `"$url`""
  Log("Capturing screenshot with: {0}" -f $browser)
  Start-Process -FilePath $browser -ArgumentList $args -Wait -WindowStyle Hidden
  return (Test-Path $outPath)
}

function Ensure-Vercel{
  $cmd=Get-Command vercel -ErrorAction SilentlyContinue
  if(-not$cmd){Log"Installing Vercel CLI...";npm install -g vercel|Out-Null;$cmd=Get-Command vercel}
  Log("Vercel CLI found at: {0}" -f $cmd.Source)
}

function Ensure-VercelLogin{
  try{$who=vercel whoami 2>$null}catch{$who=$null}
  if(-not$who){Log"Not logged in; launching login...";vercel login;$who=vercel whoami}
  Log("Logged in as: {0}" -f $who)
}

function Ensure-VercelLink{
  if(-not(Test-Path ".vercel")){
    Log"Linking project 'truvern'...";vercel link --yes --project truvern --scope nelson-addaes-projects
  }else{Log".vercel folder exists; already linked."}
}

function Run-Deploy{
  $ts=Get-Date -Format "yyyyMMdd-HHmmss";$log=".\\logs\\vercel-deploy-$ts.txt"
  Log"Deploying production build...";Start-Process -FilePath "cmd.exe" -ArgumentList "/c vercel --prod --yes > `"$log`" 2>&1" -Wait
  if(Test-Path $log){Log"Deployment complete. Showing last lines:";Get-Content $log -Tail 15}
  return $log
}

function Test-Url200($url,$timeoutSec=25){
  try{$r=Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 5 -TimeoutSec $timeoutSec
      return@{Url=$url;Code=$r.StatusCode;Ok=($r.StatusCode-eq200);ErrMsg=""}}
  catch{return@{Url=$url;Code="";Ok=$false;ErrMsg=$_.Exception.Message}}
}

# ---------- MAIN ----------
$project="C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $project
Ensure-LogsFolder;Ensure-Vercel;Ensure-VercelLogin;Ensure-VercelLink
Log"=== Phase121r4h: Truvern Deploy + Verify + Screenshot + Open ==="

if((Read-Host"Proceed with PRODUCTION deploy? (Y/N)")-notin@('Y','y')){return}
$deployLog=Run-Deploy

if((Read-Host"Run post-deploy HTTP checks? (Y/N)")-in@('Y','y')){
  Log"Running HTTP 200 checks..."
  $urls=@("https://truvern.com/","https://truvern.com/trust-network","https://truvern.com/vendors","https://truvern.com/reports/board")
  $results=@()
  foreach($u in $urls){
    $r=Test-Url200 -url $u
    if($r.Ok){Write-Host("OK   {0} -> 200" -f $u)-ForegroundColor Green}
    else{Write-Host("FAIL {0} -> {1} ({2})" -f $u,$r.Code,$r.ErrMsg)-ForegroundColor Red}
    $results+=$r
  }
  $ts=Get-Date -Format"yyyyMMdd-HHmmss";$logf=".\\logs\\route-verify-$ts.txt"
  $lines=@();foreach($r in $results){$code=if($r.Code){$r.Code}else{"ERR"};$msg=if($r.ErrMsg){$r.ErrMsg}else{""};$lines+="`t$($r.Url)`t$code`t$msg"}
  $lines|Set-Content -Path $logf -Encoding UTF8;Log("Verification log: $logf")
  $allOk=($results|Where-Object{-not$_.Ok}).Count-eq0
}else{$allOk=$false}

# ---------- Step 5 & 6 ----------
if((Read-Host"Capture screenshot of /reports/board now? (Y/N)")-in@('Y','y')){
  $ts=Get-Date -Format"yyyyMMdd-HHmmss";$png=".\\logs\\board-$ts.png";$url="https://truvern.com/reports/board"
  Log"Capturing screenshot of $url ...";Start-Sleep -Seconds 3
  if(Capture-Screenshot -url $url -outPath $png){
    Log("Screenshot saved: $png")
    # Step 6: Auto-open screenshot
    if(Test-Path $png){Start-Process $png;Log"Screenshot opened for review."}
  }else{Write-Warning"Screenshot capture failed."}
}else{Log"Skipped screenshot capture."}

Log"=== Phase121r4h complete ==="
# ==========================================================
