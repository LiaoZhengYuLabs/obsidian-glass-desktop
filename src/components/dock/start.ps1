param([switch]$NoStartup)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDock.ps1"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }

if (!(Test-Path -LiteralPath $mainScript)) {
    throw "ObsidianAIDock.ps1 is missing."
}

$existing = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }

if (!$existing) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-STA",
        "-WindowStyle", "Hidden",
        "-File", ('"' + $mainScript + '"')
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden
}

if (!$NoStartup) {
    $startup = [Environment]::GetFolderPath("Startup")
    $startupLink = $startup + "\Obsidian AI Dock.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $mainScript + '"'
    $shortcut.WorkingDirectory = $projectRoot
    $dockRoot = Get-ObsidianGlassDockRoot
    if (![string]::IsNullOrWhiteSpace($dockRoot)) {
        $shortcut.IconLocation = (Join-Path $dockRoot "Dock_64.exe") + ",0"
    }
    $shortcut.Save()
}

$started = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 200
    $process = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
    if ($process) { $started = $true; break }
}

if (!$started) {
    throw "Obsidian AI Dock did not start. Check logs\dock.log."
}

Write-Host "Obsidian AI Dock started." -ForegroundColor Green
if (!$NoStartup) { Write-Host "Startup shortcut enabled." }
