# Phase85a-EnvPushFix.ps1 - reusable env setter + deploy helpers
function Get-VercelPath {
  try { return (Get-Command vercel -ErrorAction Stop).Source } catch {
    Write-Host "Installing Vercel CLI globally..." -ForegroundColor Yellow
    npm i -g vercel | Out-Host
    return (Get-Command vercel -ErrorAction Stop).Source
  }
}
function Set-VercelEnv {
  param([string]$Name,[string]$Value,[string]$Target='production',[string]$Token=$env:VERCEL_TOKEN)
  $vercelPath = Get-VercelPath
  $rm = "`"$vercelPath`" env rm $Name $Target -y"
  if ($Token) { $rm += " --token $Token" }
  cmd.exe /c "$rm >NUL 2>&1"
  $add = "echo $Value | `"$vercelPath`" env add $Name $Target"
  if ($Token) { $add += " --token $Token" }
  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $add" -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "Failed to set env $Name (Exit $($p.ExitCode))" }
  Write-Host "✓ Vercel env set: $Name"
}
