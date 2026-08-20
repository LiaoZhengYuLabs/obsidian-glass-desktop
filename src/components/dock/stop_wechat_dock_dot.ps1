$ErrorActionPreference = "SilentlyContinue"

$startupFolder = [Environment]::GetFolderPath("Startup")
Remove-Item -LiteralPath "$startupFolder\WeChatDockDot.lnk" -Force
Get-Process -Name WeChatDockDot | Stop-Process -Force

Write-Host "WeChat dock dot stopped and removed from startup."
