@echo off
setlocal
cd /d "%~dp0"
if not exist "logs" mkdir "logs"

set LOG=logs\Phase93-run-%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log
set LOG=%LOG: =0%  rem scrub spaces in timestamp

rem Prefer PowerShell 7 if installed
where pwsh >nul 2>nul && (set PS=pwsh) || (set PS=powershell)

echo Starting... > "%LOG%"

rem Open a new console that stays open (cmd /k) and run the script with a hard pause
start "Phase93" cmd /k ^
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-Location '%~dp0'; if(!(Test-Path '.\Phase93-ClientNullGuard-Clean.ps1')) { Write-Host 'Script not found'; pause; exit 1 }; try { . '.\Phase93-ClientNullGuard-Clean.ps1' *>&1 | Tee-Object '%LOG%'; } catch { Write-Host ('ERROR: ' + $_.Exception.Message); } finally { Write-Host '---'; Write-Host ('Log: %LOG%'); } & pause"
