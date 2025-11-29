# Phase121r3-ResultsFix-StartProc.ps1  — run prisma/vercel via Start-Process to avoid NativeCommandError
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $root) { Set-Location $root }

# logging
New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG = ".\logs\phase121r3-$stamp.log"
$OUT_PRISMA = ".\logs\phase121r3-prisma-$stamp.txt"
$OUT_VERCEL = ".\logs\phase121r3-vercel-$stamp.txt"

function Log([string]$m){ $m | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121r3 start ==="

if (-not (Test-Path ".\package.json")) { Log "ERROR: package.json missing"; throw "package.json missing" }

# 1) Ensure the results page type is fixed (leave as-is if you already patched)
$pagePath = Join-Path $root "app\assessment\results\page.tsx"
if (Test-Path $pagePath) {
  $txt = [IO.File]::ReadAllText($pagePath, [Text.Encoding]::UTF8)
  if ($txt -match 'searchParams\s*:\s*Promise') {
    $txt = $txt -replace 'searchParams\s*:\s*Promise\s*<\s*Record\s*<\s*string\s*,\s*string\s*>\s*>\s*',
                         'searchParams?: { [key: string]: string | string[] | undefined } '
    [IO.File]::WriteAllText($pagePath, $txt, [Text.Encoding]::UTF8)
    Log "Normalized searchParams typing in results page."
  }
}

# Small helper to run native commands safely and capture exit code without PS errors
function Run-Native {
  param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Args,
    [Parameter(Mandatory=$true)][string]$OutFile
  )
  if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = $Args
  $psi.WorkingDirectory = $root
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $null = $proc.Start()
  $stdout = $proc.StandardOutput.ReadToEnd()
  $stderr = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()

  # write combined output to file
  $stdout | Out-File -FilePath $OutFile -Encoding UTF8
  if ($stderr) { "`r`n--- STDERR ---`r`n$stderr" | Out-File -FilePath $OutFile -Encoding UTF8 -Append }

  return @{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

# 2) Prisma generate via cmd.exe (npx or local prisma.cmd), using Start-Process
$prismaCmd = if (Test-Path ".\node_modules\.bin\prisma.cmd") { ".\node_modules\.bin\prisma.cmd generate" } else { "npx prisma generate" }
Log ("Running prisma: {0}" -f $prismaCmd)
$pr = Run-Native -Exe "cmd.exe" -Args "/d /c $prismaCmd" -OutFile $OUT_PRISMA
Log ("Prisma exit code: {0}" -f $pr.ExitCode)
if ($pr.ExitCode -ne 0) {
  Log "ERROR: prisma failed. See $OUT_PRISMA"
  Write-Host "Prisma failed. Open $OUT_PRISMA"
  exit 1
}

# 3) Deploy using vercel (cloud build) via Start-Process
Log "Deploying with vercel --prod"
$vr = Run-Native -Exe "cmd.exe" -Args "/d /c vercel --prod" -OutFile $OUT_VERCEL
Log ("Vercel exit code: {0}" -f $vr.ExitCode)

# Try to parse deployment URL
$deploymentUrl = "(unknown)"
$allText = ($vr.StdOut + "`n" + $vr.StdErr)
$matches = [Text.RegularExpressions.Regex]::Matches($allText,'https?://\S+')
foreach ($m in $matches) {
  if ($m.Value -like "*.vercel.app*") { $deploymentUrl = $m.Value; break }
}
Log ("Deployment URL: {0}" -f $deploymentUrl)

# 4) Verify public routes
$urls = @(
  "https://truvern.com/",
  "https://truvern.com/trust-network",
  "https://truvern.com/vendors",
  "https://truvern.com/reports/board"
)
Log "--- HTTP 200 verification ---"
$all200 = $true
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 25
    Log ("{0} -> {1}" -f $u, $r.StatusCode)
    if ($r.StatusCode -ne 200) { $all200 = $false }
  } catch {
    Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
    $all200 = $false
  }
}

Log "=== Summary ==="
Log ("Deployment URL: {0}" -f $deploymentUrl)
Log ("All key routes HTTP 200: {0}" -f ($(if($all200){"YES"}else{"NO"})))
Log ("Log saved: {0}" -f $LOG)
Write-Host ""
Write-Host ("Done. Prisma log: {0}" -f $OUT_PRISMA)
Write-Host ("Done. Vercel log:  {0}" -f $OUT_VERCEL)
Write-Host ("Full script log:  {0}" -f $LOG)
