$ErrorActionPreference = "SilentlyContinue"
Get-Process -Name "SeelenLivePreview" | Stop-Process
Write-Host "Seelen horizontal live preview is stopped."
