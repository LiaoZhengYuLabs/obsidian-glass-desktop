$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$dotExe = "$projectFolder\WeChatDockDot.exe"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = "$startupFolder\WeChatDockDot.lnk"

if (-not (Test-Path -LiteralPath $dotExe)) {
    throw "WeChatDockDot.exe was not found."
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = $dotExe
$shortcut.WorkingDirectory = $projectFolder
$shortcut.Description = "微信 Dock 运行黑点"
$shortcut.Save()

$runningDot = Get-Process -Name WeChatDockDot -ErrorAction SilentlyContinue
if (-not $runningDot) {
    Start-Process -FilePath $dotExe -WorkingDirectory $projectFolder
}

Write-Host "WeChat dock dot is running."
