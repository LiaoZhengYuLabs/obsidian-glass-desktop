[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Preview,
    [switch]$RestorePreviousTask
)

$ErrorActionPreference = 'Stop'
$taskName = 'Obsidian Glass Desktop - Current'
$stateRoot = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop\startup-current'
$statePath = Join-Path $stateRoot 'install-state.json'

if (!(Test-Path -LiteralPath $statePath -PathType Leaf)) {
    Write-Host 'No current startup state was found; nothing to restore.' -ForegroundColor Yellow
    exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$shortcutPath = [string]$state.StartupShortcutPath
$backupPath = [string]$state.TaskBackupPath

if ($Preview) {
    Write-Host 'Preview mode: no task, shortcut, or previous task will be changed.' -ForegroundColor Cyan
    Write-Host ('Task to inspect: ' + $taskName)
    Write-Host ('Shortcut to inspect: ' + $shortcutPath)
    exit 0
}

if ($null -ne $task -and $PSCmdlet.ShouldProcess($taskName, 'Unregister owned scheduled task')) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

if (![string]::IsNullOrWhiteSpace($shortcutPath) -and (Test-Path -LiteralPath $shortcutPath -PathType Leaf) -and $PSCmdlet.ShouldProcess($shortcutPath, 'Remove owned Startup shortcut')) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

if ($RestorePreviousTask -and ![string]::IsNullOrWhiteSpace($backupPath) -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    if ($PSCmdlet.ShouldProcess($taskName, 'Restore backed-up scheduled task')) {
        Register-ScheduledTask -TaskName $taskName -Xml (Get-Content -LiteralPath $backupPath -Raw -Encoding Unicode) -Force | Out-Null
    }
}

Remove-Item -LiteralPath $statePath -Force
Write-Host 'Current startup entry restored. Installed software, personal files, and third-party settings were not deleted.' -ForegroundColor Green
