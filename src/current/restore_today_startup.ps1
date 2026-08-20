$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupRoot = $projectRoot + "\StartupBackups"
$pointerPath = $backupRoot + "\latest.txt"
$startupFolder = [Environment]::GetFolderPath("Startup")
$taskName = "Obsidian Desktop Fast Startup"

if (!(Test-Path -LiteralPath $pointerPath)) {
    throw "No startup backup pointer was found."
}

$backupFolder = [IO.File]::ReadAllText($pointerPath, [Text.Encoding]::UTF8).Trim()
if (!(Test-Path -LiteralPath $backupFolder)) {
    throw "Startup backup folder is missing: $backupFolder"
}

foreach ($name in @("SonomaAI Music Visualizer.vbs", "WeChatDockDot.lnk", "Obsidian Dock Media Progress.lnk")) {
    $source = $backupFolder + "\" + $name
    if (Test-Path -LiteralPath $source) {
        Move-Item -LiteralPath $source -Destination ($startupFolder + "\" + $name) -Force
    }
}

$taskXml = $backupFolder + "\scheduled-task.xml"
if (Test-Path -LiteralPath $taskXml) {
    Register-ScheduledTask -TaskName $taskName -Xml ([IO.File]::ReadAllText($taskXml)) -Force | Out-Null
}

Get-Process -Name "ObsidianSoundCloudPlayer" -ErrorAction SilentlyContinue | Stop-Process
$rainmeter = "C:\Program Files\Rainmeter\Rainmeter.exe"
if (Test-Path -LiteralPath $rainmeter) {
    & $rainmeter "!ActivateConfig" "SonomaAI\Music" "Music.ini" | Out-Null
}

Write-Host "已恢复本次修改前的分散启动入口。" -ForegroundColor Green
