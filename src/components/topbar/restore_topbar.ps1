$ErrorActionPreference = 'Stop'

$stateRoot = "$env:LOCALAPPDATA\ObsidianDesktopTopbar"
$startupFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ObsidianDesktopTopbar.vbs"
$backup = "$stateRoot\mydockfinder-config.before-obsidian-topbar.ini"
$sourceRoot = Split-Path -Parent $PSCommandPath
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $sourceRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$dockRoot = Get-ObsidianGlassDockRoot
$dockConfig = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'config.ini' } else { $null }
$dockExe = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'Dock_64.exe' } else { $null }

Get-Process -Name ObsidianDesktopTopbar -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath $startupFile -Force -ErrorAction SilentlyContinue

if (![string]::IsNullOrWhiteSpace($dockConfig) -and (Test-Path -LiteralPath $backup)) {
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
