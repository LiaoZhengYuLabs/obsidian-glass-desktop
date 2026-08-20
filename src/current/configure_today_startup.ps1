$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$orchestrator = $projectRoot + "\startup_optimized.ps1"
$taskName = "Obsidian Desktop Fast Startup"
$startupFolder = [Environment]::GetFolderPath("Startup")
$backupRoot = $projectRoot + "\StartupBackups"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFolder = $backupRoot + "\today-startup-" + $stamp
$pointerPath = $backupRoot + "\latest.txt"
$logFolder = $projectRoot + "\logs"
$logPath = $logFolder + "\configure-startup.log"

New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

function Write-ConfigureLog {
    param([string]$Message)
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $Message
    [IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
}

if (!(Test-Path -LiteralPath $orchestrator)) {
    throw "startup_optimized.ps1 is missing."
}

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Export-ScheduledTask -TaskName $taskName | Out-File -LiteralPath ($backupFolder + "\scheduled-task.xml") -Encoding Unicode
    Write-ConfigureLog "Existing scheduled task exported."
}

$powerShell = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $orchestrator + '"'
$action = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments -WorkingDirectory $projectRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-ConfigureLog "Unified logon task registered."

$legacyEntries = @(
    "SonomaAI Music Visualizer.vbs",
    "WeChatDockDot.lnk",
    "Obsidian Dock Media Progress.lnk"
)
foreach ($name in $legacyEntries) {
    $source = $startupFolder + "\" + $name
    if (Test-Path -LiteralPath $source) {
        Move-Item -LiteralPath $source -Destination ($backupFolder + "\" + $name) -Force
        Write-ConfigureLog ("Moved duplicate startup entry to backup: " + $name)
    }
}

$rainmeter = "C:\Program Files\Rainmeter\Rainmeter.exe"
if (Test-Path -LiteralPath $rainmeter) {
    & $rainmeter "!DeactivateConfig" "SonomaAI\Music" | Out-Null
    Write-ConfigureLog "Standalone Rainmeter music skin deactivated."
}

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
[IO.File]::WriteAllText($pointerPath, $backupFolder, (New-Object Text.UTF8Encoding($false)))

Write-Host "今天的桌面功能已合并到统一开机任务。" -ForegroundColor Green
Write-Host ("备份位置：" + $backupFolder)
