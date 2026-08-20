[CmdletBinding()]
param([switch]$Preview)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$stopper = Join-Path $packageRoot 'src\Stop-DesktopSession.ps1'
$restorer = Join-Path $packageRoot 'src\Restore-StartupKit.ps1'

if ($Preview) {
    Write-Host '恢复预览：不会停止进程、删除启动入口或修改任务。' -ForegroundColor Cyan
    & $stopper -WhatIf
    & $restorer -WhatIf
    exit 0
}

Write-Host '正在停止本工具记录的组件并移除本工具创建的启动入口。' -ForegroundColor Cyan
& $stopper
& $restorer
Write-Host '恢复完成。不会删除软件、个人文件、壁纸或第三方配置。' -ForegroundColor Green
