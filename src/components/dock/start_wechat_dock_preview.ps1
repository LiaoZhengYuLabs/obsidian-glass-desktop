$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$previewExe = "$projectFolder\WeChatDockPreview.exe"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = "$startupFolder\WeChatDockPreview.lnk"

if (-not (Test-Path -LiteralPath $previewExe)) {
    throw "WeChatDockPreview.exe was not found."
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = $previewExe
$shortcut.WorkingDirectory = $projectFolder
$shortcut.Description = "微信 Dock 实时预览"
$shortcut.Save()

if (-not (Get-Process -Name WeChatDockPreview -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $previewExe -WorkingDirectory $projectFolder
}

Write-Host "WeChat Dock live preview is running."
