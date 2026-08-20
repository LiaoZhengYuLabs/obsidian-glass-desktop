param([switch]$NoStartup)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDashboard.ps1"
$controlOverlayScript = $projectRoot + "\SystemControlOverlay.ps1"
$controlOverlayDisabledFlag = $projectRoot + "\data\control-overlay-disabled.flag"
$delayedScript = $projectRoot + "\start-delayed.ps1"
$silentLauncher = $projectRoot + "\start-silent.vbs"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupLink = $startupFolder + "\Obsidian AI Desktop Dashboard.lnk"

if (!(Test-Path -LiteralPath $mainScript)) {
    throw "ObsidianAIDashboard.ps1 is missing."
}
if (!(Test-Path -LiteralPath $silentLauncher)) {
    throw "start-silent.vbs is missing."
}

$running = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
}

if (!$running) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-STA",
        "-WindowStyle", "Hidden",
        "-File", ('"' + $mainScript + '"')
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -WorkingDirectory $projectRoot
}

if ((Test-Path -LiteralPath $controlOverlayScript) -and !(Test-Path -LiteralPath $controlOverlayDisabledFlag)) {
    $controlOverlayRunning = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $controlOverlayScript + "*")
    }
    if (!$controlOverlayRunning) {
        $controlArguments = @(
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-STA",
            "-WindowStyle", "Hidden",
            "-File", ('"' + $controlOverlayScript + '"')
        )
        Start-Process -FilePath "powershell.exe" -ArgumentList $controlArguments -WindowStyle Hidden -WorkingDirectory $projectRoot
    }
}

if (!$NoStartup) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $shortcut.Arguments = '//B //NoLogo "' + $silentLauncher + '"'
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.Description = "Obsidian AI Desktop Dashboard - silent delayed startup"
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

Start-Sleep -Milliseconds 650
$running = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
}
if (!$running) {
    throw "Dashboard did not start. Check logs\dashboard.log."
}

Write-Host "Obsidian AI Desktop Dashboard started." -ForegroundColor Green
if (!$NoStartup) { Write-Host "Single delayed startup shortcut enabled (2 seconds)." }
if (Test-Path -LiteralPath $controlOverlayDisabledFlag) {
    Write-Host "System control overlay remains disabled; Windows native OSD is unchanged." -ForegroundColor DarkGray
} elseif (Test-Path -LiteralPath $controlOverlayScript) {
    Write-Host "Realtime brightness/volume capsule enabled." -ForegroundColor DarkGray
}
