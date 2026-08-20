$ErrorActionPreference = 'Stop'

$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockConfig = "$dockRoot\ico.ini"
$backupPath = "$dockConfig.before-remove-classic-pawpause"
$dockExe = "$dockRoot\Mydock.exe"

Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

if (Test-Path -LiteralPath $backupPath) {
    Copy-Item -LiteralPath $backupPath -Destination $dockConfig -Force
}

Start-Process -FilePath $dockExe
Write-Host '已恢复 ChatGPT Classic 和 PawPause 的 Dock 固定项。'
