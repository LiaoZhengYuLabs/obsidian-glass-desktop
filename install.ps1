[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$UseStartupFolder,
    [switch]$SkipScheduledTask,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "配置文件不存在: $ConfigPath"
}

$installer = Join-Path $packageRoot 'src\Install-StartupKit.ps1'
$common = @{
    ConfigPath = $ConfigPath
    UseStartupFolder = $UseStartupFolder
    SkipScheduledTask = $SkipScheduledTask
}

if (-not $Apply) {
    Write-Host '安全预览模式：不会创建计划任务、快捷方式或启动任何组件。' -ForegroundColor Cyan
    & $installer @common -WhatIf
    Write-Host ''
    Write-Host '确认配置和依赖后，再运行：' -ForegroundColor Yellow
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\install.ps1 -Apply'
    exit 0
}

Write-Host '正在安装 Obsidian Glass Desktop 的当前用户启动入口。' -ForegroundColor Cyan
& $installer @common
Write-Host '安装完成。仅创建本工具自己的启动入口，状态和日志位于 %LOCALAPPDATA%\ObsidianGlassDesktop。' -ForegroundColor Green
