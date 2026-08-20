$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sidebarScript = $projectRoot + "\ObsidianSidebar.ps1"
$processes = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($sidebarScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }

if ($processes) {
    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
    }
    Write-Host "Obsidian AI Workspace sidebar stopped." -ForegroundColor Green
} else {
    Write-Host "Obsidian AI Workspace sidebar is not running."
}

$restoreWindowStyle = $projectRoot + "\restore-window-style.ps1"
if (Test-Path -LiteralPath $restoreWindowStyle) {
    & $restoreWindowStyle
}
