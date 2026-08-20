$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectFolder)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$dockFolder = Get-ObsidianGlassDockRoot
if ([string]::IsNullOrWhiteSpace($dockFolder)) { throw "MyDockFinder was not found." }
$pointerFile = "$projectFolder\backups\latest-wechat-preview.txt"

if (-not (Test-Path -LiteralPath $pointerFile)) {
    throw "No WeChat preview backup was found."
}

$backupFolder = [System.IO.File]::ReadAllText($pointerFile).Trim()
& "$projectFolder\stop_wechat_preview_guard.ps1"
Get-Process -Name WeChatDockPreview -ErrorAction SilentlyContinue | Stop-Process -Force
$previewStartup = Join-Path ([Environment]::GetFolderPath("Startup")) "WeChatDockPreview.lnk"
if (Test-Path -LiteralPath $previewStartup) {
    Remove-Item -LiteralPath $previewStartup -Force
}
foreach ($name in @("ico.ini", "ico_bak.ini")) {
    $source = "$backupFolder\$name"
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Backup file not found: $source"
    }
    Copy-Item -LiteralPath $source -Destination "$dockFolder\$name" -Force
}

$shortcutBackup = "$backupFolder\wechat.lnk"
if (Test-Path -LiteralPath $shortcutBackup) {
    $shortcutRoot = Join-Path $env:USERPROFILE "AppShortcuts\DockLaunchers"
    New-Item -ItemType Directory -Path $shortcutRoot -Force | Out-Null
    Copy-Item -LiteralPath $shortcutBackup -Destination (Join-Path $shortcutRoot "wechat.lnk") -Force
}

Write-Host "The previous WeChat Dock mapping has been restored."
