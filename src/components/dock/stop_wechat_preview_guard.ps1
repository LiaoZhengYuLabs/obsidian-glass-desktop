$ErrorActionPreference = "Stop"

$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = "$startupFolder\WeChatPreviewGuard.lnk"

Get-Process -Name WeChatPreviewGuard -ErrorAction SilentlyContinue | Stop-Process
if (Test-Path -LiteralPath $startupShortcut) {
    Remove-Item -LiteralPath $startupShortcut -Force
}

Write-Host "WeChat preview guard is stopped."

