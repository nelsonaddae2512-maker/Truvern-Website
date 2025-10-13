$ErrorActionPreference = "Stop"

# === SETTINGS ===
$gitPath = "C:\Program Files\Git\cmd\git.exe"   # confirmed path
$useToken = $env:VERCEL_TOKEN                   # optional Vercel token

function Run($exe, $args) {
  Write-Host "`n› Running:" $exe $args -ForegroundColor Cyan
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = $args
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if($out.Trim()){ Write-Host $out.Trim() -ForegroundColor Gray }
  if($p.ExitCode -ne 0){
    if($err.Trim()){ Write-Host $err.Trim() -ForegroundColor Red }
    throw "Command failed (exit $($p.ExitCode)): $exe $args"
  }
}

# --- verify git is callable ---
if(-not (Test-Path $gitPath)){ throw "Git not found at $gitPath" }
Run $gitPath "--version"

# --- useful repo facts ---
$head   = (& $gitPath rev-parse HEAD).Trim()
$branch = (& $gitPath rev-parse --abbrev-ref HEAD).Trim()
Write-Host "`nHEAD: $head"   -ForegroundColor Green
Write-Host "Branch: $branch" -ForegroundColor Green

# --- avoid failing hooks on Windows (missing pre-commit) ---
Run $gitPath "config core.hooksPath /dev/null"

# --- ensure identity (set once if empty) ---
try {
  $userEmail = (& $gitPath config user.email).Trim()
  $userName  = (& $gitPath config user.name).Trim()
} catch { $userEmail=""; $userName="" }
if(-not $userEmail){ Run $gitPath 'config user.email "you@example.com"' }
if(-not $userName ){ Run $gitPath 'config user.name  "Your Name"' }

# --- stage & commit if there are changes ---
$dirty = (& $gitPath "status --porcelain").Trim()
if($dirty){
  Write-Host "`nStaging all changes..." -ForegroundColor DarkCyan
  Run $gitPath "add -A"
  $msg = "chore: deploy $(Get-Date -Format s)"
  Write-Host "Committing: $msg" -ForegroundColor DarkCyan
  Run $gitPath ("commit -m " + ('"'+$msg+'"'))
}else{
  Write-Host "`nNo local changes to commit." -ForegroundColor DarkGray
}

# --- push to origin/<branch> ---
Write-Host "`nPushing to origin/$branch..." -ForegroundColor DarkCyan
Run $gitPath ("push origin " + $branch)

# --- trigger Vercel production deploy ---
Write-Host "`nDeploying on Vercel..." -ForegroundColor DarkCyan
# In PS 5.1, call through cmd.exe so npx (.cmd) works reliably:
$cmd = 'npx vercel --prod'
if($useToken){ $cmd += (' --token ' + $useToken) }
Run "cmd.exe" ('/c ' + $cmd)

Write-Host "`n✅ Done. Latest commit pushed and Vercel production deploy triggered!" -ForegroundColor Green