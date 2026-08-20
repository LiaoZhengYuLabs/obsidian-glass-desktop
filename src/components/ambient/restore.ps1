$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = "$projectRoot\install-state.json"
if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Output '未找到安装状态，无需恢复。'
    exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
Get-Process DockMediaProgress -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if ($state.shortcutPath -and (Test-Path -LiteralPath $state.shortcutPath)) {
    Remove-Item -LiteralPath $state.shortcutPath -Force
}

if ($state.dockerBackup -and (Test-Path -LiteralPath $state.dockerBackup) -and $state.dockerSettings) {
    Copy-Item -LiteralPath $state.dockerBackup -Destination $state.dockerSettings -Force
}

if ($state.dockerStartupApprovedBackup) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    $bytes = [Convert]::FromBase64String([string]$state.dockerStartupApprovedBackup)
    Set-ItemProperty -LiteralPath $key -Name 'Docker Desktop' -Value $bytes -Type Binary
}

Write-Output 'Dock 媒体进度状态层已移除，Docker Desktop 原自启设置已恢复。'
