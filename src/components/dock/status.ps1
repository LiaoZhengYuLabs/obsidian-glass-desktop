$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDock.ps1"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$myDockRoot = Get-ObsidianGlassDockRoot

$processes = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
$iconPath = if (![string]::IsNullOrWhiteSpace($myDockRoot)) { Join-Path $myDockRoot 'ico.ini' } else { $null }
$layoutText = if (![string]::IsNullOrWhiteSpace($iconPath) -and (Test-Path -LiteralPath $iconPath -PathType Leaf)) { [IO.File]::ReadAllText($iconPath, [Text.Encoding]::UTF8) } else { '' }
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
    ConfigHash = if (![string]::IsNullOrWhiteSpace($myDockRoot) -and (Test-Path -LiteralPath (Join-Path $myDockRoot 'config.ini') -PathType Leaf)) { (Get-FileHash (Join-Path $myDockRoot 'config.ini') -Algorithm SHA256).Hash } else { '' }
    IconLayoutHash = if (![string]::IsNullOrWhiteSpace($iconPath) -and (Test-Path -LiteralPath $iconPath -PathType Leaf)) { (Get-FileHash $iconPath -Algorithm SHA256).Hash } else { '' }
} | Format-List
