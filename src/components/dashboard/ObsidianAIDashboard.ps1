$ErrorActionPreference = "Stop"

$macWidgetEntry = (Split-Path -Parent $MyInvocation.MyCommand.Path) + "\MacWidgetDashboard.ps1"
if (Test-Path -LiteralPath $macWidgetEntry) {
    & $macWidgetEntry
    exit $LASTEXITCODE
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$script:dashboardRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:dataRoot = $script:dashboardRoot + "\data"
$script:componentRoot = $script:dashboardRoot + "\components"
$script:logPath = $script:dashboardRoot + "\logs\dashboard.log"
$script:layoutPath = $script:dataRoot + "\layout.json"
$script:weatherPath = $script:dataRoot + "\weather.json"
$script:agentPath = $script:dataRoot + "\ai-agents.json"
$script:githubPath = $script:dataRoot + "\github.json"
$script:todoPath = $script:dataRoot + "\todo.json"
$script:componentSettingsPath = $script:dataRoot + "\component-settings.json"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$requiredFolders = @()
$requiredFolders += $script:dataRoot
$requiredFolders += ($script:dashboardRoot + "\logs")
$requiredFolders += ($script:dashboardRoot + "\state")
foreach ($folder in $requiredFolders) {
    if (!(Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
}

function Write-DashboardLog {
    param([string]$Message)
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $Message
    [IO.File]::AppendAllText($script:logPath, $line + [Environment]::NewLine, $script:utf8NoBom)
}

function Read-DashboardJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json
    } catch {
        Write-DashboardLog ("JSON read failed: " + $Path + " | " + $_.Exception.Message)
        return $null
    }
}

function Write-DashboardJson {
    param(
        [string]$Path,
        $Value
    )
    try {
        $json = $Value | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($Path, $json, $script:utf8NoBom)
    } catch {
        Write-DashboardLog ("JSON write failed: " + $Path + " | " + $_.Exception.Message)
    }
}

function Get-UiText {
    param(
        [string]$Name,
        [string]$Fallback
    )

    if ($null -ne $script:componentSettings -and $null -ne $script:componentSettings.text) {
        $property = $script:componentSettings.text.PSObject.Properties[$Name]
        if ($null -ne $property -and ![string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }
    return $Fallback
}

function Get-ComponentNumberSetting {
    param(
        [string]$Section,
        [string]$Name,
        [double]$Fallback,
        [double]$Minimum,
        [double]$Maximum
    )

    try {
        $sectionValue = $script:componentSettings.PSObject.Properties[$Section].Value
        $property = $sectionValue.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return [Math]::Max($Minimum, [Math]::Min($Maximum, [double]$property.Value))
        }
    } catch {}
    return $Fallback
}

$script:componentSettings = Read-DashboardJson -Path $script:componentSettingsPath
$script:selectedTodoDate = (Get-Date).Date

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianAIDesktopDashboard", [ref]$createdNew)
if (!$createdNew) {
    Write-DashboardLog "A second launch was ignored by the single-instance guard."
    exit 0
}

if (!("ObsidianDashboardNative" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ObsidianDashboardNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    public static extern int GetWindowLong(IntPtr hwnd, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    public static extern int SetWindowLong(IntPtr hwnd, int index, int value);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
'@
}

. ($script:dashboardRoot + "\services\weatherService.ps1")
. ($script:dashboardRoot + "\services\aiService.ps1")
. ($script:dashboardRoot + "\services\githubService.ps1")
. ($script:dashboardRoot + "\services\systemService.ps1")
. ($script:dashboardRoot + "\services\quickToolsService.ps1")
. ($script:dashboardRoot + "\services\todoService.ps1")

function Import-DashboardXaml {
    param([string]$Path)
    $xml = New-Object Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($Path)
    $reader = New-Object Xml.XmlNodeReader($xml)
    try {
        return [Windows.Markup.XamlReader]::Load($reader)
    } finally {
        $reader.Close()
    }
}

function ConvertTo-DashboardBrush {
    param([string]$Color)
    return (New-Object Windows.Media.BrushConverter).ConvertFromString($Color)
}

function Enable-DashboardGlass {
    param([IntPtr]$Handle)

    $GWL_EXSTYLE = -20
    $WS_EX_TOOLWINDOW = 0x00000080
    $style = [ObsidianDashboardNative]::GetWindowLong($Handle, $GWL_EXSTYLE)
    [void][ObsidianDashboardNative]::SetWindowLong($Handle, $GWL_EXSTYLE, ($style -bor $WS_EX_TOOLWINDOW))

    $policy = New-Object ObsidianDashboardNative+AccentPolicy
    $policy.AccentState = 4
    $policy.AccentFlags = 2
    $policy.GradientColor = [int]0x8F111111
    $policy.AnimationId = 0
    $size = [Runtime.InteropServices.Marshal]::SizeOf($policy)
    $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try {
        [Runtime.InteropServices.Marshal]::StructureToPtr($policy, $pointer, $false)
        $data = New-Object ObsidianDashboardNative+WindowCompositionAttributeData
        $data.Attribute = 19
        $data.Data = $pointer
        $data.SizeOfData = $size
        [void][ObsidianDashboardNative]::SetWindowCompositionAttribute($Handle, [ref]$data)
    } finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
    }

    $cornerPreference = 2
    [void][ObsidianDashboardNative]::DwmSetWindowAttribute($Handle, 33, [ref]$cornerPreference, 4)
}

function Add-DashboardWidget {
    param(
        [Windows.Window]$Window,
        [string]$SlotName,
        [string]$WidgetName
    )
    $slot = $Window.FindName($SlotName)
    $path = $script:componentRoot + "\" + $WidgetName + "\view.xaml"
    $widget = Import-DashboardXaml -Path $path
    [void]$slot.Children.Add($widget)
    return $widget
}

function Enable-CardInteraction {
    param([Windows.Controls.Border]$Card)

    $Card.Add_MouseEnter({
        param($sender, $eventArgs)
        $sender.Background = ConvertTo-DashboardBrush "#24FFFFFF"
        $sender.BorderBrush = ConvertTo-DashboardBrush "#3AFFFFFF"
        if ($null -ne $sender.Effect) { $sender.Effect.Opacity = 0.70 }
        $animation = New-Object Windows.Media.Animation.DoubleAnimation
        $animation.To = -2
        $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(180))
        $animation.EasingFunction = New-Object Windows.Media.Animation.QuadraticEase
        [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
        $sender.RenderTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $animation)
    })
    $Card.Add_MouseLeave({
        param($sender, $eventArgs)
        $sender.Background = ConvertTo-DashboardBrush "#16FFFFFF"
        $sender.BorderBrush = ConvertTo-DashboardBrush "#22FFFFFF"
        if ($null -ne $sender.Effect) { $sender.Effect.Opacity = 0.52 }
        $animation = New-Object Windows.Media.Animation.DoubleAnimation
        $animation.To = 0
        $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
        $animation.EasingFunction = New-Object Windows.Media.Animation.QuadraticEase
        [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
        $sender.RenderTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $animation)
    })
}

function Enable-StatusPulse {
    param([Windows.UIElement]$Element)
    if ($null -eq $Element) { return }
    if ($null -eq $script:pulseElements) { $script:pulseElements = New-Object Collections.ArrayList }
    [void]$script:pulseElements.Add($Element)
}

function Get-AppIconSource {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) {
        $icon = [Drawing.SystemIcons]::Application
        return [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(32, 32))
    }

    if ([IO.Path]::GetExtension($Path) -ieq ".ico") {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = New-Object Uri($Path)
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    }

    try {
        $icon = [Drawing.Icon]::ExtractAssociatedIcon($Path)
        if ($null -ne $icon) {
            $source = [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(32, 32))
            $source.Freeze()
            $icon.Dispose()
            return $source
        }
    } catch {}

    $fallback = [Drawing.SystemIcons]::Application
    return [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($fallback.Handle, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(32, 32))
}

function New-CpuArcGeometry {
    param([double]$Percent)
    $value = [Math]::Max(0, [Math]::Min(99.9, $Percent))
    if ($value -le 0.1) { return $null }

    $center = 43.0
    $radius = 37.0
    $start = New-Object Windows.Point($center, ($center - $radius))
    $angle = (($value / 100.0) * 359.9) - 90.0
    $radians = $angle * [Math]::PI / 180.0
    $end = New-Object Windows.Point(($center + ($radius * [Math]::Cos($radians))), ($center + ($radius * [Math]::Sin($radians))))
    $geometry = New-Object Windows.Media.StreamGeometry
    $context = $geometry.Open()
    $context.BeginFigure($start, $false, $false)
    $context.ArcTo($end, (New-Object Windows.Size($radius, $radius)), 0, ($value -gt 50), [Windows.Media.SweepDirection]::Clockwise, $true, $false)
    $context.Close()
    $geometry.Freeze()
    return $geometry
}

function Save-DashboardLayout {
    $layout = Read-DashboardJson -Path $script:layoutPath
    if ($null -eq $layout) { $layout = New-Object psobject }
    $layout | Add-Member -NotePropertyName left -NotePropertyValue ([Math]::Round($script:window.Left, 0)) -Force
    $layout | Add-Member -NotePropertyName top -NotePropertyValue ([Math]::Round($script:window.Top, 0)) -Force
    $layout | Add-Member -NotePropertyName scale -NotePropertyValue $script:scale -Force
    $layout | Add-Member -NotePropertyName alwaysOnTop -NotePropertyValue ([bool]$script:window.Topmost) -Force
    Write-DashboardJson -Path $script:layoutPath -Value $layout
}

function Apply-DashboardLayout {
    $layout = Read-DashboardJson -Path $script:layoutPath
    if ($null -eq $layout) { return }
    $script:scale = [Math]::Max(0.80, [Math]::Min(1.20, [double]$layout.scale))
    $script:window.Width = 392 * $script:scale
    $script:window.Height = 500 * $script:scale
    $workArea = [Windows.SystemParameters]::WorkArea
    $maxLeft = [Math]::Max(96, $workArea.Right - $script:window.Width - 18)
    $maxTop = [Math]::Max($workArea.Top + 12, $workArea.Bottom - $script:window.Height - 18)
    $script:window.Left = [Math]::Min($maxLeft, [Math]::Max(96, [double]$layout.left))
    $script:window.Top = [Math]::Min($maxTop, [Math]::Max($workArea.Top + 12, [double]$layout.top))
    $script:window.Topmost = [bool]$layout.alwaysOnTop
}

if (-not ("ObsidianDesktopContextNative" -as [type])) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ObsidianDesktopContextNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extraInfo);
}
"@
}

$script:contextSessionStarted = [DateTime]::Now
$script:lastDesktopContext = $null

function Get-ObsidianAppDisplayName {
    param([string]$ProcessName)

    if ([string]::IsNullOrWhiteSpace($ProcessName)) { return Get-UiText -Name "desktopName" -Fallback "Desktop" }
    switch ($ProcessName.ToLowerInvariant()) {
        "msedge" { return "Microsoft Edge" }
        "chrome" { return "Google Chrome" }
        "code" { return "Visual Studio Code" }
        "chatgpt" { return "ChatGPT" }
        "weixin" { return Get-UiText -Name "wechat" -Fallback "Weixin" }
        "explorer" { return Get-UiText -Name "fileExplorer" -Fallback "File Explorer" }
        "systemsettings" { return Get-UiText -Name "settingsApp" -Fallback "Settings" }
        "xlsmartui" { return Get-UiText -Name "tianxiAgent" -Fallback "Tianxi Agent" }
        "xlaui" { return Get-UiText -Name "tianxiAgent" -Fallback "Tianxi Agent" }
        "windowsterminal" { return "Windows Terminal" }
        "powershell" { return "Windows PowerShell" }
        "pwsh" { return "PowerShell" }
        "spotify" { return "Spotify" }
        "vlc" { return "VLC" }
        "applicationframehost" { return Get-UiText -Name "windowsMedia" -Fallback "Windows Media" }
    }
    return $ProcessName
}

function Get-ObsidianDesktopContext {
    try {
        $handle = [ObsidianDesktopContextNative]::GetForegroundWindow()
        if ($handle -eq [IntPtr]::Zero) { throw "No foreground window." }

        $titleBuffer = New-Object Text.StringBuilder 768
        [void][ObsidianDesktopContextNative]::GetWindowText($handle, $titleBuffer, $titleBuffer.Capacity)
        [uint32]$processId = 0
        [void][ObsidianDesktopContextNative]::GetWindowThreadProcessId($handle, [ref]$processId)
        $process = Get-Process -Id $processId -ErrorAction Stop
        $processName = [string]$process.ProcessName
        $title = $titleBuffer.ToString().Trim()

        $rect = New-Object ObsidianDesktopContextNative+RECT
        [void][ObsidianDesktopContextNative]::GetWindowRect($handle, [ref]$rect)
        $screen = [Windows.Forms.Screen]::FromHandle($handle)
        $bounds = $screen.Bounds
        $isFullscreen = [Math]::Abs($rect.Left - $bounds.Left) -le 4 -and
            [Math]::Abs($rect.Top - $bounds.Top) -le 4 -and
            [Math]::Abs($rect.Right - $bounds.Right) -le 4 -and
            [Math]::Abs($rect.Bottom - $bounds.Bottom) -le 4

        $mediaProcesses = @("msedge", "chrome", "firefox", "vlc", "mpv", "potplayer", "spotify", "applicationframehost")
        $developmentProcesses = @("code", "chatgpt", "powershell", "pwsh", "windowsterminal", "devenv", "idea64", "pycharm64")
        $lowerProcess = $processName.ToLowerInvariant()
        $mediaWords = "\u7535\u5F71|\u5F71\u9662|\u5267\u96C6|episode|season|youtube|bilibili|netflix|player|\u64AD\u653E"
        $isMedia = ($mediaProcesses -contains $lowerProcess) -and ($isFullscreen -or $title -match $mediaWords)
        $mode = if ($isMedia) { "MEDIA" } elseif ($developmentProcesses -contains $lowerProcess) { "DEEP WORK" } else { "DESKTOP" }

        return [pscustomobject]@{
            ProcessName = $processName
            AppName = Get-ObsidianAppDisplayName -ProcessName $processName
            WindowTitle = if ($title) { $title } else { Get-UiText -Name "mediaQuiet" -Fallback "Quiet desktop" }
            IsFullscreen = $isFullscreen
            IsMedia = $isMedia
            Mode = $mode
        }
    } catch {
        return [pscustomobject]@{
            ProcessName = ""
            AppName = Get-UiText -Name "desktopName" -Fallback "Desktop"
            WindowTitle = Get-UiText -Name "activeWindowWaiting" -Fallback "Waiting for an active window"
            IsFullscreen = $false
            IsMedia = $false
            Mode = "DESKTOP"
        }
    }
}

function Update-ContextWidgets {
    if ($null -eq $script:mediaWidget -or $null -eq $script:workspaceWidget) { return }

    $context = Get-ObsidianDesktopContext
    $script:lastDesktopContext = $context
    $cleanTitle = $context.WindowTitle -replace "\s+-\s+Microsoft.*Edge$", "" -replace "\s+-\s+Google Chrome$", ""

    $script:workspaceWidget.FindName("ActiveAppText").Text = $context.AppName
    $script:workspaceWidget.FindName("WindowTitleText").Text = $cleanTitle
    $displayMode = switch ($context.Mode) {
        "MEDIA" { Get-UiText -Name "modeMedia" -Fallback "Media" }
        "DEEP WORK" { Get-UiText -Name "modeDeepWork" -Fallback "Deep work" }
        default { Get-UiText -Name "modeDesktop" -Fallback "Desktop" }
    }
    $script:workspaceWidget.FindName("SessionModeText").Text = $displayMode
    $elapsed = [DateTime]::Now - $script:contextSessionStarted
    $script:workspaceWidget.FindName("SessionTimeText").Text = $elapsed.ToString("hh\:mm")
    $workspaceColor = if ($context.Mode -eq "MEDIA") { "#FFFDE68A" } elseif ($context.Mode -eq "DEEP WORK") { "#FFA7F3D0" } else { "#70FFFFFF" }
    $script:workspaceWidget.FindName("WorkspaceDot").Fill = ConvertTo-DashboardBrush $workspaceColor

    if ($context.IsMedia) {
        $script:mediaWidget.FindName("MediaAppText").Text = $context.AppName
        $script:mediaWidget.FindName("MediaTitleText").Text = $cleanTitle
        $script:mediaWidget.FindName("MediaStateText").Text = Get-UiText -Name "mediaPlaying" -Fallback "Playing"
        $script:mediaWidget.FindName("MediaModeText").Text = if ($context.IsFullscreen) { Get-UiText -Name "mediaFullscreen" -Fallback "Fullscreen quiet mode" } else { Get-UiText -Name "mediaSession" -Fallback "Media session" }
        $script:mediaWidget.FindName("MediaDot").Fill = ConvertTo-DashboardBrush "#FFA7F3D0"
    } else {
        $script:mediaWidget.FindName("MediaAppText").Text = Get-UiText -Name "mediaNone" -Fallback "No foreground media"
        $script:mediaWidget.FindName("MediaTitleText").Text = Get-UiText -Name "mediaQuiet" -Fallback "Quiet desktop"
        $script:mediaWidget.FindName("MediaStateText").Text = Get-UiText -Name "mediaIdle" -Fallback "Idle"
        $script:mediaWidget.FindName("MediaModeText").Text = Get-UiText -Name "mediaAmbient" -Fallback "Ambient"
        $script:mediaWidget.FindName("MediaDot").Fill = ConvertTo-DashboardBrush "#58FFFFFF"
    }
}

function Send-ObsidianMediaPlayPause {
    [ObsidianDesktopContextNative]::keybd_event(0xB3, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 35
    [ObsidianDesktopContextNative]::keybd_event(0xB3, 0, 2, [UIntPtr]::Zero)
}

function Update-TimeWeatherWidget {
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
    $now = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $zone)
    $culture = [Globalization.CultureInfo]::GetCultureInfo("zh-CN")
    $script:timeWidget.FindName("TimeText").Text = $now.ToString("HH:mm")
    $script:timeWidget.FindName("DateText").Text = $now.ToString("yyyy/MM/dd")
    $script:timeWidget.FindName("WeekdayText").Text = $now.ToString("dddd", $culture)

    $weather = Get-WeatherSnapshot -DataPath $script:weatherPath
    $condition = switch ([string]$weather.Condition) {
        "WEATHER SERVICE OFFLINE" { Get-UiText -Name "weatherOffline" -Fallback "Weather offline" }
        "WAITING FOR WEATHER DATA" { Get-UiText -Name "weatherWaiting" -Fallback "Waiting for weather" }
        "WEATHER API REQUIRED" { Get-UiText -Name "weatherRequired" -Fallback "Weather setup required" }
        default { [string]$weather.Condition }
    }
    $updatedAt = if ([string]$weather.UpdatedAt -eq "NOT SYNCED") { Get-UiText -Name "notSynced" -Fallback "Not synced" } else { [string]$weather.UpdatedAt }
    $script:timeWidget.FindName("LocationText").Text = $weather.Location
    $script:timeWidget.FindName("ConditionText").Text = $condition
    $script:timeWidget.FindName("TemperatureText").Text = if ($weather.Temperature -eq "--") { "--" + [char]0x00B0 } else { $weather.Temperature + [char]0x00B0 }
    $script:timeWidget.FindName("HumidityText").Text = (Get-UiText -Name "humidity" -Fallback "Humidity") + "  " + $weather.Humidity
    $script:timeWidget.FindName("AirQualityText").Text = (Get-UiText -Name "airQuality" -Fallback "Air") + "  " + $weather.AirQuality
    $script:timeWidget.FindName("WeatherUpdatedText").Text = $updatedAt
    $script:timeWidget.FindName("WeatherDot").Fill = ConvertTo-DashboardBrush $(if ($weather.IsConfigured) { "#FFA7F3D0" } else { "#FFFDE68A" })
}

function Update-AIAgentWidget {
    $snapshot = Get-AIAgentSnapshot -DataPath $script:agentPath
    $panel = $script:aiWidget.FindName("AgentsPanel")
    $panel.Children.Clear()

    foreach ($agent in @($snapshot.Agents | Select-Object -First 4)) {
        $row = New-Object Windows.Controls.Grid
        $row.Height = 20
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(12) }))
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star) }))
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = [Windows.GridLength]::Auto }))

        $dot = New-Object Windows.Shapes.Ellipse
        $dot.Width = 5
        $dot.Height = 5
        $dot.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $dot.Fill = ConvertTo-DashboardBrush $(switch ([string]$agent.status) { "Working" { "#FFFDE68A" } "Offline" { "#FFFDA4AF" } default { "#FFA7F3D0" } })
        [Windows.Controls.Grid]::SetColumn($dot, 0)

        $name = New-Object Windows.Controls.TextBlock
        $name.Text = [string]$agent.name
        $name.Foreground = ConvertTo-DashboardBrush "#D9FFFFFF"
        $name.FontSize = 9
        $name.VerticalAlignment = [Windows.VerticalAlignment]::Center
        [Windows.Controls.Grid]::SetColumn($name, 1)

        $status = New-Object Windows.Controls.TextBlock
        $status.Text = switch ([string]$agent.status) {
            "Working" { Get-UiText -Name "agentWorking" -Fallback "Working" }
            "Offline" { Get-UiText -Name "agentOffline" -Fallback "Offline" }
            default { Get-UiText -Name "agentReady" -Fallback "Ready" }
        }
        $status.Foreground = ConvertTo-DashboardBrush "#70FFFFFF"
        $status.FontSize = 8
        $status.VerticalAlignment = [Windows.VerticalAlignment]::Center
        [Windows.Controls.Grid]::SetColumn($status, 2)

        [void]$row.Children.Add($dot)
        [void]$row.Children.Add($name)
        [void]$row.Children.Add($status)
        [void]$panel.Children.Add($row)
    }

    $script:aiWidget.FindName("TaskText").Text = $snapshot.CurrentTask
    $script:aiWidget.FindName("ProjectText").Text = $snapshot.CurrentProject
    $script:aiWidget.FindName("ProgressText").Text = [string]$snapshot.Progress + "%"
    $script:aiWidget.FindName("ProgressFill").Width = 280 * ([double]$snapshot.Progress / 100.0)
}

function Update-GithubWidget {
    $snapshot = Get-GithubSnapshot -DataPath $script:githubPath -DashboardRoot $script:dashboardRoot
    $repository = if ([string]$snapshot.Repository -eq "NO LOCAL REPO") { Get-UiText -Name "noRepository" -Fallback "No local repository" } else { [string]$snapshot.Repository }
    $latest = if ([string]$snapshot.LatestCommit -in @("Configure repositoryPath", "GITHUB SERVICE OFFLINE")) { Get-UiText -Name "repositoryHelp" -Fallback "Configure repository path" } else { [string]$snapshot.LatestCommit }
    $branch = if ([string]$snapshot.Branch -eq "NO LOCAL REPO") { Get-UiText -Name "notConnected" -Fallback "Not connected" } else { [string]$snapshot.Branch }
    $script:githubWidget.FindName("RepositoryText").Text = $repository
    $script:githubWidget.FindName("BranchText").Text = (Get-UiText -Name "branch" -Fallback "Branch") + "  " + $branch
    $script:githubWidget.FindName("CommitsText").Text = (Get-UiText -Name "commits" -Fallback "Commits") + "  " + $snapshot.Commits
    $script:githubWidget.FindName("LatestCommitText").Text = $latest
    $script:githubWidget.FindName("ProjectText").Text = (Get-UiText -Name "project" -Fallback "Project") + "  " + $snapshot.Project
}

function Apply-SystemSnapshot {
    param($Snapshot)
    try {
        $snapshot = $Snapshot
        $script:systemWidget.FindName("CpuValue").Text = [Math]::Round($snapshot.Cpu).ToString() + "%"
        $script:systemWidget.FindName("CpuArc").Data = New-CpuArcGeometry -Percent $snapshot.Cpu
        $script:systemWidget.FindName("GpuValue").Text = (Get-UiText -Name "gpu" -Fallback "GPU") + "  " + [Math]::Round($snapshot.Gpu).ToString() + "%"
        $script:systemWidget.FindName("RamValue").Text = (Get-UiText -Name "ram" -Fallback "RAM") + "  " + [Math]::Round($snapshot.Ram).ToString() + "%"
        $script:systemWidget.FindName("SsdValue").Text = (Get-UiText -Name "disk" -Fallback "Disk") + "  " + [Math]::Round($snapshot.Ssd).ToString() + "%"
        $script:systemWidget.FindName("BatteryValue").Text = if ($null -eq $snapshot.Battery) { (Get-UiText -Name "battery" -Fallback "Battery") + "  --" } else { (Get-UiText -Name "battery" -Fallback "Battery") + "  " + [Math]::Round($snapshot.Battery).ToString() + "%" }
        $script:systemWidget.FindName("TemperatureValue").Text = if ($null -eq $snapshot.Temperature) { (Get-UiText -Name "temperature" -Fallback "Temp") + "  --" } else { (Get-UiText -Name "temperature" -Fallback "Temp") + "  " + [Math]::Round($snapshot.Temperature).ToString() + [char]0x00B0 }
        $script:systemWidget.FindName("NetworkValue").Text = (Get-UiText -Name "network" -Fallback "Net") + "  " + $snapshot.NetworkMBps.ToString("0.0") + "M"

        $deviceParts = @([string]$snapshot.Manufacturer, [string]$snapshot.Model) | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
        $deviceSummary = ($deviceParts -join " ").Trim()
        if ([string]::IsNullOrWhiteSpace($deviceSummary)) { $deviceSummary = [string]$snapshot.ComputerName }
        $script:systemWidget.FindName("DeviceInfoText").Text = $deviceSummary + "  |  " + [string]$snapshot.OperatingSystem

        $tooltipLines = @(
            (Get-UiText -Name "deviceName" -Fallback "Device") + ": " + [string]$snapshot.ComputerName,
            (Get-UiText -Name "system" -Fallback "System") + ": " + [string]$snapshot.OperatingSystem + "  " + [string]$snapshot.OsBuild,
            (Get-UiText -Name "processor" -Fallback "CPU") + ": " + [string]$snapshot.ProcessorName,
            (Get-UiText -Name "graphics" -Fallback "GPU") + ": " + [string]$snapshot.GraphicsName,
            (Get-UiText -Name "memory" -Fallback "Memory") + ": " + [string]$snapshot.MemoryTotalGB + " GB"
        )
        $script:systemWidget.ToolTip = $tooltipLines -join [Environment]::NewLine
    } catch {
        Write-DashboardLog ("System monitor update failed: " + $_.Exception.Message)
    }
}

function Initialize-SystemSampler {
    $script:systemRunspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $script:systemRunspace.ApartmentState = [Threading.ApartmentState]::MTA
    $script:systemRunspace.Open()

    $initializer = [Management.Automation.PowerShell]::Create()
    $initializer.Runspace = $script:systemRunspace
    $serviceSource = [IO.File]::ReadAllText($script:dashboardRoot + "\services\systemService.ps1", [Text.Encoding]::UTF8)
    [void]$initializer.AddScript($serviceSource)
    try {
        [void]$initializer.Invoke()
        if ($initializer.HadErrors) {
            Write-DashboardLog "System sampler initialization returned errors."
        }
    } finally {
        $initializer.Dispose()
    }
    $script:systemPowerShell = $null
    $script:systemAsyncResult = $null
    $script:lastSystemSample = [DateTime]::MinValue
}

function Start-SystemSample {
    if ($null -ne $script:systemAsyncResult) { return }
    $script:systemPowerShell = [Management.Automation.PowerShell]::Create()
    $script:systemPowerShell.Runspace = $script:systemRunspace
    [void]$script:systemPowerShell.AddScript("Get-SystemSnapshot | ConvertTo-Json -Compress -Depth 4")
    $script:systemAsyncResult = $script:systemPowerShell.BeginInvoke()
    $script:lastSystemSample = Get-Date
}

function Complete-SystemSample {
    if ($null -ne $script:systemAsyncResult -and $script:systemAsyncResult.IsCompleted) {
        try {
            $result = $script:systemPowerShell.EndInvoke($script:systemAsyncResult)
            $json = (@($result) | ForEach-Object { $_.ToString() }) -join ""
            if (![string]::IsNullOrWhiteSpace($json)) {
                Apply-SystemSnapshot -Snapshot ($json | ConvertFrom-Json)
            }
            if ($script:systemPowerShell.HadErrors) {
                Write-DashboardLog "System sampler completed with non-fatal errors."
            }
        } catch {
            Write-DashboardLog ("System sampler completion failed: " + $_.Exception.Message)
        } finally {
            $script:systemPowerShell.Dispose()
            $script:systemPowerShell = $null
            $script:systemAsyncResult = $null
        }
    }

    if ($null -eq $script:systemAsyncResult -and ((Get-Date) - $script:lastSystemSample).TotalSeconds -ge 12) {
        Start-SystemSample
    }
}

function Stop-SystemSampler {
    if ($null -ne $script:systemPowerShell) {
        try { $script:systemPowerShell.Stop() } catch {}
        $script:systemPowerShell.Dispose()
        $script:systemPowerShell = $null
        $script:systemAsyncResult = $null
    }
    if ($null -ne $script:systemRunspace) {
        try { $script:systemRunspace.Close() } catch {}
        $script:systemRunspace.Dispose()
        $script:systemRunspace = $null
    }
}

function Update-QuickToolsWidget {
    $tools = Get-QuickTools -DashboardRoot $script:dashboardRoot
    $panel = $script:quickToolsWidget.FindName("ToolsPanel")
    $panel.Children.Clear()
    $available = 0

    foreach ($tool in $tools) {
        $button = New-Object Windows.Controls.Button
        $button.Width = 36
        $button.Height = 36
        $button.Margin = New-Object Windows.Thickness(1)
        $button.Padding = New-Object Windows.Thickness(4)
        $button.Background = [Windows.Media.Brushes]::Transparent
        $button.BorderBrush = ConvertTo-DashboardBrush "#18FFFFFF"
        $button.BorderThickness = New-Object Windows.Thickness(1)
        $button.Cursor = [Windows.Input.Cursors]::Hand
        $button.Style = $script:window.Resources["IconButtonStyle"]
        $button.ToolTip = if ($tool.IsAvailable) { $tool.Name } else { $tool.Name + " - not found" }
        $button.Tag = $tool
        $button.IsEnabled = [bool]$tool.IsAvailable
        $button.Opacity = if ($tool.IsAvailable) { 1.0 } else { 0.35 }

        $image = New-Object Windows.Controls.Image
        $image.Width = 26
        $image.Height = 26
        $image.Stretch = [Windows.Media.Stretch]::Uniform
        $image.Source = Get-AppIconSource -Path ([string]$tool.IconPath)
        $button.Content = $image
        $button.Add_Click({
            param($sender, $eventArgs)
            try {
                Start-QuickTool -Tool $sender.Tag
                Write-DashboardLog ("Quick tool launched: " + $sender.Tag.Name)
            } catch {
                Write-DashboardLog ("Quick tool launch failed: " + $_.Exception.Message)
            }
        })
        [void]$panel.Children.Add($button)
        if ($tool.IsAvailable) { $available++ }
    }
    $script:quickToolsWidget.FindName("ToolsStatusText").Text = $available.ToString() + " / 5 " + (Get-UiText -Name "availableTools" -Fallback "tools available")
}

function Hide-TodoInput {
    if ($null -eq $script:todoWidget) { return }
    $script:todoWidget.FindName("TodoInputPanel").Visibility = [Windows.Visibility]::Collapsed
    $script:todoWidget.FindName("TasksScrollViewer").Visibility = [Windows.Visibility]::Visible
    $script:todoWidget.FindName("TodoInputText").Text = ""
    $script:todoEditActive = $false
}

function Show-TodoInput {
    if ($null -eq $script:todoWidget) { return }
    $script:todoEditActive = $true
    $script:todoWidget.FindName("TasksScrollViewer").Visibility = [Windows.Visibility]::Hidden
    $script:todoWidget.FindName("TodoInputPanel").Visibility = [Windows.Visibility]::Visible
    $input = $script:todoWidget.FindName("TodoInputText")
    $input.Text = ""
    [void]$input.Focus()
}

function Update-TodoWidget {
    param([switch]$Force)

    if ($script:todoEditActive -and !$Force) { return }
    $dateKey = $script:selectedTodoDate.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
    $snapshot = Get-TodoSnapshot -DataPath $script:todoPath -Date $dateKey
    $panel = $script:todoWidget.FindName("TasksPanel")
    $panel.Children.Clear()
    $maxTasks = [int](Get-ComponentNumberSetting -Section "todo" -Name "maxTasksPerDay" -Fallback 12 -Minimum 1 -Maximum 30)
    $tasks = @($snapshot.Tasks | Sort-Object @{ Expression = { [bool]$_.done } }, @{ Expression = { -[int]$_.priority } } | Select-Object -First $maxTasks)
    $completed = @($tasks | Where-Object { [bool]$_.done }).Count

    if ($tasks.Count -eq 0) {
        $empty = New-Object Windows.Controls.TextBlock
        $empty.Text = Get-UiText -Name "todoEmpty" -Fallback "No plans for today"
        $empty.Foreground = ConvertTo-DashboardBrush "#55FFFFFF"
        $empty.FontSize = 8
        $empty.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
        $empty.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $empty.Margin = New-Object Windows.Thickness(0, 9, 0, 0)
        [void]$panel.Children.Add($empty)
    }

    foreach ($task in $tasks) {
        $row = New-Object Windows.Controls.Grid
        $row.Height = 22
        $row.Margin = New-Object Windows.Thickness(0, 0, 0, 1)
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(18) }))
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(16) }))
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star) }))
        [void]$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = New-Object Windows.GridLength(22) }))

        $toggle = New-Object Windows.Controls.Primitives.ToggleButton
        $toggle.IsChecked = [bool]$task.done
        $toggle.Width = 17
        $toggle.Height = 20
        $toggle.Cursor = [Windows.Input.Cursors]::Hand
        $toggle.Style = $script:window.Resources["TodoToggleStyle"]
        $indicator = New-Object Windows.Controls.Border
        $indicator.Width = 10
        $indicator.Height = 10
        $indicator.CornerRadius = New-Object Windows.CornerRadius(3)
        $indicator.BorderThickness = New-Object Windows.Thickness(1)
        $indicator.BorderBrush = ConvertTo-DashboardBrush "#55FFFFFF"
        $indicator.Background = ConvertTo-DashboardBrush $(if ([bool]$task.done) { "#FFA7F3D0" } else { "#0CFFFFFF" })
        $toggle.Content = $indicator
        $toggle.Tag = [pscustomobject]@{ Id = [string]$task.id; Date = $dateKey }
        $toggle.ToolTip = if ([bool]$task.done) { Get-UiText -Name "todoCompleted" -Fallback "Completed" } else { Get-UiText -Name "todoPriorityNormal" -Fallback "Open" }
        $toggle.Add_Click({
            param($sender, $eventArgs)
            Set-TodoState -DataPath $script:todoPath -Date ([string]$sender.Tag.Date) -TaskId ([string]$sender.Tag.Id) -Done ([bool]$sender.IsChecked)
            Update-TodoWidget -Force
        })
        [Windows.Controls.Grid]::SetColumn($toggle, 0)

        $priority = if ($null -eq $task.PSObject.Properties["priority"]) { 0 } else { [int]$task.priority }
        $priorityButton = New-Object Windows.Controls.Button
        $priorityButton.Width = 14
        $priorityButton.Height = 18
        $priorityButton.Background = [Windows.Media.Brushes]::Transparent
        $priorityButton.BorderThickness = New-Object Windows.Thickness(0)
        $priorityButton.Cursor = [Windows.Input.Cursors]::Hand
        $priorityDot = New-Object Windows.Shapes.Ellipse
        $priorityDot.Width = 6
        $priorityDot.Height = 6
        $priorityDot.Fill = ConvertTo-DashboardBrush $(if ($priority -gt 0) { "#FFFDE68A" } else { "#28FFFFFF" })
        $priorityButton.Content = $priorityDot
        $priorityButton.Tag = [pscustomobject]@{ Id = [string]$task.id; Date = $dateKey; Priority = $priority }
        $priorityButton.ToolTip = if ($priority -gt 0) { Get-UiText -Name "todoPriorityHigh" -Fallback "Important" } else { Get-UiText -Name "todoPriorityNormal" -Fallback "Normal" }
        $priorityButton.Add_Click({
            param($sender, $eventArgs)
            $nextPriority = if ([int]$sender.Tag.Priority -gt 0) { 0 } else { 1 }
            Set-TodoPriority -DataPath $script:todoPath -Date ([string]$sender.Tag.Date) -TaskId ([string]$sender.Tag.Id) -Priority $nextPriority
            Update-TodoWidget -Force
        })
        [Windows.Controls.Grid]::SetColumn($priorityButton, 1)

        $editor = New-Object Windows.Controls.TextBox
        $editor.Text = [string]$task.title
        $editor.Background = [Windows.Media.Brushes]::Transparent
        $editor.BorderThickness = New-Object Windows.Thickness(0)
        $editor.Padding = New-Object Windows.Thickness(3, 1, 3, 1)
        $editor.Foreground = ConvertTo-DashboardBrush $(if ([bool]$task.done) { "#70FFFFFF" } else { "#CFFFFFFF" })
        $editor.CaretBrush = ConvertTo-DashboardBrush "#FFFFFFFF"
        $editor.FontSize = 8
        $editor.MaxLength = 80
        $editor.TextWrapping = [Windows.TextWrapping]::NoWrap
        $editor.VerticalContentAlignment = [Windows.VerticalAlignment]::Center
        $editor.Tag = [pscustomobject]@{ Id = [string]$task.id; Date = $dateKey; Original = [string]$task.title }
        $editor.Add_GotKeyboardFocus({ $script:todoEditActive = $true })
        $editor.Add_LostKeyboardFocus({
            param($sender, $eventArgs)
            $script:todoEditActive = $false
            if (![string]::IsNullOrWhiteSpace($sender.Text) -and $sender.Text.Trim() -ne [string]$sender.Tag.Original) {
                [void](Set-TodoTitle -DataPath $script:todoPath -Date ([string]$sender.Tag.Date) -TaskId ([string]$sender.Tag.Id) -Title $sender.Text)
                $sender.Tag.Original = $sender.Text.Trim()
            } elseif ([string]::IsNullOrWhiteSpace($sender.Text)) {
                $sender.Text = [string]$sender.Tag.Original
            }
        })
        $editor.Add_KeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.Key -eq [Windows.Input.Key]::Enter) {
                [Windows.Input.Keyboard]::ClearFocus()
                $eventArgs.Handled = $true
            } elseif ($eventArgs.Key -eq [Windows.Input.Key]::Escape) {
                $sender.Text = [string]$sender.Tag.Original
                [Windows.Input.Keyboard]::ClearFocus()
                $eventArgs.Handled = $true
            }
        })
        [Windows.Controls.Grid]::SetColumn($editor, 2)

        $deleteButton = New-Object Windows.Controls.Button
        $deleteButton.Width = 20
        $deleteButton.Height = 19
        $deleteButton.Content = [char]0xE711
        $deleteButton.FontFamily = New-Object Windows.Media.FontFamily("Segoe Fluent Icons")
        $deleteButton.FontSize = 8
        $deleteButton.Foreground = ConvertTo-DashboardBrush "#68FFFFFF"
        $deleteButton.Background = [Windows.Media.Brushes]::Transparent
        $deleteButton.BorderThickness = New-Object Windows.Thickness(0)
        $deleteButton.Cursor = [Windows.Input.Cursors]::Hand
        $deleteButton.Style = $script:window.Resources["IconButtonStyle"]
        $deleteButton.Tag = [pscustomobject]@{ Id = [string]$task.id; Date = $dateKey }
        $deleteButton.ToolTip = Get-UiText -Name "deletePlan" -Fallback "Delete"
        $deleteButton.Add_Click({
            param($sender, $eventArgs)
            Remove-TodoTask -DataPath $script:todoPath -Date ([string]$sender.Tag.Date) -TaskId ([string]$sender.Tag.Id)
            Update-TodoWidget -Force
        })
        [Windows.Controls.Grid]::SetColumn($deleteButton, 3)

        [void]$row.Children.Add($toggle)
        [void]$row.Children.Add($priorityButton)
        [void]$row.Children.Add($editor)
        [void]$row.Children.Add($deleteButton)
        [void]$panel.Children.Add($row)
    }

    $culture = [Globalization.CultureInfo]::GetCultureInfo("zh-CN")
    $datePrefix = if ($script:selectedTodoDate.Date -eq (Get-Date).Date) { Get-UiText -Name "todoToday" -Fallback "Today" } else { $script:selectedTodoDate.ToString("dddd", $culture) }
    $dateFormat = Get-UiText -Name "todoDateFormat" -Fallback "MM/dd"
    $script:todoWidget.FindName("TodoDateText").Text = $datePrefix + "  " + $script:selectedTodoDate.ToString($dateFormat, $culture)
    $summaryFormat = Get-UiText -Name "todoCompleted" -Fallback "Completed {0}/{1}"
    $energyFormat = Get-UiText -Name "todoEnergy" -Fallback "Energy {0}%"
    $energy = if ($tasks.Count -eq 0) { 0 } else { [int][Math]::Round(($completed / [double]$tasks.Count) * 100) }
    $script:todoWidget.FindName("TodoSummaryText").Text = $summaryFormat -f $completed, $tasks.Count
    $script:todoWidget.FindName("TodoEnergyText").Text = $energyFormat -f $energy
    $script:todoWidget.FindName("TodoDot").Fill = ConvertTo-DashboardBrush $(if ($tasks.Count -gt 0 -and $completed -eq $tasks.Count) { "#FFA7F3D0" } elseif ($tasks.Count -gt 0) { "#FFFDE68A" } else { "#48FFFFFF" })
}

function Add-SelectedTodoTask {
    $input = $script:todoWidget.FindName("TodoInputText")
    $dateKey = $script:selectedTodoDate.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
    $maxTasks = [int](Get-ComponentNumberSetting -Section "todo" -Name "maxTasksPerDay" -Fallback 12 -Minimum 1 -Maximum 30)
    if (Add-TodoTask -DataPath $script:todoPath -Date $dateKey -Title $input.Text -MaxTasks $maxTasks) {
        Hide-TodoInput
        Update-TodoWidget -Force
    }
}

function Apply-ComponentTextSettings {
    if ($null -eq $script:window) { return }
    $script:window.FindName("DashboardTitleText").Text = Get-UiText -Name "dashboardTitle" -Fallback "Obsidian Desktop"
    $script:timeWidget.FindName("TimeWeatherTitleText").Text = Get-UiText -Name "timeWeatherTitle" -Fallback "Time and Weather"
    $script:mediaWidget.FindName("MediaTitleLabel").Text = Get-UiText -Name "mediaTitle" -Fallback "Now Playing"
    $script:systemWidget.FindName("SystemTitleText").Text = Get-UiText -Name "systemTitle" -Fallback "Computer"
    $script:todoWidget.FindName("TodoTitleText").Text = Get-UiText -Name "todoTitle" -Fallback "Daily Plan"
    $script:workspaceWidget.FindName("WorkspaceTitleText").Text = Get-UiText -Name "workspaceTitle" -Fallback "Workspace"
    $script:aiWidget.FindName("AiTitleText").Text = Get-UiText -Name "aiTitle" -Fallback "AI Core"
    $script:githubWidget.FindName("GithubTitleText").Text = Get-UiText -Name "githubTitle" -Fallback "GitHub"
    $script:quickToolsWidget.FindName("QuickToolsTitleText").Text = Get-UiText -Name "quickToolsTitle" -Fallback "Quick Tools"
}

function Refresh-ComponentSettings {
    $settings = Read-DashboardJson -Path $script:componentSettingsPath
    if ($null -ne $settings) { $script:componentSettings = $settings }
    Apply-ComponentTextSettings
}

try {
    $script:window = Import-DashboardXaml -Path ($script:dashboardRoot + "\Dashboard.xaml")
    $script:scale = 1.0
    Initialize-SystemSampler

    $script:timeWidget = Add-DashboardWidget -Window $script:window -SlotName "TimeWeatherSlot" -WidgetName "TimeWeatherWidget"
    $script:aiWidget = Add-DashboardWidget -Window $script:window -SlotName "AIAgentSlot" -WidgetName "AIAgentWidget"
    $script:githubWidget = Add-DashboardWidget -Window $script:window -SlotName "GithubSlot" -WidgetName "GithubWidget"
    $script:quickToolsWidget = Add-DashboardWidget -Window $script:window -SlotName "QuickToolsSlot" -WidgetName "QuickToolsWidget"
    $script:systemWidget = Add-DashboardWidget -Window $script:window -SlotName "SystemMonitorSlot" -WidgetName "SystemMonitorWidget"
    $script:todoWidget = Add-DashboardWidget -Window $script:window -SlotName "TodoSlot" -WidgetName "TodoWidget"
    $script:mediaWidget = Add-DashboardWidget -Window $script:window -SlotName "MediaSlot" -WidgetName "MediaWidget"
    $script:workspaceWidget = Add-DashboardWidget -Window $script:window -SlotName "WorkspacePulseSlot" -WidgetName "WorkspacePulseWidget"
    Apply-ComponentTextSettings

    foreach ($widget in @($script:timeWidget, $script:aiWidget, $script:githubWidget, $script:quickToolsWidget, $script:systemWidget, $script:todoWidget, $script:mediaWidget, $script:workspaceWidget)) {
        Enable-CardInteraction -Card $widget
    }
    foreach ($dot in @(
        $script:timeWidget.FindName("WeatherDot"),
        $script:aiWidget.FindName("CoreDot"),
        $script:quickToolsWidget.FindName("ToolsDot"),
        $script:todoWidget.FindName("TodoDot"),
        $script:mediaWidget.FindName("MediaDot"),
        $script:workspaceWidget.FindName("WorkspaceDot")
    )) { Enable-StatusPulse -Element $dot }

    Apply-DashboardLayout

    $script:window.Add_SourceInitialized({
        $helper = New-Object Windows.Interop.WindowInteropHelper($script:window)
        Enable-DashboardGlass -Handle $helper.Handle
    })

    $script:window.FindName("CloseButton").Add_Click({ $script:window.Close() })
    $script:window.FindName("DragHeader").Add_MouseLeftButtonDown({
        param($sender, $eventArgs)
        if ($eventArgs.ClickCount -eq 2) {
            $workArea = [Windows.SystemParameters]::WorkArea
            $script:window.Left = $workArea.Right - $script:window.Width - 18
            $script:window.Top = $workArea.Top + 18
            Save-DashboardLayout
            return
        }
        try {
            $script:window.DragMove()
            Save-DashboardLayout
        } catch {}
    })
    $script:window.Add_MouseWheel({
        param($sender, $eventArgs)
        if (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -eq 0) { return }
        $delta = if ($eventArgs.Delta -gt 0) { 0.05 } else { -0.05 }
        $script:scale = [Math]::Max(0.80, [Math]::Min(1.20, $script:scale + $delta))
        $script:window.Width = 392 * $script:scale
        $script:window.Height = 500 * $script:scale
        Save-DashboardLayout
        $eventArgs.Handled = $true
    })

    $script:mediaWidget.FindName("MediaPlayPauseButton").Add_Click({
        Send-ObsidianMediaPlayPause
        Update-ContextWidgets
    })

    $script:todoEditActive = $false
    $script:todoWidget.FindName("AddTodoButton").Add_Click({ Show-TodoInput })
    $script:todoWidget.FindName("CancelTodoButton").Add_Click({ Hide-TodoInput })
    $script:todoWidget.FindName("ConfirmTodoButton").Add_Click({ Add-SelectedTodoTask })
    $script:todoWidget.FindName("PreviousDayButton").Add_Click({
        Hide-TodoInput
        $script:selectedTodoDate = $script:selectedTodoDate.AddDays(-1)
        Update-TodoWidget -Force
    })
    $script:todoWidget.FindName("NextDayButton").Add_Click({
        Hide-TodoInput
        $script:selectedTodoDate = $script:selectedTodoDate.AddDays(1)
        Update-TodoWidget -Force
    })
    $script:todoWidget.FindName("TodayButton").Add_Click({
        Hide-TodoInput
        $script:selectedTodoDate = (Get-Date).Date
        Update-TodoWidget -Force
    })
    $script:todoWidget.FindName("TodoInputText").Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -eq [Windows.Input.Key]::Enter) {
            Add-SelectedTodoTask
            $eventArgs.Handled = $true
        } elseif ($eventArgs.Key -eq [Windows.Input.Key]::Escape) {
            Hide-TodoInput
            $eventArgs.Handled = $true
        }
    })

    $timeTimer = New-Object Windows.Threading.DispatcherTimer
    $timeTimer.Interval = [TimeSpan]::FromSeconds(1)
    $timeTimer.Add_Tick({ Update-TimeWeatherWidget })

    $dataTimer = New-Object Windows.Threading.DispatcherTimer
    $dataTimer.Interval = [TimeSpan]::FromSeconds(10)
    $dataTimer.Add_Tick({
        try {
            Refresh-ComponentSettings
            Update-AIAgentWidget
            Update-TodoWidget
        } catch {
            Write-DashboardLog ("Data refresh failed: " + $_.Exception.Message)
        }
    })

    $contextTimer = New-Object Windows.Threading.DispatcherTimer
    $contextTimer.Interval = [TimeSpan]::FromSeconds(2)
    $contextTimer.Add_Tick({ Update-ContextWidgets })

    $githubTimer = New-Object Windows.Threading.DispatcherTimer
    $githubTimer.Interval = [TimeSpan]::FromSeconds(30)
    $githubTimer.Add_Tick({ Update-GithubWidget })

    $systemTimer = New-Object Windows.Threading.DispatcherTimer
    $systemTimer.Interval = [TimeSpan]::FromMilliseconds(400)
    $systemTimer.Add_Tick({ Complete-SystemSample })

    $pulseTimer = New-Object Windows.Threading.DispatcherTimer
    $pulseTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
    $script:pulseDimmed = $false
    $pulseTimer.Add_Tick({
        $script:pulseDimmed = !$script:pulseDimmed
        $target = if ($script:pulseDimmed) { 0.50 } else { 1.0 }
        foreach ($element in $script:pulseElements) {
            $animation = New-Object Windows.Media.Animation.DoubleAnimation
            $animation.To = $target
            $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(320))
            [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 10)
            $element.BeginAnimation([Windows.UIElement]::OpacityProperty, $animation)
        }
    })

    $script:window.Add_Loaded({
        Write-DashboardLog "Dashboard first frame loaded with six widgets."
        $timeTimer.Start()
        $dataTimer.Start()
        $contextTimer.Start()
        $githubTimer.Start()
        $systemTimer.Start()
        $pulseTimer.Start()
        Start-SystemSample

        Update-TimeWeatherWidget
        Update-AIAgentWidget
        Update-TodoWidget
        Update-ContextWidgets

        $script:deferredToolsTimer = New-Object Windows.Threading.DispatcherTimer
        $script:deferredToolsTimer.Interval = [TimeSpan]::FromMilliseconds(220)
        $script:deferredToolsTimer.Add_Tick({
            $script:deferredToolsTimer.Stop()
            Update-QuickToolsWidget
        })
        $script:deferredToolsTimer.Start()

        $script:deferredGithubTimer = New-Object Windows.Threading.DispatcherTimer
        $script:deferredGithubTimer.Interval = [TimeSpan]::FromMilliseconds(520)
        $script:deferredGithubTimer.Add_Tick({
            $script:deferredGithubTimer.Stop()
            Update-GithubWidget
        })
        $script:deferredGithubTimer.Start()

    })

    $script:window.Add_Closed({
        foreach ($timer in @($timeTimer, $dataTimer, $contextTimer, $githubTimer, $systemTimer, $pulseTimer)) { $timer.Stop() }
        Stop-SystemSampler
        Write-DashboardLog "Dashboard closed."
    })

    Write-DashboardLog "Starting independent Obsidian AI Desktop Dashboard."
    [void]$script:window.ShowDialog()
} catch {
    Write-DashboardLog ("Fatal error: " + $_.Exception.ToString())
    throw
} finally {
    if ($null -ne $mutex) {
        try { $mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}
