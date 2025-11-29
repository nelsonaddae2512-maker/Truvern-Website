Set-ExecutionPolicy -Scope Process Bypass -Force
Set-Content -Path .\Phase61c-RunSeedDemo.ps1 -Value (Get-Clipboard) -Encoding UTF8  # or paste manually into a ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Phase61c-RunSeedDemo.ps1

