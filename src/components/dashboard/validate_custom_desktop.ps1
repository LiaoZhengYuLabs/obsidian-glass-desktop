$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $root
$errors = New-Object System.Collections.Generic.List[string]
$passFlag = $root + "\validation-passed.flag"
$errorDir = $root + "\validation-errors"
if (Test-Path -LiteralPath $passFlag) { Remove-Item -LiteralPath $passFlag -Force }
if (Test-Path -LiteralPath $errorDir) { Remove-Item -LiteralPath $errorDir -Recurse -Force }

function Test-PowerShellFile {
    param([string]$Path)
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    foreach ($item in @($parseErrors)) {
        $errors.Add(("PowerShell: {0}:{1} {2}" -f $Path, $item.Extent.StartLineNumber, $item.Message))
    }
}

function Test-XamlFile {
    param([string]$Path)
    try {
        Add-Type -AssemblyName PresentationFramework
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        [void][Windows.Markup.XamlReader]::Parse($text)
    } catch {
        $errors.Add(("XAML: {0} {1}" -f $Path, $_.Exception.Message))
    }
}

function Test-JsonFile {
    param([string]$Path)
    try {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        [void]($text | ConvertFrom-Json)
    } catch {
        $errors.Add(("JSON: {0} {1}" -f $Path, $_.Exception.Message))
    }
}

Test-PowerShellFile ($root + "\ObsidianAIDashboard.ps1")
Test-PowerShellFile ($root + "\MacWidgetDashboard.ps1")
Test-PowerShellFile ($workspaceRoot + "\ObsidianAIWorkspace\ObsidianSidebar.ps1")
Test-PowerShellFile ($workspaceRoot + "\configure_mydock_three_zones.ps1")
Test-PowerShellFile ($workspaceRoot + "\restore_mac_widget_reference.ps1")
Test-PowerShellFile ($root + "\restore_custom_desktop.ps1")
Test-PowerShellFile ($root + "\validate_custom_desktop.ps1")
Test-PowerShellFile ($root + "\verify_runtime_silent.ps1")
Test-PowerShellFile ($root + "\test_todo_runtime_silent.ps1")
Test-PowerShellFile ($root + "\render_custom_preview.ps1")
Test-PowerShellFile ($workspaceRoot + "\ObsidianAIWorkspace\apply_sidebar_when_safe.ps1")
Test-PowerShellFile ($workspaceRoot + "\ObsidianAIWorkspace\verify_custom_sidebar_silent.ps1")
$serviceFiles = Get-ChildItem -LiteralPath ($root + "\services") -Filter "*.ps1" -File
foreach ($file in $serviceFiles) { Test-PowerShellFile $file.FullName }
Test-XamlFile ($root + "\Dashboard.xaml")

$componentFiles = Get-ChildItem -LiteralPath ($root + "\components") -Recurse -Filter "view.xaml" -File
foreach ($file in $componentFiles) { Test-XamlFile $file.FullName }

$jsonFiles = @(
    ($root + "\data\mac-widget-settings.json")
    ($root + "\data\component-settings.json")
    ($root + "\data\todo.json")
    ($root + "\data\ai-agents.json")
    ($workspaceRoot + "\ObsidianAIWorkspace\state\sidebar-style.json")
)
foreach ($file in $jsonFiles) { Test-JsonFile $file }

$dashboardText = [IO.File]::ReadAllText($root + "\Dashboard.xaml", [Text.Encoding]::UTF8)
$requiredNames = @(
    "WeatherCard", "WeatherLocationText", "WeatherTemperatureText",
    "WeatherConditionText", "ForecastIcon1", "ForecastTemp5", "ClockCard",
    "HourHandRotate", "MinuteHandRotate", "CalendarCard", "CalendarDaysPanel",
    "BatteryCard", "BatteryPercentText", "MediaCard", "MediaTrackText",
    "MediaPlayPauseButton", "FeatureCard", "SpeechToggleButton",
    "SpeechStatusText", "SpeechResultText", "CopySpeechButton"
)
foreach ($name in $requiredNames) {
    if ($dashboardText -notmatch ('x:Name="' + [Regex]::Escape($name) + '"')) {
        $errors.Add("Missing dashboard element: $name")
    }
}

$result = [ordered]@{
    ok = ($errors.Count -eq 0)
    checkedAt = (Get-Date).ToString("o")
    powershellFiles = 12 + $serviceFiles.Count
    xamlFiles = 1 + $componentFiles.Count
    jsonFiles = $jsonFiles.Count
    errors = @($errors)
}
$json = $result | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($root + "\validation-result.json", $json, (New-Object Text.UTF8Encoding($false)))

if ($errors.Count -gt 0) {
    [void](New-Item -ItemType Directory -Path $errorDir -Force)
    $index = 0
    foreach ($item in $errors) {
        $index++
        $safeName = ($item -replace '[\\/:*?"<>|\r\n]+', '_')
        if ($safeName.Length -gt 150) { $safeName = $safeName.Substring($safeName.Length - 150) }
        [IO.File]::WriteAllText(($errorDir + "\" + $index.ToString("00") + "-" + $safeName + ".txt"), $item, (New-Object Text.UTF8Encoding($false)))
        Write-Error $item
    }
    exit 1
}

Write-Output "CUSTOM_DESKTOP_VALIDATION_OK"
[IO.File]::WriteAllText($passFlag, "OK", (New-Object Text.UTF8Encoding($false)))
exit 0
