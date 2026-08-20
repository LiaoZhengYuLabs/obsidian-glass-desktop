$ErrorActionPreference = "SilentlyContinue"

$controllerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$controllerScript = $controllerRoot + "\DockVisibilityController.ps1"
$stateRoot = $env:LOCALAPPDATA + "\ObsidianDockVisibility"
$statePath = $stateRoot + "\mode.txt"

if (!(Test-Path -LiteralPath $controllerScript)) {
    exit 1
}
if (!(Test-Path -LiteralPath $stateRoot)) {
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
}
if (!(Test-Path -LiteralPath $statePath)) {
    Set-Content -LiteralPath $statePath -Value "fixed" -NoNewline -Encoding ASCII
}

$alreadyRunning = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
    $_.CommandLine -like "*DockVisibilityController.ps1*"
}
if ($alreadyRunning) {
    exit 0
}

$arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $controllerScript + '"'
Start-Process `
    -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList $arguments `
    -WindowStyle Hidden
