$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDock.ps1"
$myDockRoot = "C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder"

$processes = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
$layoutText = [IO.File]::ReadAllText($myDockRoot + "\ico.ini", [Text.Encoding]::UTF8)
$fixedCount = ([regex]::Matches($layoutText, "(?m)^filepath=.+$")).Count
$activeCount = 0
$pageCount = 0
$logPath = $projectRoot + "\logs\dock.log"
if (Test-Path -LiteralPath $logPath) {
    $runtimeLine = Get-Content -LiteralPath $logPath -Tail 100 |
        Where-Object { $_ -match 'Runtime refreshed: (\d+) active apps, (\d+) retained pages' } |
        Select-Object -Last 1
    if ($runtimeLine -match 'Runtime refreshed: (?<active>\d+) active apps, (?<pages>\d+) retained pages') {
        $activeCount = [int]$matches.active
        $pageCount = [int]$matches.pages
    }
}
$startupLink = [Environment]::GetFolderPath("Startup") + "\Obsidian AI Dock.lnk"

[pscustomobject]@{
    Running = ($processes.Count -eq 1)
    ProcessCount = $processes.Count
    FixedApplications = $fixedCount
    ActiveApplications = $activeCount
    RetainedPages = $pageCount
    StartupEnabled = (Test-Path -LiteralPath $startupLink)
    MyDockFinderRunning = ($null -ne (Get-Process Dock_64 -ErrorAction SilentlyContinue))
    ConfigHash = (Get-FileHash ($myDockRoot + "\config.ini") -Algorithm SHA256).Hash
    IconLayoutHash = (Get-FileHash ($myDockRoot + "\ico.ini") -Algorithm SHA256).Hash
} | Format-List
