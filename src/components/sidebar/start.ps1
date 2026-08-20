param([switch]$NoStartup)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sidebarScript = $projectRoot + "\ObsidianSidebar.ps1"
$silentLauncher = $projectRoot + "\start-silent.vbs"
$startupLink = [Environment]::GetFolderPath("Startup") + "\Obsidian AI Workspace.lnk"

if (!(Test-Path -LiteralPath $sidebarScript)) {
    throw "ObsidianSidebar.ps1 is missing."
}
if (!(Test-Path -LiteralPath $silentLauncher)) {
    throw "start-silent.vbs is missing."
}

if (!$NoStartup) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $shortcut.Arguments = '//B //NoLogo "' + $silentLauncher + '"'
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.Description = "Obsidian AI Workspace - silent startup"
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

$existing = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($sidebarScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }

if ($existing) {
    Write-Host "Obsidian AI Workspace sidebar is already running." -ForegroundColor Green
    exit 0
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-STA",
    "-WindowStyle", "Hidden",
    "-File", ('"' + $sidebarScript + '"')
)
Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden

$started = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 200
    $process = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($sidebarScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
    if ($process) {
        $started = $true
        break
    }
}

if (!$started) {
    throw "The sidebar process did not start. Check logs\sidebar.log."
}

Write-Host "Obsidian AI Workspace sidebar started." -ForegroundColor Green
