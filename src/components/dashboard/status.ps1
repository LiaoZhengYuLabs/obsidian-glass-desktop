$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDashboard.ps1"
$delayedScript = $projectRoot + "\start-delayed.ps1"
$silentLauncher = $projectRoot + "\start-silent.vbs"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupLink = $startupFolder + "\Obsidian AI Desktop Dashboard.lnk"
$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
})

$startupMatches = @()
$shell = New-Object -ComObject WScript.Shell
Get-ChildItem -LiteralPath $startupFolder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $shortcut = $shell.CreateShortcut($_.FullName)
        if ([string]$shortcut.Arguments -like ("*" + $delayedScript + "*") -or
            [string]$shortcut.Arguments -like ("*" + $silentLauncher + "*")) {
            $startupMatches += $_.FullName
        }
    } catch {}
}

$stateRoot = Join-Path $env:LOCALAPPDATA "ObsidianGlassDesktop\dashboard"
$dataRoot = Join-Path $stateRoot "data"
$layout = $null
try { $layout = [IO.File]::ReadAllText((Join-Path $dataRoot "mac-widget-layout.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json } catch {}
$widgetCount = 0
if ($null -ne $layout -and $null -ne $layout.widgets) { $widgetCount = @($layout.widgets.PSObject.Properties).Count }
$speechRoot = Join-Path $env:LOCALAPPDATA "ObsidianGlassDesktop\runtime\speech"
$speechPython = Join-Path $speechRoot "python.exe"
$speechModel = Join-Path $speechRoot "models\models--mobiuslabsgmbh--faster-whisper-large-v3-turbo"
$speechGpu = Join-Path $speechRoot "cuda\libs\cublas64_12.dll"

[pscustomobject]@{
    Running = ($running.Count -eq 1)
    ProcessCount = $running.Count
    ProcessIds = @($running.ProcessId) -join ", "
    StartupEnabled = (Test-Path -LiteralPath $startupLink)
    DashboardStartupEntries = $startupMatches.Count
    StartupMode = if ($startupMatches.Count -eq 1) { "Silent delayed startup" } elseif ($startupMatches.Count -gt 1) { "Multiple startup entries" } else { "Check startup shortcut" }
    LayoutVersion = if ($layout) { $layout.version } else { "unknown" }
    IndependentWidgets = $widgetCount
    WhisperRuntimeInstalled = (Test-Path -LiteralPath $speechPython)
    WhisperModelCached = (Test-Path -LiteralPath $speechModel)
    WhisperGpuRuntimeInstalled = (Test-Path -LiteralPath $speechGpu)
} | Format-List
