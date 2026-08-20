$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$overlayScript = $projectRoot + "\SystemControlOverlay.ps1"
$running = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $overlayScript + "*")
})

if ($running) {
    foreach ($process in $running) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "System control overlay stopped." -ForegroundColor Green
} else {
    Write-Host "System control overlay is not running." -ForegroundColor DarkGray
}
