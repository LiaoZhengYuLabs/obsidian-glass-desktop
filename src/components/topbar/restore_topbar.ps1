$ErrorActionPreference = 'Stop'

$stateRoot = "$env:LOCALAPPDATA\ObsidianDesktopTopbar"
$startupFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ObsidianDesktopTopbar.vbs"
$dockConfig = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder\config.ini'
$backup = "$stateRoot\mydockfinder-config.before-obsidian-topbar.ini"
$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockExe = "$dockRoot\Mydock.exe"

Get-Process -Name ObsidianDesktopTopbar -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath $startupFile -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $backup) {
    Copy-Item -LiteralPath $backup -Destination $dockConfig -Force
}

if (Test-Path -LiteralPath $dockExe) {
    Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    Start-Process -FilePath $dockExe
}

Write-Host '已停用 Obsidian 顶部栏并恢复 MyFinder 原有配置。'
