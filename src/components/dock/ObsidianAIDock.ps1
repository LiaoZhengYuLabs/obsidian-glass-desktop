$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateRoot = $projectRoot + "\state"
$logRoot = $projectRoot + "\logs"
$orderPath = $stateRoot + "\fixed-order.json"
$logPath = $logRoot + "\dock.log"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) {
    . $pathsHelper
}
$myDockRoot = Get-ObsidianGlassDockRoot
$myDockIconPath = if (![string]::IsNullOrWhiteSpace($myDockRoot)) { $myDockRoot + "\ico.ini" } else { $null }

New-Item -ItemType Directory -Path $stateRoot, $logRoot -Force | Out-Null

function Write-DockLog {
    param([string]$Message)
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + "  " + $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianAIDock", [ref]$createdNew)
if (!$createdNew) {
    Write-DockLog "A second instance was blocked."
    $mutex.Dispose()
    exit 0
}

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class ObsidianDockWindowInfo {
    public IntPtr Handle;
    public int ProcessId;
    public string Title;
    public string ClassName;
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
    public bool IsMinimized;
}

public static class ObsidianDockNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct SIZE { public int Width, Height; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DWM_THUMBNAIL_PROPERTIES {
        public uint Flags;
        public RECT Destination;
        public RECT Source;
        public byte Opacity;
        [MarshalAs(UnmanagedType.Bool)] public bool Visible;
        [MarshalAs(UnmanagedType.Bool)] public bool SourceClientAreaOnly;
    }

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

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint colorKey, byte alpha, uint flags);
    [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool altTab);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int SetWindowCompositionAttribute(IntPtr hWnd, ref WindowCompositionAttributeData data);
    [DllImport("user32.dll")] public static extern int SetWindowRgn(IntPtr hWnd, IntPtr region, bool redraw);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int left, int top, int right, int bottom, int ellipseWidth, int ellipseHeight);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr handle);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out int value, int size);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hWnd, int attribute, ref int value, int size);
    [DllImport("dwmapi.dll")] public static extern int DwmRegisterThumbnail(IntPtr destination, IntPtr source, out IntPtr thumbnail);
    [DllImport("dwmapi.dll")] public static extern int DwmUnregisterThumbnail(IntPtr thumbnail);
    [DllImport("dwmapi.dll")] public static extern int DwmQueryThumbnailSourceSize(IntPtr thumbnail, out SIZE size);
    [DllImport("dwmapi.dll")] public static extern int DwmUpdateThumbnailProperties(IntPtr thumbnail, ref DWM_THUMBNAIL_PROPERTIES properties);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern int SHDefExtractIcon(string fileName, int index, uint flags, out IntPtr largeIcon, out IntPtr smallIcon, uint iconSize);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);

    public static List<ObsidianDockWindowInfo> GetVisibleWindows() {
        List<ObsidianDockWindowInfo> result = new List<ObsidianDockWindowInfo>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) return true;
            int cloaked = 0;
            if (DwmGetWindowAttribute(hWnd, 14, out cloaked, 4) == 0 && cloaked != 0) return true;
            bool isMinimized = IsIconic(hWnd);
            int length = GetWindowTextLength(hWnd);
            if (length <= 0) return true;
            StringBuilder title = new StringBuilder(length + 1);
            GetWindowText(hWnd, title, title.Capacity);
            StringBuilder className = new StringBuilder(256);
            GetClassName(hWnd, className, className.Capacity);
            RECT rect;
            if (!GetWindowRect(hWnd, out rect)) return true;
            if (!isMinimized && ((rect.Right - rect.Left) < 80 || (rect.Bottom - rect.Top) < 60)) return true;
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            result.Add(new ObsidianDockWindowInfo {
                Handle = hWnd,
                ProcessId = (int)processId,
                Title = title.ToString(),
                ClassName = className.ToString(),
                Left = rect.Left,
                Top = rect.Top,
                Right = rect.Right,
                Bottom = rect.Bottom,
                IsMinimized = isMinimized
            });
            return true;
        }, IntPtr.Zero);
        return result;
    }

    public static void ActivateWindow(IntPtr hWnd) {
        if (hWnd == IntPtr.Zero) return;
        if (IsIconic(hWnd)) ShowWindow(hWnd, 9);
        ShowWindow(hWnd, 5);
        SetForegroundWindow(hWnd);
        SwitchToThisWindow(hWnd, true);
    }

    public static int SetMyDockVisible(int processId, bool visible) {
        int changed = 0;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint owner;
            GetWindowThreadProcessId(hWnd, out owner);
            if (owner != (uint)processId) return true;
            StringBuilder className = new StringBuilder(128);
            GetClassName(hWnd, className, className.Capacity);
            if (className.ToString() == "MyDockAPP") {
                int style = GetWindowLong(hWnd, -20);
                if (visible) {
                    SetWindowLong(hWnd, -20, (style | 0x80000) & ~0x20);
                    SetLayeredWindowAttributes(hWnd, 0, 255, 2);
                    ShowWindow(hWnd, 5);
                } else {
                    SetWindowLong(hWnd, -20, style | 0x80000 | 0x20);
                    SetLayeredWindowAttributes(hWnd, 0, 0, 2);
                    ShowWindow(hWnd, 5);
                }
                changed++;
            }
            return true;
        }, IntPtr.Zero);
        return changed;
    }
}
"@

$script:iconCache = @{}
$script:shell = New-Object -ComObject WScript.Shell
$script:fixedApps = @()
$script:currentApps = @()
$script:retainedPages = @()
$script:pageRetention = @{}
$script:allButtons = New-Object Collections.Generic.List[object]
$script:runtimeSignature = ""
$script:previewThumbnail = [IntPtr]::Zero
$script:previewPending = $null
$script:previewApp = $null
$script:previewVisible = $false
$script:suppressClickUntil = [DateTime]::MinValue
$script:lastClickKey = ""
$script:lastClickAt = [DateTime]::MinValue
$script:gameSafeMode = $false

function Get-ShortcutDetails {
    param([string]$Path)
    $target = $Path
    $iconPath = $Path
    $iconIndex = 0
    if ($Path.EndsWith(".lnk", [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $Path)) {
        try {
            $shortcut = $script:shell.CreateShortcut($Path)
            if (![string]::IsNullOrWhiteSpace($shortcut.TargetPath)) { $target = $shortcut.TargetPath }
            if (![string]::IsNullOrWhiteSpace($shortcut.IconLocation)) {
                $comma = $shortcut.IconLocation.LastIndexOf(",")
                if ($comma -gt 1) {
                    $candidate = $shortcut.IconLocation.Substring(0, $comma).Trim('"')
                    $candidateIndex = 0
                    [void][int]::TryParse($shortcut.IconLocation.Substring($comma + 1), [ref]$candidateIndex)
                    if (Test-Path -LiteralPath $candidate) {
                        $iconPath = $candidate
                        $iconIndex = $candidateIndex
                    }
                }
            }
        } catch { }
    }
    return [pscustomobject]@{ Target = $target; IconPath = $iconPath; IconIndex = $iconIndex }
}

function Get-IconFrame {
    param(
        [string]$Path,
        [int]$Index = 0
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = $env:WINDIR + "\explorer.exe" }
    $key = $Path.ToLowerInvariant() + "|" + $Index
    if ($script:iconCache.ContainsKey($key)) { return $script:iconCache[$key] }

    $details = Get-ShortcutDetails -Path $Path
    $iconFile = $details.IconPath
    $iconIndex = if ($Index -ne 0) { $Index } else { $details.IconIndex }
    if (!(Test-Path -LiteralPath $iconFile)) {
        $iconFile = $details.Target
        $iconIndex = 0
    }
    if (!(Test-Path -LiteralPath $iconFile)) {
        $iconFile = $env:WINDIR + "\explorer.exe"
        $iconIndex = 0
    }

    $large = [IntPtr]::Zero
    $small = [IntPtr]::Zero
    $size = [uint32]((64 -shl 16) -bor 64)
    $result = [ObsidianDockNative]::SHDefExtractIcon($iconFile, $iconIndex, 0, [ref]$large, [ref]$small, $size)
    if ($result -ne 0 -or $large -eq [IntPtr]::Zero) {
        $iconFile = $env:WINDIR + "\explorer.exe"
        [void][ObsidianDockNative]::SHDefExtractIcon($iconFile, 0, 0, [ref]$large, [ref]$small, $size)
    }
    try {
        $frame = [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $large,
            [Windows.Int32Rect]::Empty,
            [Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(64, 64)
        )
        $frame.Freeze()
        $script:iconCache[$key] = $frame
        return $frame
    } finally {
        if ($large -ne [IntPtr]::Zero) { [ObsidianDockNative]::DestroyIcon($large) | Out-Null }
        if ($small -ne [IntPtr]::Zero) { [ObsidianDockNative]::DestroyIcon($small) | Out-Null }
    }
}

function Get-ProcessHints {
    param($Entry)
    $value = ($Entry.AppName + " " + $Entry.FilePath + " " + $Entry.RealPath).ToLowerInvariant()
    if ($value -match "file explorer|explorer\.exe") { return @("explorer") }
    if ($value -match "chrome") { return @("chrome") }
    if ($value -match "msedge|edge") { return @("msedge") }
    if ($value -match "wechat|weixin") { return @("Weixin") }
    if ($value -match "settings|systemsettings") { return @("SystemSettings", "ApplicationFrameHost") }
    if ($value -match "codex") { return @("Codex", "ChatGPT") }
    if ($value -match "nvidia") { return @("NVIDIA App") }
    if ($value -match "visual studio code|code\.exe") { return @("Code") }
    if ($value -match "pawpause") { return @("PawPause") }
    if ($value -match "quickq") { return @("QuickQ") }
    if ($value -match "tianxi|xlsmartui") { return @("XLSmartUI", "XLAUI") }
    if ($value -match "store") { return @("WinStore.App", "ApplicationFrameHost") }
    if ($value -match "chatgpt") { return @("ChatGPT") }
    if ($value -match "cine gate|wscript") { return @("wscript") }
    try { return @([IO.Path]::GetFileNameWithoutExtension($Entry.RealPath)) } catch { return @() }
}

function Read-MyDockItems {
    if ([string]::IsNullOrWhiteSpace($myDockIconPath) -or !(Test-Path -LiteralPath $myDockIconPath -PathType Leaf)) {
        Write-DockLog "MyDockFinder was not found; fixed app zone will start empty. Set OBSIDIAN_GLASS_DOCK_ROOT to enable it."
        return @()
    }
    $text = [IO.File]::ReadAllText($myDockIconPath, [Text.Encoding]::UTF8)
    $sections = [regex]::Split($text, "(?m)(?=^\[ico\d+\]\s*$)")
    $apps = New-Object Collections.Generic.List[object]
    $trash = $null
    foreach ($section in $sections) {
        if ($section -notmatch "(?m)^\[ico(?<index>\d+)\]\s*$") { continue }
        $index = [int]$matches.index
        $values = @{}
        foreach ($line in ($section -split "\r?\n")) {
            if ($line -match "^(?<key>[^=]+)=(?<value>.*)$") {
                $values[$matches.key.Trim()] = $matches.value.Trim()
            }
        }
        if ($values.ContainsKey("delimiter")) { continue }
        if ($values["appname"] -eq "trash|") {
            $trash = [pscustomobject]@{
                Id = "trash"
                Name = if ($values.ContainsKey("tag")) { $values["tag"] } else { "Recycle Bin" }
                Target = "shell:RecycleBinFolder"
                IconPath = $env:WINDIR + "\System32\imageres.dll"
                IconIndex = -55
                ProcessHints = @()
                TitleHint = ""
                Section = "trash"
            }
            continue
        }
        if (!$values.ContainsKey("filepath")) { continue }
        $entry = [pscustomobject]@{
            Id = "fixed:" + $index + ":" + $values["filepath"].ToLowerInvariant()
            OriginalIndex = $index
            Name = if ($values.ContainsKey("tag")) { $values["tag"] } else { [IO.Path]::GetFileNameWithoutExtension($values["appname"]) }
            AppName = $values["appname"]
            Target = $values["filepath"]
            FilePath = $values["filepath"]
            RealPath = if ($values.ContainsKey("realpath")) { $values["realpath"] } else { $values["filepath"] }
            IconPath = $values["filepath"]
            IconIndex = 0
            ProcessHints = @()
            TitleHint = ""
            Section = "fixed"
        }
        $entry.ProcessHints = @(Get-ProcessHints -Entry $entry)
        if ($entry.AppName -match "(?i)Codex") { $entry.TitleHint = "Codex" }
        elseif ($entry.AppName -match "(?i)ChatGPT") { $entry.TitleHint = "ChatGPT" }
        elseif ($entry.AppName -match "(?i)Store") { $entry.TitleHint = "Store|Microsoft Store" }
        elseif ($entry.AppName -match "(?i)Settings") { $entry.TitleHint = "Settings|SystemSettings" }
        $apps.Add($entry)
    }
    return [pscustomobject]@{ Apps = $apps.ToArray(); Trash = $trash }
}

function Load-FixedOrder {
    param([array]$Apps)
    if (!(Test-Path -LiteralPath $orderPath)) { return @($Apps | Sort-Object OriginalIndex) }
    try {
        $saved = [IO.File]::ReadAllText($orderPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $order = @($saved.Order)
        $map = @{}
        foreach ($app in $Apps) { $map[$app.Id] = $app }
        $result = New-Object Collections.Generic.List[object]
        foreach ($id in $order) {
            if ($map.ContainsKey([string]$id)) {
                $result.Add($map[[string]$id])
                $map.Remove([string]$id)
            }
        }
        foreach ($app in ($Apps | Sort-Object OriginalIndex)) {
            if ($map.ContainsKey($app.Id)) { $result.Add($app) }
        }
        return $result.ToArray()
    } catch {
        Write-DockLog ("Fixed order load failed: " + $_.Exception.Message)
        return @($Apps | Sort-Object OriginalIndex)
    }
}

function Save-FixedOrder {
    $state = [pscustomobject]@{ Version = 1; Order = @($script:fixedApps | ForEach-Object { $_.Id }) }
    $json = $state | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($orderPath, $json, [Text.UTF8Encoding]::new($false))
}

function Get-WindowProcessPath {
    param([Diagnostics.Process]$Process)
    try { return $Process.MainModule.FileName } catch { return "" }
}

function Get-RunningDisplayName {
    param(
        [string]$ProcessName,
        [string]$Path,
        [string]$Title
    )
    foreach ($fixed in $script:fixedApps) {
        if (@($fixed.ProcessHints) -contains $ProcessName) {
            if ([string]::IsNullOrWhiteSpace($fixed.TitleHint) -or $Title -match $fixed.TitleHint) {
                return $fixed.Name
            }
        }
    }
    $known = @{
        "explorer" = "File Explorer"
        "Weixin" = "WeChat"
        "Code" = "Visual Studio Code"
        "ChatGPT" = "ChatGPT"
        "msedge" = "Microsoft Edge"
        "chrome" = "Google Chrome"
        "WindowsTerminal" = "Windows Terminal"
        "Notepad" = "Notepad"
        "ApplicationFrameHost" = $Title
    }
    if ($known.ContainsKey($ProcessName) -and ![string]::IsNullOrWhiteSpace($known[$ProcessName])) {
        return $known[$ProcessName]
    }
    if (![string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            foreach ($candidate in @($version.FileDescription, $version.ProductName)) {
                if (![string]::IsNullOrWhiteSpace($candidate)) { return $candidate.Trim() }
            }
        } catch { }
    }
    return $ProcessName
}

function Get-RunningApps {
    $excludedProcesses = @(
        "Dock_64", "Dockmod", "Dockmod64", "Rainmeter", "seelen-ui", "slu-service",
        "Lively", "Lively.Player.WebView2", "Lively.Watchdog", "MicaForEveryone.App",
        "SearchHost", "StartMenuExperienceHost", "ShellExperienceHost", "TextInputHost",
        "dwm", "LockApp", "explorerframe"
    )
    $excludedClasses = @(
        "Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "MyDockAPP",
        "MyFinderApp", "CEF-OSC-WIDGET", "Windows.UI.Core.CoreWindow"
    )
    $groups = @{}
    $order = New-Object Collections.Generic.List[string]
    foreach ($windowInfo in [ObsidianDockNative]::GetVisibleWindows()) {
        if ($windowInfo.ProcessId -eq $PID -or $excludedClasses -contains $windowInfo.ClassName) { continue }
        $process = Get-Process -Id $windowInfo.ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $process -or $excludedProcesses -contains $process.ProcessName) { continue }
        $path = Get-WindowProcessPath -Process $process
        $key = if (![string]::IsNullOrWhiteSpace($path)) { $path.ToLowerInvariant() } else { $process.ProcessName.ToLowerInvariant() }
        if (!$groups.ContainsKey($key)) {
            $name = Get-RunningDisplayName -ProcessName $process.ProcessName -Path $path -Title $windowInfo.Title
            $groups[$key] = [pscustomobject]@{
                Id = "runtime:" + $key
                Key = $key
                Name = $name
                ProcessName = $process.ProcessName
                Path = $path
                Target = $path
                IconPath = if (![string]::IsNullOrWhiteSpace($path)) { $path } else { $env:WINDIR + "\explorer.exe" }
                IconIndex = 0
                Windows = New-Object Collections.Generic.List[object]
                WindowTitle = $windowInfo.Title
                LastActiveTime = (Get-Date).ToString("o")
                Section = "running"
            }
            $order.Add($key)
        }
        $groups[$key].Windows.Add($windowInfo)
        if ([ObsidianDockNative]::GetForegroundWindow() -eq $windowInfo.Handle) {
            $groups[$key].WindowTitle = $windowInfo.Title
        }
    }
    $result = New-Object Collections.Generic.List[object]
    foreach ($key in $order) { $result.Add($groups[$key]) }
    return $result.ToArray()
}

function Get-RetainedPages {
    $pages = New-Object Collections.Generic.List[object]
    $liveHandles = @{}
    $now = Get-Date

    foreach ($app in $script:currentApps) {
        foreach ($windowInfo in $app.Windows) {
            if (!$windowInfo.IsMinimized) { continue }

            $handleKey = ([long]$windowInfo.Handle).ToString()
            $liveHandles[$handleKey] = $true
            if (!$script:pageRetention.ContainsKey($handleKey)) {
                $script:pageRetention[$handleKey] = $now
                Write-DockLog ("Page retained: " + $app.Name + " | " + $windowInfo.Title)
            }

            $pages.Add([pscustomobject]@{
                Id = "page:" + $handleKey
                Key = $app.Key
                Name = $app.Name
                ProcessName = $app.ProcessName
                Path = $app.Path
                Target = $app.Target
                IconPath = $app.IconPath
                IconIndex = $app.IconIndex
                WindowTitle = $windowInfo.Title
                WindowHandle = $windowInfo.Handle
                Windows = @($windowInfo)
                RetainedAt = $script:pageRetention[$handleKey]
                LastActiveTime = $script:pageRetention[$handleKey].ToString("o")
                Section = "page"
            })
        }
    }

    foreach ($key in @($script:pageRetention.Keys)) {
        if (!$liveHandles.ContainsKey($key)) {
            $script:pageRetention.Remove($key)
            Write-DockLog ("Page released: " + $key)
        }
    }

    return @($pages.ToArray() | Sort-Object RetainedAt)
}

function Test-FixedRunning {
    param($Fixed)
    foreach ($app in $script:currentApps) {
        if (@($Fixed.ProcessHints) -contains $app.ProcessName) {
            if ([string]::IsNullOrWhiteSpace($Fixed.TitleHint) -or
                @($app.Windows | Where-Object { $_.Title -match $Fixed.TitleHint }).Count -gt 0) {
                return $true
            }
        }
    }
    return $false
}

function Get-MatchingCurrentApp {
    param($App)
    if ($null -eq $App) { return $null }
    foreach ($current in $script:currentApps) {
        if (![string]::IsNullOrWhiteSpace($App.ProcessName) -and $current.ProcessName -eq $App.ProcessName) { return $current }
        if (![string]::IsNullOrWhiteSpace($App.Key) -and $current.Key -eq $App.Key) { return $current }
        if ($null -ne $App.ProcessHints -and @($App.ProcessHints) -contains $current.ProcessName) {
            if ([string]::IsNullOrWhiteSpace($App.TitleHint) -or
                @($current.Windows | Where-Object { $_.Title -match $App.TitleHint }).Count -gt 0) {
                return $current
            }
        }
    }
    return $null
}

[xml]$dockXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Obsidian AI Dock"
        Width="860"
        Height="86"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        Opacity="0"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="True">
    <Grid x:Name="DockRoot" Margin="7,5,7,9">
        <Border x:Name="DockShadow" CornerRadius="36" Background="#01000000">
            <Border.Effect>
                <DropShadowEffect BlurRadius="24" ShadowDepth="5" Opacity="0.28" Color="#000000"/>
            </Border.Effect>
        </Border>
        <Border x:Name="DockGlass"
                CornerRadius="36"
                Background="#08FFFFFF"
                BorderBrush="#5CFFFFFF"
                BorderThickness="0.8"
                Padding="9,3">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="1"/>
                    <ColumnDefinition Width="138"/>
                    <ColumnDefinition Width="1"/>
                    <ColumnDefinition Width="150"/>
                    <ColumnDefinition Width="1"/>
                    <ColumnDefinition Width="34"/>
                </Grid.ColumnDefinitions>
                <Grid Grid.Column="0">
                    <Grid.RowDefinitions><RowDefinition Height="10"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <TextBlock Text="APPS" Foreground="#78000000" FontFamily="Segoe UI Variable Text" FontSize="7" Margin="4,0,0,0"/>
                    <ScrollViewer x:Name="FixedScroll" AutomationProperties.Name="Fixed applications scroller" Grid.Row="1" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" PanningMode="HorizontalOnly" IsManipulationEnabled="True">
                        <StackPanel x:Name="FixedPanel" Orientation="Horizontal" VerticalAlignment="Center"/>
                    </ScrollViewer>
                </Grid>
                <Border Grid.Column="1" Background="#2F000000" Margin="0,10"/>
                <Grid Grid.Column="2" Margin="8,0">
                    <Grid.RowDefinitions><RowDefinition Height="10"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <TextBlock Text="ACTIVE" Foreground="#78000000" FontFamily="Segoe UI Variable Text" FontSize="7" Margin="4,0,0,0"/>
                    <ScrollViewer x:Name="RunningScroll" AutomationProperties.Name="Running applications scroller" Grid.Row="1" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" PanningMode="HorizontalOnly" IsManipulationEnabled="True">
                        <StackPanel x:Name="RunningPanel" Orientation="Horizontal" VerticalAlignment="Center"/>
                    </ScrollViewer>
                </Grid>
                <Border Grid.Column="3" Background="#2F000000" Margin="0,10"/>
                <Grid Grid.Column="4" Margin="8,0">
                    <Grid.RowDefinitions><RowDefinition Height="10"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <TextBlock Text="PAGES" Foreground="#78000000" FontFamily="Segoe UI Variable Text" FontSize="7" Margin="4,0,0,0"/>
                    <ScrollViewer x:Name="PageScroll" AutomationProperties.Name="Retained pages scroller" Grid.Row="1" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" PanningMode="HorizontalOnly" IsManipulationEnabled="True">
                        <StackPanel x:Name="PagePanel" Orientation="Horizontal" VerticalAlignment="Center"/>
                    </ScrollViewer>
                </Grid>
                <Border Grid.Column="5" Background="#2F000000" Margin="0,10"/>
                <StackPanel x:Name="UtilityPanel" Grid.Column="6" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center"/>
            </Grid>
        </Border>
        <Border x:Name="PointerGlow" CornerRadius="36" IsHitTestVisible="False" Opacity="0.16">
            <Border.Background>
                <RadialGradientBrush x:Name="GlowBrush" RadiusX="0.18" RadiusY="1.25">
                    <GradientStop Color="#A8FFFFFF" Offset="0"/>
                    <GradientStop Color="#38FFFFFF" Offset="0.38"/>
                    <GradientStop Color="#00000000" Offset="1"/>
                </RadialGradientBrush>
            </Border.Background>
        </Border>
    </Grid>
</Window>
"@

$dockReader = New-Object Xml.XmlNodeReader($dockXaml)
$window = [Windows.Markup.XamlReader]::Load($dockReader)
$dockRoot = $window.FindName("DockRoot")
$dockGlass = $window.FindName("DockGlass")
$glowBrush = $window.FindName("GlowBrush")
$fixedPanel = $window.FindName("FixedPanel")
$runningPanel = $window.FindName("RunningPanel")
$pagePanel = $window.FindName("PagePanel")
$fixedScroll = $window.FindName("FixedScroll")
$runningScroll = $window.FindName("RunningScroll")
$pageScroll = $window.FindName("PageScroll")
$utilityPanel = $window.FindName("UtilityPanel")

[xml]$previewXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Obsidian AI Dock Preview"
        Width="320"
        Height="220"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="False"
        Background="#090A0E"
        ShowInTaskbar="False"
        ShowActivated="False"
        Focusable="False"
        Topmost="True">
    <Border x:Name="PreviewCard"
            CornerRadius="18"
            Background="#ED090A0E"
            BorderBrush="#7EF5F7FC"
            BorderThickness="1"
            Padding="10">
        <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="8" Opacity="0.62" Color="#000000"/></Border.Effect>
        <Border.RenderTransform>
            <TransformGroup>
                <ScaleTransform x:Name="PreviewScale" ScaleX="0.85" ScaleY="0.85"/>
                <TranslateTransform x:Name="PreviewFloat" Y="2"/>
            </TransformGroup>
        </Border.RenderTransform>
        <Border.RenderTransformOrigin>0.5,1</Border.RenderTransformOrigin>
        <Grid>
            <Grid.RowDefinitions><RowDefinition Height="34"/><RowDefinition Height="126"/><RowDefinition Height="40"/></Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="30"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <Image x:Name="PreviewIcon" Width="24" Height="24" Stretch="Uniform" VerticalAlignment="Top"/>
                <TextBlock x:Name="PreviewName" Grid.Column="1" Foreground="#F2F4F8" FontFamily="Segoe UI Variable Text" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Top" TextTrimming="CharacterEllipsis"/>
                <TextBlock Grid.Column="2" Text="LIVE" Foreground="#9FC9D8FF" FontFamily="Segoe UI Variable Text" FontSize="8" Margin="8,3,0,0"/>
            </Grid>
            <Border Grid.Row="1" CornerRadius="10" Background="#00000000" BorderBrush="#34495568" BorderThickness="1">
                <TextBlock x:Name="PreviewEmpty" Text="LIVE WINDOW PREVIEW" Foreground="#63728091" FontFamily="Segoe UI Variable Text" FontSize="9" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <Grid Grid.Row="2" Margin="2,7,2,0">
                <Grid.RowDefinitions><RowDefinition Height="18"/><RowDefinition Height="15"/></Grid.RowDefinitions>
                <TextBlock x:Name="PreviewTitle" Foreground="#D8DEE7F0" FontFamily="Segoe UI Variable Text" FontSize="10" TextTrimming="CharacterEllipsis"/>
                <TextBlock x:Name="PreviewUpdated" Grid.Row="1" Foreground="#788592A2" FontFamily="Segoe UI Variable Text" FontSize="9"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$previewReader = New-Object Xml.XmlNodeReader($previewXaml)
$previewWindow = [Windows.Markup.XamlReader]::Load($previewReader)
$previewCard = $previewWindow.FindName("PreviewCard")
$previewScale = $previewWindow.FindName("PreviewScale")
$previewFloat = $previewWindow.FindName("PreviewFloat")
$previewIcon = $previewWindow.FindName("PreviewIcon")
$previewName = $previewWindow.FindName("PreviewName")
$previewTitle = $previewWindow.FindName("PreviewTitle")
$previewUpdated = $previewWindow.FindName("PreviewUpdated")
$previewEmpty = $previewWindow.FindName("PreviewEmpty")

function New-DoubleAnimation {
    param([double]$To, [int]$Milliseconds)
    $animation = [Windows.Media.Animation.DoubleAnimation]::new()
    $animation.To = $To
    $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($Milliseconds))
    $ease = [Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [Windows.Media.Animation.EasingMode]::EaseOut
    $animation.EasingFunction = $ease
    return $animation
}

function Set-ButtonTransform {
    param($Meta, [double]$Scale, [double]$Translate, [int]$Index)
    $Meta.Scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-DoubleAnimation -To $Scale -Milliseconds 180))
    $Meta.Scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-DoubleAnimation -To $Scale -Milliseconds 180))
    $Meta.Translate.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, (New-DoubleAnimation -To $Translate -Milliseconds 180))
    [Windows.Controls.Panel]::SetZIndex($Meta.Border, $Index)
}

function Apply-Magnification {
    param($HoveredBorder)
    $hoverIndex = $script:allButtons.IndexOf($HoveredBorder)
    for ($i = 0; $i -lt $script:allButtons.Count; $i++) {
        $border = $script:allButtons[$i]
        $distance = [Math]::Abs($i - $hoverIndex)
        if ($distance -eq 0) { Set-ButtonTransform -Meta $border.Tag -Scale 1.35 -Translate -10 -Index 30 }
        elseif ($distance -eq 1) { Set-ButtonTransform -Meta $border.Tag -Scale 1.15 -Translate -4 -Index 20 }
        else { Set-ButtonTransform -Meta $border.Tag -Scale 1.0 -Translate 0 -Index 1 }
    }
}

function Reset-Magnification {
    foreach ($border in $script:allButtons) { Set-ButtonTransform -Meta $border.Tag -Scale 1.0 -Translate 0 -Index 1 }
}

function Invoke-DockApp {
    param($App)
    if ($null -eq $App) { return $false }
    if ($App.Section -eq "trash") {
        try {
            Start-Process explorer.exe -ArgumentList "shell:RecycleBinFolder"
            Write-DockLog "Launched: Recycle Bin"
            return $true
        } catch {
            Write-DockLog ("Launch failed: Recycle Bin | " + $_.Exception.Message)
            return $false
        }
    }
    if ($App.Section -eq "page" -and $null -ne $App.WindowHandle) {
        $pageHandle = [IntPtr]$App.WindowHandle
        if ([ObsidianDockNative]::IsWindow($pageHandle)) {
            [ObsidianDockNative]::ActivateWindow($pageHandle)
            Write-DockLog ("Restored retained page: " + $App.Name + " | " + $App.WindowTitle)
            return $true
        }
        Write-DockLog ("Retained page no longer exists: " + $App.WindowTitle)
        return $false
    }
    $current = Get-MatchingCurrentApp -App $App
    if ($null -ne $current -and $current.Windows.Count -gt 0) {
        [ObsidianDockNative]::ActivateWindow([IntPtr]$current.Windows[0].Handle)
        Write-DockLog ("Activated: " + $App.Name + " | " + $current.WindowTitle)
        return $true
    }
    $target = if (![string]::IsNullOrWhiteSpace($App.Target)) { $App.Target } else { $App.Path }
    if (![string]::IsNullOrWhiteSpace($target)) {
        try {
            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = $target
            $startInfo.UseShellExecute = $true
            [void][Diagnostics.Process]::Start($startInfo)
            Write-DockLog ("Launched: " + $App.Name + " | " + $target)
            return $true
        } catch {
            Write-DockLog ("Launch failed: " + $target + " | " + $_.Exception.Message)
            return $false
        }
    }
    Write-DockLog ("Launch skipped because no target was available: " + $App.Name)
    return $false
}

function Move-FixedEntry {
    param([string]$SourceId, [string]$TargetId)
    if ($SourceId -eq $TargetId) { return }
    $source = @($script:fixedApps | Where-Object { $_.Id -eq $SourceId }) | Select-Object -First 1
    $target = @($script:fixedApps | Where-Object { $_.Id -eq $TargetId }) | Select-Object -First 1
    if ($null -eq $source -or $null -eq $target) { return }
    $list = New-Object Collections.Generic.List[object]
    foreach ($app in $script:fixedApps) { if ($app.Id -ne $SourceId) { $list.Add($app) } }
    $targetIndex = -1
    for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i].Id -eq $TargetId) { $targetIndex = $i; break } }
    if ($targetIndex -lt 0) { $list.Add($source) } else { $list.Insert($targetIndex, $source) }
    $script:fixedApps = $list.ToArray()
    Save-FixedOrder
    Render-Dock
    Write-DockLog ("Fixed entry reordered: " + $source.Name)
}

function New-DockButton {
    param(
        $App,
        [string]$Section,
        [bool]$Running,
        [bool]$EnablePreview,
        [bool]$EnableDrag
    )
    $isPage = ($Section -eq "page")
    $border = [Windows.Controls.Border]::new()
    $border.Width = if ($isPage) { 36 } else { 30 }
    $border.Height = 40
    $border.Margin = if ($isPage) { [Windows.Thickness]::new(1, 0, 1, 0) } else { [Windows.Thickness]::new(1.2, 0, 1.2, 0) }
    $border.CornerRadius = if ($isPage) { [Windows.CornerRadius]::new(5) } else { [Windows.CornerRadius]::new(9) }
    $baseBackground = if ($isPage) {
        [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#22000000"))
    } else {
        [Windows.Media.Brushes]::Transparent
    }
    $border.Background = $baseBackground
    if ($isPage) {
        $border.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#38000000"))
        $border.BorderThickness = [Windows.Thickness]::new(0.7)
        $border.Padding = [Windows.Thickness]::new(3, 2, 3, 2)
    }
    $border.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.65)
    $scale = [Windows.Media.ScaleTransform]::new(1, 1)
    $translate = [Windows.Media.TranslateTransform]::new(0, 0)
    $group = [Windows.Media.TransformGroup]::new()
    $group.Children.Add($scale)
    $group.Children.Add($translate)
    $border.RenderTransform = $group

    $grid = [Windows.Controls.Grid]::new()
    $pageInvokeButton = $null
    $image = [Windows.Controls.Image]::new()
    $image.Width = if ($isPage) { 11 } else { 26 }
    $image.Height = if ($isPage) { 11 } else { 26 }
    $image.Stretch = [Windows.Media.Stretch]::Uniform
    $image.Source = Get-IconFrame -Path $App.IconPath -Index $App.IconIndex
    [Windows.Automation.AutomationProperties]::SetName($image, $Section + " app: " + $App.Name)

    if ($isPage) {
        $grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
        $grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
        $grid.RowDefinitions[0].Height = [Windows.GridLength]::new(14)
        $grid.RowDefinitions[1].Height = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
        $image.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
        $image.VerticalAlignment = [Windows.VerticalAlignment]::Top
        $grid.Children.Add($image) | Out-Null

        $pageState = [Windows.Controls.TextBlock]::new()
        $pageState.Text = "MIN"
        $pageState.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $pageState.FontSize = 5
        $pageState.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#82000000"))
        $pageState.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
        $pageState.VerticalAlignment = [Windows.VerticalAlignment]::Top
        $grid.Children.Add($pageState) | Out-Null

        $pageTitle = [Windows.Controls.TextBlock]::new()
        $pageTitle.Text = $App.WindowTitle
        $pageTitle.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $pageTitle.FontSize = 5.2
        $pageTitle.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#D0000000"))
        $pageTitle.TextWrapping = [Windows.TextWrapping]::Wrap
        $pageTitle.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
        $pageTitle.MaxHeight = 21
        $pageTitle.VerticalAlignment = [Windows.VerticalAlignment]::Center
        [Windows.Controls.Grid]::SetRow($pageTitle, 1)
        $grid.Children.Add($pageTitle) | Out-Null

        $pageInvokeButton = [Windows.Controls.Button]::new()
        $pageInvokeButton.Background = [Windows.Media.Brushes]::Transparent
        $pageInvokeButton.BorderThickness = [Windows.Thickness]::new(0)
        $pageInvokeButton.Cursor = [Windows.Input.Cursors]::Hand
        $pageInvokeButton.Focusable = $false
        $pageInvokeButton.Tag = $App
        [Windows.Controls.Grid]::SetRowSpan($pageInvokeButton, 2)
        [Windows.Automation.AutomationProperties]::SetName($pageInvokeButton, "Retained page: " + $App.WindowTitle)
        $pageInvokeButton.Add_Click({
            param($sender, $eventArgs)
            Write-DockLog ("Clicked: page | " + $sender.Tag.Name)
            [void](Invoke-DockApp -App $sender.Tag)
        })
        $grid.Children.Add($pageInvokeButton) | Out-Null
    } else {
        $image.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
        $image.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $grid.Children.Add($image) | Out-Null
    }

    $dot = [Windows.Shapes.Ellipse]::new()
    $dot.Width = if ($isPage) { 2.5 } else { 3.5 }
    $dot.Height = if ($isPage) { 2.5 } else { 3.5 }
    $dot.Fill = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#A8000000"))
    $dot.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $dot.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
    $dot.Margin = [Windows.Thickness]::new(0, 0, 0, 1)
    $dot.Visibility = if ($Running) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $grid.Children.Add($dot) | Out-Null
    $border.Child = $grid
    $border.ToolTip = if ($isPage) { $App.WindowTitle } else { $App.Name }
    $automationName = if ($isPage) { "Retained page: " + $App.WindowTitle } else { $Section + " app: " + $App.Name }
    [Windows.Automation.AutomationProperties]::SetName($border, $automationName)
    $meta = [pscustomobject]@{
        Border = $border
        App = $App
        Section = $Section
        Scale = $scale
        Translate = $translate
        Dot = $dot
        BaseBackground = $baseBackground
        EnablePreview = $EnablePreview
        DragStart = [Windows.Point]::new(0, 0)
        DragTriggered = $false
    }
    $border.Tag = $meta
    $script:allButtons.Add($border)

    $border.Add_MouseEnter({
        param($sender, $eventArgs)
        Apply-Magnification -HoveredBorder $sender
        $sender.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#260078D4"))
        if ($sender.Tag.EnablePreview) {
            $script:previewPending = $sender.Tag.App
            $previewOpenTimer.Stop()
            $previewOpenTimer.Start()
        }
    })
    $border.Add_MouseLeave({
        param($sender, $eventArgs)
        $sender.Background = $sender.Tag.BaseBackground
        if ($sender.Tag.EnablePreview) {
            $previewOpenTimer.Stop()
            if (!$previewWindow.IsMouseOver) {
                $previewHideTimer.Stop()
                $previewHideTimer.Start()
            }
        }
    })
    $border.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $sender.Tag.DragStart = $eventArgs.GetPosition($sender)
        $sender.Tag.DragTriggered = $false
    })
    $border.Add_PreviewMouseLeftButtonUp({
        param($sender, $eventArgs)
        if ($sender.Tag.Section -eq "page") { return }
        if ((Get-Date) -lt $script:suppressClickUntil) { return }
        if ([bool]$sender.Tag.DragTriggered) { return }
        $eventArgs.Handled = $true
        $clickTime = Get-Date
        $clickKey = [string]$sender.Tag.App.Id
        if ($clickKey -eq $script:lastClickKey -and ($clickTime - $script:lastClickAt).TotalMilliseconds -lt 450) {
            Write-DockLog ("Ignored duplicate click: " + $sender.Tag.App.Name)
            return
        }
        $script:lastClickKey = $clickKey
        $script:lastClickAt = $clickTime
        Write-DockLog ("Clicked: " + $sender.Tag.Section + " | " + $sender.Tag.App.Name)
        [void](Invoke-DockApp -App $sender.Tag.App)
    })

    if ($EnableDrag) {
        $border.AllowDrop = $true
        $border.Add_MouseMove({
            param($sender, $eventArgs)
            if ($eventArgs.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { return }
            $position = $eventArgs.GetPosition($sender)
            if ([Math]::Abs($position.X - $sender.Tag.DragStart.X) -lt 6 -and [Math]::Abs($position.Y - $sender.Tag.DragStart.Y) -lt 6) { return }
            $sender.Tag.DragTriggered = $true
            $script:suppressClickUntil = (Get-Date).AddMilliseconds(300)
            [Windows.DragDrop]::DoDragDrop($sender, $sender.Tag.App.Id, [Windows.DragDropEffects]::Move) | Out-Null
        })
        $border.Add_DragOver({ param($sender, $eventArgs); $eventArgs.Effects = [Windows.DragDropEffects]::Move; $eventArgs.Handled = $true })
        $border.Add_Drop({
            param($sender, $eventArgs)
            $sourceId = [string]$eventArgs.Data.GetData([string])
            Move-FixedEntry -SourceId $sourceId -TargetId $sender.Tag.App.Id
            $eventArgs.Handled = $true
        })
    }
    return $border
}

function Render-Dock {
    $fixedPanel.Children.Clear()
    $runningPanel.Children.Clear()
    $pagePanel.Children.Clear()
    $utilityPanel.Children.Clear()
    $script:allButtons.Clear()

    foreach ($app in $script:fixedApps) {
        $button = New-DockButton -App $app -Section "fixed" -Running (Test-FixedRunning -Fixed $app) -EnablePreview $false -EnableDrag $true
        $fixedPanel.Children.Add($button) | Out-Null
    }
    foreach ($app in $script:currentApps) {
        $button = New-DockButton -App $app -Section "running" -Running $true -EnablePreview $false -EnableDrag $false
        $runningPanel.Children.Add($button) | Out-Null
    }
    foreach ($page in $script:retainedPages) {
        $button = New-DockButton -App $page -Section "page" -Running $true -EnablePreview $true -EnableDrag $false
        $pagePanel.Children.Add($button) | Out-Null
    }
    if ($null -ne $script:trashItem) {
        $button = New-DockButton -App $script:trashItem -Section "trash" -Running $false -EnablePreview $false -EnableDrag $false
        $utilityPanel.Children.Add($button) | Out-Null
    }
}

function Clear-PreviewThumbnail {
    if ($script:previewThumbnail -ne [IntPtr]::Zero) {
        [ObsidianDockNative]::DwmUnregisterThumbnail($script:previewThumbnail) | Out-Null
        $script:previewThumbnail = [IntPtr]::Zero
    }
}

function Set-PreviewThumbnail {
    param([IntPtr]$SourceHandle)
    Clear-PreviewThumbnail
    if ($SourceHandle -eq [IntPtr]::Zero) { return $false }
    $helper = [Windows.Interop.WindowInteropHelper]::new($previewWindow)
    $destination = $helper.Handle
    if ($destination -eq [IntPtr]::Zero) { return $false }
    $thumbnail = [IntPtr]::Zero
    if ([ObsidianDockNative]::DwmRegisterThumbnail($destination, $SourceHandle, [ref]$thumbnail) -ne 0) { return $false }
    $size = New-Object ObsidianDockNative+SIZE
    [void][ObsidianDockNative]::DwmQueryThumbnailSourceSize($thumbnail, [ref]$size)
    $dpi = [ObsidianDockNative]::GetDpiForWindow($destination)
    if ($dpi -le 0) { $dpi = 96 }
    $scale = $dpi / 96.0
    $left = [int](10 * $scale)
    $top = [int](44 * $scale)
    $areaWidth = [int](300 * $scale)
    $areaHeight = [int](126 * $scale)
    $sourceRatio = if ($size.Height -gt 0) { $size.Width / [double]$size.Height } else { 1.6 }
    $areaRatio = $areaWidth / [double]$areaHeight
    if ($sourceRatio -gt $areaRatio) {
        $height = [int]($areaWidth / $sourceRatio)
        $top += [int](($areaHeight - $height) / 2)
        $areaHeight = $height
    } else {
        $width = [int]($areaHeight * $sourceRatio)
        $left += [int](($areaWidth - $width) / 2)
        $areaWidth = $width
    }
    $destinationRect = New-Object ObsidianDockNative+RECT
    $destinationRect.Left = $left
    $destinationRect.Top = $top
    $destinationRect.Right = $left + $areaWidth
    $destinationRect.Bottom = $top + $areaHeight
    $properties = New-Object ObsidianDockNative+DWM_THUMBNAIL_PROPERTIES
    $properties.Flags = 1 -bor 4 -bor 8 -bor 16
    $properties.Destination = $destinationRect
    $properties.Opacity = 255
    $properties.Visible = $true
    $properties.SourceClientAreaOnly = $false
    if ([ObsidianDockNative]::DwmUpdateThumbnailProperties($thumbnail, [ref]$properties) -ne 0) {
        [ObsidianDockNative]::DwmUnregisterThumbnail($thumbnail) | Out-Null
        return $false
    }
    $script:previewThumbnail = $thumbnail
    return $true
}

function Show-AppPreview {
    param($App)
    if ($null -eq $App) { return }
    $previewHideTimer.Stop()
    $previewCloseTimer.Stop()
    $script:previewApp = $App
    $current = Get-MatchingCurrentApp -App $App
    $windowInfo = $null
    if ($App.Section -eq "page" -and @($App.Windows).Count -gt 0) {
        $windowInfo = @($App.Windows)[0]
    } elseif ($null -ne $current -and $current.Windows.Count -gt 0) {
        $windowInfo = @($current.Windows | Where-Object { $_.Title -eq $App.WindowTitle }) | Select-Object -First 1
        if ($null -eq $windowInfo) { $windowInfo = $current.Windows[0] }
    }
    $previewIcon.Source = Get-IconFrame -Path $App.IconPath -Index $App.IconIndex
    $previewName.Text = $App.Name
    $previewTitle.Text = if ($null -ne $windowInfo) { $windowInfo.Title } else { $App.WindowTitle }
    if ([string]::IsNullOrWhiteSpace($previewTitle.Text)) { $previewTitle.Text = "Window is not currently open" }
    $updated = Get-Date
    try { $updated = [DateTime]$App.LastActiveTime } catch { }
    $previewUpdated.Text = "Updated " + $updated.ToString("HH:mm:ss")
    $workArea = [Windows.SystemParameters]::WorkArea
    $previewWindow.Left = [Math]::Min($workArea.Right - $previewWindow.Width - 18, $window.Left + $window.Width - $previewWindow.Width - 86)
    $previewWindow.Top = [Math]::Max($workArea.Top + 10, $window.Top - $previewWindow.Height + 4)
    $previewWindow.Opacity = 0
    $previewScale.ScaleX = 0.85
    $previewScale.ScaleY = 0.85
    $previewWindow.Show()
    $previewWindow.UpdateLayout()
    $previewWindow.BeginAnimation([Windows.Window]::OpacityProperty, (New-DoubleAnimation -To 1 -Milliseconds 300))
    $previewScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-DoubleAnimation -To 1 -Milliseconds 300))
    $previewScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-DoubleAnimation -To 1 -Milliseconds 300))
    $floatAnimation = [Windows.Media.Animation.DoubleAnimation]::new(-2, 2, [Windows.Duration]::new([TimeSpan]::FromSeconds(2.8)))
    $floatAnimation.AutoReverse = $true
    $floatAnimation.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $previewFloat.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $floatAnimation)
    $hasThumbnail = if ($null -ne $windowInfo) { Set-PreviewThumbnail -SourceHandle ([IntPtr]$windowInfo.Handle) } else { $false }
    $previewEmpty.Visibility = if ($hasThumbnail) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }
    $script:previewVisible = $true
    Write-DockLog ("Preview shown: " + $App.Name)
}

function Hide-AppPreview {
    if (!$script:previewVisible) { return }
    $script:previewVisible = $false
    $previewWindow.BeginAnimation([Windows.Window]::OpacityProperty, (New-DoubleAnimation -To 0 -Milliseconds 300))
    $previewScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-DoubleAnimation -To 0.85 -Milliseconds 300))
    $previewScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-DoubleAnimation -To 0.85 -Milliseconds 300))
    $previewCloseTimer.Stop()
    $previewCloseTimer.Start()
}

function Set-NativeDockVisible {
    param([bool]$Visible)
    $dock = Get-Process Dock_64 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $dock) {
        return [ObsidianDockNative]::SetMyDockVisible($dock.Id, $Visible)
    }
    return 0
}

function Set-WindowGlass {
    param([Windows.Window]$TargetWindow, [int]$GradientColor)
    $helper = [Windows.Interop.WindowInteropHelper]::new($TargetWindow)
    $handle = $helper.Handle
    $policy = New-Object ObsidianDockNative+AccentPolicy
    $policy.AccentState = 4
    $policy.AccentFlags = 2
    $policy.GradientColor = $GradientColor
    $policy.AnimationId = 0
    $size = [Runtime.InteropServices.Marshal]::SizeOf($policy)
    $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try {
        [Runtime.InteropServices.Marshal]::StructureToPtr($policy, $pointer, $false)
        $data = New-Object ObsidianDockNative+WindowCompositionAttributeData
        $data.Attribute = 19
        $data.Data = $pointer
        $data.SizeOfData = $size
        [ObsidianDockNative]::SetWindowCompositionAttribute($handle, [ref]$data) | Out-Null
    } finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
    }
    $corner = 2
    [ObsidianDockNative]::DwmSetWindowAttribute($handle, 33, [ref]$corner, 4) | Out-Null
}

function Set-WindowToolStyle {
    param(
        [Windows.Window]$TargetWindow,
        [bool]$NoActivate
    )
    $helper = [Windows.Interop.WindowInteropHelper]::new($TargetWindow)
    $handle = $helper.Handle
    $style = [ObsidianDockNative]::GetWindowLong($handle, -20)
    $style = $style -bor 0x00000080
    if ($NoActivate) { $style = $style -bor 0x08000000 }
    [ObsidianDockNative]::SetWindowLong($handle, -20, $style) | Out-Null
}

function Set-DockWindowRegion {
    $helper = [Windows.Interop.WindowInteropHelper]::new($window)
    $source = [Windows.PresentationSource]::FromVisual($window)
    if ($null -eq $source -or $null -eq $source.CompositionTarget) { return }

    $transform = $source.CompositionTarget.TransformToDevice
    $left = [int][Math]::Round(7 * $transform.M11)
    $top = [int][Math]::Round(5 * $transform.M22)
    $right = [int][Math]::Round(($window.ActualWidth - 7) * $transform.M11) + 1
    $bottom = [int][Math]::Round(($window.ActualHeight - 9) * $transform.M22) + 1
    $diameterX = [int][Math]::Round(72 * $transform.M11)
    $diameterY = [int][Math]::Round(72 * $transform.M22)
    $region = [ObsidianDockNative]::CreateRoundRectRgn($left, $top, $right, $bottom, $diameterX, $diameterY)
    if ($region -eq [IntPtr]::Zero) { return }

    if ([ObsidianDockNative]::SetWindowRgn($helper.Handle, $region, $true) -eq 0) {
        [void][ObsidianDockNative]::DeleteObject($region)
    }
}

function Set-DockPosition {
    $workArea = [Windows.SystemParameters]::WorkArea
    $window.Width = [Math]::Min(860, [Math]::Max(760, $workArea.Width - 24))
    $window.Left = [Math]::Round($workArea.Left + (($workArea.Width - $window.Width) / 2), 0)
    $window.Top = [Math]::Round($workArea.Bottom - $window.Height - 8, 0)
}

function Test-ForegroundFullscreen {
    $handle = [ObsidianDockNative]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { return $false }
    $helper = [Windows.Interop.WindowInteropHelper]::new($window)
    if ($handle -eq $helper.Handle) { return $false }
    $rect = New-Object ObsidianDockNative+RECT
    if (![ObsidianDockNative]::GetWindowRect($handle, [ref]$rect)) { return $false }
    $screen = [Windows.Forms.Screen]::FromHandle($handle).Bounds
    $coversScreen = ($rect.Left -le $screen.Left -and $rect.Top -le $screen.Top -and $rect.Right -ge $screen.Right -and $rect.Bottom -ge $screen.Bottom)
    if (!$coversScreen) { return $false }

    # A framed maximized window should keep the Dock available. True fullscreen
    # windows normally remove WS_CAPTION and are handled by safe mode below.
    $style = [ObsidianDockNative]::GetWindowLong($handle, -16)
    $hasCaption = (($style -band 0x00C00000) -ne 0)
    return !$hasCaption
}

function Set-DockFullscreenState {
    param([bool]$Enabled)

    $window.BeginAnimation([Windows.Window]::OpacityProperty, $null)
    if ($Enabled) {
        Hide-AppPreview
        $window.IsHitTestVisible = $false
        $window.Topmost = $false
        $window.Opacity = 0
        $window.Left = [Windows.SystemParameters]::VirtualScreenLeft - $window.Width - 120
        Write-DockLog "Fullscreen safe mode enabled without ending the Dock process."
        return
    }

    Set-DockPosition
    $window.IsHitTestVisible = $true
    $window.Topmost = $true
    $window.Opacity = 1
    Write-DockLog "Fullscreen safe mode disabled; Dock interaction restored."
}

function Refresh-DockRuntime {
    try {
        [void](Set-NativeDockVisible -Visible $false)
        $script:currentApps = @(Get-RunningApps)
        $script:retainedPages = @(Get-RetainedPages)
        $currentSignature = @($script:currentApps | ForEach-Object { $_.Key + ":" + $_.WindowTitle }) -join "|"
        $pageSignature = @($script:retainedPages | ForEach-Object { ([long]$_.WindowHandle).ToString() + ":" + $_.WindowTitle }) -join "|"
        $signature = $currentSignature + "::" + $pageSignature
        if ($signature -ne $script:runtimeSignature) {
            $script:runtimeSignature = $signature
            Render-Dock
            Write-DockLog ("Runtime refreshed: " + $script:currentApps.Count + " active apps, " + $script:retainedPages.Count + " retained pages.")
        }
        $fullscreen = Test-ForegroundFullscreen
        if ($fullscreen -ne $script:gameSafeMode) {
            $script:gameSafeMode = $fullscreen
            Set-DockFullscreenState -Enabled $fullscreen
        }
    } catch {
        Write-DockLog ("Runtime refresh failed: " + $_.Exception.ToString() + " | " + $_.ScriptStackTrace)
    }
}

$runtimeTimer = [Windows.Threading.DispatcherTimer]::new()
$runtimeTimer.Interval = [TimeSpan]::FromMilliseconds(1400)
$runtimeTimer.Add_Tick({ Refresh-DockRuntime })

$previewOpenTimer = [Windows.Threading.DispatcherTimer]::new()
$previewOpenTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$previewOpenTimer.Add_Tick({
    $previewOpenTimer.Stop()
    if ($null -ne $script:previewPending) {
        try {
            Show-AppPreview -App $script:previewPending
        } catch {
            Write-DockLog ("Preview failed: " + $_.Exception.ToString() + " | " + $_.ScriptStackTrace)
            Clear-PreviewThumbnail
            $previewWindow.Hide()
        }
    }
})

$previewHideTimer = [Windows.Threading.DispatcherTimer]::new()
$previewHideTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$previewHideTimer.Add_Tick({
    $previewHideTimer.Stop()
    if (!$previewWindow.IsMouseOver) { Hide-AppPreview }
})

$previewCloseTimer = [Windows.Threading.DispatcherTimer]::new()
$previewCloseTimer.Interval = [TimeSpan]::FromMilliseconds(320)
$previewCloseTimer.Add_Tick({
    $previewCloseTimer.Stop()
    if (!$script:previewVisible) {
        Clear-PreviewThumbnail
        $previewFloat.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
        $previewWindow.Hide()
    }
})

$dockRoot.Add_MouseMove({
    param($sender, $eventArgs)
    $position = $eventArgs.GetPosition($dockRoot)
    if ($dockRoot.ActualWidth -gt 0 -and $dockRoot.ActualHeight -gt 0) {
        $point = [Windows.Point]::new($position.X / $dockRoot.ActualWidth, $position.Y / $dockRoot.ActualHeight)
        $glowBrush.Center = $point
        $glowBrush.GradientOrigin = $point
    }
})
$dockRoot.Add_MouseLeave({ Reset-Magnification })
foreach ($scrollViewer in @($fixedScroll, $runningScroll, $pageScroll)) {
    $scrollViewer.Add_PreviewMouseWheel({
        param($sender, $eventArgs)
        $sender.ScrollToHorizontalOffset($sender.HorizontalOffset - ($eventArgs.Delta * 0.42))
        $eventArgs.Handled = $true
    })
}
$previewWindow.Add_MouseEnter({ $previewHideTimer.Stop() })
$previewWindow.Add_MouseLeave({ $previewHideTimer.Stop(); $previewHideTimer.Start() })
$previewWindow.Add_MouseLeftButtonUp({
    if ($null -ne $script:previewApp) { Invoke-DockApp -App $script:previewApp }
})
$window.Add_MouseRightButtonUp({
    if ([Windows.Input.Keyboard]::IsKeyDown([Windows.Input.Key]::LeftShift) -or [Windows.Input.Keyboard]::IsKeyDown([Windows.Input.Key]::RightShift)) {
        $window.Close()
    }
})
$window.Add_SourceInitialized({
    Set-WindowGlass -TargetWindow $window -GradientColor ([int]0x4CFFFFFF)
    Set-WindowToolStyle -TargetWindow $window -NoActivate $false
})
$previewWindow.Add_SourceInitialized({
    Set-WindowGlass -TargetWindow $previewWindow -GradientColor ([int]0xE6090A0E)
    Set-WindowToolStyle -TargetWindow $previewWindow -NoActivate $true
})
$window.Add_Loaded({
    Set-DockPosition
    $window.UpdateLayout()
    Set-DockWindowRegion
    [void](Set-NativeDockVisible -Visible $false)
    $window.Opacity = 0
    $window.BeginAnimation([Windows.Window]::OpacityProperty, (New-DoubleAnimation -To 1 -Milliseconds 380))
    Refresh-DockRuntime
    $runtimeTimer.Start()
    Write-DockLog ("Dock loaded at " + $window.Left + "," + $window.Top + ".")
})
$window.Add_Closed({
    $runtimeTimer.Stop()
    $previewOpenTimer.Stop()
    $previewHideTimer.Stop()
    $previewCloseTimer.Stop()
    Clear-PreviewThumbnail
    if ($previewWindow.IsVisible) { $previewWindow.Close() }
    [void](Set-NativeDockVisible -Visible $true)
    Write-DockLog "Dock closed and MyDockFinder restored."
})

try {
    $layout = Read-MyDockItems
    $script:fixedApps = @(Load-FixedOrder -Apps $layout.Apps)
    $script:trashItem = $layout.Trash
    Write-DockLog ("Starting Obsidian AI Dock with " + $script:fixedApps.Count + " fixed apps.")
    $window.ShowDialog() | Out-Null
} catch {
    Write-DockLog ("Fatal error: " + $_.Exception.ToString() + " | " + $_.ScriptStackTrace)
    [void](Set-NativeDockVisible -Visible $true)
    throw
} finally {
    [void](Set-NativeDockVisible -Visible $true)
    if ($createdNew) { try { $mutex.ReleaseMutex() } catch { } }
    $mutex.Dispose()
}
