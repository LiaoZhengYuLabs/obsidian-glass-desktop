$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& ($projectRoot + "\stop.ps1")

$startup = [Environment]::GetFolderPath("Startup")
$startupLink = $startup + "\Obsidian AI Workspace.lnk"
if (Test-Path -LiteralPath $startupLink) {
    Remove-Item -LiteralPath $startupLink -Force
}

$recentState = $projectRoot + "\state\recent-apps.csv"
if (Test-Path -LiteralPath $recentState) {
    Remove-Item -LiteralPath $recentState -Force
}

$appLayout = $projectRoot + "\state\app-layout.json"
if (Test-Path -LiteralPath $appLayout) {
    Remove-Item -LiteralPath $appLayout -Force
}

Write-Host "Obsidian AI Workspace runtime changes were restored." -ForegroundColor Green
Write-Host "No application, user file, MyDockFinder, Seelen UI, or Windows system file was removed."
