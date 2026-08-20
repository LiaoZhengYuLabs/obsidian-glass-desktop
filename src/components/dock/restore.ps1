$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

& ($projectRoot + "\stop.ps1")

$startupLink = [Environment]::GetFolderPath("Startup") + "\Obsidian AI Dock.lnk"
if (Test-Path -LiteralPath $startupLink) {
    Remove-Item -LiteralPath $startupLink -Force
}

foreach ($name in @("fixed-order.json", "recent-apps.json")) {
    $path = $projectRoot + "\state\" + $name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

Write-Host "Original MyDockFinder Dock is active again." -ForegroundColor Green
Write-Host "No application, launcher, MyDockFinder configuration, wallpaper, or personal file was removed."

