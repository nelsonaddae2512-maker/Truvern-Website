Write-Host "Starting Vercel environment sync..." -ForegroundColor Cyan

function Get-FirstPath($cmd) {
  try { $found = & where.exe $cmd 2>$null; if ($LASTEXITCODE -eq 0 -and $found) { return ($found -split "`r?`n")[0].Trim() } }
  catch {}
  $gc = Get-Command $cmd -ErrorAction SilentlyContinue
  if ($gc) { return $gc.Source }
  return $null
}

function Read-DotEnv($file) {
  if (-not (Test-Path $file)) { throw "❌ .env not found at $file" }
  $map = @{}
  Get-Content $file | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $k = $line.Substring(0,$idx).Trim()
    $v = $line.Substring($idx+1).Trim()
    if(($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
      $v = $v.Substring(1, $v.Length-2)
    }
    $map[$k] = $v
  }
  return $map
}

function Add-VercelEnv {
  param([string]$Name,[string]$Target,[string]$Value,[string]$NpxPath)
  Write-Host ("→ Setting {0} for {1}..." -f $Name, $Target) -ForegroundColor Cyan
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c echo $Value | `"$NpxPath`" vercel env add $Name $Target"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $proc = [System.Diagnostics.Process]::Start($psi)
  $out = $proc.StandardOutput.ReadToEnd()
  $err = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()
  if ($proc.ExitCode -ne 0) {
    Write-Host $out -ForegroundColor DarkGray
    Write-Host $err -ForegroundColor Red
    throw ("❌ Failed setting {0} for {1} (exit {2})" -f $Name,$Target,$proc.ExitCode)
  } else {
    Write-Host ("✓ {0} stored for {1}" -f $Name,$Target) -ForegroundColor Green
  }
}

$envMap = Read-DotEnv ".\.env"
$need = @("DATABASE_URL","DIRECT_DATABASE_URL","SHADOW_DATABASE_URL")
foreach($k in $need){ if(-not $envMap.ContainsKey($k)) { throw "❌ Missing $k" } }

$npx = Get-FirstPath "npx.cmd"
if (-not $npx) { $npx = Get-FirstPath "npx" }
if (-not $npx) { throw "❌ Node.js not found. Install Node.js LTS." }

Write-Host "Linking Vercel project..." -ForegroundColor DarkCyan
Start-Process -FilePath $npx -ArgumentList @("vercel","link","--yes") -NoNewWindow -Wait

foreach($n in $need){ Add-VercelEnv -Name $n -Target "production" -Value $envMap[$n] -NpxPath $npx }
foreach($n in $need){ Add-VercelEnv -Name $n -Target "preview" -Value $envMap[$n] -NpxPath $npx }

Write-Host "✅ All done syncing environment variables!" -ForegroundColor Green