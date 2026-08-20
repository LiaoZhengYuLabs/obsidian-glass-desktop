$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stopScript = $projectRoot + "\stop.ps1"
$startupLink = [Environment]::GetFolderPath("Startup") + "\Obsidian AI Desktop Dashboard.lnk"

if (Test-Path -LiteralPath $stopScript) { & $stopScript }
if (Test-Path -LiteralPath $startupLink) {
    Remove-Item -LiteralPath $startupLink -Force
    Write-Host "Dashboard startup shortcut removed." -ForegroundColor Green
}

Write-Host "Existing Dock, taskbar, wallpaper, shortcuts, Cine Gate and personal files were left unchanged."
Write-Host "Dashboard project and data were kept."
