$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pointer = $root + "\backups\latest-app-usage.txt"
if (!(Test-Path -LiteralPath $pointer)) {
    throw "App usage widget backup pointer was not found."
}

$backup = [IO.File]::ReadAllText($pointer, [Text.Encoding]::UTF8).Trim()
if (!(Test-Path -LiteralPath $backup)) {
    throw "App usage widget backup folder was not found."
}

& ($root + "\stop.ps1")
foreach ($name in @("Dashboard.xaml", "MacWidgetDashboard.ps1", "README.md", "CHANGELOG.md")) {
    Copy-Item -LiteralPath ($backup + "\" + $name) -Destination ($root + "\" + $name) -Force
}
if (Test-Path -LiteralPath ($backup + "\mac-widget-layout.json")) {
    Copy-Item -LiteralPath ($backup + "\mac-widget-layout.json") -Destination ($root + "\data\mac-widget-layout.json") -Force
}
& ($root + "\start.ps1") -NoStartup
Write-Host "The dashboard was restored to the state before the app usage widget." -ForegroundColor Green

