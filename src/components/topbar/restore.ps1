$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$latestBackup = "$projectRoot\latest-backup.txt"
if (-not (Test-Path -LiteralPath $latestBackup)) { throw 'No Desktop Media Center backup record was found.' }
$backupRoot = [IO.File]::ReadAllText($latestBackup).Trim()
if (-not (Test-Path -LiteralPath $backupRoot)) { throw "Backup folder not found: $backupRoot" }

$seelenRoot = "$env:APPDATA\com.seelen.seelen-ui"
$toolbarPath = "$seelenRoot\data\seelen-fancy-toolbar\state.yml"
if (-not (Test-Path -LiteralPath $toolbarPath)) { $toolbarPath = "$seelenRoot\toolbar_items.yml" }
$baseToolbarPath = "$seelenRoot\profiles\base\toolbar.yml"
$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$installRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"

if (Test-Path -LiteralPath "$installRoot\media-center.pid") {
    $mediaPid = 0
    [void][int]::TryParse(([IO.File]::ReadAllText("$installRoot\media-center.pid").Trim()), [ref]$mediaPid)
    if ($mediaPid -gt 0) { Stop-Process -Id $mediaPid -Force -ErrorAction SilentlyContinue }
}

$seelen = Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue
if ($seelen) { $seelen | Stop-Process -Force; Start-Sleep -Seconds 2 }
$dock = Get-Process -Name 'Dock_64' -ErrorAction SilentlyContinue
if ($dock) { $dock | Stop-Process -Force; Start-Sleep -Seconds 2 }

$activeBackup = "$backupRoot\active-toolbar.yml"
if (-not (Test-Path -LiteralPath $activeBackup)) { $activeBackup = "$backupRoot\toolbar_items.yml" }
Copy-Item -LiteralPath $activeBackup -Destination $toolbarPath -Force
Copy-Item -LiteralPath "$backupRoot\base-toolbar.yml" -Destination $baseToolbarPath -Force
if (Test-Path -LiteralPath "$backupRoot\seelen-settings.json") {
    Copy-Item -LiteralPath "$backupRoot\seelen-settings.json" -Destination "$seelenRoot\settings.json" -Force
}
Copy-Item -LiteralPath "$backupRoot\mydock-config.ini" -Destination "$dockRoot\config.ini" -Force
if (Test-Path -LiteralPath "$backupRoot\ico.ini") { Copy-Item -LiteralPath "$backupRoot\ico.ini" -Destination "$dockRoot\ico.ini" -Force }
if (Test-Path -LiteralPath "$backupRoot\ico_bak.ini") { Copy-Item -LiteralPath "$backupRoot\ico_bak.ini" -Destination "$dockRoot\ico_bak.ini" -Force }

$seelenExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\seelen-ui.exe"
if (Test-Path -LiteralPath $seelenExe) { Start-Process -FilePath $seelenExe }
$dockExe = "$dockRoot\Dock_64.exe"
if (Test-Path -LiteralPath $dockExe) { Start-Process -FilePath $dockExe -WorkingDirectory $dockRoot -WindowStyle Hidden }

Write-Host 'The previous Seelen toolbar and MyDockFinder reflection settings were restored.'
Write-Host 'Recorded media and custom folders were preserved.'
