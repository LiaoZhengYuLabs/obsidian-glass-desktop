$ErrorActionPreference = 'Stop'

$statePath = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop\media-progress-state.json'
$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
}
Get-Process DockMediaProgress -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if ($null -ne $state -and $state.shortcutPath -and (Test-Path -LiteralPath ([string]$state.shortcutPath) -PathType Leaf)) {
    Remove-Item -LiteralPath ([string]$state.shortcutPath) -Force
}

if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    Remove-Item -LiteralPath $statePath -Force
}

Write-Output 'Dock 媒体进度状态层已移除。未修改 Docker、注册表、系统设置或其他应用的开机自启。'
