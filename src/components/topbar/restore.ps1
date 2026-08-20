$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$latestBackup = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop\latest-media-center-backup.txt'
if (-not (Test-Path -LiteralPath $latestBackup)) { throw 'No Desktop Media Center backup record was found.' }
$backupRoot = [IO.File]::ReadAllText($latestBackup).Trim()
if (-not (Test-Path -LiteralPath $backupRoot)) { throw "Backup folder not found: $backupRoot" }

$seelenRoot = "$env:APPDATA\com.seelen.seelen-ui"
$toolbarPath = "$seelenRoot\data\seelen-fancy-toolbar\state.yml"
if (-not (Test-Path -LiteralPath $toolbarPath)) { $toolbarPath = "$seelenRoot\toolbar_items.yml" }
$baseToolbarPath = "$seelenRoot\profiles\base\toolbar.yml"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$dockRoot = Get-ObsidianGlassDockRoot
$dockConfig = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'config.ini' } else { $null }
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
if (![string]::IsNullOrWhiteSpace($dockConfig)) { Copy-Item -LiteralPath "$backupRoot\mydock-config.ini" -Destination $dockConfig -Force }
if (![string]::IsNullOrWhiteSpace($dockRoot) -and (Test-Path -LiteralPath "$backupRoot\ico.ini")) { Copy-Item -LiteralPath "$backupRoot\ico.ini" -Destination (Join-Path $dockRoot 'ico.ini') -Force }
if (![string]::IsNullOrWhiteSpace($dockRoot) -and (Test-Path -LiteralPath "$backupRoot\ico_bak.ini")) { Copy-Item -LiteralPath "$backupRoot\ico_bak.ini" -Destination (Join-Path $dockRoot 'ico_bak.ini') -Force }

$seelenExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\seelen-ui.exe"
if (Test-Path -LiteralPath $seelenExe) { Start-Process -FilePath $seelenExe }
$dockExe = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'Dock_64.exe' } else { $null }
if (![string]::IsNullOrWhiteSpace($dockExe) -and (Test-Path -LiteralPath $dockExe)) { Start-Process -FilePath $dockExe -WorkingDirectory $dockRoot -WindowStyle Hidden }

Write-Host 'The previous Seelen toolbar and MyDockFinder reflection settings were restored.'
Write-Host 'Recorded media and custom folders were preserved.'
