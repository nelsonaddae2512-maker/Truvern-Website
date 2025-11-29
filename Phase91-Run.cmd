@echo off
setlocal

REM Detect pwsh (PowerShell 7) first; fallback to Windows PowerShell
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Phase91-FinalDomainRepair-Safe.ps1" %* 2>&1 | tee "%~dp0logs\Phase91-run-%DATE:~-4%%DATE:~4,2%%DATE:~7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"
) else (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Phase91-FinalDomainRepair-Safe.ps1" %* 2>&1 | tee "%~dp0logs\Phase91-run-%DATE:~-4%%DATE:~4,2%%DATE:~7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"
)

echo.
echo [Done] Press any key to close...
pause >nul
