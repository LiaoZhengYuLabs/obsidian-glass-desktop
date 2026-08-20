$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$installRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$seelenRoot = "$env:APPDATA\com.seelen.seelen-ui"
$toolbarPath = "$seelenRoot\data\seelen-fancy-toolbar\state.yml"
if (-not (Test-Path -LiteralPath $toolbarPath)) { $toolbarPath = "$seelenRoot\toolbar_items.yml" }
$baseToolbarPath = "$seelenRoot\profiles\base\toolbar.yml"
$seelenSettingsPath = "$seelenRoot\settings.json"
$dockRoot = Get-ObsidianGlassDockRoot
$dockConfig = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'config.ini' } else { $null }
$dockIconConfig = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'ico.ini' } else { $null }
$dockIconBackup = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot 'ico_bak.ini' } else { $null }
$backupRoot = Join-Path (Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop') ('media-center-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$latestBackup = Join-Path (Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop') 'latest-media-center-backup.txt'

if (-not (Test-Path -LiteralPath $toolbarPath)) { throw "Seelen toolbar not found: $toolbarPath" }
if (-not (Test-Path -LiteralPath $baseToolbarPath)) { throw "Seelen base toolbar not found: $baseToolbarPath" }
if (![string]::IsNullOrWhiteSpace($dockConfig) -and -not (Test-Path -LiteralPath $dockConfig -PathType Leaf)) { throw "MyDockFinder config not found: $dockConfig" }

New-Item -ItemType Directory -Force -Path $installRoot, $backupRoot | Out-Null

Copy-Item -LiteralPath $toolbarPath -Destination "$backupRoot\active-toolbar.yml" -Force
Copy-Item -LiteralPath $baseToolbarPath -Destination "$backupRoot\base-toolbar.yml" -Force
if (Test-Path -LiteralPath $seelenSettingsPath) { Copy-Item -LiteralPath $seelenSettingsPath -Destination "$backupRoot\seelen-settings.json" -Force }
if (![string]::IsNullOrWhiteSpace($dockConfig) -and (Test-Path -LiteralPath $dockConfig -PathType Leaf)) {
    Copy-Item -LiteralPath $dockConfig -Destination "$backupRoot\mydock-config.ini" -Force
}
if (Test-Path -LiteralPath $dockIconConfig) { Copy-Item -LiteralPath $dockIconConfig -Destination "$backupRoot\ico.ini" -Force }
if (Test-Path -LiteralPath $dockIconBackup) { Copy-Item -LiteralPath $dockIconBackup -Destination "$backupRoot\ico_bak.ini" -Force }

Copy-Item -LiteralPath "$projectRoot\DesktopMediaCenter.ps1" -Destination "$installRoot\DesktopMediaCenter.ps1" -Force
Copy-Item -LiteralPath "$projectRoot\MediaCenter.xaml" -Destination "$installRoot\MediaCenter.xaml" -Force
foreach ($optionalFile in @('open-screenshot.cmd','open-recording.cmd','open-camera.cmd','toggle-language.ps1','toggle-language.cmd')) {
    $optionalSource = Join-Path $projectRoot $optionalFile
    if (Test-Path -LiteralPath $optionalSource -PathType Leaf) {
        Copy-Item -LiteralPath $optionalSource -Destination (Join-Path $installRoot $optionalFile) -Force
    }
}

$pictures = [Environment]::GetFolderPath('MyPictures')
if ([string]::IsNullOrWhiteSpace($pictures)) { $pictures = "$env:USERPROFILE\Pictures" }
$library = "$pictures\桌面媒体中心"
New-Item -ItemType Directory -Force -Path $library, "$library\截图", "$library\屏幕录像", "$library\摄像头录像", "$installRoot\logs", "$installRoot\thumbnails" | Out-Null

function Set-ToolbarMediaEntries {
    param([string]$Path)
    $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $root = $installRoot.Replace('\', '/')
    $block = @"
  - type: Text
    id: media-screenshot
    template: return '截图'
    tooltip: return '直接截图与历史图片'
    badge: null
    onClick: null
    onClickV2: open("$root/open-screenshot.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - type: Text
    id: media-recording
    template: return '录像'
    tooltip: return '屏幕录像与历史视频'
    badge: null
    onClick: null
    onClickV2: open("$root/open-recording.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - type: Text
    id: media-camera
    template: return '摄像头'
    tooltip: return '桌面摄像头窗口与历史录像'
    badge: null
    onClick: null
    onClickV2: open("$root/open-camera.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - type: Text
    id: language-toggle
    template: return '中/EN'
    tooltip: return '切换简体中文与 English 输入'
    badge: null
    onClick: null
    onClickV2: open("$root/toggle-language.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
"@

    $pattern = '(?ms)^  - type: Text\r?\n    id: (?:practical-capture|media-screenshot).*?(?=^  - type: Text\r?\n    id: practical-tasks)'
    if ([regex]::IsMatch($text, $pattern)) {
        $updated = [regex]::Replace($text, $pattern, $block)
    } else {
        $anchor = '(?m)^  - type: Text\r?\n    id: practical-tasks'
        if (-not [regex]::IsMatch($text, $anchor)) { throw "Toolbar task anchor not found in $Path" }
        $updated = [regex]::Replace($text, $anchor, $block + "  - type: Text`r`n    id: practical-tasks", 1)
    }
    [IO.File]::WriteAllText($Path, $updated, (New-Object Text.UTF8Encoding($false)))
}

function Set-DockReflection {
    param([string]$Path)
    $lines = New-Object Collections.Generic.List[string]
    foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) { [void]$lines.Add($line) }
    $themesIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim().Equals('[themes]', [StringComparison]::OrdinalIgnoreCase)) { $themesIndex = $index; break }
    }
    if ($themesIndex -lt 0) {
        [void]$lines.Add('')
        [void]$lines.Add('[themes]')
        $themesIndex = $lines.Count - 1
    }
    $sectionEnd = $lines.Count
    for ($index = $themesIndex + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\[') { $sectionEnd = $index; break }
    }
    $values = [ordered]@{
        enable_iconreflection = '1'
        blur_iconreflection = '16'
        opacity_iconreflection = '34'
        blur_iconreflectionoffset = '2'
        blur_iconreflectionstoppoint = '68'
    }
    foreach ($key in @($values.Keys)) {
        $found = $false
        for ($index = $themesIndex + 1; $index -lt $sectionEnd; $index++) {
            if ($lines[$index] -match ('^' + [regex]::Escape($key) + '=')) {
                $lines[$index] = "$key=$($values[$key])"
                $found = $true
                break
            }
        }
        if (-not $found) {
            $lines.Insert($sectionEnd, "$key=$($values[$key])")
            $sectionEnd++
        }
    }
    [IO.File]::WriteAllLines($Path, $lines, (New-Object Text.UTF8Encoding($false)))
}

$seelen = Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue
if ($seelen) {
    $seelen | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$dock = Get-Process -Name 'Dock_64' -ErrorAction SilentlyContinue
if ($dock) {
    $dock | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$migrator = "$projectRoot\migrate_seelen_toolbar_v27.ps1"
if (-not (Test-Path -LiteralPath $migrator)) { throw "Seelen toolbar migrator not found: $migrator" }
& $migrator -SourcePath "$backupRoot\active-toolbar.yml" -DestinationPath $toolbarPath -RuntimeRoot $installRoot | Out-Null
& $migrator -SourcePath "$backupRoot\base-toolbar.yml" -DestinationPath $baseToolbarPath -RuntimeRoot $installRoot | Out-Null

if (Test-Path -LiteralPath $seelenSettingsPath) {
    $seelenSettings = Get-Content -LiteralPath $seelenSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $toolbarSettings = $seelenSettings.byWidget.'@seelen/fancy-toolbar'
    if ($toolbarSettings) {
        $toolbarSettings.enabled = $true
        $toolbarSettings.hideMode = 'Never'
        $settingsJson = $seelenSettings | ConvertTo-Json -Depth 40
        [IO.File]::WriteAllText($seelenSettingsPath, $settingsJson, (New-Object Text.UTF8Encoding($false)))
    }
}
if (![string]::IsNullOrWhiteSpace($dockConfig) -and (Test-Path -LiteralPath $dockConfig -PathType Leaf)) {
    Set-DockReflection $dockConfig
}

$seelenExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\seelen-ui.exe"
if (Test-Path -LiteralPath $seelenExe) { Start-Process -FilePath $seelenExe }
if (![string]::IsNullOrWhiteSpace($dockRoot)) {
    $dockExe = "$dockRoot\Dock_64.exe"
    if (Test-Path -LiteralPath $dockExe) { Start-Process -FilePath $dockExe -WorkingDirectory $dockRoot -WindowStyle Hidden }
}

$stateRoot = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop'
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
$state = [ordered]@{
    installedAt = (Get-Date).ToString('o')
    backup = $backupRoot
    installRoot = $installRoot
    libraryRoot = $library
    toolbar = $toolbarPath
    baseToolbar = $baseToolbarPath
    seelenSettings = $seelenSettingsPath
    dockConfig = $dockConfig
}
[IO.File]::WriteAllText((Join-Path $stateRoot 'topbar-install-state.json'), ($state | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText((Join-Path $stateRoot 'latest-media-center-backup.txt'), $backupRoot, (New-Object Text.UTF8Encoding($false)))

Write-Host 'Desktop Media Center installed.'
Write-Host "Media library: $library"
Write-Host 'Dock reflection opacity: 34'
Write-Host 'The media panel will open only after a top-bar item is clicked.'
Write-Host "Backup: $backupRoot"
