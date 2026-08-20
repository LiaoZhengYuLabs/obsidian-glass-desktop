param([switch]$Enable)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$overlayScript = $projectRoot + "\SystemControlOverlay.ps1"
$disabledFlag = $projectRoot + "\data\control-overlay-disabled.flag"

if (!(Test-Path -LiteralPath $overlayScript)) {
    throw "SystemControlOverlay.ps1 is missing."
}

if ($Enable -and (Test-Path -LiteralPath $disabledFlag)) {
    Remove-Item -LiteralPath $disabledFlag -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $disabledFlag) {
    Write-Host "System control overlay is disabled. Use -Enable to restore it."
    exit 0
}

$running = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $overlayScript + "*")
})

if (!$running) {
    $arguments = @(
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy", "Bypass",
        "-STA",
        "-WindowStyle", "Hidden",
        "-File", ('"' + $overlayScript + '"')
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -WorkingDirectory $projectRoot
    Write-Host "System control overlay started." -ForegroundColor Green
} else {
    Write-Host "System control overlay is already running." -ForegroundColor DarkGray
}
