@echo off
REM Always stay open (-NoExit) and run wrapper PS1
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0Run-UptimeCheck.ps1" -BaseUrl https://truvern.com
