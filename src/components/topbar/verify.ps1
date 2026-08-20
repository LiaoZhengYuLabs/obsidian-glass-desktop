$ErrorActionPreference = 'Continue'
$installRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
$seelenRoot = "$env:APPDATA\com.seelen.seelen-ui"
$dockConfig = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder\config.ini'
$pictures = [Environment]::GetFolderPath('MyPictures')
if (-not $pictures) { $pictures = "$env:USERPROFILE\Pictures" }
$library = "$pictures\桌面媒体中心"

function Result([string]$Name, [bool]$Passed, [string]$Detail) {
    [pscustomobject]@{ Check=$Name; Passed=$Passed; Detail=$Detail }
}

$results = @()
$toolbarPath = "$seelenRoot\data\seelen-fancy-toolbar\state.yml"
if (-not (Test-Path -LiteralPath $toolbarPath)) { $toolbarPath = "$seelenRoot\toolbar_items.yml" }
$toolbar = if (Test-Path $toolbarPath) { [IO.File]::ReadAllText($toolbarPath) } else { '' }
$dock = if (Test-Path $dockConfig) { [IO.File]::ReadAllText($dockConfig) } else { '' }
$settingsPath = "$seelenRoot\settings.json"
$toolbarHideMode = $null
if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $toolbarHideMode = $settings.byWidget.'@seelen/fancy-toolbar'.hideMode
}

$results += Result 'Screenshot top item' ($toolbar -match 'id: media-screenshot') 'Seelen toolbar screenshot entry'
$results += Result 'Recording top item' ($toolbar -match 'id: media-recording') 'Seelen toolbar recording entry'
$results += Result 'Camera top item' ($toolbar -match 'id: media-camera') 'Seelen toolbar camera entry'
$results += Result 'Language top item' ($toolbar -match 'id: language-toggle') 'Simplified Chinese and English input switch'
$originalIds = @('practical-files','practical-project','practical-code','practical-terminal','practical-capture','practical-tasks','practical-settings','native-full-shutdown','dynamic-volume','realtime-power','quick-x','quick-github','quick-chatgpt-classic')
$missingOriginalIds = @($originalIds | Where-Object { $toolbar -notmatch ('id:\s*' + [regex]::Escape($_)) })
$results += Result 'Original top items preserved' ($missingOriginalIds.Count -eq 0) ('Missing: ' + ($missingOriginalIds -join ', '))
$results += Result 'Seelen 2.7 toolbar format' ($toolbar -notmatch '(?m)^  - type:') 'No legacy typed toolbar entries'
$results += Result 'Toolbar always visible' ($toolbarHideMode -eq 'Never') 'Fancy Toolbar hide mode'
$results += Result 'Runtime script' (Test-Path "$installRoot\DesktopMediaCenter.ps1") "$installRoot\DesktopMediaCenter.ps1"
$results += Result 'XAML panel' (Test-Path "$installRoot\MediaCenter.xaml") "$installRoot\MediaCenter.xaml"
$runtimeScript = if (Test-Path "$installRoot\DesktopMediaCenter.ps1") { [IO.File]::ReadAllText("$installRoot\DesktopMediaCenter.ps1") } else { '' }
$runtimeXaml = if (Test-Path "$installRoot\MediaCenter.xaml") { [IO.File]::ReadAllText("$installRoot\MediaCenter.xaml") } else { '' }
$results += Result 'Recording toggle control' ($runtimeXaml -match 'x:Name="RecordingToggleButton"') 'dedicated screen recording switch'
$results += Result 'Recording duration display' (($runtimeXaml -match 'x:Name="RecordingDurationText"') -and ($runtimeScript -match 'Format-RecordingDuration')) 'HH:MM:SS live duration'
$results += Result 'Language switch' (Test-Path "$installRoot\toggle-language.ps1") "$installRoot\toggle-language.ps1"
$results += Result 'Screenshot library' (Test-Path "$library\截图") "$library\截图"
$results += Result 'Recording library' (Test-Path "$library\屏幕录像") "$library\屏幕录像"
$results += Result 'Camera library' (Test-Path "$library\摄像头录像") "$library\摄像头录像"
$results += Result 'FFmpeg' ([bool](Get-Command ffmpeg.exe -ErrorAction SilentlyContinue)) 'screen and camera recording engine'
$results += Result 'FFplay' ([bool](Get-Command ffplay.exe -ErrorAction SilentlyContinue)) 'camera preview engine'
$results += Result 'Reflection enabled' ($dock -match '(?m)^enable_iconreflection=1\r?$') 'MyDockFinder reflection switch'
$results += Result 'Reflection visible' ($dock -match '(?m)^opacity_iconreflection=34\r?$') 'MyDockFinder reflection opacity'
$results += Result 'Seelen running' ([bool](Get-Process seelen-ui -ErrorAction SilentlyContinue)) 'top toolbar process'
$results += Result 'Dock running' ([bool](Get-Process Dock_64 -ErrorAction SilentlyContinue)) 'MyDockFinder process'

$results | Format-Table -AutoSize
if ($results.Passed -contains $false) { exit 1 }
exit 0
