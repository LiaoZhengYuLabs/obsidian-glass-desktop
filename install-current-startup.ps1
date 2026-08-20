[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [switch]$UseStartupFolder,
    [switch]$SkipScheduledTask
)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$taskName = 'Obsidian Glass Desktop - Current'
$launcher = Join-Path $packageRoot 'start-current.ps1'
$stateRoot = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop\startup-current'
$backupRoot = Join-Path $stateRoot 'backups'
$statePath = Join-Path $stateRoot 'install-state.json'

if (!(Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Current launcher is missing: $launcher"
}

if (!$Apply) {
    Write-Host 'Preview mode: no task, shortcut, or component will be created.' -ForegroundColor Cyan
    Write-Host ('Task name: ' + $taskName)
    Write-Host ('Launcher: ' + $launcher)
    Write-Host 'To apply the current startup entry:' -ForegroundColor Yellow
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\install-current-startup.ps1 -Apply'
    exit 0
}

$useTask = !$SkipScheduledTask
$useShortcut = [bool]$UseStartupFolder
if (!$useTask -and !$useShortcut) {
    throw 'No startup entry selected. Remove -SkipScheduledTask or add -UseStartupFolder.'
}

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$taskBackupPath = $null
if ($null -ne $existingTask) {
    $taskBackupPath = Join-Path $backupRoot ('task-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')
    Export-ScheduledTask -TaskName $taskName | Set-Content -LiteralPath $taskBackupPath -Encoding Unicode
}

$powerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$argumentText = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $launcher + '"'
$shortcutPath = $null

if ($useTask) {
    $action = New-ScheduledTaskAction -Execute $powerShell -Argument $argumentText -WorkingDirectory $packageRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType InteractiveToken -RunLevel Limited
    if ($PSCmdlet.ShouldProcess($taskName, 'Register current-user scheduled task')) {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    }
}

if ($useShortcut) {
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder 'Obsidian Glass Desktop - Current.lnk'
    if ($PSCmdlet.ShouldProcess($shortcutPath, 'Create current-user Startup shortcut')) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $powerShell
        $shortcut.Arguments = $argumentText
        $shortcut.WorkingDirectory = $packageRoot
        $shortcut.WindowStyle = 7
        $shortcut.Description = 'Obsidian Glass Desktop current snapshot'
        $shortcut.Save()
    }
}

$state = [ordered]@{
    TaskName = $taskName
    LauncherPath = $launcher
    InstalledAt = (Get-Date).ToString('o')
    TaskBackupPath = $taskBackupPath
    StartupShortcutPath = $shortcutPath
    TaskCreated = $useTask
    ShortcutCreated = $useShortcut
}
$state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding UTF8
Write-Host 'Current startup entry installed for the current user. No system core files were changed.' -ForegroundColor Green
Write-Host ('State file: ' + $statePath)
