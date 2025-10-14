$ErrorActionPreference = "Stop"

function Find-Exe([string[]]$names) {
  foreach($n in $names){
    # Common global locations
    $candidates = @(
      (Get-Command $n -ErrorAction SilentlyContinue | Select -Expand Source -ErrorAction SilentlyContinue),
      "$env:APPDATA\npm\$n",
      "$env:APPDATA\npm\$($n.TrimEnd('.exe')).cmd",
      "$env:ProgramFiles\Git\cmd\git.exe",
      "$env:ProgramFiles(x86)\Git\cmd\git.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    if($candidates){ return $candidates[0] }
  return $null
}

function Run([string]$exe, [string]$args) {
  Write-Host "`n> Running: $exe $args" -ForegroundColor Cyan

  # Normalize quoted paths
  if ($exe -match "^\s*[""']?([A-Za-z]:\\.+?)[""']?\s*$") {
    $exe = $Matches[1]
  }

  if (-not (Test-Path $exe)) {
    throw "File not found: $exe"
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = $args
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($out) { Write-Host $out.Trim() }
  if ($p.ExitCode -ne 0) {
    if ($err) { Write-Host $err -ForegroundColor Red }
    throw "Command failed (exit $($p.ExitCode)): $exe $args"
  }
}
  if($p.ExitCode -ne 0){
    if($err){ Write-Host $err -ForegroundColor Red }
    throw "Command failed (exit $($p.ExitCode)): $exe $args"
  }
}

# --- tools ---
$git  = Find-Exe @("git.exe","git")
if(-not $git){ throw "git.exe not found. Install Git for Windows." }

# Prefer vercel.cmd if installed globally; else use npx vercel
$vercel = Find-Exe @("vercel.cmd","vercel.exe","vercel")
$npx    = Find-Exe @("npx.cmd","npx.exe","npx")

if(-not $vercel -and -not $npx){ throw "Neither vercel nor npx found. Install Node.js LTS and Vercel CLI." }

function Vercel([string]$args){
  if($env:VERCEL_TOKEN){ $args = "$args --token `"$($env:VERCEL_TOKEN)`"" }
  if($vercel){ Run $vercel $args } else { Run $npx "vercel $args" }
}

# --- 1) Pull envs from Vercel -> .env.local ---
Write-Host "`n=== Pulling envs from Vercel ===" -ForegroundColor Yellow
Vercel "env pull `".env.local`" --environment production"

# Ensure .env exists (Next/Prisma read .env first; keep .env.local for Next runtime)
if(-not (Test-Path ".env")){
  Copy-Item ".env.local" ".env"
  Write-Host "Created .env from .env.local" -ForegroundColor Green
} else {
  Write-Host ".env already exists (leaving as-is)" -ForegroundColor DarkGray
}

# --- 2) Prisma (if schema present) ---
if(Test-Path "prisma\schema.prisma"){
  Write-Host "`n=== Prisma generate & push ===" -ForegroundColor Yellow
  if(-not $npx){ throw "npx not found; required for Prisma." }
  Run $npx "prisma generate"
  Run $npx "prisma db push"
  if(Test-Path "prisma\seed.ts" -or Test-Path "prisma\seed.js"){
    Write-Host "Seeding database..." -ForegroundColor DarkCyan
    Run $npx "prisma db seed"
  } else {
    Write-Host "No prisma seed script found (skipping)." -ForegroundColor DarkGray
  }
} else {
  Write-Host "No prisma\schema.prisma found (skipping Prisma step)." -ForegroundColor DarkGray
}

# --- 3) Commit changes (only if dirty) & push ---
Write-Host "`n=== Commit & push (if changes) ===" -ForegroundColor Yellow
$dirty = & $git status --porcelain
if($LASTEXITCODE -ne 0){ throw "git status failed" }
if($dirty){
  Run $git "add -A"
  $msg = "chore: deploy $(Get-Date -Format s)"
  Run $git "commit -m `"$msg`""
  # ensure main exists locally; if not, default to current branch
  $branch = (& $git rev-parse --abbrev-ref HEAD).Trim()
  if(-not $branch){ $branch = "main" }
  Run $git "push origin $branch"
}else{
  Write-Host "No local changes to commit." -ForegroundColor DarkGray
}

# --- 4) Trigger production deploy ---
Write-Host "`n=== Vercel production deploy ===" -ForegroundColor Yellow
Vercel "--prod"

Write-Host "`nAll done " -ForegroundColor Green
