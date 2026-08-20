$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$guardExe = "$projectFolder\WeChatPreviewGuard.exe"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = "$startupFolder\WeChatPreviewGuard.lnk"

if (-not (Test-Path -LiteralPath $guardExe)) {
    throw "WeChatPreviewGuard.exe was not found."
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = $guardExe
$shortcut.WorkingDirectory = $projectFolder
$shortcut.Description = "微信 Dock 预览保护"
$shortcut.Save()

$runningGuard = Get-Process -Name WeChatPreviewGuard -ErrorAction SilentlyContinue
if (-not $runningGuard) {
    Start-Process -FilePath $guardExe -WorkingDirectory $projectFolder
}

Write-Host "WeChat preview guard is running."
