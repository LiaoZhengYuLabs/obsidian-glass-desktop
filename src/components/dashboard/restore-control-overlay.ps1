$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$disabledFlag = $projectRoot + "\data\control-overlay-disabled.flag"
$stopScript = $projectRoot + "\stop-control-overlay.ps1"

if (Test-Path -LiteralPath $stopScript) {
    & $stopScript
}

if (!(Test-Path -LiteralPath ($projectRoot + "\data"))) {
    New-Item -ItemType Directory -Path ($projectRoot + "\data") -Force | Out-Null
}

Set-Content -LiteralPath $disabledFlag -Value "Custom overlay disabled; Windows native OSD remains unchanged." -Encoding UTF8
Write-Host "已恢复为 Windows 原生音量/亮度提示。" -ForegroundColor Green
Write-Host "未修改系统核心文件、注册表、壁纸或桌面组件。"
Write-Host "需要重新启用时运行：powershell -ExecutionPolicy Bypass -File .\start-control-overlay.ps1 -Enable"
