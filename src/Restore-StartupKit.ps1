[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RestorePreviousTask
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\StartupKit.Common.ps1')

$statePath = Get-KitInstallStatePath
if (!(Test-Path -LiteralPath $statePath -PathType Leaf)) {
    Write-KitLog -Message 'No installation state was found; nothing to restore.' -Level 'WARN'
    exit 0
}

$state = (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json)
$taskName = [string](Get-KitProperty -Object $state -Name 'TaskName' -DefaultValue '')
$task = $null
if (![string]::IsNullOrWhiteSpace($taskName)) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

if ($null -ne $task -and $PSCmdlet.ShouldProcess($taskName, 'Unregister owned scheduled task')) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-KitLog -Message "Unregistered task '$taskName'."
}

$shortcutPath = [string](Get-KitProperty -Object $state -Name 'StartupShortcutPath' -DefaultValue '')
if (![string]::IsNullOrWhiteSpace($shortcutPath) -and (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
    if ($PSCmdlet.ShouldProcess($shortcutPath, 'Remove owned Startup-folder shortcut')) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-KitLog -Message "Removed owned shortcut '$shortcutPath'."
    }
}

$backupPath = [string](Get-KitProperty -Object $state -Name 'TaskBackupPath' -DefaultValue '')
if ($RestorePreviousTask -and ![string]::IsNullOrWhiteSpace($backupPath) -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    if ($PSCmdlet.ShouldProcess($taskName, 'Restore backed-up scheduled task XML')) {
        $xml = Get-Content -LiteralPath $backupPath -Raw -Encoding UTF8
        Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
        Write-KitLog -Message "Restored previous task from '$backupPath'."
    }
}

if ($PSCmdlet.ShouldProcess($statePath, 'Remove startup kit installation state')) {
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Write-KitLog -Message 'Startup kit restore completed. Personal files and installed software were not touched.'
}
