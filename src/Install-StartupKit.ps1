[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ConfigPath,
    [switch]$UseStartupFolder,
    [switch]$SkipScheduledTask
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\StartupKit.Common.ps1')

$packageRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}
$configFullPath = Resolve-KitPath -Path $ConfigPath -BasePath $packageRoot
$config = Read-KitConfig -Path $configFullPath
$taskName = [string](Get-KitProperty -Object $config -Name 'taskName' -DefaultValue 'Obsidian Glass Desktop')

if (!(Test-KitTaskName -TaskName $taskName)) {
    throw 'Task name contains unsupported characters.'
}

$useTask = [bool](Get-KitProperty -Object $config -Name 'useScheduledTask' -DefaultValue $true)
$useShortcut = [bool](Get-KitProperty -Object $config -Name 'useStartupFolderShortcut' -DefaultValue $false)
if ($UseStartupFolder) {
    $useShortcut = $true
}
if ($SkipScheduledTask) {
    $useTask = $false
}
if (!$useTask -and !$useShortcut) {
    throw 'The profile disables both the scheduled task and Startup-folder shortcut.'
}

$stateRoot = Get-KitStateRoot -Ensure:(!$WhatIfPreference)
$backupRoot = Join-Path $stateRoot 'backups'
$launcher = Join-Path $PSScriptRoot 'Start-DesktopSession.ps1'
$powershell = Get-KitPowerShellPath
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$installState = [ordered]@{
    TaskName = $taskName
    ConfigPath = $configFullPath
    LauncherPath = $launcher
    InstalledAt = (Get-Date).ToString('o')
    TaskBackupPath = $null
    StartupShortcutPath = $null
    TaskCreated = $false
    ShortcutCreated = $false
}

if ($WhatIfPreference) {
    Write-Host "What if: prepare installation for task '$taskName'."
}
else {
    Write-KitLog -Message "Preparing installation for task '$taskName'."
}

if ($useTask) {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $existingTask -and !$WhatIfPreference) {
        $backupPath = Join-Path $backupRoot (($taskName -replace '[^A-Za-z0-9._-]', '_') + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')
        Export-ScheduledTask -TaskName $taskName | Set-Content -LiteralPath $backupPath -Encoding UTF8
        $installState.TaskBackupPath = $backupPath
        Write-KitLog -Message "Backed up existing task to '$backupPath'."
    }
    elseif ($null -ne $existingTask) {
        Write-Host "What if: back up existing task '$taskName'."
    }

    if ($PSCmdlet.ShouldProcess($taskName, 'Register scheduled task')) {
        $actionText = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}"' -f $launcher, $configFullPath
        $action = New-ScheduledTaskAction -Execute $powershell -Argument $actionText -WorkingDirectory $packageRoot
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
        $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType InteractiveToken -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        $installState.TaskCreated = $true
        Write-KitLog -Message "Registered scheduled task '$taskName'."
    }
}

if ($useShortcut) {
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder 'Obsidian Glass Desktop.lnk'
    if ($PSCmdlet.ShouldProcess($shortcutPath, 'Create Startup-folder shortcut')) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $powershell
        $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}"' -f $launcher, $configFullPath
        $shortcut.WorkingDirectory = $packageRoot
        $shortcut.WindowStyle = 7
        $shortcut.Description = 'Obsidian Glass Desktop'
        $shortcut.Save()
        $installState.StartupShortcutPath = $shortcutPath
        $installState.ShortcutCreated = $true
        Write-KitLog -Message "Created Startup-folder shortcut '$shortcutPath'."
    }
}

if ($WhatIfPreference) {
    Write-Host 'What if: installation metadata would be saved outside the source tree.'
    Write-Host 'What if: no system core files or personal files would be changed.'
}
else {
    Write-KitJson -Object $installState -Path (Get-KitInstallStatePath)
    Write-KitLog -Message 'Installation metadata saved outside the source tree.'
    Write-Host 'Startup kit installation finished. No system core files or personal files were changed.'
}
