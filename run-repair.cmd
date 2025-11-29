@echo off
setlocal
cd /d "C:\Users\MR.NELSON\Downloads\truvern"
REM Launch PowerShell in this folder, keep window open, bypass policy, and run the script
powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File ".\repair-build-and-deploy.ps1"
