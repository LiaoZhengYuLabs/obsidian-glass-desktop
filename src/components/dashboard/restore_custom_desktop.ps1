$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $root
$backupRoot = $root + "\backups\custom-desktop-20260713"
$encoding = New-Object Text.UTF8Encoding($false)

if (!(Test-Path -LiteralPath ($backupRoot + "\Dashboard.xaml"))) {
    throw "Dashboard backup is missing."
}

Copy-Item -LiteralPath ($backupRoot + "\Dashboard.xaml") -Destination ($root + "\Dashboard.xaml") -Force
Copy-Item -LiteralPath ($backupRoot + "\layout.json") -Destination ($root + "\data\layout.json") -Force

$mainPath = $root + "\ObsidianAIDashboard.ps1"
$main = [IO.File]::ReadAllText($mainPath, [Text.Encoding]::UTF8)
$main = $main.Replace('$script:window.Width = 392 * $script:scale', '$script:window.Width = 320 * $script:scale')
$main = $main.Replace('$script:window.Height = 500 * $script:scale', '$script:window.Height = 720 * $script:scale')

$main = [Regex]::Replace(
    $main,
    '    \$workArea = \[Windows\.SystemParameters\]::WorkArea\r?\n    \$maxLeft = .*?\r?\n    \$maxTop = .*?\r?\n    \$script:window\.Left = .*?\r?\n    \$script:window\.Top = .*?\r?\n    \$script:window\.Topmost = \[bool\]\$layout\.alwaysOnTop',
    "    `$script:window.Left = [Math]::Max(100, [double]`$layout.left)`r`n    `$script:window.Top = [Math]::Max(56, [double]`$layout.top)`r`n    `$script:window.Topmost = [bool]`$layout.alwaysOnTop",
    [Text.RegularExpressions.RegexOptions]::Singleline
)

$main = [Regex]::Replace(
    $main,
    'if \(-not \("ObsidianDesktopContextNative" -as \[type\]\)\) \{.*?\r?\nfunction Update-TimeWeatherWidget \{',
    'function Update-TimeWeatherWidget {',
    [Text.RegularExpressions.RegexOptions]::Singleline
)

$removeLines = @(
    '    $script:mediaWidget = Add-DashboardWidget -Window $script:window -SlotName "MediaSlot" -WidgetName "MediaWidget"',
    '    $script:workspaceWidget = Add-DashboardWidget -Window $script:window -SlotName "WorkspacePulseSlot" -WidgetName "WorkspacePulseWidget"',
    '        $script:mediaWidget.FindName("MediaDot"),',
    '        $script:workspaceWidget.FindName("WorkspaceDot")',
    '        $contextTimer.Start()',
    '        Update-ContextWidgets'
)
foreach ($line in $removeLines) {
    $main = $main.Replace($line + "`r`n", "").Replace($line + "`n", "")
}
$main = $main.Replace(
    '@($script:timeWidget, $script:aiWidget, $script:githubWidget, $script:quickToolsWidget, $script:systemWidget, $script:todoWidget, $script:mediaWidget, $script:workspaceWidget)',
    '@($script:timeWidget, $script:aiWidget, $script:githubWidget, $script:quickToolsWidget, $script:systemWidget, $script:todoWidget)'
)
$main = $main.Replace(
    '        $script:todoWidget.FindName("TodoDot"),' + "`r`n",
    '        $script:todoWidget.FindName("TodoDot")' + "`r`n"
).Replace(
    '        $script:todoWidget.FindName("TodoDot"),' + "`n",
    '        $script:todoWidget.FindName("TodoDot")' + "`n"
)

$main = [Regex]::Replace(
    $main,
    '            \$workArea = \[Windows\.SystemParameters\]::WorkArea\r?\n            \$script:window\.Left = .*?\r?\n            \$script:window\.Top = .*?\r?\n            Save-DashboardLayout',
    "            `$script:window.Left = 112`r`n            `$script:window.Top = 76`r`n            Save-DashboardLayout"
)
$main = [Regex]::Replace(
    $main,
    '    \$script:mediaWidget\.FindName\("MediaPlayPauseButton"\)\.Add_Click\(\{.*?\r?\n    \}\)\r?\n\r?\n',
    '',
    [Text.RegularExpressions.RegexOptions]::Singleline
)
$main = [Regex]::Replace(
    $main,
    '    \$contextTimer = New-Object Windows\.Threading\.DispatcherTimer\r?\n    \$contextTimer\.Interval = .*?\r?\n    \$contextTimer\.Add_Tick\(\{ Update-ContextWidgets \}\)\r?\n\r?\n',
    ''
)
$main = $main.Replace(
    '@($timeTimer, $dataTimer, $contextTimer, $githubTimer, $systemTimer, $pulseTimer)',
    '@($timeTimer, $dataTimer, $githubTimer, $systemTimer, $pulseTimer)'
)
[IO.File]::WriteAllText($mainPath, $main, $encoding)

$componentFiles = Get-ChildItem -LiteralPath ($root + "\components") -Recurse -Filter "view.xaml" -File
foreach ($file in $componentFiles) {
    if ($file.FullName -match 'MediaWidget|WorkspacePulseWidget') { continue }
    $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    $text = $text.Replace('CornerRadius="14"', 'CornerRadius="18"')
    $text = $text.Replace('Background="#12FFFFFF"', 'Background="#16FFFFFF"')
    $text = $text.Replace('BorderBrush="#20FFFFFF"', 'BorderBrush="#22FFFFFF"')
    $text = $text.Replace('<DropShadowEffect Color="#C8000000" BlurRadius="11" ShadowDepth="3" Opacity="0.44"/>', '<DropShadowEffect Color="#D0000000" BlurRadius="14" ShadowDepth="4" Opacity="0.52"/>')
    [IO.File]::WriteAllText($file.FullName, $text, $encoding)
}

$sidebarPath = $workspaceRoot + "\ObsidianAIWorkspace\ObsidianSidebar.ps1"
$sidebar = [IO.File]::ReadAllText($sidebarPath, [Text.Encoding]::UTF8)
$sidebar = $sidebar.Replace('Width="78"', 'Width="90"').Replace('Height="540"', 'Height="590"')
$sidebar = $sidebar.Replace('$panel.Width = 74', '$panel.Width = 86').Replace('$viewer.Width = 74', '$viewer.Width = 86')
$sidebar = $sidebar.Replace('$fixedAppsPanel = New-AppRegion -Top 8 -Height 220', '$fixedAppsPanel = New-AppRegion -Top 8 -Height 250')
$sidebar = $sidebar.Replace('New-SectionSeparator -Top 234 -Color "#566F7690"', 'New-SectionSeparator -Top 266 -Color "#566F7690"')
$sidebar = $sidebar.Replace('$currentAppsPanel = New-AppRegion -Top 241 -Height 140', '$currentAppsPanel = New-AppRegion -Top 273 -Height 160')
$sidebar = $sidebar.Replace('New-SectionSeparator -Top 389 -Color "#384B5161"', 'New-SectionSeparator -Top 439 -Color "#384B5161"')
$sidebar = $sidebar.Replace('$recentAppsPanel = New-AppRegion -Top 396 -Height 116', '$recentAppsPanel = New-AppRegion -Top 446 -Height 120')
$sidebar = $sidebar.Replace('$hiddenLeft = -68.0', '$hiddenLeft = -78.0')
[IO.File]::WriteAllText($sidebarPath, $sidebar, $encoding)

Write-Output "Custom desktop layout restored. Restart the Dashboard and Sidebar to apply it."
