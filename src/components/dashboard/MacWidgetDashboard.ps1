$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$script:root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:xamlPath = $script:root + "\Dashboard.xaml"
$script:dataRoot = $script:root + "\data"
$script:settingsPath = $script:dataRoot + "\mac-widget-settings.json"
$script:layoutPath = $script:dataRoot + "\mac-widget-layout.json"
$script:weatherCachePath = $script:dataRoot + "\mac-widget-weather-cache.json"
$script:todoPath = $script:dataRoot + "\mac-widget-todo.json"
$script:todoBackupPath = $script:dataRoot + "\mac-widget-todo.backup.json"
$script:legacyTodoPath = $script:dataRoot + "\todo.json"
$script:photoRoot = $script:dataRoot + "\wechat-photos"
$script:photoLibraryPath = $script:dataRoot + "\wechat-photo-library.json"
$script:photoDropRoot = $env:USERPROFILE + "\Pictures\微信生活"
$script:photoLockScreenRoot = $script:dataRoot + "\wechat-lockscreens"
$script:photoLockScreenStatePath = $script:dataRoot + "\wechat-lockscreen-state.json"
$script:appUsagePath = $script:dataRoot + "\app-usage.json"
$script:mediaHistoryPath = $script:dataRoot + "\media-history.json"
$script:modeDeckStatePath = $script:dataRoot + "\mode-deck.json"
$script:modeDeckBackdropPath = $script:root + "\assets\mode-deck-reference.jpg"
$script:lockStatePath = $env:LOCALAPPDATA + "\CodexLockscreen\state.json"
$script:powerHistoryPath = $script:dataRoot + "\power-history.json"
$script:logPath = $script:root + "\logs\dashboard.log"
$script:cinemaStatePath = $script:dataRoot + "\cinema-mode-active.flag"
$script:virtualDesktopAccessorPath = $script:root + "\lib\VirtualDesktopAccessor.dll"
$script:utf8 = New-Object Text.UTF8Encoding($false)
$script:speechEngine = $null
$script:speechListening = $false
$script:speechSources = @()
$script:speechProcess = $null
$script:speechIdleTimer = $null
$script:todoSaveTimer = $null
$script:todoLoaded = $false
$script:speechWorkerPath = $script:root + "\speech\whisper_worker.py"
$script:speechPythonPath = $script:root + "\speech-runtime\python-portable\python.exe"
$script:speechCachePath = $script:root + "\speech-runtime\models"
$script:speechCudaPath = $script:root + "\speech-runtime\cuda\libs"
$script:subtitleWorkerPath = $script:root + "\speech\subtitle_worker.py"
$script:syncedLyricsFetcherPath = $script:root + "\speech\synced_lyrics_fetcher.py"
$script:syncedLyricsRoot = $script:dataRoot + "\synced-lyrics"
$script:subtitleProcess = $null
$script:subtitleSources = @()
$script:subtitleRequested = $false
$script:subtitleListening = $false
$script:subtitleAudioTicks = 0
$script:subtitleSilenceTicks = 0
$script:subtitleHasCaption = $false
$script:subtitleLastCaptionUtc = [DateTime]::MinValue
$script:subtitleLastChinese = ""
$script:subtitleLastOriginal = ""
$script:subtitleMediaIdentity = ""
$script:subtitleStatusText = "双语字幕待机"
$script:subtitleStatusColor = "#72FFFFFF"
$script:subtitleRetryAfterUtc = [DateTime]::MinValue
$script:subtitleWarmupTimer = $null
$script:subtitleWarmupStage = 0
$script:subtitleWarmupRequested = $false
$script:subtitleLanguagePath = $script:dataRoot + "\subtitle-language.txt"
$script:subtitleLanguage = "auto"
$script:subtitleLanguageLabels = [ordered]@{
    auto = "自动"
    en = "英语"
    ja = "日语"
    ko = "韩语"
    es = "西语"
    fr = "法语"
    de = "德语"
    ru = "俄语"
    th = "泰语"
    zh = "中文"
    it = "意大利语"
    pt = "葡萄牙语"
    ar = "阿拉伯语"
    hi = "印地语"
    vi = "越南语"
    id = "印尼语"
    ms = "马来语"
    tr = "土耳其语"
    pl = "波兰语"
    nl = "荷兰语"
}
$script:syncedLyricsEntries = @()
$script:syncedLyricsKey = ""
$script:syncedLyricsRequestedKey = ""
$script:syncedLyricsFailedKey = ""
$script:syncedLyricsCachePath = ""
$script:syncedLyricsFetchProcess = $null
$script:syncedLyricsActive = $false
$script:syncedLyricsLastIndex = -1
$script:syncedLyricsLastElapsed = -1.0
$script:syncedLyricsDuration = 0.0
$script:syncedLyricsPlayerDuration = 0.0
$script:syncedLyricsOffsetSeconds = 0.20
$script:widgetWindows = @{}
$script:statusLights = New-Object 'System.Collections.Generic.List[Windows.UIElement]'
$script:statusLightsDimmed = $false
$script:widgetPetAssetRoot = $script:root + "\assets\widget-pets"
$script:petAnimations = @{}
$script:petAnimationTimer = $null
$script:petFrameWidth = 96.0
$script:petFrameHeight = 104.0
$script:photoSwipeStartX = $null
$script:photoTouchStartX = $null
$script:photoPreviewPauseTimer = $null
$script:photoFolderSyncTimer = $null
$script:photoFolderSyncBusy = $false
$script:mediaManager = $null
$script:mediaSession = $null
$script:mediaPlaybackStatus = "Idle"
$script:mediaTimeline = $null
$script:mediaVisualizerPhase = 0.0
$script:mediaVisualizerBars = @()
$script:mediaVisualizerTimer = $null
$script:mediaVisualizerStartTimer = $null
$script:mediaVisualizerStarted = $false
$script:mediaVisualizerFastIntervalMs = 100
$script:mediaVisualizerIdleIntervalMs = 420
$script:mediaCurrentTitle = ""
$script:mediaCurrentArtist = ""
$script:mediaSourceName = ""
$script:mediaSourceId = ""
$script:mediaContentMode = "music"
$script:mediaFallbackActiveUntilUtc = [DateTime]::MinValue
$script:mediaOverlayActive = $false
$script:mediaOverlayLastVisibleUtc = [DateTime]::MinValue
$script:pinnedPausedForExternalMedia = $false
$script:pinnedMediaAutoplayDisabled = $true
$script:pinnedMediaTitle = "依然与你同在"
$script:pinnedMediaArtist = "Still With You · Jung Kook"
$script:pinnedMediaUri = "https://soundcloud.com/bangtan/thankyouarmy2020"
$script:pinnedMediaStatePath = $script:root + "\SoundCloudPlayer\player-state.txt"
$script:pinnedMediaCommandPath = $script:root + "\SoundCloudPlayer\player-command.txt"
$script:pinnedMediaStartPath = $script:root + "\SoundCloudPlayer\start.ps1"
$script:mediaAvatarPath = $script:root + "\assets\media\strawberry-player-avatar.png"
$script:pinnedMediaElapsed = 0.0
$script:pinnedMediaDuration = 0.0
$script:mediaPlayingVisualState = $null
$script:mediaElapsedSeconds = 0.0
$script:mediaDurationSeconds = 0.0
$script:mediaHistory = @()
$script:mediaHistoryLoaded = $false
$script:mediaHistoryActiveKey = ""
$script:mediaHistoryLastSaveUtc = [DateTime]::MinValue
$script:mediaHistoryHardwareSnapshot = $null
$script:mediaHistoryHardwareLastSampleUtc = [DateTime]::MinValue
$script:mediaHistoryLastDisplaySignature = ""
$script:mediaHistoryLastRowsSignature = ""
$script:mediaHistoryLastRowsRefreshUtc = [DateTime]::MinValue
$script:mediaHistoryMaxEntries = 80
$script:mediaHistoryCopyStatusUntilUtc = [DateTime]::MinValue
$script:mediaHistoryCopyStatusText = ""
$script:pinnedMediaUpdatedUtc = [DateTime]::MinValue
$script:virtualDesktopTimer = $null
$script:virtualDesktopAccessorLoaded = $false
$script:hostWindowHandle = [IntPtr]::Zero
$script:supportedPhotoExtensions = @(".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".heic", ".heif", ".mov", ".mp4", ".m4v", ".webm")
$script:widgetsAutoHidden = $false
$script:widgetVisibilityBeforeAutoHide = @{}
$script:cinemaOverlayHandles = @{}
$script:cinemaModeTimer = $null
$script:cinemaSafeTickCount = 0
$script:desktopSurfaceActive = $false
$script:desktopSurfaceRestoreTimer = $null
$script:appUsageSeconds = @{}
$script:appUsageDate = (Get-Date).ToString("yyyy-MM-dd")
$script:appUsageCurrentName = "桌面空闲"
$script:appUsageLastTick = [DateTime]::UtcNow
$script:appUsageLastSave = [DateTime]::UtcNow
$script:appUsageTimer = $null
$script:modeDeckSaveTimer = $null
$script:modeDeckState = $null
$script:modeDeckReady = $false
$script:modeDeckRuntimeProfile = "none"
$script:modeDeckLastAction = "待机 · 尚未应用调优"
$script:modeDeckVisibilitySnapshot = @{}
$script:lockWidgetTimer = $null
$script:lockWidgetAutoHidden = $false
$script:powerHistoryTimer = $null
$script:deferredPowerHistoryTimer = $null
$script:lastLockWidgetStamp = ""
$script:powerHistorySnapshot = $null
    # Keep the media visualizer at the far right without touching the other desktop cards.
    $script:mediaCardAnchor = [pscustomobject]@{ Left = [double][Windows.SystemParameters]::WorkArea.Right - 458.0; Top = 525.0 }
$script:photoCardAnchor = [pscustomobject]@{ Left = 774.0; Top = 58.0 }
$script:widgetDefinitions = [ordered]@{
    WeatherCard  = @{ Width = 350; Height = 142; Column = 0; Row = 0 }
    FeatureCard  = @{ Width = 190; Height = 228; Column = 0; Row = 1 }
    CinemaModeCard = @{ Width = 120; Height = 105; Column = 1; Row = 0 }
    CodeModeCard = @{ Width = 120; Height = 132; Column = 1; Row = 1 }
    MusicModeCard = @{ Width = 120; Height = 132; Column = 1; Row = 2 }
    LockCard     = @{ Width = 124; Height = 124; Column = -1; Row = 2 }
    ClockCard    = @{ Width = 124; Height = 124; Column = 0; Row = 2 }
    CalendarCard = @{ Width = 124; Height = 124; Column = 1; Row = 2 }
    BatteryCard  = @{ Width = 124; Height = 124; Column = 0; Row = 3 }
    MediaCard    = @{ Width = 440; Height = 142; Column = 1; Row = 3 }
    AppUsageCard = @{ Width = 212; Height = 155; Column = 1; Row = 3 }
    PhotoCard    = @{ Width = 300; Height = 400; Column = 2; Row = 0 }
}

function Write-WidgetLog {
    param([string]$Message)
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $Message
    [IO.File]::AppendAllText($script:logPath, $line + [Environment]::NewLine, $script:utf8)
}

function Read-Utf8Json {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json
    } catch {
        Write-WidgetLog ("JSON read failed: " + $Path + " | " + $_.Exception.Message)
        return $null
    }
}

function Write-Utf8Json {
    param([string]$Path, $Value)
    $json = $Value | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($Path, $json, $script:utf8)
}

function Get-WidgetText {
    param([string]$Name, [string]$Fallback)
    if ($null -ne $script:settings) {
        $property = $script:settings.PSObject.Properties[$Name]
        if ($null -ne $property -and ![string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }
    return $Fallback
}

function ConvertTo-Brush {
    param([string]$Color)
    $value = [string]$Color
    if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$') {
        Write-WidgetLog ("Invalid brush value was replaced: " + $value)
        $value = "#FFFFFFFF"
    }
    try {
        return [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($value.Trim()))
    } catch {
        Write-WidgetLog ("Brush conversion failed for " + $value + ": " + $_.Exception.Message)
        return [Windows.Media.SolidColorBrush]::new([Windows.Media.Colors]::White)
    }
}

if (!("MacWidgetNative" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class MacWidgetNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO
    {
        public int Size;
        public RECT Monitor;
        public RECT Work;
        public uint Flags;
    }

    enum EDataFlow { eRender, eCapture, eAll }
    enum ERole { eConsole, eMultimedia, eCommunications }
    [Flags] enum CLSCTX : uint
    {
        INPROC_SERVER = 0x1,
        INPROC_HANDLER = 0x2,
        LOCAL_SERVER = 0x4,
        REMOTE_SERVER = 0x10,
        ALL = INPROC_SERVER | INPROC_HANDLER | LOCAL_SERVER | REMOTE_SERVER
    }
    [Flags] enum DEVICE_STATE : uint
    {
        ACTIVE = 0x1,
        DISABLED = 0x2,
        NOTPRESENT = 0x4,
        UNPLUGGED = 0x8,
        MASK_ALL = 0xF
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorComObject { }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(EDataFlow dataFlow, DEVICE_STATE stateMask, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice endpoint);
        [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
        [PreserveSig] int RegisterEndpointNotificationCallback(IntPtr client);
        [PreserveSig] int UnregisterEndpointNotificationCallback(IntPtr client);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, CLSCTX clsctx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object instance);
        [PreserveSig] int OpenPropertyStore(int access, out IntPtr properties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetState(out DEVICE_STATE state);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")]
    interface IAudioMeterInformation
    {
        [PreserveSig] int GetPeakValue(out float peak);
        [PreserveSig] int GetMeteringChannelCount(out int count);
        [PreserveSig] int GetChannelsPeakValues(int count, IntPtr values);
        [PreserveSig] int QueryHardwareSupport(out int mask);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A5CD92FF-29BE-454C-8D04-D82879FB3F1B")]
    interface IVirtualDesktopManager
    {
        [PreserveSig] int IsWindowOnCurrentVirtualDesktop(IntPtr topLevelWindow, out int onCurrentDesktop);
        [PreserveSig] int GetWindowDesktopId(IntPtr topLevelWindow, out Guid desktopId);
        [PreserveSig] int MoveWindowToDesktop(IntPtr topLevelWindow, ref Guid desktopId);
    }

    [ComImport, Guid("AA509086-5CA9-4C25-8F95-589D3C07B48A")]
    class VirtualDesktopManagerComObject { }

    static IAudioMeterInformation audioMeter;
    static IVirtualDesktopManager virtualDesktopManager;

    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("user32.dll")] public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")] public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr LoadLibrary(string path);
    [DllImport("VirtualDesktopAccessor.dll", CallingConvention = CallingConvention.Cdecl)] private static extern int IsPinnedWindow(IntPtr hWnd);
    [DllImport("VirtualDesktopAccessor.dll", CallingConvention = CallingConvention.Cdecl)] private static extern int PinWindow(IntPtr hWnd);
    [DllImport("VirtualDesktopAccessor.dll", CallingConvention = CallingConvention.Cdecl)] private static extern int UnPinWindow(IntPtr hWnd);

    static IntPtr virtualDesktopAccessorModule = IntPtr.Zero;

    public static string GetTitle(IntPtr hWnd)
    {
        int length = GetWindowTextLength(hWnd);
        if (length <= 0) return "";
        StringBuilder text = new StringBuilder(length + 1);
        GetWindowText(hWnd, text, text.Capacity);
        return text.ToString();
    }

    public static string GetWindowClass(IntPtr hWnd)
    {
        StringBuilder text = new StringBuilder(128);
        GetClassName(hWnd, text, text.Capacity);
        return text.ToString();
    }

    public static void SendMediaKey(byte key)
    {
        keybd_event(key, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 2, UIntPtr.Zero);
    }

    public static void ConfigureDesktopWidgetWindow(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero) return;
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x00000080;
        const int WS_EX_APPWINDOW = 0x00040000;
        int style = GetWindowLong(hWnd, GWL_EXSTYLE);
        style |= WS_EX_TOOLWINDOW;
        style &= ~WS_EX_APPWINDOW;
        SetWindowLong(hWnd, GWL_EXSTYLE, style);
        SetWindowPos(hWnd, IntPtr.Zero, 0, 0, 0, 0, 0x37);
    }

    public static void RefreshDesktopWidgetWindow(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero || !IsWindow(hWnd)) return;
        ShowWindow(hWnd, 0);
        ShowWindow(hWnd, 4);
        SetWindowPos(hWnd, new IntPtr(-1), 0, 0, 0, 0, 0x13);
        SetWindowPos(hWnd, new IntPtr(-2), 0, 0, 0, 0, 0x13);
    }

    public static bool LoadVirtualDesktopAccessor(string path)
    {
        if (virtualDesktopAccessorModule != IntPtr.Zero) return true;
        try
        {
            virtualDesktopAccessorModule = LoadLibrary(path);
            return virtualDesktopAccessorModule != IntPtr.Zero;
        }
        catch
        {
            virtualDesktopAccessorModule = IntPtr.Zero;
            return false;
        }
    }

    public static bool EnsureWindowPinned(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero || !IsWindow(hWnd) || virtualDesktopAccessorModule == IntPtr.Zero) return false;
        try
        {
            int pinned = IsPinnedWindow(hWnd);
            if (pinned == 1) return true;
            return PinWindow(hWnd) >= 0 && IsPinnedWindow(hWnd) == 1;
        }
        catch
        {
            return false;
        }
    }

    public static void ReleaseWindowPin(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero || virtualDesktopAccessorModule == IntPtr.Zero) return;
        try
        {
            if (IsPinnedWindow(hWnd) == 1) UnPinWindow(hWnd);
        }
        catch { }
    }

    static bool EnsureAudioMeter()
    {
        if (audioMeter != null) return true;
        try
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            IMMDevice endpoint;
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out endpoint) != 0 || endpoint == null) return false;
            Guid iid = typeof(IAudioMeterInformation).GUID;
            object instance;
            if (endpoint.Activate(ref iid, CLSCTX.ALL, IntPtr.Zero, out instance) != 0 || instance == null) return false;
            audioMeter = (IAudioMeterInformation)instance;
            return true;
        }
        catch
        {
            audioMeter = null;
            return false;
        }
    }

    public static float GetAudioPeak()
    {
        lock (typeof(MacWidgetNative))
        {
            if (!EnsureAudioMeter()) return 0f;
            try
            {
                float peak;
                if (audioMeter.GetPeakValue(out peak) == 0)
                {
                    return Math.Max(0f, Math.Min(1f, peak));
                }
            }
            catch
            {
                audioMeter = null;
            }
            return 0f;
        }
    }

    static bool EnsureVirtualDesktopManager()
    {
        if (virtualDesktopManager != null) return true;
        try
        {
            virtualDesktopManager = (IVirtualDesktopManager)new VirtualDesktopManagerComObject();
            return virtualDesktopManager != null;
        }
        catch
        {
            virtualDesktopManager = null;
            return false;
        }
    }

    static Guid GetCurrentDesktopId()
    {
        if (!EnsureVirtualDesktopManager()) return Guid.Empty;
        Guid result = Guid.Empty;
        int currentProcessId = Process.GetCurrentProcess().Id;
        IntPtr foreground = GetForegroundWindow();

        if (foreground != IntPtr.Zero)
        {
            uint foregroundProcessId;
            GetWindowThreadProcessId(foreground, out foregroundProcessId);
            int onCurrent;
            Guid desktopId;
            if (foregroundProcessId != currentProcessId &&
                virtualDesktopManager.IsWindowOnCurrentVirtualDesktop(foreground, out onCurrent) >= 0 &&
                onCurrent != 0 &&
                virtualDesktopManager.GetWindowDesktopId(foreground, out desktopId) >= 0 &&
                desktopId != Guid.Empty)
            {
                return desktopId;
            }
        }

        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (result != Guid.Empty || !IsWindowVisible(hWnd)) return result == Guid.Empty;
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId == 0 || processId == currentProcessId) return true;
            int onCurrent;
            Guid desktopId;
            if (virtualDesktopManager.IsWindowOnCurrentVirtualDesktop(hWnd, out onCurrent) >= 0 &&
                onCurrent != 0 &&
                virtualDesktopManager.GetWindowDesktopId(hWnd, out desktopId) >= 0 &&
                desktopId != Guid.Empty)
            {
                result = desktopId;
                return false;
            }
            return true;
        }, IntPtr.Zero);

        return result;
    }

    public static bool EnsureWindowOnCurrentDesktop(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero || !IsWindow(hWnd) || !EnsureVirtualDesktopManager()) return false;
        try
        {
            int onCurrent;
            if (virtualDesktopManager.IsWindowOnCurrentVirtualDesktop(hWnd, out onCurrent) >= 0 && onCurrent != 0) return true;
            Guid desktopId = GetCurrentDesktopId();
            return desktopId != Guid.Empty && virtualDesktopManager.MoveWindowToDesktop(hWnd, ref desktopId) >= 0;
        }
        catch
        {
            virtualDesktopManager = null;
            return false;
        }
    }

    public static IntPtr[] GetCinemaOverlayWindows()
    {
        List<IntPtr> windows = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd)) return true;

            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId == 0) return true;

            string processName;
            try
            {
                processName = Process.GetProcessById((int)processId).ProcessName;
            }
            catch
            {
                return true;
            }

            string title = GetTitle(hWnd);
            string windowClass = GetWindowClass(hWnd);
            bool isSeelenSurface = string.Equals(processName, "seelen-ui", StringComparison.OrdinalIgnoreCase) &&
                (string.Equals(title, "Seelen Fancy Toolbar", StringComparison.OrdinalIgnoreCase) ||
                 string.Equals(title, "SeelenWeg", StringComparison.OrdinalIgnoreCase));
            bool isMyDockFinderSurface = string.Equals(processName, "Dock_64", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(windowClass, "MyDockAPP", StringComparison.OrdinalIgnoreCase);

            if (isSeelenSurface || isMyDockFinderSurface) windows.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }

    public static IntPtr GetFirstApplicationWindow()
    {
        IntPtr result = IntPtr.Zero;
        int currentProcessId = Process.GetCurrentProcess().Id;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd) || IsIconic(hWnd)) return true;

            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId == 0 || processId == currentProcessId) return true;

            string processName;
            try
            {
                processName = Process.GetProcessById((int)processId).ProcessName;
            }
            catch
            {
                return true;
            }

            string[] ignoredProcesses = {
                "seelen-ui", "Dock_64", "Dockmod", "Dockmod64", "MyDockFinder",
                "SearchHost", "StartMenuExperienceHost", "ShellExperienceHost"
            };
            foreach (string ignored in ignoredProcesses)
            {
                if (string.Equals(processName, ignored, StringComparison.OrdinalIgnoreCase)) return true;
            }

            RECT rect;
            if (!GetWindowRect(hWnd, out rect)) return true;
            if (rect.Right - rect.Left < 160 || rect.Bottom - rect.Top < 100) return true;

            result = hWnd;
            return false;
        }, IntPtr.Zero);
        return result;
    }

    public static void SetWindowVisible(IntPtr hWnd, bool visible)
    {
        if (!IsWindow(hWnd)) return;
        ShowWindowAsync(hWnd, visible ? 4 : 0);
    }

    public static bool IsFullscreen(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero || IsIconic(hWnd)) return false;
        if (IsZoomed(hWnd)) return false;

        RECT windowRect;
        if (!GetWindowRect(hWnd, out windowRect)) return false;
        IntPtr monitor = MonitorFromWindow(hWnd, 2);
        if (monitor == IntPtr.Zero) return false;

        MONITORINFO info = new MONITORINFO();
        info.Size = Marshal.SizeOf(typeof(MONITORINFO));
        if (!GetMonitorInfo(monitor, ref info)) return false;

        const int tolerance = 8;
        return windowRect.Left <= info.Monitor.Left + tolerance &&
               windowRect.Top <= info.Monitor.Top + tolerance &&
               windowRect.Right >= info.Monitor.Right - tolerance &&
               windowRect.Bottom >= info.Monitor.Bottom - tolerance;
    }

    public static bool IsMaximizedOrFullscreen(IntPtr hWnd)
    {
        return hWnd != IntPtr.Zero && !IsIconic(hWnd) && (IsZoomed(hWnd) || IsFullscreen(hWnd));
    }
}
'@
}

function Initialize-WidgetVirtualDesktopSupport {
    $script:virtualDesktopAccessorLoaded = $false
    if (Test-Path -LiteralPath $script:virtualDesktopAccessorPath) {
        $script:virtualDesktopAccessorLoaded = [MacWidgetNative]::LoadVirtualDesktopAccessor($script:virtualDesktopAccessorPath)
    }

    if ($script:virtualDesktopAccessorLoaded) {
        Write-WidgetLog "Virtual desktop pin support loaded."
    } else {
        Write-WidgetLog "Virtual desktop pin library unavailable; current-desktop fallback enabled."
    }
}

function Register-DesktopWidgetHandle {
    param(
        [IntPtr]$Handle,
        [string]$Name
    )

    if ($Handle -eq [IntPtr]::Zero) { return $false }
    [MacWidgetNative]::ConfigureDesktopWidgetWindow($Handle)

    $ready = if ($script:virtualDesktopAccessorLoaded) {
        [MacWidgetNative]::EnsureWindowPinned($Handle)
    } else {
        [MacWidgetNative]::EnsureWindowOnCurrentDesktop($Handle)
    }

    Write-WidgetLog (("Desktop window registered: {0}; all-desktop pin={1}.") -f $Name, $ready)
    return $ready
}

function Ensure-WidgetVirtualDesktopPins {
    foreach ($name in $script:widgetDefinitions.Keys) {
        $widgetWindow = $script:widgetWindows[$name]
        if ($null -eq $widgetWindow -or $null -eq $widgetWindow.Tag) { continue }
        $handle = [IntPtr]$widgetWindow.Tag.Handle
        if ($handle -eq [IntPtr]::Zero) { continue }

        if ($script:virtualDesktopAccessorLoaded) {
            [void][MacWidgetNative]::EnsureWindowPinned($handle)
        } else {
            [void][MacWidgetNative]::EnsureWindowOnCurrentDesktop($handle)
        }
    }
}

function Restore-DesktopWidgetSurfaces {
    $restored = 0
    foreach ($name in $script:widgetDefinitions.Keys) {
        $widgetWindow = $script:widgetWindows[$name]
        if ($null -eq $widgetWindow -or !$widgetWindow.IsVisible -or $null -eq $widgetWindow.Tag) { continue }
        $handle = [IntPtr]$widgetWindow.Tag.Handle
        if ($handle -eq [IntPtr]::Zero) { continue }

        [MacWidgetNative]::RefreshDesktopWidgetWindow($handle)
        [MacWidgetNative]::ConfigureDesktopWidgetWindow($handle)
        if ($name -eq "MediaCard" -or $name -eq "PhotoCard") {
            Restore-FixedWidgetAnchor -Name $name
        }
        if ($script:virtualDesktopAccessorLoaded) {
            [void][MacWidgetNative]::EnsureWindowPinned($handle)
        }
        $restored++
    }

    if ($restored -gt 0) {
        Write-WidgetLog ("Desktop surface transition restored {0} widget windows." -f $restored)
    }
}

function Queue-DesktopWidgetSurfaceRestore {
    Restore-DesktopWidgetSurfaces
    if ($null -ne $script:desktopSurfaceRestoreTimer) {
        $script:desktopSurfaceRestoreTimer.Stop()
        $script:desktopSurfaceRestoreTimer.Start()
    }
}

function Release-WidgetVirtualDesktopPins {
    if (!$script:virtualDesktopAccessorLoaded) { return }
    foreach ($widgetWindow in @($script:widgetWindows.Values)) {
        if ($null -ne $widgetWindow -and $null -ne $widgetWindow.Tag) {
            [MacWidgetNative]::ReleaseWindowPin([IntPtr]$widgetWindow.Tag.Handle)
        }
    }
    if ($script:hostWindowHandle -ne [IntPtr]::Zero) {
        [MacWidgetNative]::ReleaseWindowPin($script:hostWindowHandle)
    }
}

function Set-CinemaShellVisibility {
    param([bool]$Hidden)

    if ($Hidden) {
        foreach ($handle in [MacWidgetNative]::GetCinemaOverlayWindows()) {
            $key = $handle.ToInt64().ToString()
            if (!$script:cinemaOverlayHandles.ContainsKey($key)) {
                $script:cinemaOverlayHandles[$key] = $handle
            }
            [MacWidgetNative]::SetWindowVisible($handle, $false)
        }
        if (!(Test-Path -LiteralPath $script:cinemaStatePath)) {
            [IO.File]::WriteAllText($script:cinemaStatePath, (Get-Date).ToString("o"), $script:utf8)
        }
        return
    }

    foreach ($handle in @($script:cinemaOverlayHandles.Values)) {
        [MacWidgetNative]::SetWindowVisible($handle, $true)
    }
    $script:cinemaOverlayHandles = @{}
    if (Test-Path -LiteralPath $script:cinemaStatePath) {
        [IO.File]::Delete($script:cinemaStatePath)
    }
}

function Set-WidgetCinemaMode {
    param(
        [bool]$Hidden,
        [bool]$HideShell,
        [string]$Reason
    )

    Set-CinemaShellVisibility -Hidden $HideShell
    if ($Hidden -eq $script:widgetsAutoHidden) { return }

    if ($Hidden) {
        $script:widgetVisibilityBeforeAutoHide = @{}
        foreach ($name in $script:widgetDefinitions.Keys) {
            $widgetWindow = $script:widgetWindows[$name]
            if ($null -eq $widgetWindow) { continue }
            $script:widgetVisibilityBeforeAutoHide[$name] = [bool]$widgetWindow.IsVisible
            if ($widgetWindow.IsVisible) { $widgetWindow.Hide() }
        }
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
            try { $video.Pause() } catch {}
        }
        $script:widgetsAutoHidden = $true
        Write-WidgetLog ("Desktop-only widgets hidden: " + $Reason)
        return
    }

    $script:widgetsAutoHidden = $false
    foreach ($name in $script:widgetDefinitions.Keys) {
        $widgetWindow = $script:widgetWindows[$name]
        if ($null -eq $widgetWindow) { continue }
        $wasVisible = $script:widgetVisibilityBeforeAutoHide.ContainsKey($name) -and [bool]$script:widgetVisibilityBeforeAutoHide[$name]
        if ($wasVisible -and !$widgetWindow.IsVisible) { $widgetWindow.Show() }
    }
    $video = $script:window.FindName("PhotoVideo")
    if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
        $surface = $script:window.FindName("PhotoSwipeSurface")
        if ($null -ne $surface -and $surface.IsMouseOver) {
            try { $video.Play() } catch {}
        }
    }
    $script:widgetVisibilityBeforeAutoHide = @{}
    Write-WidgetLog "Desktop-only widgets restored on desktop."
}

function Update-WidgetCinemaMode {
    $foreground = [MacWidgetNative]::GetForegroundWindow()
    if ($foreground -eq [IntPtr]::Zero) { return }

    [uint32]$foregroundProcessId = 0
    [void][MacWidgetNative]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
    if ($foregroundProcessId -eq [Diagnostics.Process]::GetCurrentProcess().Id) { return }

    try {
        $foregroundProcess = Get-Process -Id $foregroundProcessId -ErrorAction Stop
    } catch {
        return
    }

    $processName = [string]$foregroundProcess.ProcessName
    $title = [MacWidgetNative]::GetTitle($foreground)
    $windowClass = [MacWidgetNative]::GetWindowClass($foreground)
    $isTaskView = $processName -eq "explorer" -and $title -match "任务视图|Task View"
    if ($isTaskView) {
        $script:desktopSurfaceActive = $false
        $script:cinemaSafeTickCount = 0
        Set-WidgetCinemaMode -Hidden $true -HideShell $false -Reason "task view"
        return
    }
    $transientShellProcesses = @("SearchHost", "StartMenuExperienceHost", "ShellExperienceHost", "Seelen UI", "Seelen-UI", "MyDockFinder")
    if ($processName -in $transientShellProcesses) {
        $foreground = [MacWidgetNative]::GetFirstApplicationWindow()
        if ($foreground -eq [IntPtr]::Zero) { return }
        [void][MacWidgetNative]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
        try {
            $foregroundProcess = Get-Process -Id $foregroundProcessId -ErrorAction Stop
        } catch {
            return
        }
        $processName = [string]$foregroundProcess.ProcessName
        $title = [MacWidgetNative]::GetTitle($foreground)
        $windowClass = [MacWidgetNative]::GetWindowClass($foreground)
    }

    $isDesktop = $processName -eq "explorer" -and (
        [string]::IsNullOrWhiteSpace($title) -or
        $title -eq "Program Manager" -or
        $windowClass -in @("Progman", "WorkerW")
    )
    if ($isDesktop) {
        $script:cinemaSafeTickCount++
        if ($script:cinemaSafeTickCount -ge 2) {
            Set-WidgetCinemaMode -Hidden $false -HideShell $false -Reason "desktop"
            if (!$script:desktopSurfaceActive) {
                $script:desktopSurfaceActive = $true
                Queue-DesktopWidgetSurfaceRestore
            }
        }
        return
    }

    $script:desktopSurfaceActive = $false
    $script:cinemaSafeTickCount = 0
    $isFullscreenWindow = [MacWidgetNative]::IsFullscreen($foreground)
    $reason = "foreground application: " + $processName
    Set-WidgetCinemaMode -Hidden $true -HideShell $isFullscreenWindow -Reason $reason
}

function Import-WidgetXaml {
    $xml = New-Object Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($script:xamlPath)
    $reader = New-Object Xml.XmlNodeReader($xml)
    try { return [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
}

function Save-WidgetLayout {
    if ($script:widgetWindows.Count -eq 0) { return }
    $positions = [ordered]@{}
    foreach ($name in $script:widgetDefinitions.Keys) {
        $widgetWindow = $script:widgetWindows[$name]
        if ($null -eq $widgetWindow) { continue }
        $left = [Math]::Round($widgetWindow.Left, 0)
        $top = [Math]::Round($widgetWindow.Top, 0)
        if ($name -eq "MediaCard" -or $name -eq "PhotoCard") {
            $anchor = if ($name -eq "MediaCard") { $script:mediaCardAnchor } else { $script:photoCardAnchor }
            $left = [Math]::Round($anchor.Left, 0)
            $top = [Math]::Round($anchor.Top, 0)
            if ([Math]::Abs($widgetWindow.Left - $left) -gt 1 -or [Math]::Abs($widgetWindow.Top - $top) -gt 1) {
                $widgetWindow.Left = $left
                $widgetWindow.Top = $top
            }
        }
        $positions[$name] = [ordered]@{
            left = $left
            top = $top
            visible = if ($script:widgetsAutoHidden -and $script:widgetVisibilityBeforeAutoHide.ContainsKey($name)) {
                [bool]$script:widgetVisibilityBeforeAutoHide[$name]
            } else {
                [bool]$widgetWindow.IsVisible
            }
        }
    }
    $layout = [ordered]@{ version = 2; widgets = $positions }
    Write-Utf8Json -Path $script:layoutPath -Value $layout
}

function Restore-FixedWidgetAnchor {
    param([string]$Name)
    $widgetWindow = $script:widgetWindows[$Name]
    if ($null -eq $widgetWindow) { return }
    $anchor = if ($Name -eq "MediaCard") { $script:mediaCardAnchor } elseif ($Name -eq "PhotoCard") { $script:photoCardAnchor } else { $null }
    if ($null -eq $anchor) { return }
    $left = [double]$anchor.Left
    $top = [double]$anchor.Top
    if ([Math]::Abs($widgetWindow.Left - $left) -gt 1 -or [Math]::Abs($widgetWindow.Top - $top) -gt 1) {
        $widgetWindow.Left = $left
        $widgetWindow.Top = $top
    }
}

function Get-WidgetPosition {
    param([string]$Name, [double]$Width, [double]$Height, [int]$Column, [int]$Row)

    $workArea = [Windows.SystemParameters]::WorkArea
    $layout = Read-Utf8Json -Path $script:layoutPath
    $saved = $null
    if ($null -ne $layout -and $null -ne $layout.widgets) {
        $property = $layout.widgets.PSObject.Properties[$Name]
        if ($null -ne $property) { $saved = $property.Value }
    }

    $rightMargin = 18
    $gap = 10
    $wideWindow = 370
    $smallWindow = 144
    if ($Name -eq "FeatureCard") {
        $defaultLeft = $workArea.Right - 482
        $defaultTop = $workArea.Top + 34
    } elseif ($Name -eq "AppUsageCard") {
        $defaultLeft = $workArea.Right - 252
        $defaultTop = $workArea.Top + 34
    } elseif ($Name -eq "CinemaModeCard") {
        $defaultLeft = $workArea.Right - 480
        $defaultTop = $workArea.Top + 302
    } elseif ($Name -eq "CodeModeCard") {
        $defaultLeft = $workArea.Right - 320
        $defaultTop = $workArea.Top + 302
    } elseif ($Name -eq "MusicModeCard") {
        $defaultLeft = $workArea.Right - 160
        $defaultTop = $workArea.Top + 302
    } elseif ($Name -eq "PhotoCard") {
        $defaultLeft = $workArea.Left + 340
        $defaultTop = $workArea.Top + 128
    } elseif ($Name -eq "LockCard") {
        $clockSaved = $null
        if ($null -ne $layout -and $null -ne $layout.widgets) {
            $clockProperty = $layout.widgets.PSObject.Properties['ClockCard']
            if ($null -ne $clockProperty) { $clockSaved = $clockProperty.Value }
        }
        if ($null -ne $clockSaved) {
            $defaultLeft = [double]$clockSaved.left - $Width - 9
            $defaultTop = [double]$clockSaved.top
        } else {
            $defaultLeft = $workArea.Right - (($smallWindow * 4) + ($gap * 3)) - $rightMargin
            $defaultTop = $workArea.Bottom - $Height - 24
        }
    } else {
        $defaultLeft = if ($Column -eq 0) {
            $workArea.Right - $wideWindow - $rightMargin
        } else {
            $workArea.Right - $wideWindow - $rightMargin + $smallWindow + $gap
        }
        $defaultTop = switch ($Row) {
            0 { $workArea.Top + 52 }
            1 { $workArea.Top + 214 }
            2 { $workArea.Top + 418 }
            default { $workArea.Top + 562 }
        }
    }

    $left = if ($null -ne $saved) { [double]$saved.left } else { $defaultLeft }
    $top = if ($null -ne $saved) { [double]$saved.top } else { $defaultTop }
    $minLeft = $workArea.Left + 8
    $minTop = $workArea.Top + 8
    $maxLeft = [Math]::Max($minLeft, $workArea.Right - $Width - 8)
    $maxTop = [Math]::Max($minTop, $workArea.Bottom - $Height - 8)

    return [pscustomobject]@{
        Left = [Math]::Min($maxLeft, [Math]::Max($minLeft, $left))
        Top = [Math]::Min($maxTop, [Math]::Max($minTop, $top))
    }
}

function Test-InteractiveWidgetSource {
    param($Source)

    $current = $Source
    while ($null -ne $current) {
        if (
            $current -is [Windows.Controls.Primitives.ButtonBase] -or
            $current -is [Windows.Controls.TextBox] -or
            $current -is [Windows.Controls.ComboBox] -or
            $current -is [Windows.Controls.Slider] -or
            $current -is [Windows.Controls.CheckBox] -or
            $current -is [Windows.Controls.Primitives.ScrollBar] -or
            $current -is [Windows.Controls.ScrollViewer]
        ) { return $true }
        if ($current -is [Windows.FrameworkElement] -and $current.Name -like "MediaHistoryLinkRow*") { return $true }
        if ($current -is [Windows.FrameworkElement] -and $current.Name -eq "PhotoSwipeSurface") { return $true }
        try { $current = [Windows.Media.VisualTreeHelper]::GetParent($current) } catch { break }
    }
    return $false
}

function New-WidgetDoubleAnimation {
    param(
        [double]$To,
        [int]$Milliseconds
    )

    $animation = [Windows.Media.Animation.DoubleAnimation]::new()
    $animation.To = $To
    $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($Milliseconds))
    $ease = [Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [Windows.Media.Animation.EasingMode]::EaseOut
    $animation.EasingFunction = $ease
    [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
    return $animation
}

function Get-WidgetTheme {
    param([string]$Name)

    switch ($Name) {
        "WeatherCard" {
            return [pscustomobject]@{ Accent = "#FF83CBFF"; Secondary = "#FFD9F2FF"; EdgeA = "#FFF0FAFF"; EdgeB = "#FF4E91C9"; SurfaceA = "#E00A1825"; SurfaceB = "#D0050C14"; Soft = "#FFBFDFF6"; Ornament = "❄  ✦"; PetSlug = "prompt-penguin" }
        }
        "FeatureCard" {
            return [pscustomobject]@{ Accent = "#FFC39CFF"; Secondary = "#FFF0DEFF"; EdgeA = "#FFF8EEFF"; EdgeB = "#FF7653A8"; SurfaceA = "#E0141020"; SurfaceB = "#D0080710"; Soft = "#FFD9BFF2"; Ornament = "✿  ✦"; PetSlug = "fine-pup" }
        }
        "LockCard" {
            return [pscustomobject]@{ Accent = "#FFFF7FAF"; Secondary = "#FFFFD5E6"; EdgeA = "#FFFFF2F8"; EdgeB = "#FFC84F81"; SurfaceA = "#E0250D1A"; SurfaceB = "#D0120710"; Soft = "#FFFFB8D2"; Ornament = "♡  ✦"; PetSlug = "byte-bunny" }
        }
        "ClockCard" {
            return [pscustomobject]@{ Accent = "#FFFFC857"; Secondary = "#FFFFF0B0"; EdgeA = "#FFFFF9E5"; EdgeB = "#FFB7791F"; SurfaceA = "#E01C1608"; SurfaceB = "#D00B0702"; Soft = "#FFFFD987"; Ornament = "☼  ✦"; PetSlug = "little-deer" }
        }
        "CalendarCard" {
            return [pscustomobject]@{ Accent = "#FF62BFFF"; Secondary = "#FFB9FFF0"; EdgeA = "#FFEAFBFF"; EdgeB = "#FF3D7DBD"; SurfaceA = "#E0061722"; SurfaceB = "#D0030B13"; Soft = "#FF9FDCEB"; Ornament = "❄  ✦"; PetSlug = "nightly-fox" }
        }
        "BatteryCard" {
            return [pscustomobject]@{ Accent = "#FF9AD66D"; Secondary = "#FFE0F5BF"; EdgeA = "#FFF0FFE2"; EdgeB = "#FF4D8B3A"; SurfaceA = "#E00B1B13"; SurfaceB = "#D0040D08"; Soft = "#FFB8DBA3"; Ornament = "❖  ✦"; PetSlug = "cloudy" }
        }
        "MediaCard" {
            return [pscustomobject]@{ Accent = "#FF98D87C"; Secondary = "#FFD9F7CB"; EdgeA = "#FFF1FFE8"; EdgeB = "#FF579F62"; SurfaceA = "#F2061B12"; SurfaceB = "#E0000B07"; Soft = "#FFB7ECA0"; Ornament = "✦"; PetSlug = "silver-shorthair" }
        }
        "AppUsageCard" {
            return [pscustomobject]@{ Accent = "#FFB8C6D6"; Secondary = "#FF5B6A7B"; EdgeA = "#FFFFFFFF"; EdgeB = "#FFB6C2CF"; SurfaceA = "#F9FFFFFF"; SurfaceB = "#EAF1F5F8"; Soft = "#FF8798AA"; Ornament = "✦  ❉"; PetSlug = "silver-shorthair" }
        }
        "CinemaModeCard" {
            return [pscustomobject]@{ Accent = "#FF86C8FF"; Secondary = "#FFE6F3FF"; EdgeA = "#FFF5FCFF"; EdgeB = "#FF527FB0"; SurfaceA = "#E9162738"; SurfaceB = "#D80A111B"; Soft = "#FFB9E5FF"; Ornament = "✦"; PetSlug = "" }
        }
        "CodeModeCard" {
            return [pscustomobject]@{ Accent = "#FF8AD8A7"; Secondary = "#FFE4FFE9"; EdgeA = "#FFF5FFF7"; EdgeB = "#FF4B9066"; SurfaceA = "#E9142C20"; SurfaceB = "#D808110D"; Soft = "#FFB8EBC8"; Ornament = "◇"; PetSlug = "" }
        }
        "MusicModeCard" {
            return [pscustomobject]@{ Accent = "#FFD5A6F2"; Secondary = "#FFF4E6FF"; EdgeA = "#FFFFF8FF"; EdgeB = "#FF8E5CAB"; SurfaceA = "#E91D1530"; SurfaceB = "#D80B0712"; Soft = "#FFE6C4FF"; Ornament = "✦"; PetSlug = "" }
        }
        "PhotoCard" {
            return [pscustomobject]@{ Accent = "#FFFFD6AE"; Secondary = "#FFFFF1DE"; EdgeA = "#FFFFFFFF"; EdgeB = "#FFB98762"; SurfaceA = "#D91A130E"; SurfaceB = "#CC090704"; Soft = "#FFE5C7AE"; Ornament = "♡  ✿"; PetSlug = "byte-bunny" }
        }
        default {
            return [pscustomobject]@{ Accent = "#FF9CCBFF"; Secondary = "#FFE9F5FF"; EdgeA = "#FFFFFFFF"; EdgeB = "#FF5C7EA5"; SurfaceA = "#E00C121A"; SurfaceB = "#D005080D"; Soft = "#FFC8DCF0"; Ornament = "✦"; PetSlug = "byte-bunny" }
        }
    }
}

function Get-ModeDeckDefaultState {
    return [pscustomobject]@{
        version = 1
        activeMode = "none"
        cinema = [pscustomobject]@{ enabled = $false; picture = 78; soundfield = 60 }
        code = [pscustomobject]@{ enabled = $false; completion = $true; terminal = "高性能"; toolchain = $true }
        music = [pscustomobject]@{ enabled = $false; bass = 70; voice = 55; ambience = 65 }
    }
}

function Get-ModeDeckPropertyValue {
    param($Object, [string]$Name, $Fallback)
    if ($null -eq $Object) { return $Fallback }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Fallback }
    return $property.Value
}

function Get-ModeDeckInt {
    param($Value, [int]$Fallback, [int]$Minimum, [int]$Maximum)
    $number = 0
    if (![int]::TryParse([string]$Value, [ref]$number)) { $number = $Fallback }
    return [Math]::Min($Maximum, [Math]::Max($Minimum, $number))
}

function Load-ModeDeckState {
    $defaults = Get-ModeDeckDefaultState
    $saved = Read-Utf8Json -Path $script:modeDeckStatePath
    $savedCinema = Get-ModeDeckPropertyValue -Object $saved -Name "cinema" -Fallback $null
    $savedCode = Get-ModeDeckPropertyValue -Object $saved -Name "code" -Fallback $null
    $savedMusic = Get-ModeDeckPropertyValue -Object $saved -Name "music" -Fallback $null
    $active = [string](Get-ModeDeckPropertyValue -Object $saved -Name "activeMode" -Fallback "none")
    if ($active -notin @("none", "cinema", "code", "music")) { $active = "none" }

    $terminal = [string](Get-ModeDeckPropertyValue -Object $savedCode -Name "terminal" -Fallback "高性能")
    if ($terminal -notin @("标准", "高性能", "低干扰")) { $terminal = "高性能" }

    $script:modeDeckState = [pscustomobject]@{
        version = 1
        activeMode = $active
        cinema = [pscustomobject]@{
            enabled = [bool](Get-ModeDeckPropertyValue -Object $savedCinema -Name "enabled" -Fallback $defaults.cinema.enabled)
            picture = Get-ModeDeckInt (Get-ModeDeckPropertyValue -Object $savedCinema -Name "picture" -Fallback $defaults.cinema.picture) 78 0 100
            soundfield = Get-ModeDeckInt (Get-ModeDeckPropertyValue -Object $savedCinema -Name "soundfield" -Fallback $defaults.cinema.soundfield) 60 0 100
        }
        code = [pscustomobject]@{
            enabled = [bool](Get-ModeDeckPropertyValue -Object $savedCode -Name "enabled" -Fallback $defaults.code.enabled)
            completion = [bool](Get-ModeDeckPropertyValue -Object $savedCode -Name "completion" -Fallback $defaults.code.completion)
            terminal = $terminal
            toolchain = [bool](Get-ModeDeckPropertyValue -Object $savedCode -Name "toolchain" -Fallback $defaults.code.toolchain)
        }
        music = [pscustomobject]@{
            enabled = [bool](Get-ModeDeckPropertyValue -Object $savedMusic -Name "enabled" -Fallback $defaults.music.enabled)
            bass = Get-ModeDeckInt (Get-ModeDeckPropertyValue -Object $savedMusic -Name "bass" -Fallback $defaults.music.bass) 70 0 100
            voice = Get-ModeDeckInt (Get-ModeDeckPropertyValue -Object $savedMusic -Name "voice" -Fallback $defaults.music.voice) 55 0 100
            ambience = Get-ModeDeckInt (Get-ModeDeckPropertyValue -Object $savedMusic -Name "ambience" -Fallback $defaults.music.ambience) 65 0 100
        }
    }
}

function Save-ModeDeckState {
    if ($null -eq $script:modeDeckState) { return }
    $value = [ordered]@{
        version = 1
        activeMode = [string]$script:modeDeckState.activeMode
        cinema = [ordered]@{
            enabled = [bool]$script:modeDeckState.cinema.enabled
            picture = [int]$script:modeDeckState.cinema.picture
            soundfield = [int]$script:modeDeckState.cinema.soundfield
        }
        code = [ordered]@{
            enabled = [bool]$script:modeDeckState.code.enabled
            completion = [bool]$script:modeDeckState.code.completion
            terminal = [string]$script:modeDeckState.code.terminal
            toolchain = [bool]$script:modeDeckState.code.toolchain
        }
        music = [ordered]@{
            enabled = [bool]$script:modeDeckState.music.enabled
            bass = [int]$script:modeDeckState.music.bass
            voice = [int]$script:modeDeckState.music.voice
            ambience = [int]$script:modeDeckState.music.ambience
        }
    }
    try { Write-Utf8Json -Path $script:modeDeckStatePath -Value $value }
    catch { Write-WidgetLog ("Mode deck state save failed: " + $_.Exception.Message) }
}

function Request-ModeDeckSave {
    if ($null -eq $script:modeDeckSaveTimer) { Save-ModeDeckState; return }
    $script:modeDeckSaveTimer.Stop()
    $script:modeDeckSaveTimer.Start()
}

function Set-ModeDeckValueTexts {
    if ($null -eq $script:window) { return }
    $pairs = @(
        @("CinemaPictureSlider", "CinemaPictureValueText"),
        @("CinemaSoundSlider", "CinemaSoundValueText"),
        @("MusicBassSlider", "MusicBassValueText"),
        @("MusicVoiceSlider", "MusicVoiceValueText"),
        @("MusicAmbienceSlider", "MusicAmbienceValueText")
    )
    foreach ($pair in $pairs) {
        $slider = $script:window.FindName($pair[0])
        $label = $script:window.FindName($pair[1])
        if ($null -ne $slider -and $null -ne $label) {
            $label.Text = ([Math]::Round([double]$slider.Value)).ToString() + "%"
        }
    }
}

function Set-ModeDeckActionStatus {
    param(
        [string]$Text,
        [string]$Color = "#9EFFFFFF"
    )

    $script:modeDeckLastAction = $Text
    if ($null -eq $script:window) { return }
    $statusModes = @{
        CinemaActionStatusText = "cinema"
        CodeActionStatusText = "code"
        MusicActionStatusText = "music"
    }
    foreach ($statusName in $statusModes.Keys) {
        $status = $script:window.FindName($statusName)
        if ($null -ne $status) {
            $isActiveStatus = $null -eq $script:modeDeckState -or
                [string]$script:modeDeckState.activeMode -eq "none" -or
                [string]$script:modeDeckState.activeMode -eq [string]$statusModes[$statusName]
            $statusText = if ($isActiveStatus) { $Text } else { "待机 · 点击一键调优" }
            $statusColor = if ($isActiveStatus) { $Color } else { "#78FFFFFF" }
            $status.Text = $statusText
            $status.Foreground = ConvertTo-Brush -Color $statusColor
        }
    }
}

function Show-ModeDeckCompanionWidget {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $widgetWindow = $script:widgetWindows[$Name]
    if ($null -eq $widgetWindow) { return }

    if (!$script:modeDeckVisibilitySnapshot.ContainsKey($Name)) {
        $script:modeDeckVisibilitySnapshot[$Name] = [bool]$widgetWindow.IsVisible
    }
    if ($script:widgetsAutoHidden -or $widgetWindow.IsVisible) { return }

    $widgetWindow.Show()
    if ($null -ne $widgetWindow.Tag -and $null -ne $widgetWindow.Tag.Handle) {
        try { [MacWidgetNative]::ConfigureDesktopWidgetWindow([IntPtr]$widgetWindow.Tag.Handle) } catch {}
    }
}

function Restore-ModeDeckCompanionWidgets {
    if ($script:modeDeckVisibilitySnapshot.Count -eq 0) { return }
    if (!$script:widgetsAutoHidden) {
        foreach ($name in @($script:modeDeckVisibilitySnapshot.Keys)) {
            $widgetWindow = $script:widgetWindows[$name]
            if ($null -eq $widgetWindow) { continue }
            $wasVisible = [bool]$script:modeDeckVisibilitySnapshot[$name]
            if ($wasVisible -and !$widgetWindow.IsVisible) { $widgetWindow.Show() }
            if (!$wasVisible -and $widgetWindow.IsVisible) { $widgetWindow.Hide() }
        }
    }
    $script:modeDeckVisibilitySnapshot = @{}
}

function Reset-ModeDeckMediaRuntime {
    $script:subtitleAudioTicks = 0
    $script:subtitleSilenceTicks = 0
    if ($script:mediaContentMode -ne "video") { return }

    $script:mediaFallbackActiveUntilUtc = [DateTime]::MinValue
    $script:subtitleRetryAfterUtc = [DateTime]::UtcNow.AddSeconds(2)
    if ($script:mediaPlaybackStatus -ne "Playing") {
        $script:mediaContentMode = "music"
        if ($script:subtitleRequested) {
            try { Stop-MediaSubtitles } catch { Write-WidgetLog ("Mode deck subtitle cleanup failed: " + $_.Exception.Message) }
        }
        Write-WidgetLog "Mode deck video profile cleared; idle media state returned to standby."
        return
    }

    Write-WidgetLog "Mode deck video profile left active; live media detection remains authoritative."
}

function Invoke-ModeDeckCinemaTune {
    $script:modeDeckRuntimeProfile = "cinema"
    $script:mediaContentMode = "video"
    $script:subtitleRetryAfterUtc = [DateTime]::MinValue
    Show-ModeDeckCompanionWidget -Name "MediaCard"

    $mediaState = $script:window.FindName("MediaStateText")
    if ($null -ne $mediaState -and $script:mediaPlaybackStatus -eq "Playing") {
        $mediaState.Text = "电影字幕监听"
        Set-MediaSubtitleStatus -Text "电影模式 · 正在监听对白" -Color "#FFA7F3D0"
    } else {
        Set-MediaSubtitleStatus -Text "电影模式已就绪 · 播放后自动双语字幕" -Color "#FFFFD98A"
    }
    Set-ModeDeckActionStatus -Text "电影：字幕监听 + 全屏避让已启用" -Color "#FFA8DEFF"
    Write-WidgetLog "Mode deck cinema tuning applied: subtitle listener ready; existing fullscreen avoidance retained."
}

function Invoke-ModeDeckCodeTune {
    $script:modeDeckRuntimeProfile = "code"
    $script:modeDeckState.code.completion = $true
    $script:modeDeckState.code.toolchain = $true
    $script:modeDeckState.code.terminal = "高性能"

    $completionToggle = $script:window.FindName("CodeCompletionToggle")
    $toolchainToggle = $script:window.FindName("CodeToolchainToggle")
    $terminalCombo = $script:window.FindName("CodeTerminalCombo")
    if ($null -ne $completionToggle) { $completionToggle.IsChecked = $true }
    if ($null -ne $toolchainToggle) { $toolchainToggle.IsChecked = $true }
    if ($null -ne $terminalCombo) { $terminalCombo.SelectedIndex = 1 }

    Show-ModeDeckCompanionWidget -Name "FeatureCard"
    Set-ModeDeckActionStatus -Text "AI 编程：工作台 + 本地配置已就绪" -Color "#FFA7F3D0"
    Write-WidgetLog "Mode deck code tuning applied: local AI workbench revealed; completion, toolchain hints and terminal profile enabled."
}

function Invoke-ModeDeckMusicTune {
    $script:modeDeckRuntimeProfile = "music"
    $script:mediaContentMode = "music"
    $script:subtitleRetryAfterUtc = [DateTime]::MinValue
    Show-ModeDeckCompanionWidget -Name "MediaCard"

    Set-ModeDeckActionStatus -Text "音乐：可视化 + 歌词管线已就绪" -Color "#FFE3B7FF"
    Write-WidgetLog "Mode deck music tuning applied: existing media and visualizer timers retained; duplicate click-time refresh skipped."
}

function Restore-ModeDeckRuntimeProfile {
    param([switch]$Silent)
    $wasCinema = [string]$script:modeDeckRuntimeProfile -eq "cinema"
    Restore-ModeDeckCompanionWidgets
    if ($wasCinema) { Reset-ModeDeckMediaRuntime }
    $script:modeDeckRuntimeProfile = "none"
    if (!$Silent) {
        Set-ModeDeckActionStatus -Text "已恢复待机 · 不修改系统设置" -Color "#9EFFFFFF"
        Write-WidgetLog "Mode deck runtime profile restored to standby."
    }
}

function Apply-ModeDeckPersistedRuntimeProfile {
    if ($null -eq $script:modeDeckState) { return }
    switch ([string]$script:modeDeckState.activeMode) {
        "cinema" { Invoke-ModeDeckCinemaTune; break }
        "code" { Invoke-ModeDeckCodeTune; break }
        "music" { Invoke-ModeDeckMusicTune; break }
        default { Set-ModeDeckActionStatus -Text "待机 · 尚未应用调优" -Color "#9EFFFFFF"; break }
    }
    Set-ModeDeckVisualState
}

function Set-ModeDeckVisualState {
    if ($null -eq $script:window -or $null -eq $script:modeDeckState) { return }
    $profiles = @(
        @{ Mode = "cinema"; Panel = "CinemaModeCard"; Button = "CinemaModeButton"; Label = "CinemaModeButtonText"; Active = "#594B8FE8"; Idle = "#241F3A61"; Edge = "#FF8EBAFF" },
        @{ Mode = "code"; Panel = "CodeModeCard"; Button = "CodeModeButton"; Label = "CodeModeButtonText"; Active = "#4B4DAA72"; Idle = "#23324E37"; Edge = "#FF9CE4A7" },
        @{ Mode = "music"; Panel = "MusicModeCard"; Button = "MusicModeButton"; Label = "MusicModeButtonText"; Active = "#594E3A9D"; Idle = "#242D215D"; Edge = "#FFDBA6F2" }
    )
    foreach ($profile in $profiles) {
        $panel = $script:window.FindName($profile.Panel)
        $button = $script:window.FindName($profile.Button)
        $label = $script:window.FindName($profile.Label)
        $active = [string]$script:modeDeckState.activeMode -eq $profile.Mode
        $panelEdgeColor = if ($active) { $profile.Edge } else { "#42FFFFFF" }
        $buttonFillColor = if ($active) { $profile.Active } else { $profile.Idle }
        if ($null -ne $panel) {
            $panel.Opacity = if ($active) { 1.0 } else { 0.72 }
            $panel.BorderBrush = ConvertTo-Brush -Color $panelEdgeColor
        }
        if ($null -ne $button) {
            $button.Background = ConvertTo-Brush -Color $buttonFillColor
            $button.ToolTip = if ($active) { "关闭" + $profile.Mode + "模式" } else { "一键调优" + $profile.Mode + "模式" }
        }
        if ($null -ne $label) { $label.Text = if ($active) { "已启用" } else { "一键调优" } }
    }
    $completionText = $script:window.FindName("CodeCompletionStateText")
    if ($null -ne $completionText) { $completionText.Text = if ($script:modeDeckState.code.completion) { "开启" } else { "关闭" } }
    $toolchainText = $script:window.FindName("CodeToolchainStateText")
    if ($null -ne $toolchainText) { $toolchainText.Text = if ($script:modeDeckState.code.toolchain) { "开启" } else { "关闭" } }
}

function Set-ModeDeckMode {
    param([string]$Mode)
    if ($Mode -notin @("cinema", "code", "music")) { return }
    if ($null -eq $script:modeDeckState) { Load-ModeDeckState }
    $previousMode = [string]$script:modeDeckState.activeMode
    $nextMode = if ($previousMode -eq $Mode) { "none" } else { $Mode }
    $leavingMode = $previousMode -ne "none" -and $previousMode -ne $nextMode
    if ($leavingMode) { Restore-ModeDeckRuntimeProfile -Silent }
    $script:modeDeckState.activeMode = $nextMode
    $script:modeDeckState.cinema.enabled = ([string]$script:modeDeckState.activeMode -eq "cinema")
    $script:modeDeckState.code.enabled = ([string]$script:modeDeckState.activeMode -eq "code")
    $script:modeDeckState.music.enabled = ([string]$script:modeDeckState.activeMode -eq "music")
    switch ([string]$script:modeDeckState.activeMode) {
        "cinema" { Invoke-ModeDeckCinemaTune; break }
        "code" { Invoke-ModeDeckCodeTune; break }
        "music" { Invoke-ModeDeckMusicTune; break }
        default {
            if ($leavingMode) {
                Set-ModeDeckActionStatus -Text "已恢复待机 · 不修改系统设置" -Color "#9EFFFFFF"
                Write-WidgetLog "Mode deck runtime profile restored to standby."
            } else {
                Restore-ModeDeckRuntimeProfile
            }
            break
        }
    }
    Set-ModeDeckVisualState
    Request-ModeDeckSave
    Write-WidgetLog ("Mode deck changed: " + [string]$script:modeDeckState.activeMode)
}

function Reset-ModeDeckState {
    Restore-ModeDeckRuntimeProfile
    $script:modeDeckState = Get-ModeDeckDefaultState
    $script:modeDeckReady = $false
    $script:window.FindName("CinemaPictureSlider").Value = $script:modeDeckState.cinema.picture
    $script:window.FindName("CinemaSoundSlider").Value = $script:modeDeckState.cinema.soundfield
    $script:window.FindName("MusicBassSlider").Value = $script:modeDeckState.music.bass
    $script:window.FindName("MusicVoiceSlider").Value = $script:modeDeckState.music.voice
    $script:window.FindName("MusicAmbienceSlider").Value = $script:modeDeckState.music.ambience
    $script:window.FindName("CodeCompletionToggle").IsChecked = $script:modeDeckState.code.completion
    $script:window.FindName("CodeToolchainToggle").IsChecked = $script:modeDeckState.code.toolchain
    $script:window.FindName("CodeTerminalCombo").SelectedIndex = 1
    $script:modeDeckReady = $true
    Set-ModeDeckValueTexts
    Set-ModeDeckVisualState
    Request-ModeDeckSave
}

function Initialize-ModeDeckWidget {
    Load-ModeDeckState
    $script:modeDeckSaveTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:modeDeckSaveTimer.Interval = [TimeSpan]::FromMilliseconds(450)
    $script:modeDeckSaveTimer.Add_Tick({
        $script:modeDeckSaveTimer.Stop()
        Save-ModeDeckState
    })

    $backdrop = $script:window.FindName("ModeDeckBackdrop")
    if ($null -ne $backdrop -and (Test-Path -LiteralPath $script:modeDeckBackdropPath)) {
        try {
            $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.UriSource = [Uri]::new($script:modeDeckBackdropPath, [UriKind]::Absolute)
            $bitmap.EndInit()
            $bitmap.Freeze()
            $backdrop.Source = $bitmap
            $blur = [Windows.Media.Effects.BlurEffect]::new()
            $blur.Radius = 10
            $backdrop.Effect = $blur
        } catch { Write-WidgetLog ("Mode deck reference image failed: " + $_.Exception.Message) }
    }

    $script:modeDeckReady = $false
    $script:window.FindName("CinemaPictureSlider").Value = $script:modeDeckState.cinema.picture
    $script:window.FindName("CinemaSoundSlider").Value = $script:modeDeckState.cinema.soundfield
    $script:window.FindName("MusicBassSlider").Value = $script:modeDeckState.music.bass
    $script:window.FindName("MusicVoiceSlider").Value = $script:modeDeckState.music.voice
    $script:window.FindName("MusicAmbienceSlider").Value = $script:modeDeckState.music.ambience
    $script:window.FindName("CodeCompletionToggle").IsChecked = $script:modeDeckState.code.completion
    $script:window.FindName("CodeToolchainToggle").IsChecked = $script:modeDeckState.code.toolchain
    $script:window.FindName("CodeTerminalCombo").SelectedIndex = @("标准", "高性能", "低干扰").IndexOf([string]$script:modeDeckState.code.terminal)
    if ($script:window.FindName("CodeTerminalCombo").SelectedIndex -lt 0) { $script:window.FindName("CodeTerminalCombo").SelectedIndex = 1 }
    $script:modeDeckReady = $true

    $script:window.FindName("CinemaModeButton").Add_Click({ Set-ModeDeckMode -Mode "cinema" })
    $script:window.FindName("CodeModeButton").Add_Click({ Set-ModeDeckMode -Mode "code" })
    $script:window.FindName("MusicModeButton").Add_Click({ Set-ModeDeckMode -Mode "music" })

    $script:window.FindName("CinemaPictureSlider").Add_ValueChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.cinema.picture = [int][Math]::Round($sender.Value)
        Set-ModeDeckValueTexts
        Request-ModeDeckSave
    })
    $script:window.FindName("CinemaSoundSlider").Add_ValueChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.cinema.soundfield = [int][Math]::Round($sender.Value)
        Set-ModeDeckValueTexts
        Request-ModeDeckSave
    })
    $script:window.FindName("MusicBassSlider").Add_ValueChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.music.bass = [int][Math]::Round($sender.Value)
        Set-ModeDeckValueTexts
        Request-ModeDeckSave
    })
    $script:window.FindName("MusicVoiceSlider").Add_ValueChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.music.voice = [int][Math]::Round($sender.Value)
        Set-ModeDeckValueTexts
        Request-ModeDeckSave
    })
    $script:window.FindName("MusicAmbienceSlider").Add_ValueChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.music.ambience = [int][Math]::Round($sender.Value)
        Set-ModeDeckValueTexts
        Request-ModeDeckSave
    })
    $script:window.FindName("CodeCompletionToggle").Add_Click({
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.code.completion = [bool]$script:window.FindName("CodeCompletionToggle").IsChecked
        Set-ModeDeckVisualState
        Request-ModeDeckSave
    })
    $script:window.FindName("CodeToolchainToggle").Add_Click({
        if (!$script:modeDeckReady) { return }
        $script:modeDeckState.code.toolchain = [bool]$script:window.FindName("CodeToolchainToggle").IsChecked
        Set-ModeDeckVisualState
        Request-ModeDeckSave
    })
    $script:window.FindName("CodeTerminalCombo").Add_SelectionChanged({
        param($sender, $eventArgs)
        if (!$script:modeDeckReady -or $null -eq $sender.SelectedItem) { return }
        $script:modeDeckState.code.terminal = [string]$sender.SelectedItem.Content
        Request-ModeDeckSave
    })
    $script:window.FindName("ModeDeckOpenAIButton").Add_Click({
        $feature = $script:widgetWindows["FeatureCard"]
        if ($null -ne $feature) {
            if (!$feature.IsVisible -and !$script:widgetsAutoHidden) { $feature.Show() }
            try { [void]$feature.Activate() } catch {}
        }
    })
    $script:window.FindName("ModeDeckResetButton").Add_Click({ Reset-ModeDeckState })
    Set-ModeDeckValueTexts
    Set-ModeDeckVisualState
    Write-WidgetLog "Mode deck initialized with local cinema, code and music profiles."
}

function Get-WidgetAccentColor {
    param([string]$Name)
    return (Get-WidgetTheme -Name $Name).Accent
}

function New-WidgetThemeEdgeBrush {
    param($Theme)

    $brush = [Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [Windows.Point]::new(0, 0)
    $brush.EndPoint = [Windows.Point]::new(1, 1)
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.EdgeA), 0.0))
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.Accent), 0.34))
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.EdgeB), 0.72))
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.Secondary), 1.0))
    return $brush
}

function New-WidgetThemeSurfaceBrush {
    param($Theme)

    $brush = [Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [Windows.Point]::new(0, 0)
    $brush.EndPoint = [Windows.Point]::new(0.9, 1)
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.SurfaceA), 0.0))
    [void]$brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($Theme.SurfaceB), 1.0))
    return $brush
}

function New-WidgetPetBrush {
    param([string]$PetSlug)

    $petPath = $script:widgetPetAssetRoot + "\" + $PetSlug + ".png"
    if (!(Test-Path -LiteralPath $petPath)) {
        Write-WidgetLog ("Pet sprite missing: " + $petPath)
        return $null
    }

    try {
        $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.DecodePixelWidth = 768
        $bitmap.UriSource = [Uri]::new($petPath, [UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()

        $brush = [Windows.Media.ImageBrush]::new($bitmap)
        $brush.ViewboxUnits = [Windows.Media.BrushMappingMode]::Absolute
        $brush.Viewbox = [Windows.Rect]::new(0, 0, $script:petFrameWidth, $script:petFrameHeight)
        $brush.Stretch = [Windows.Media.Stretch]::Uniform
        $brush.AlignmentX = [Windows.Media.AlignmentX]::Center
        $brush.AlignmentY = [Windows.Media.AlignmentY]::Center
        return $brush
    } catch {
        Write-WidgetLog ("Pet sprite load failed: " + $petPath + " | " + $_.Exception.Message)
        return $null
    }
}

function Set-WidgetVisualState {
    param(
        [Windows.Window]$WidgetWindow,
        [bool]$Hovered
    )

    $meta = $WidgetWindow.Tag
    if ($null -eq $meta -or $null -eq $meta.CardScale) { return }
    $scale = if ($Hovered) { 1.018 } else { 1.0 }
    $lift = if ($Hovered) { -2.0 } else { 0.0 }
    $glow = if ($meta.IsPhoto) { if ($Hovered) { 0.48 } else { 0.24 } } else { if ($Hovered) { 0.92 } else { 0.52 } }
    $sheen = if ($meta.IsPhoto) { if ($Hovered) { 0.42 } else { 0.18 } } else { if ($Hovered) { 0.92 } else { 0.48 } }
    $shadow = if ($Hovered) { 0.78 } else { 0.58 }

    $meta.CardScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-WidgetDoubleAnimation -To $scale -Milliseconds 180))
    $meta.CardScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-WidgetDoubleAnimation -To $scale -Milliseconds 180))
    $meta.CardTranslate.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, (New-WidgetDoubleAnimation -To $lift -Milliseconds 180))
    $meta.Glow.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $glow -Milliseconds 220))
    $meta.Sheen.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $sheen -Milliseconds 220))
    if ($null -ne $meta.Card.Effect) {
        $meta.Card.Effect.BeginAnimation([Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-WidgetDoubleAnimation -To $shadow -Milliseconds 220))
    }

    $meta.PetHovered = $Hovered
    if ($null -ne $meta.PetVisual) {
        $petScale = if ($Hovered) { 1.12 } else { 1.0 }
        $petOpacity = if ($Hovered) { 0.98 } else { 0.82 }
        $auraOpacity = if ($Hovered) { 0.68 } else { 0.22 }
        $meta.PetScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-WidgetDoubleAnimation -To $petScale -Milliseconds 200))
        $meta.PetScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-WidgetDoubleAnimation -To $petScale -Milliseconds 200))
        $meta.PetVisual.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $petOpacity -Milliseconds 220))
        $meta.PetAura.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $auraOpacity -Milliseconds 240))
        foreach ($sparkle in $meta.PetSparkles) {
            $target = if ($Hovered) { 0.92 } else { 0.2 }
            $sparkle.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $target -Milliseconds 220))
        }
    }
}

function Update-WidgetPetAnimations {
    foreach ($name in @($script:petAnimations.Keys)) {
        $widgetWindow = $script:petAnimations[$name]
        if ($null -eq $widgetWindow -or !$widgetWindow.IsVisible) { continue }

        $meta = $widgetWindow.Tag
        if ($null -eq $meta -or $null -eq $meta.PetBrush) { continue }

        if ($meta.PetHovered) {
            $row = 3
            $frameCount = 4
            $meta.PetActionName = "Waving"
            $meta.PetActionTicks = 0
        } else {
            $meta.PetActionTicks++
            if ($meta.PetActionName -eq "Waving") {
                $meta.PetActionName = "Idle"
                $meta.PetActionRow = 0
                $meta.PetActionFrameCount = 6
                $meta.PetActionTicks = 0
                $meta.PetFrame = 0
            }

            if ($meta.PetActionName -eq "Idle" -and $meta.PetActionTicks -ge $meta.PetNextActionTicks) {
                switch ($meta.PetActionCycle % 4) {
                    0 { $meta.PetActionName = "Jumping"; $meta.PetActionRow = 4; $meta.PetActionFrameCount = 5; $meta.PetActionDuration = 10 }
                    1 { $meta.PetActionName = "Waiting"; $meta.PetActionRow = 6; $meta.PetActionFrameCount = 6; $meta.PetActionDuration = 12 }
                    2 { $meta.PetActionName = "Running"; $meta.PetActionRow = 7; $meta.PetActionFrameCount = 6; $meta.PetActionDuration = 12 }
                    default { $meta.PetActionName = "Review"; $meta.PetActionRow = 8; $meta.PetActionFrameCount = 6; $meta.PetActionDuration = 12 }
                }
                $meta.PetActionCycle++
                $meta.PetActionTicks = 0
                $meta.PetFrame = 0
            } elseif ($meta.PetActionName -ne "Idle" -and $meta.PetActionTicks -ge $meta.PetActionDuration) {
                $meta.PetActionName = "Idle"
                $meta.PetActionRow = 0
                $meta.PetActionFrameCount = 6
                $meta.PetActionTicks = 0
                $meta.PetNextActionTicks = 14 + (($meta.PetActionCycle + $script:petAnimations.Count) % 13)
                $meta.PetFrame = 0
            }

            $row = $meta.PetActionRow
            $frameCount = $meta.PetActionFrameCount
        }
        $meta.PetFrame = ($meta.PetFrame + 1) % $frameCount
        $meta.PetBrush.Viewbox = [Windows.Rect]::new(($meta.PetFrame * $script:petFrameWidth), ($row * $script:petFrameHeight), $script:petFrameWidth, $script:petFrameHeight)

        $phaseStep = if ($meta.PetHovered) { 0.46 } else { 0.25 }
        $floatAmount = if ($meta.PetHovered) { 2.2 } else { 1.1 }
        $tiltAmount = if ($meta.PetHovered) { 2.4 } else { 0.8 }
        $meta.PetPhase = $meta.PetPhase + $phaseStep
        $meta.PetTranslate.X = if (!$meta.PetHovered -and $meta.PetActionName -eq "Running") { [Math]::Sin($meta.PetPhase * 0.78) * 4.5 } else { 0 }
        $meta.PetTranslate.Y = [Math]::Sin($meta.PetPhase) * $floatAmount
        $meta.PetRotate.Angle = [Math]::Sin($meta.PetPhase * 0.72) * $tiltAmount

        $sparkIndex = 0
        foreach ($sparkle in $meta.PetSparkles) {
            $sparkWave = (1 + [Math]::Sin($meta.PetPhase + ($sparkIndex * 1.7))) / 2
            $sparkle.Opacity = if ($meta.PetHovered) { 0.34 + ($sparkWave * 0.58) } else { 0.08 + ($sparkWave * 0.16) }
            $sparkIndex++
        }
    }
}

function New-ModularWidgetWindow {
    param([string]$Name, $Card, $Definition)

    $parent = $Card.Parent
    if ($parent -is [Windows.Controls.Panel]) { [void]$parent.Children.Remove($Card) }
    [Windows.Controls.Grid]::SetRow($Card, 0)
    [Windows.Controls.Grid]::SetColumn($Card, 0)
    $Card.Margin = [Windows.Thickness]::new(0)
    $Card.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
    $Card.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
    $Card.Cursor = [Windows.Input.Cursors]::SizeAll
    if ($null -ne $Card.Effect) {
        $Card.Effect = $Card.Effect.Clone()
    }

    $theme = Get-WidgetTheme -Name $Name
    $accent = $theme.Accent
    $accentBrush = ConvertTo-Brush -Color $accent
    $secondaryBrush = ConvertTo-Brush -Color $theme.Secondary
    $edgeBrush = New-WidgetThemeEdgeBrush -Theme $theme
    $isPhoto = ($Name -eq "PhotoCard")
    $isLock = ($Name -eq "LockCard")
    $isMedia = ($Name -eq "MediaCard")

    $Card.Background = New-WidgetThemeSurfaceBrush -Theme $theme
    $Card.BorderBrush = $edgeBrush
    $Card.BorderThickness = [Windows.Thickness]::new(1.4)
    $Card.CornerRadius = [Windows.CornerRadius]::new(20)
    $cardShadow = [Windows.Media.Effects.DropShadowEffect]::new()
    $cardShadow.Color = [Windows.Media.ColorConverter]::ConvertFromString($accent)
    $cardShadow.BlurRadius = if ($isPhoto) { 18 } else { 26 }
    $cardShadow.ShadowDepth = 3
    $cardShadow.Direction = 270
    $cardShadow.Opacity = if ($isPhoto) { 0.48 } else { 0.58 }
    $Card.Effect = $cardShadow

    $container = [Windows.Controls.Grid]::new()
    $container.Margin = [Windows.Thickness]::new(10)
    $container.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    $containerScale = [Windows.Media.ScaleTransform]::new(1, 1)
    $container.RenderTransform = $containerScale

    $outerGlow = [Windows.Controls.Border]::new()
    $outerGlow.CornerRadius = [Windows.CornerRadius]::new(20)
    $outerGlow.BorderThickness = [Windows.Thickness]::new(1.2)
    $outerGlow.BorderBrush = $edgeBrush
    $outerGlow.Background = [Windows.Media.Brushes]::Transparent
    $outerGlow.Opacity = if ($isPhoto) { 0.24 } else { 0.52 }
    $outerGlow.IsHitTestVisible = $false
    $glowEffect = [Windows.Media.Effects.DropShadowEffect]::new()
    $glowEffect.Color = [Windows.Media.ColorConverter]::ConvertFromString($accent)
    $glowEffect.BlurRadius = if ($isPhoto) { 14 } else { 24 }
    $glowEffect.ShadowDepth = 0
    $glowEffect.Opacity = 0.56
    $outerGlow.Effect = $glowEffect
    [void]$container.Children.Add($outerGlow)

    $cardScale = [Windows.Media.ScaleTransform]::new(1, 1)
    $cardTranslate = [Windows.Media.TranslateTransform]::new(0, 0)
    $cardTransform = [Windows.Media.TransformGroup]::new()
    [void]$cardTransform.Children.Add($cardScale)
    [void]$cardTransform.Children.Add($cardTranslate)
    $Card.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    $Card.RenderTransform = $cardTransform
    [void]$container.Children.Add($Card)

    $innerRim = [Windows.Controls.Border]::new()
    $innerRim.Margin = [Windows.Thickness]::new(3)
    $innerRim.CornerRadius = [Windows.CornerRadius]::new(17)
    $innerRim.BorderThickness = [Windows.Thickness]::new(0.7)
    $innerRim.BorderBrush = $edgeBrush
    $innerRim.Background = [Windows.Media.Brushes]::Transparent
    $innerRim.Opacity = 0.42
    $innerRim.IsHitTestVisible = $false
    [void]$container.Children.Add($innerRim)

    $sheen = [Windows.Controls.Border]::new()
    $sheen.Height = 1.5
    $sheen.Margin = [Windows.Thickness]::new(18, 5, 18, 0)
    $sheen.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
    $sheen.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $sheen.CornerRadius = [Windows.CornerRadius]::new(1)
    $sheen.Background = $accentBrush
    $sheen.Opacity = if ($isPhoto) { 0.18 } else { 0.48 }
    $sheen.IsHitTestVisible = $false
    $sheenEffect = [Windows.Media.Effects.BlurEffect]::new()
    $sheenEffect.Radius = 3
    $sheen.Effect = $sheenEffect
    [void]$container.Children.Add($sheen)

    $topOrnament = [Windows.Controls.TextBlock]::new()
    $topOrnament.Text = $theme.Ornament
    $topOrnament.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Symbol")
    $topOrnament.FontSize = 9
    $topOrnament.Foreground = $secondaryBrush
    $topOrnament.HorizontalAlignment = if ($isMedia) { [Windows.HorizontalAlignment]::Right } else { [Windows.HorizontalAlignment]::Left }
    $topOrnament.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $topOrnament.Margin = if ($isMedia) { [Windows.Thickness]::new(0, 7, 10, 0) } else { [Windows.Thickness]::new(10, 7, 0, 0) }
    $topOrnament.Opacity = if ($isMedia) { 0.28 } else { 0.7 }
    $topOrnament.IsHitTestVisible = $false
    $ornamentEffect = [Windows.Media.Effects.DropShadowEffect]::new()
    $ornamentEffect.Color = [Windows.Media.ColorConverter]::ConvertFromString($accent)
    $ornamentEffect.BlurRadius = 7
    $ornamentEffect.ShadowDepth = 0
    $ornamentEffect.Opacity = 0.8
    $topOrnament.Effect = $ornamentEffect
    [void]$container.Children.Add($topOrnament)

    $bottomOrnament = [Windows.Controls.TextBlock]::new()
    $bottomOrnament.Text = "✦"
    $bottomOrnament.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Symbol")
    $bottomOrnament.FontSize = 8
    $bottomOrnament.Foreground = $secondaryBrush
    $bottomOrnament.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    $bottomOrnament.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
    $bottomOrnament.Margin = [Windows.Thickness]::new(10, 0, 0, 9)
    $bottomOrnament.Opacity = if ($isMedia) { 0 } else { 0.42 }
    $bottomOrnament.IsHitTestVisible = $false
    [void]$container.Children.Add($bottomOrnament)

    $petBrush = if ([string]::IsNullOrWhiteSpace([string]$theme.PetSlug)) {
        $null
    } else {
        New-WidgetPetBrush -PetSlug $theme.PetSlug
    }
    $petVisual = $null
    $petAura = $null
    $petScale = $null
    $petRotate = $null
    $petTranslate = $null
    $petSparkles = [System.Collections.ArrayList]::new()

    if ($null -ne $petBrush) {
        $shortSide = [Math]::Min([double]$Definition.Width, [double]$Definition.Height)
        $petHeight = if ($isMedia) { [Math]::Min(48.0, [Math]::Max(38.0, ($shortSide * 0.34))) } elseif ($isLock) { 34.0 } else { [Math]::Max(34.0, [Math]::Min(62.0, ($shortSide * 0.30))) }
        $petWidth = $petHeight * ($script:petFrameWidth / $script:petFrameHeight)
        $petBottom = if ($isMedia) { 6.0 } elseif ($isPhoto) { 44.0 } else { 6.0 }

        $petAura = [Windows.Shapes.Ellipse]::new()
        $petAura.Width = $petHeight * 0.92
        $petAura.Height = $petHeight * 0.62
        $petAura.Fill = $accentBrush
        $petAura.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
        $petAura.VerticalAlignment = if ($isLock) { [Windows.VerticalAlignment]::Top } else { [Windows.VerticalAlignment]::Bottom }
        $petAura.Margin = if ($isLock) { [Windows.Thickness]::new(0, 17, 5, 0) } else { [Windows.Thickness]::new(0, 0, 5, ($petBottom + 1)) }
        $petAura.Opacity = 0.22
        $petAura.IsHitTestVisible = $false
        $petAuraEffect = [Windows.Media.Effects.BlurEffect]::new()
        $petAuraEffect.Radius = 12
        $petAura.Effect = $petAuraEffect
        [void]$container.Children.Add($petAura)

        $petVisual = [Windows.Shapes.Rectangle]::new()
        $petVisual.Width = $petWidth
        $petVisual.Height = $petHeight
        $petVisual.Fill = $petBrush
        $petVisual.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
        $petVisual.VerticalAlignment = if ($isLock) { [Windows.VerticalAlignment]::Top } else { [Windows.VerticalAlignment]::Bottom }
        $petVisual.Margin = if ($isLock) { [Windows.Thickness]::new(0, 14, 6, 0) } else { [Windows.Thickness]::new(0, 0, 6, $petBottom) }
        $petVisual.Opacity = 0.82
        $petVisual.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.84)
        $petVisual.IsHitTestVisible = $false

        $petScale = [Windows.Media.ScaleTransform]::new(1, 1)
        $petRotate = [Windows.Media.RotateTransform]::new(0)
        $petTranslate = [Windows.Media.TranslateTransform]::new(0, 0)
        $petTransform = [Windows.Media.TransformGroup]::new()
        [void]$petTransform.Children.Add($petScale)
        [void]$petTransform.Children.Add($petRotate)
        [void]$petTransform.Children.Add($petTranslate)
        $petVisual.RenderTransform = $petTransform
        [void]$container.Children.Add($petVisual)

        $sparkleOffsets = @(
            [pscustomobject]@{ Right = ($petWidth + 7); Bottom = ($petBottom + ($petHeight * 0.70)); Size = 8 },
            [pscustomobject]@{ Right = 4; Bottom = ($petBottom + ($petHeight * 0.84)); Size = 6 },
            [pscustomobject]@{ Right = ($petWidth + 1); Bottom = ($petBottom + ($petHeight * 0.22)); Size = 5 }
        )
        foreach ($offset in $sparkleOffsets) {
            $sparkle = [Windows.Controls.TextBlock]::new()
            $sparkle.Text = "✦"
            $sparkle.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Symbol")
            $sparkle.FontSize = [double]$offset.Size
            $sparkle.Foreground = $secondaryBrush
            $sparkle.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
            $sparkle.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
            $sparkle.Margin = [Windows.Thickness]::new(0, 0, [double]$offset.Right, [double]$offset.Bottom)
            $sparkle.Opacity = 0.16
            $sparkle.IsHitTestVisible = $false
            [void]$container.Children.Add($sparkle)
            [void]$petSparkles.Add($sparkle)
        }
    }

    $statusLight = [Windows.Shapes.Ellipse]::new()
    $statusLight.Width = 5
    $statusLight.Height = 5
    $statusLight.Fill = $accentBrush
    $statusLight.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
    $statusLight.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $statusLight.Margin = [Windows.Thickness]::new(0, 10, 12, 0)
    $statusLight.Opacity = 0.74
    $statusLight.IsHitTestVisible = $false
    if ($isPhoto -or $isMedia) { $statusLight.Visibility = [Windows.Visibility]::Collapsed }
    $statusEffect = [Windows.Media.Effects.DropShadowEffect]::new()
    $statusEffect.Color = [Windows.Media.ColorConverter]::ConvertFromString($accent)
    $statusEffect.BlurRadius = 9
    $statusEffect.ShadowDepth = 0
    $statusEffect.Opacity = 0.9
    $statusLight.Effect = $statusEffect
    [void]$container.Children.Add($statusLight)

    $widgetWindow = [Windows.Window]::new()
    $widgetWindow.Title = "桌面组件 - " + $Name
    $widgetWindow.Width = [double]$Definition.Width + 20
    $widgetWindow.Height = [double]$Definition.Height + 20
    $widgetWindow.WindowStyle = [Windows.WindowStyle]::None
    $widgetWindow.ResizeMode = [Windows.ResizeMode]::NoResize
    $widgetWindow.AllowsTransparency = $true
    $widgetWindow.Background = [Windows.Media.Brushes]::Transparent
    $widgetWindow.ShowInTaskbar = $false
    $widgetWindow.ShowActivated = $false
    $widgetWindow.Topmost = $false
    $widgetWindow.Content = $container

    $layoutSaveTimer = [Windows.Threading.DispatcherTimer]::new()
    $layoutSaveTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $layoutSaveTimer.Add_Tick({
        param($sender, $eventArgs)
        $sender.Stop()
        if ($script:widgetWindows.Count -eq $script:widgetDefinitions.Count) { Save-WidgetLayout }
    })
    $widgetWindow.Tag = [pscustomobject]@{
        Name = $Name
        LayoutSaveTimer = $layoutSaveTimer
        Card = $Card
        Theme = $theme
        Glow = $outerGlow
        InnerRim = $innerRim
        Sheen = $sheen
        StatusLight = $statusLight
        CardScale = $cardScale
        CardTranslate = $cardTranslate
        ContainerScale = $containerScale
        IsPhoto = $isPhoto
        PetVisual = $petVisual
        PetBrush = $petBrush
        PetScale = $petScale
        PetRotate = $petRotate
        PetTranslate = $petTranslate
        PetAura = $petAura
        PetSparkles = $petSparkles
        PetHovered = $false
        PetFrame = 0
        PetPhase = ([double]$script:petAnimations.Count * 0.83)
        PetActionName = "Idle"
        PetActionRow = 0
        PetActionFrameCount = 6
        PetActionTicks = 0
        PetActionDuration = 0
        PetNextActionTicks = (16 + ($script:petAnimations.Count * 3))
        PetActionCycle = $script:petAnimations.Count
        Handle = [IntPtr]::Zero
    }

    $position = Get-WidgetPosition -Name $Name -Width $widgetWindow.Width -Height $widgetWindow.Height -Column ([int]$Definition.Column) -Row ([int]$Definition.Row)
    $widgetWindow.Left = $position.Left
    $widgetWindow.Top = $position.Top
    $widgetWindow.Add_MouseLeftButtonDown({
        param($sender, $eventArgs)
        if ($eventArgs.ChangedButton -ne [Windows.Input.MouseButton]::Left) { return }
        if (Test-InteractiveWidgetSource -Source $eventArgs.OriginalSource) { return }
        try {
            [void]$sender.Activate()
            $sender.DragMove()
            $sender.Tag.LayoutSaveTimer.Stop()
            Save-WidgetLayout
        } catch {}
    })
    $widgetWindow.Add_LocationChanged({
        param($sender, $eventArgs)
        if ($sender.Tag.Name -eq "MediaCard" -or $sender.Tag.Name -eq "PhotoCard") {
            Restore-FixedWidgetAnchor -Name $sender.Tag.Name
        }
        $sender.Tag.LayoutSaveTimer.Stop()
        $sender.Tag.LayoutSaveTimer.Start()
    })
    $widgetWindow.Add_MouseEnter({
        param($sender, $eventArgs)
        Set-WidgetVisualState -WidgetWindow $sender -Hovered $true
    })
    $widgetWindow.Add_MouseLeave({
        param($sender, $eventArgs)
        Set-WidgetVisualState -WidgetWindow $sender -Hovered $false
    })
    $widgetWindow.Add_SourceInitialized({
        param($sender, $eventArgs)
        $helper = [Windows.Interop.WindowInteropHelper]::new($sender)
        $sender.Tag.Handle = $helper.Handle
        [void](Register-DesktopWidgetHandle -Handle $helper.Handle -Name $sender.Tag.Name)
    })
    $widgetWindow.Add_Loaded({
        param($sender, $eventArgs)
        $sender.Opacity = 0
        $sender.Tag.ContainerScale.ScaleX = 0.965
        $sender.Tag.ContainerScale.ScaleY = 0.965
        $sender.BeginAnimation([Windows.Window]::OpacityProperty, (New-WidgetDoubleAnimation -To 1 -Milliseconds 360))
        $sender.Tag.ContainerScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (New-WidgetDoubleAnimation -To 1 -Milliseconds 360))
        $sender.Tag.ContainerScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (New-WidgetDoubleAnimation -To 1 -Milliseconds 360))

        if (!$script:statusLights.Contains($sender.Tag.StatusLight)) {
            $script:statusLights.Add($sender.Tag.StatusLight)
        }
    })

    $script:widgetWindows[$Name] = $widgetWindow
    $script:petAnimations[$Name] = $widgetWindow
}

function Initialize-ModularWidgetWindows {
    foreach ($name in $script:widgetDefinitions.Keys) {
        $card = $script:window.FindName($name)
        if ($null -eq $card) { throw "Widget card not found: $name" }
        New-ModularWidgetWindow -Name $name -Card $card -Definition $script:widgetDefinitions[$name]
    }

    $script:window.Left = -10000
    $script:window.Top = -10000
    $script:window.Width = 1
    $script:window.Height = 1
    $script:window.Opacity = 0
    $script:window.IsHitTestVisible = $false
    $layout = Read-Utf8Json -Path $script:layoutPath
    foreach ($name in $script:widgetDefinitions.Keys) {
        $widgetWindow = $script:widgetWindows[$name]
        $shouldShow = $true
        if ($null -ne $layout -and $null -ne $layout.widgets) {
            $layoutProperty = $layout.widgets.PSObject.Properties[$name]
            if ($null -ne $layoutProperty -and $null -ne $layoutProperty.Value.visible) {
                $shouldShow = [bool]$layoutProperty.Value.visible
            }
        }
        if ($shouldShow) { $widgetWindow.Show() } else { $widgetWindow.Hide() }
    }
    if ($script:lockWidgetAutoHidden) {
        $lockWidgetWindow = $script:widgetWindows['LockCard']
        if ($null -ne $lockWidgetWindow -and $lockWidgetWindow.IsVisible) {
            $lockWidgetWindow.Hide()
            Write-WidgetLog 'Lock duration widget is recording in the background and was auto-hidden.'
        }
    }
    Save-WidgetLayout
}

function Get-InitialTodoItems {
    $items = New-Object System.Collections.Generic.List[object]
    $legacy = Read-Utf8Json -Path $script:legacyTodoPath
    if ($null -ne $legacy -and $null -ne $legacy.plans) {
        foreach ($plan in @($legacy.plans)) {
            foreach ($task in @($plan.tasks)) {
                if ($items.Count -ge 4) { break }
                $title = [string]$task.title
                if (![string]::IsNullOrWhiteSpace($title)) {
                    $items.Add([pscustomobject]@{
                        text = $title
                        completed = [bool]$task.done
                    })
                }
            }
            if ($items.Count -ge 4) { break }
        }
    }

    while ($items.Count -lt 4) {
        $items.Add([pscustomobject]@{ text = ""; completed = $false })
    }
    return @($items.ToArray())
}

function Save-TodoState {
    if (!$script:todoLoaded -or $null -eq $script:window) { return }

    try {
        $items = @()
        for ($index = 1; $index -le 4; $index++) {
            $textBox = $script:window.FindName("TodoText" + $index)
            $checkBox = $script:window.FindName("TodoCheck" + $index)
            $items += [ordered]@{
                slot = $index
                text = [string]$textBox.Text
                completed = [bool]($checkBox.IsChecked -eq $true)
            }
        }

        $state = [ordered]@{
            version = 2
            savedAt = (Get-Date).ToString("o")
            items = $items
        }
        $json = $state | ConvertTo-Json -Depth 6
        $temporaryPath = $script:todoPath + ".tmp"
        [IO.File]::WriteAllText($temporaryPath, $json, $script:utf8)

        if (Test-Path -LiteralPath $script:todoPath) {
            $existing = Read-Utf8Json -Path $script:todoPath
            if ($null -ne $existing) {
                Copy-Item -LiteralPath $script:todoPath -Destination $script:todoBackupPath -Force
            }
        }
        Copy-Item -LiteralPath $temporaryPath -Destination $script:todoPath -Force
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-WidgetLog ("Todo save failed: " + $_.Exception.Message)
    }
}

function Update-TodoAppearance {
    $completedCount = 0
    for ($index = 1; $index -le 4; $index++) {
        $textBox = $script:window.FindName("TodoText" + $index)
        $checkBox = $script:window.FindName("TodoCheck" + $index)
        $completed = [bool]($checkBox.IsChecked -eq $true)
        if ($completed) {
            $completedCount++
            $textBox.TextDecorations = [Windows.TextDecorations]::Strikethrough
            $textBox.Foreground = ConvertTo-Brush -Color "#9FFFFFFF"
        } else {
            $textBox.TextDecorations = $null
            $textBox.Foreground = ConvertTo-Brush -Color "#F2FFFFFF"
        }
    }
    $script:window.FindName("TodoSummaryText").Text = $completedCount.ToString() + " / 4 已完成"
}

function Add-SpeechResultToTodo {
    $resultText = $script:window.FindName("SpeechResultText")
    $placeholder = Get-WidgetText -Name "speechPlaceholder" -Fallback "识别结果会显示在这里"
    $text = [string]$resultText.Text
    if ([string]::IsNullOrWhiteSpace($text) -or $text -eq $placeholder) {
        Set-SpeechState -Text "请先听写或输入内容"
        return
    }

    $segments = New-Object Collections.Generic.List[string]
    foreach ($part in ($text -split '(?:\r?\n)+|(?<=[。！？!?；;])\s*')) {
        $clean = ([string]$part).Trim()
        if (![string]::IsNullOrWhiteSpace($clean)) { $segments.Add($clean) }
    }
    if ($segments.Count -eq 0) { $segments.Add($text.Trim()) }

    $added = 0
    foreach ($segment in $segments) {
        $target = $null
        for ($index = 1; $index -le 4; $index++) {
            $candidate = $script:window.FindName("TodoText" + $index)
            if ([string]::IsNullOrWhiteSpace([string]$candidate.Text)) {
                $target = $candidate
                $script:window.FindName("TodoCheck" + $index).IsChecked = $false
                break
            }
        }
        if ($null -eq $target) { $target = $script:window.FindName("TodoText4") }

        $next = if ([string]::IsNullOrWhiteSpace([string]$target.Text)) {
            $segment
        } else {
            ([string]$target.Text).TrimEnd() + [Environment]::NewLine + $segment
        }
        if ($next.Length -gt 500) { $next = $next.Substring(0, 500) }
        $target.Text = $next
        $added++
    }

    Update-TodoAppearance
    Save-TodoState
    $script:window.FindName("SpeechHintText").Text = "已整理为 " + $added + " 条纵向任务"
    Set-SpeechState -Text ("已生成 " + $added + " 条待办")
    Write-WidgetLog ("Speech result converted to todo items: " + $added)
}

function Get-WeChatPhotoInitialDirectory {
    $candidates = @(
        ($env:USERPROFILE + "\Documents\WeChat Files"),
        ($env:USERPROFILE + "\Documents\Weixin Files"),
        $script:photoDropRoot,
        ($env:USERPROFILE + "\Pictures"),
        ($env:USERPROFILE + "\Downloads")
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $env:USERPROFILE
}

function Test-SupportedPhotoFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try {
        return $script:supportedPhotoExtensions -contains [IO.Path]::GetExtension($Path).ToLowerInvariant()
    } catch {
        return $false
    }
}

function Get-NormalizedPhotoPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    try { return [IO.Path]::GetFullPath($Path).TrimEnd("\").ToLowerInvariant() }
    catch { return $Path.Trim().ToLowerInvariant() }
}

function New-PhotoCachePath {
    param([string]$Extension, [string]$Prefix = "wechat")

    $safeExtension = $Extension.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($safeExtension)) { $safeExtension = ".png" }
    $name = $Prefix + "-" + (Get-Date -Format "yyyyMMdd-HHmmssfff") + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8) + $safeExtension
    return $script:photoRoot + "\" + $name
}

function Save-PhotoLibrary {
    if ($null -ne $script:photoLibrary) {
        Write-Utf8Json -Path $script:photoLibraryPath -Value $script:photoLibrary
    }
}

function Get-PhotoMediaKind {
    param([string]$Path)

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -in @(".mov", ".mp4", ".m4v", ".webm")) { return "video" }
    return "image"
}

function Add-WeChatPhotoFiles {
    param(
        [string[]]$Paths,
        [string]$Origin = "direct-import",
        [bool]$SelectNewest = $true,
        [bool]$Refresh = $true
    )

    if ($null -eq $script:photoLibrary -or $null -eq $Paths) { return 0 }

    $items = @($script:photoLibrary.items | Where-Object { Test-Path -LiteralPath ([string]$_.path) })
    $knownSources = @{}
    $knownCachePaths = @{}
    for ($index = 0; $index -lt $items.Count; $index++) {
        $sourceKey = Get-NormalizedPhotoPath -Path ([string]$items[$index].source)
        $cacheKey = Get-NormalizedPhotoPath -Path ([string]$items[$index].path)
        if (![string]::IsNullOrWhiteSpace($sourceKey)) { $knownSources[$sourceKey] = $index }
        if (![string]::IsNullOrWhiteSpace($cacheKey)) { $knownCachePaths[$cacheKey] = $index }
    }

    $added = 0
    $existingIndex = -1
    foreach ($source in @($Paths)) {
        if (!(Test-Path -LiteralPath $source -PathType Leaf) -or !(Test-SupportedPhotoFile -Path $source)) { continue }

        $sourceKey = Get-NormalizedPhotoPath -Path $source
        if ($knownSources.ContainsKey($sourceKey)) {
            $existingIndex = [int]$knownSources[$sourceKey]
            continue
        }
        if ($knownCachePaths.ContainsKey($sourceKey)) {
            $existingIndex = [int]$knownCachePaths[$sourceKey]
            continue
        }

        try {
            $extension = [IO.Path]::GetExtension($source).ToLowerInvariant()
            $destination = New-PhotoCachePath -Extension $extension -Prefix "wechat"
            Copy-Item -LiteralPath $source -Destination $destination -Force
            $items += [pscustomobject]@{
                path = $destination
                source = $source
                kind = Get-PhotoMediaKind -Path $destination
                origin = $Origin
                addedAt = (Get-Date).ToString("o")
            }
            $newIndex = $items.Count - 1
            $knownSources[$sourceKey] = $newIndex
            $knownCachePaths[(Get-NormalizedPhotoPath -Path $destination)] = $newIndex
            $added++
        } catch {
            Write-WidgetLog ("Photo import failed: " + $source + " | " + $_.Exception.Message)
        }
    }

    $script:photoLibrary.items = $items
    $selectExisting = $SelectNewest -and $existingIndex -ge 0 -and $Origin -ne "photo-folder"
    if ($SelectNewest) {
        if ($added -gt 0) { $script:photoLibrary.activeIndex = $items.Count - 1 }
        elseif ($selectExisting) { $script:photoLibrary.activeIndex = $existingIndex }
    }
    if ($added -gt 0 -or $selectExisting) {
        Save-PhotoLibrary
        if ($Refresh) { Update-PhotoWidget }
    }
    if ($added -gt 0) { Write-WidgetLog ("WeChat media added from " + $Origin + ": " + $added) }
    return $added
}

function Add-DroppedPhotoBitmap {
    param($Bitmap, [bool]$Refresh = $true)

    if ($null -eq $Bitmap -or $null -eq $script:photoLibrary) { return 0 }
    $destination = New-PhotoCachePath -Extension ".png" -Prefix "wechat-drag"
    try {
        if ($Bitmap -is [Windows.Media.Imaging.BitmapSource]) {
            $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($Bitmap))
            $stream = [IO.File]::Open($destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $encoder.Save($stream) } finally { $stream.Dispose() }
        } elseif ($Bitmap -is [Drawing.Image]) {
            $Bitmap.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
        } else {
            return 0
        }

        $items = @($script:photoLibrary.items | Where-Object { Test-Path -LiteralPath ([string]$_.path) })
        $items += [pscustomobject]@{
            path = $destination
            source = "wechat-drag://" + [Guid]::NewGuid().ToString("N")
            kind = "image"
            origin = "direct-drag"
            addedAt = (Get-Date).ToString("o")
        }
        $script:photoLibrary.items = $items
        $script:photoLibrary.activeIndex = $items.Count - 1
        Save-PhotoLibrary
        if ($Refresh) { Update-PhotoWidget }
        Write-WidgetLog "WeChat bitmap added by direct drag."
        return 1
    } catch {
        if (Test-Path -LiteralPath $destination) { [IO.File]::Delete($destination) }
        Write-WidgetLog ("Dropped WeChat bitmap failed: " + $_.Exception.Message)
        return 0
    }
}

function Test-WeChatPhotoDropData {
    param($Data)

    if ($null -eq $Data) { return $false }
    if ($Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return $true }
    if ($Data.GetDataPresent([Windows.DataFormats]::Bitmap)) { return $true }
    return $false
}

function Import-WeChatPhotoDropData {
    param($Data)

    if (!(Test-WeChatPhotoDropData -Data $Data)) { return 0 }
    $paths = New-Object Collections.Generic.List[string]
    $seen = @{}
    if ($Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        foreach ($entry in @($Data.GetData([Windows.DataFormats]::FileDrop))) {
            if (Test-Path -LiteralPath $entry -PathType Container) {
                foreach ($file in @(Get-ChildItem -LiteralPath $entry -File -Recurse -ErrorAction SilentlyContinue)) {
                    if (!(Test-SupportedPhotoFile -Path $file.FullName)) { continue }
                    $key = Get-NormalizedPhotoPath -Path $file.FullName
                    if (!$seen.ContainsKey($key)) { $seen[$key] = $true; $paths.Add($file.FullName) }
                }
            } elseif (Test-SupportedPhotoFile -Path $entry) {
                $key = Get-NormalizedPhotoPath -Path $entry
                if (!$seen.ContainsKey($key)) { $seen[$key] = $true; $paths.Add([string]$entry) }
            }
        }
    }

    $added = 0
    if ($paths.Count -gt 0) {
        $added = [int](Add-WeChatPhotoFiles -Paths $paths.ToArray() -Origin "direct-drag" -SelectNewest $true -Refresh $false)
    }
    if ($added -eq 0 -and $Data.GetDataPresent([Windows.DataFormats]::Bitmap)) {
        $added = [int](Add-DroppedPhotoBitmap -Bitmap ($Data.GetData([Windows.DataFormats]::Bitmap)) -Refresh $false)
    }
    if ($added -gt 0) {
        Update-PhotoWidget
        $script:window.FindName("PhotoCaptionText").Text = "已直接加入 " + $added + " 项 · 左右滑动查看"
    } else {
        $script:window.FindName("PhotoCaptionText").Text = "未发现支持的图片或动态照片"
    }
    return $added
}

function Sync-PhotoDropFolder {
    param(
        [bool]$SelectNewest = $true,
        [bool]$Refresh = $true
    )

    if ($script:photoFolderSyncBusy -or $null -eq $script:photoLibrary) { return 0 }
    $script:photoFolderSyncBusy = $true
    try {
        if (!(Test-Path -LiteralPath $script:photoDropRoot)) {
            [void](New-Item -ItemType Directory -Path $script:photoDropRoot -Force)
        }
        $files = @(Get-ChildItem -LiteralPath $script:photoDropRoot -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { Test-SupportedPhotoFile -Path $_.FullName } |
            Sort-Object LastWriteTime, FullName)
        if ($files.Count -eq 0) { return 0 }
        $paths = @($files | ForEach-Object { $_.FullName })
        return [int](Add-WeChatPhotoFiles -Paths $paths -Origin "photo-folder" -SelectNewest $SelectNewest -Refresh $Refresh)
    } finally {
        $script:photoFolderSyncBusy = $false
    }
}

function Stop-PhotoVideo {
    if ($null -ne $script:photoPreviewPauseTimer) { $script:photoPreviewPauseTimer.Stop() }
    $video = $script:window.FindName("PhotoVideo")
    if ($null -eq $video) { return }
    try { $video.Stop() } catch {}
    $video.Source = $null
    $video.Visibility = [Windows.Visibility]::Collapsed
}

function Invoke-PhotoSlideAnimation {
    param([int]$Delta)

    $translate = $script:window.FindName("PhotoSwipeTranslate")
    if ($null -eq $translate) { return }
    $animation = [Windows.Media.Animation.DoubleAnimation]::new()
    $animation.From = if ($Delta -gt 0) { 24.0 } else { -24.0 }
    $animation.To = 0.0
    $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
    $animation.EasingFunction = [Windows.Media.Animation.CubicEase]::new()
    $animation.EasingFunction.EasingMode = [Windows.Media.Animation.EasingMode]::EaseOut
    [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
    $translate.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $animation)
}

function New-PhotoBitmap {
    param([string]$Path)

    $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
    $bitmap.BeginInit()
    $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.CreateOptions = [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
    $bitmap.DecodePixelWidth = 720
    $bitmap.UriSource = [Uri]::new($Path)
    $bitmap.EndInit()
    $bitmap.Freeze()
    return $bitmap
}

function Update-PhotoWidget {
    $items = @($script:photoLibrary.items | Where-Object { Test-Path -LiteralPath ([string]$_.path) })
    $script:photoLibrary.items = $items
    $image = $script:window.FindName("PhotoImage")
    $video = $script:window.FindName("PhotoVideo")
    $empty = $script:window.FindName("PhotoEmptyOverlay")
    $emptyText = $script:window.FindName("PhotoEmptyText")
    $caption = $script:window.FindName("PhotoCaptionText")
    $previous = $script:window.FindName("PhotoPreviousButton")
    $next = $script:window.FindName("PhotoNextButton")
    $lockScreen = $script:window.FindName("PhotoLockScreenButton")
    $open = $script:window.FindName("PhotoOpenButton")

    Stop-PhotoVideo
    $image.Source = $null
    $image.Visibility = [Windows.Visibility]::Visible

    if ($items.Count -eq 0) {
        $empty.Visibility = [Windows.Visibility]::Visible
        $emptyText.Text = "拖入或点击导入微信照片"
        $caption.Text = "微信生活"
        $previous.IsEnabled = $false
        $next.IsEnabled = $false
        $lockScreen.IsEnabled = $false
        $open.IsEnabled = $true
        return
    }

    $index = [Math]::Max(0, [Math]::Min($items.Count - 1, [int]$script:photoLibrary.activeIndex))
    $script:photoLibrary.activeIndex = $index
    $path = [string]$items[$index].path
    $kind = Get-PhotoMediaKind -Path $path
    try {
        if ($kind -eq "video") {
            $image.Visibility = [Windows.Visibility]::Collapsed
            $video.Source = [Uri]::new($path)
            $video.Visibility = [Windows.Visibility]::Visible
            $video.Play()
            $caption.Text = "微信生活  " + ($index + 1) + " / " + $items.Count + "  · 动态"
            $lockScreen.IsEnabled = $false
        } else {
            $image.Source = New-PhotoBitmap -Path $path
            $caption.Text = "微信生活  " + ($index + 1) + " / " + $items.Count
            $lockScreen.IsEnabled = $true
        }
        $empty.Visibility = [Windows.Visibility]::Collapsed
        $previous.IsEnabled = ($items.Count -gt 1)
        $next.IsEnabled = ($items.Count -gt 1)
        $open.IsEnabled = $true
    } catch {
        Write-WidgetLog ("Photo load failed: " + $_.Exception.Message)
        $emptyText.Text = "此媒体需要 Windows 解码器"
        $empty.Visibility = [Windows.Visibility]::Visible
        $lockScreen.IsEnabled = $false
        $open.IsEnabled = $true
    }
}

function Initialize-PhotoLibrary {
    if (!(Test-Path -LiteralPath $script:photoRoot)) {
        [void](New-Item -ItemType Directory -Path $script:photoRoot -Force)
    }
    if (!(Test-Path -LiteralPath $script:photoLockScreenRoot)) {
        [void](New-Item -ItemType Directory -Path $script:photoLockScreenRoot -Force)
    }
    if (!(Test-Path -LiteralPath $script:photoDropRoot)) {
        [void](New-Item -ItemType Directory -Path $script:photoDropRoot -Force)
    }
    $script:photoLibrary = Read-Utf8Json -Path $script:photoLibraryPath
    if ($null -eq $script:photoLibrary) {
        $script:photoLibrary = [pscustomobject]@{ version = 1; activeIndex = 0; items = @() }
    }
    if ($null -eq $script:photoLibrary.items) {
        $script:photoLibrary | Add-Member -NotePropertyName items -NotePropertyValue @() -Force
    }
    if ($null -eq $script:photoLibrary.PSObject.Properties["activeIndex"]) {
        $script:photoLibrary | Add-Member -NotePropertyName activeIndex -NotePropertyValue 0 -Force
    }
    [void](Sync-PhotoDropFolder -SelectNewest $false -Refresh $false)
    Update-PhotoWidget
    Save-PhotoLibrary
}

function Import-WeChatPhotos {
    $dialog = [Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Title = "导入微信生活、Live Photo 或壁纸"
    $dialog.InitialDirectory = Get-WeChatPhotoInitialDirectory
    $dialog.Filter = "图片和动态内容|*.jpg;*.jpeg;*.png;*.webp;*.bmp;*.gif;*.heic;*.heif;*.mov;*.mp4;*.m4v;*.webm|图片文件|*.jpg;*.jpeg;*.png;*.webp;*.bmp;*.gif;*.heic;*.heif|动态照片和视频|*.mov;*.mp4;*.m4v;*.webm|所有文件|*.*"
    $dialog.Multiselect = $true
    $dialog.CheckFileExists = $true
    if ($dialog.ShowDialog() -ne $true) { return }

    $added = [int](Add-WeChatPhotoFiles -Paths @($dialog.FileNames) -Origin "direct-import" -SelectNewest $true -Refresh $true)
    if ($added -gt 0) {
        $script:window.FindName("PhotoCaptionText").Text = "已直接导入 " + $added + " 项 · 左右滑动查看"
    }
}

function Move-PhotoSelection {
    param([int]$Delta)
    $items = @($script:photoLibrary.items)
    if ($items.Count -lt 2) { return }
    $index = ([int]$script:photoLibrary.activeIndex + $Delta) % $items.Count
    if ($index -lt 0) { $index += $items.Count }
    $script:photoLibrary.activeIndex = $index
    Save-PhotoLibrary
    Update-PhotoWidget
    Invoke-PhotoSlideAnimation -Delta $Delta
}

function Initialize-LockScreenRuntime {
    if ($null -ne $script:lockScreenStorageType) { return }

    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $script:lockScreenStorageType = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
    $script:lockScreenType = [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]
    $script:winRtOperationAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and
            $_.IsGenericMethod -and
            $_.GetGenericArguments().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1"
        } |
        Select-Object -First 1
    $script:winRtActionAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and
            !$_.IsGenericMethod -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq "IAsyncAction"
        } |
        Select-Object -First 1
    if ($null -eq $script:winRtOperationAsTask -or $null -eq $script:winRtActionAsTask) {
        throw "Windows Runtime task bridge is unavailable."
    }
}

function Wait-WinRtOperation {
    param($Operation, [Type]$ResultType)

    Initialize-LockScreenRuntime
    $method = $script:winRtOperationAsTask.MakeGenericMethod($ResultType)
    $task = $method.Invoke($null, @($Operation))
    return $task.GetAwaiter().GetResult()
}

function Wait-WinRtAction {
    param($Operation)

    Initialize-LockScreenRuntime
    $task = $script:winRtActionAsTask.Invoke($null, @($Operation))
    [void]$task.GetAwaiter().GetResult()
}

function Save-CurrentLockScreenState {
    if (Test-Path -LiteralPath $script:photoLockScreenStatePath) { return }

    Initialize-LockScreenRuntime
    $originalUri = $script:lockScreenType::OriginalImageFile
    $previousUri = if ($null -ne $originalUri) { [string]$originalUri.AbsoluteUri } else { "" }
    $previousPath = if ($null -ne $originalUri -and $originalUri.IsFile) { [string]$originalUri.LocalPath } else { "" }
    $backupPath = ""

    if (![string]::IsNullOrWhiteSpace($previousPath) -and (Test-Path -LiteralPath $previousPath)) {
        $extension = [IO.Path]::GetExtension($previousPath)
        if ([string]::IsNullOrWhiteSpace($extension)) { $extension = ".jpg" }
        $backupPath = $script:photoLockScreenRoot + "\lockscreen-before-wechat-life" + $extension
        Copy-Item -LiteralPath $previousPath -Destination $backupPath -Force
    }

    Write-Utf8Json -Path $script:photoLockScreenStatePath -Value ([ordered]@{
        version = 1
        previousUri = $previousUri
        previousPath = $previousPath
        backupPath = $backupPath
        savedAt = (Get-Date).ToString("o")
    })
}

function Convert-PhotoToLockScreenJpeg {
    param([string]$Path)

    $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
    $bitmap.BeginInit()
    $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.CreateOptions = [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
    $bitmap.UriSource = [Uri]::new($Path)
    $bitmap.EndInit()
    $bitmap.Freeze()

    $destination = $script:photoLockScreenRoot + "\lockscreen-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".jpg"
    $encoder = [Windows.Media.Imaging.JpegBitmapEncoder]::new()
    $encoder.QualityLevel = 92
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Open($destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    return $destination
}

function Set-CurrentPhotoAsLockScreen {
    $items = @($script:photoLibrary.items)
    if ($items.Count -eq 0) { return }
    $index = [Math]::Max(0, [Math]::Min($items.Count - 1, [int]$script:photoLibrary.activeIndex))
    $path = [string]$items[$index].path
    if (!(Test-Path -LiteralPath $path)) { return }
    if ((Get-PhotoMediaKind -Path $path) -eq "video") {
        $script:window.FindName("PhotoCaptionText").Text = "动态内容可播放 · 锁屏请选择配对照片"
        return
    }

    try {
        Initialize-LockScreenRuntime
        Save-CurrentLockScreenState

        $extension = [IO.Path]::GetExtension($path).ToLowerInvariant()
        $lockScreenPath = if ($extension -in @(".jpg", ".jpeg", ".png", ".bmp")) {
            $path
        } else {
            Convert-PhotoToLockScreenJpeg -Path $path
        }

        $operation = $script:lockScreenStorageType::GetFileFromPathAsync($lockScreenPath)
        $storageFile = Wait-WinRtOperation -Operation $operation -ResultType $script:lockScreenStorageType
        Wait-WinRtAction -Operation ($script:lockScreenType::SetImageFileAsync($storageFile))
        $script:window.FindName("PhotoCaptionText").Text = "已设为锁屏壁纸  ·  " + ($index + 1) + " / " + $items.Count
        Write-WidgetLog ("Lock screen set from WeChat Life: " + $lockScreenPath)
    } catch {
        $script:window.FindName("PhotoCaptionText").Text = "锁屏壁纸设置失败"
        Write-WidgetLog ("Lock screen update failed: " + $_.Exception.Message)
    }
}

function Open-CurrentPhotoLocation {
    $items = @($script:photoLibrary.items)
    if ($items.Count -eq 0) { return }
    $index = [Math]::Max(0, [Math]::Min($items.Count - 1, [int]$script:photoLibrary.activeIndex))
    $path = [string]$items[$index].path
    if (Test-Path -LiteralPath $path) {
        Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $path + '"')
    }
}

function Open-PhotoDropFolder {
    if (!(Test-Path -LiteralPath $script:photoDropRoot)) {
        [void](New-Item -ItemType Directory -Path $script:photoDropRoot -Force)
    }
    Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $script:photoDropRoot + '"')
}

function Initialize-TodoComponent {
    $script:todoLoaded = $false
    $state = Read-Utf8Json -Path $script:todoPath
    if ($null -eq $state) {
        $state = Read-Utf8Json -Path $script:todoBackupPath
    }

    $items = @()
    if ($null -ne $state -and $null -ne $state.items) {
        $items = @($state.items)
    } else {
        $items = @(Get-InitialTodoItems)
    }

    for ($index = 1; $index -le 4; $index++) {
        $item = if ($index -le $items.Count) { $items[$index - 1] } else { $null }
        $text = if ($null -ne $item) { [string]$item.text } else { "" }
        $completed = if ($null -ne $item) { [bool]$item.completed } else { $false }
        $script:window.FindName("TodoText" + $index).Text = $text
        $script:window.FindName("TodoCheck" + $index).IsChecked = $completed
    }

    $script:todoLoaded = $true
    Update-TodoAppearance
    Save-TodoState
    Write-WidgetLog "Todo component loaded with four persistent slots."
}

function Update-Clock {
    $now = Get-Date
    $hourAngle = (($now.Hour % 12) * 30.0) + ($now.Minute * 0.5)
    $minuteAngle = ($now.Minute * 6.0) + ($now.Second * 0.1)
    $secondAngle = $now.Second * 6.0
    $script:window.FindName("HourHandRotate").Angle = $hourAngle
    $script:window.FindName("MinuteHandRotate").Angle = $minuteAngle
    $script:window.FindName("SecondHandRotate").Angle = $secondAngle
}

function Update-Calendar {
    $now = Get-Date
    $culture = [Globalization.CultureInfo]::GetCultureInfo("zh-CN")
    $script:window.FindName("CalendarMonthText").Text = $now.ToString("MMMM", $culture)
    $script:window.FindName("CalendarYearText").Text = $now.ToString("yyyy")
    $panel = $script:window.FindName("CalendarDaysPanel")
    $panel.Children.Clear()
    $first = Get-Date -Year $now.Year -Month $now.Month -Day 1
    $offset = (([int]$first.DayOfWeek + 6) % 7)
    $days = [DateTime]::DaysInMonth($now.Year, $now.Month)
    for ($index = 0; $index -lt 42; $index++) {
        $day = $index - $offset + 1
        $surface = New-Object Windows.Controls.Border
        $surface.Width = 13
        $surface.Height = 13
        $surface.CornerRadius = [Windows.CornerRadius]::new(7)
        $surface.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
        $surface.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $text = New-Object Windows.Controls.TextBlock
        $text.FontSize = 6.5
        $text.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
        $text.VerticalAlignment = [Windows.VerticalAlignment]::Center
        if ($day -ge 1 -and $day -le $days) {
            $text.Text = $day.ToString()
            if ($day -eq $now.Day) {
                $surface.Background = (ConvertTo-Brush -Color "#EEFFFFFF")
                $text.Foreground = (ConvertTo-Brush -Color "#FF55555A")
                $text.FontWeight = [Windows.FontWeights]::SemiBold
            } else {
                $text.Foreground = (ConvertTo-Brush -Color "#E0FFFFFF")
            }
        }
        $surface.Child = $text
        [void]$panel.Children.Add($surface)
    }
}

function Update-Battery {
    try {
        $status = [Windows.Forms.SystemInformation]::PowerStatus
        $percent = if ($status.BatteryLifePercent -lt 0) { -1 } else { [int][Math]::Round($status.BatteryLifePercent * 100) }
        if ($percent -lt 0) {
            $script:window.FindName("BatteryPercentText").Text = "--%"
            $script:window.FindName("BatteryStateText").Text = Get-WidgetText -Name "batteryUnknown" -Fallback "Battery unavailable"
            return
        }
        $script:window.FindName("BatteryPercentText").Text = $percent.ToString() + "%"
        $state = switch ([string]$status.PowerLineStatus) {
            "Online" {
                if ($percent -lt 100) { Get-WidgetText -Name "batteryCharging" -Fallback "Charging" }
                else { Get-WidgetText -Name "batteryConnected" -Fallback "Connected" }
            }
            default { Get-WidgetText -Name "batteryUsing" -Fallback "On battery" }
        }
        $script:window.FindName("BatteryStateText").Text = $state
        $script:window.FindName("BatteryIconText").Text = if ($percent -ge 80) { [char]0xE83F } elseif ($percent -ge 40) { [char]0xE851 } else { [char]0xE850 }
    } catch {
        Write-WidgetLog ("Battery update failed: " + $_.Exception.Message)
    }
}

function Format-LockWidgetDuration {
    param([double]$Seconds)
    $span = [TimeSpan]::FromSeconds([Math]::Max(0, [Math]::Round($Seconds)))
    $hours = [Math]::Floor($span.TotalHours)
    return '{0:00}:{1:00}:{2:00}' -f $hours, $span.Minutes, $span.Seconds
}

function Add-LockSessionVisual {
    param(
        [Windows.Controls.Panel]$Panel,
        [string]$Title,
        [string]$Duration,
        [bool]$Active = $false
    )

    $surface = [Windows.Controls.Border]::new()
    $surface.CornerRadius = [Windows.CornerRadius]::new(5)
    $surface.Background = ConvertTo-Brush -Color $(if ($Active) { '#28FF7FAF' } else { '#18FFFFFF' })
    $surface.BorderBrush = ConvertTo-Brush -Color $(if ($Active) { '#66FF9BC1' } else { '#26FFD6E6' })
    $surface.BorderThickness = [Windows.Thickness]::new(0.6)
    $surface.Padding = [Windows.Thickness]::new(4, 2, 4, 2)
    $surface.Margin = [Windows.Thickness]::new(0, 0, 0, 3)

    $stack = [Windows.Controls.StackPanel]::new()
    $titleText = [Windows.Controls.TextBlock]::new()
    $titleText.Text = $Title
    $titleText.Foreground = ConvertTo-Brush -Color '#EFFFFFFF'
    $titleText.FontSize = 6.8
    $titleText.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    $durationText = [Windows.Controls.TextBlock]::new()
    $durationText.Text = $Duration
    $durationText.Foreground = ConvertTo-Brush -Color $(if ($Active) { '#FFFFB9D2' } else { '#B8FFD6E6' })
    $durationText.FontSize = 7
    $durationText.FontWeight = [Windows.FontWeights]::SemiBold
    $durationText.Margin = [Windows.Thickness]::new(0, 1, 0, 0)
    [void]$stack.Children.Add($titleText)
    [void]$stack.Children.Add($durationText)
    $surface.Child = $stack
    [void]$Panel.Children.Add($surface)
}

function Update-LockDurationWidget {
    try {
        $totalText = $script:window.FindName('LockTotalText')
        $countText = $script:window.FindName('LockSessionCountText')
        $panel = $script:window.FindName('LockSessionsPanel')
        if ($null -eq $totalText -or $null -eq $countText -or $null -eq $panel) { return }

        $state = Read-Utf8Json -Path $script:lockStatePath
        $today = (Get-Date).ToString('yyyy-MM-dd')
        if ($null -eq $state -or [string]$state.LocalDate -ne $today) {
            $totalText.Text = '00:00:00'
            $countText.Text = '0 次'
            if ($script:lastLockWidgetStamp -ne 'empty-' + $today) {
                $panel.Children.Clear()
                $empty = [Windows.Controls.TextBlock]::new()
                $empty.Text = '今天尚无活动记录'
                $empty.Foreground = ConvertTo-Brush -Color '#A8FFD8E8'
                $empty.FontSize = 7.5
                $empty.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
                [void]$panel.Children.Add($empty)
                $script:lastLockWidgetStamp = 'empty-' + $today
            }
            return
        }

        $sessions = @($state.Sessions)
        $activeSeconds = 0.0
        $activeStartedLocal = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$state.LockedAtUtc)) {
            try {
                $activeStarted = [DateTime]::Parse([string]$state.LockedAtUtc).ToUniversalTime()
                $activeSeconds = [Math]::Max(0, ([DateTime]::UtcNow - $activeStarted).TotalSeconds)
                $activeStartedLocal = $activeStarted.ToLocalTime().ToString('HH:mm:ss')
            } catch {}
        }

        $totalText.Text = Format-LockWidgetDuration ([double]$state.TotalLockedSeconds + $activeSeconds)
        $displayCount = $sessions.Count + $(if ($activeSeconds -gt 0) { 1 } else { 0 })
        $countText.Text = $displayCount.ToString() + ' 次'
        $stamp = [string]$state.LastUpdatedUtc + '|' + $sessions.Count + '|' + $(if ($activeSeconds -gt 0) { [Math]::Floor($activeSeconds) } else { 0 })
        if ($stamp -eq $script:lastLockWidgetStamp) { return }

        $panel.Children.Clear()
        $todayPowerEvents = @()
        if ($null -ne $script:powerHistorySnapshot) {
            $todayPowerEvents = @($script:powerHistorySnapshot.events | Where-Object { [string]$_.localDate -eq $today })
        }
        foreach ($powerEvent in $todayPowerEvents) {
            $label = if ([string]$powerEvent.type -eq 'Boot') { '开机' } else { '关机' }
            $index = if ($null -ne $powerEvent.dailyIndex) { [int]$powerEvent.dailyIndex } else { 1 }
            $time = try { ([DateTime]::Parse([string]$powerEvent.localTime)).ToString('HH:mm:ss') } catch { '--:--:--' }
            Add-LockSessionVisual -Panel $panel -Title ('第 {0} 次{1}  {2}' -f $index, $label, $time) -Duration ('系统事件  ' + $today)
        }
        foreach ($session in $sessions) {
            $index = if ($null -ne $session.Index) { [int]$session.Index } else { $panel.Children.Count + 1 }
            $started = [string]$session.StartedLocal
            $ended = [string]$session.EndedLocal
            $duration = if (-not [string]::IsNullOrWhiteSpace([string]$session.DurationText)) { [string]$session.DurationText } else { Format-LockWidgetDuration ([double]$session.DurationSeconds) }
            Add-LockSessionVisual -Panel $panel -Title ('第 {0} 次  {1} → {2}' -f $index, $started, $ended) -Duration ('时长  ' + $duration)
        }
        if ($activeSeconds -gt 0) {
            Add-LockSessionVisual -Panel $panel -Title ('第 {0} 次  {1} → 锁屏中' -f ($sessions.Count + 1), $activeStartedLocal) -Duration ('当前  ' + (Format-LockWidgetDuration $activeSeconds)) -Active $true
        } elseif ($sessions.Count -eq 0 -and $todayPowerEvents.Count -eq 0) {
            $empty = [Windows.Controls.TextBlock]::new()
            $empty.Text = '今天尚无活动记录'
            $empty.Foreground = ConvertTo-Brush -Color '#A8FFD8E8'
            $empty.FontSize = 7.5
            $empty.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
            [void]$panel.Children.Add($empty)
        }
        $script:lastLockWidgetStamp = $stamp
    } catch {
        Write-WidgetLog ('Lock widget update failed: ' + $_.Exception.Message)
    }
}

function Normalize-PowerHistoryEvents {
    param([object[]]$Events)
    $seen = @{}
    $history = @(
        foreach ($event in @($Events)) {
            try {
                $eventType = [string]$event.type
                $eventTime = [DateTime]::Parse([string]$event.localTime)
                if ($eventType -ne 'Boot' -and $eventType -ne 'Shutdown') { continue }
                $key = $eventType + '|' + $eventTime.ToUniversalTime().Ticks
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                [pscustomobject][ordered]@{
                    type = $eventType
                    localTime = $eventTime.ToString('o')
                    localDate = $eventTime.ToString('yyyy-MM-dd')
                    dailyIndex = 0
                    displayTime = $eventTime.ToString('yyyy/MM/dd HH:mm:ss')
                }
            } catch {}
        }
    )
    $history = @($history | Sort-Object { [DateTime]::Parse([string]$_.localTime) } -Descending)
    foreach ($dayGroup in @($history | Group-Object localDate)) {
        foreach ($typeGroup in @($dayGroup.Group | Group-Object type)) {
            $orderedEvents = @($typeGroup.Group | Sort-Object { [DateTime]::Parse([string]$_.localTime) })
            for ($i = 0; $i -lt $orderedEvents.Count; $i++) {
                $orderedEvents[$i].dailyIndex = $i + 1
            }
        }
    }
    return $history
}

function Get-PowerHistorySnapshot {
    $operatingSystem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $bootTime = [DateTime]$operatingSystem.LastBootUpTime
    $events = @(Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-General'
        Id = 12, 13
    } -MaxEvents 400 -ErrorAction Stop)
    $shutdownEvent = $events | Where-Object { $_.Id -eq 13 } | Select-Object -First 1
    $rawHistory = @(
        foreach ($event in $events) {
            [pscustomobject]@{
                type = if ($event.Id -eq 12) { 'Boot' } else { 'Shutdown' }
                localTime = $event.TimeCreated.ToString('o')
            }
        }
    )
    $history = @(Normalize-PowerHistoryEvents -Events $rawHistory)
    return [ordered]@{
        version = 2
        updatedLocal = (Get-Date).ToString('o')
        currentBootLocal = $bootTime.ToString('o')
        lastShutdownLocal = if ($null -ne $shutdownEvent) { $shutdownEvent.TimeCreated.ToString('o') } else { $null }
        events = $history
    }
}

function Format-PowerWidgetTime {
    param([DateTime]$Value, [bool]$IncludeDate)
    if ($IncludeDate) { return $Value.ToString('MM/dd HH:mm:ss') }
    return $Value.ToString('HH:mm:ss')
}

function Update-PowerHistoryWidget {
    $snapshot = $null
    try {
        $snapshot = Get-PowerHistorySnapshot
        $cachedSnapshot = Read-Utf8Json -Path $script:powerHistoryPath
        if ($null -ne $cachedSnapshot) {
            $snapshot.events = @(Normalize-PowerHistoryEvents -Events @($snapshot.events + $cachedSnapshot.events))
        }
        Write-Utf8Json -Path $script:powerHistoryPath -Value $snapshot
    } catch {
        $snapshot = Read-Utf8Json -Path $script:powerHistoryPath
        Write-WidgetLog ('Power history refresh failed; cached values retained: ' + $_.Exception.Message)
    }

    if ($null -eq $snapshot) {
        return
    }
    $script:powerHistorySnapshot = $snapshot
    $script:lastLockWidgetStamp = ''
    Update-LockDurationWidget
}

function Get-WeatherConditionKey {
    param([int]$Code)
    if ($Code -eq 0) { return "clear" }
    if ($Code -le 3) { return "cloudy" }
    if ($Code -le 48) { return "fog" }
    if ($Code -le 57) { return "drizzle" }
    if ($Code -le 67) { return "rain" }
    if ($Code -le 77) { return "snow" }
    if ($Code -le 82) { return "shower" }
    return "thunder"
}

function Get-WeatherConditionText {
    param([int]$Code)
    $key = Get-WeatherConditionKey -Code $Code
    try {
        $value = $script:settings.weatherConditions.PSObject.Properties[$key].Value
        if (![string]::IsNullOrWhiteSpace([string]$value)) { return [string]$value }
    } catch {}
    return $key
}

function Get-WeatherGlyph {
    param([int]$Code)
    $key = Get-WeatherConditionKey -Code $Code
    switch ($key) {
        "clear" { return [char]0x2600 }
        "cloudy" { return [char]0x2601 }
        "fog" { return [char]0x224B }
        "snow" { return [char]0x2744 }
        "thunder" { return [char]0x26A1 }
        default { return [char]0x2602 }
    }
}

function Update-Weather {
    $weather = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $latitude = [double]$script:settings.weatherLatitude
        $longitude = [double]$script:settings.weatherLongitude
        $uri = "https://api.open-meteo.com/v1/forecast?latitude=" + $latitude.ToString([Globalization.CultureInfo]::InvariantCulture) +
            "&longitude=" + $longitude.ToString([Globalization.CultureInfo]::InvariantCulture) +
            "&current=temperature_2m,weather_code,relative_humidity_2m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=Asia%2FShanghai&forecast_days=5"
        $weather = Invoke-RestMethod -Uri $uri -Method Get -UseBasicParsing -TimeoutSec 7
        Write-Utf8Json -Path $script:weatherCachePath -Value $weather
    } catch {
        Write-WidgetLog ("Weather refresh failed: " + $_.Exception.Message)
        $weather = Read-Utf8Json -Path $script:weatherCachePath
    }

    if ($null -eq $weather -or $null -eq $weather.current) {
        $script:window.FindName("WeatherConditionText").Text = Get-WidgetText -Name "weatherUnavailable" -Fallback "Weather unavailable"
        $script:window.FindName("WeatherUpdatedText").Text = "--"
        return
    }

    $code = [int]$weather.current.weather_code
    $currentTemperature = [int][Math]::Round([double]$weather.current.temperature_2m)
    $maximum = [int][Math]::Round([double]$weather.daily.temperature_2m_max[0])
    $minimum = [int][Math]::Round([double]$weather.daily.temperature_2m_min[0])
    $script:window.FindName("WeatherLocationText").Text = Get-WidgetText -Name "locationName" -Fallback "Jieyang"
    $script:window.FindName("WeatherTemperatureText").Text = $currentTemperature.ToString() + [char]0x00B0
    $script:window.FindName("WeatherConditionText").Text = Get-WeatherConditionText -Code $code
    $script:window.FindName("WeatherStatusIcon").Text = Get-WeatherGlyph -Code $code
    $script:window.FindName("WeatherHighLowText").Text = (Get-WidgetText -Name "high" -Fallback "High") + " " + $maximum + [char]0x00B0 + "  " + (Get-WidgetText -Name "low" -Fallback "Low") + " " + $minimum + [char]0x00B0
    $script:window.FindName("WeatherUpdatedText").Text = Get-WidgetText -Name "weatherUpdated" -Fallback "Updated"

    $culture = [Globalization.CultureInfo]::GetCultureInfo("zh-CN")
    for ($index = 0; $index -lt 5; $index++) {
        $date = [DateTime]::Parse([string]$weather.daily.time[$index], [Globalization.CultureInfo]::InvariantCulture)
        $dayText = if ($index -eq 0) { Get-WidgetText -Name "today" -Fallback "Today" } elseif ($index -eq 1) { Get-WidgetText -Name "tomorrow" -Fallback "Tomorrow" } else { $date.ToString("ddd", $culture) }
        $forecastCode = [int]$weather.daily.weather_code[$index]
        $forecastHigh = [int][Math]::Round([double]$weather.daily.temperature_2m_max[$index])
        $script:window.FindName("ForecastDay" + ($index + 1)).Text = $dayText
        $script:window.FindName("ForecastIcon" + ($index + 1)).Text = Get-WeatherGlyph -Code $forecastCode
        $script:window.FindName("ForecastTemp" + ($index + 1)).Text = $forecastHigh.ToString() + [char]0x00B0
    }
}

function Get-ProcessDisplayName {
    param([string]$ProcessName)
    switch -Regex ($ProcessName) {
        "msedge" { return "Microsoft Edge" }
        "chrome" { return "Google Chrome" }
        "^Code$" { return "Visual Studio Code" }
        "^Codex$" { return "Codex" }
        "ChatGPT" { return "ChatGPT" }
        "WeChat|Weixin" { return "微信" }
        "^steam$" { return "Steam" }
        "explorer" { return "文件资源管理器" }
        "WindowsTerminal|^wt$" { return "Windows Terminal" }
        "powershell|pwsh" { return "PowerShell" }
        "notepad" { return "记事本" }
        "devenv" { return "Visual Studio" }
        "idea64" { return "IntelliJ IDEA" }
        "pycharm64" { return "PyCharm" }
        "Spotify" { return "Spotify" }
        "cloudmusic" { return "网易云音乐" }
        "QQMusic" { return "QQ 音乐" }
        default { return $ProcessName }
    }
}

function Format-AppUsageDuration {
    param([double]$Seconds)

    $minutes = [int][Math]::Floor([Math]::Max(0, $Seconds) / 60)
    if ($minutes -lt 1) { return "<1 分钟" }
    if ($minutes -lt 60) { return $minutes.ToString() + " 分钟" }
    $hours = [int][Math]::Floor($minutes / 60)
    $remaining = $minutes % 60
    if ($remaining -eq 0) { return $hours.ToString() + " 小时" }
    return $hours.ToString() + " 小时 " + $remaining.ToString() + " 分"
}

function Reset-AppUsageDayIfNeeded {
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if ($script:appUsageDate -eq $today) { return }
    $script:appUsageDate = $today
    $script:appUsageSeconds = @{}
    $script:appUsageCurrentName = "桌面空闲"
    $script:appUsageLastSave = [DateTime]::UtcNow
    Write-WidgetLog "App usage tracker started a new daily record."
}

function Save-AppUsageState {
    $items = @()
    foreach ($name in @($script:appUsageSeconds.Keys | Sort-Object)) {
        $items += [ordered]@{
            name = [string]$name
            seconds = [Math]::Round([double]$script:appUsageSeconds[$name], 1)
        }
    }
    Write-Utf8Json -Path $script:appUsagePath -Value ([ordered]@{
        version = 1
        date = $script:appUsageDate
        apps = $items
    })
    $script:appUsageLastSave = [DateTime]::UtcNow
}

function Get-ForegroundUsageApp {
    $foreground = [MacWidgetNative]::GetForegroundWindow()
    if ($foreground -eq [IntPtr]::Zero) { return $null }

    [uint32]$foregroundProcessId = 0
    [void][MacWidgetNative]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
    if ($foregroundProcessId -eq 0 -or $foregroundProcessId -eq [Diagnostics.Process]::GetCurrentProcess().Id) { return $null }

    try { $process = Get-Process -Id $foregroundProcessId -ErrorAction Stop } catch { return $null }
    $processName = [string]$process.ProcessName
    $title = [MacWidgetNative]::GetTitle($foreground)
    $windowClass = [MacWidgetNative]::GetWindowClass($foreground)
    $ignored = @("SearchHost", "StartMenuExperienceHost", "ShellExperienceHost", "LockApp", "dwm", "Dock_64", "MyDockFinder", "seelen-ui", "Lively")
    if ($processName -in $ignored) { return $null }

    $isDesktop = $processName -eq "explorer" -and (
        [string]::IsNullOrWhiteSpace($title) -or
        $title -eq "Program Manager" -or
        $windowClass -in @("Progman", "WorkerW")
    )
    if ($isDesktop -or [string]::IsNullOrWhiteSpace($title)) { return $null }
    return Get-ProcessDisplayName -ProcessName $processName
}

function Update-AppUsageWidget {
    $entries = @()
    $totalSeconds = 0.0
    foreach ($name in $script:appUsageSeconds.Keys) {
        $seconds = [double]$script:appUsageSeconds[$name]
        $totalSeconds += $seconds
        $entries += [pscustomobject]@{ Name = [string]$name; Seconds = $seconds }
    }
    $entries = @($entries | Sort-Object Seconds -Descending | Select-Object -First 4)
    $maximum = if ($entries.Count -gt 0) { [Math]::Max(1.0, [double]$entries[0].Seconds) } else { 1.0 }

    $script:window.FindName("AppUsageTotalText").Text = Format-AppUsageDuration -Seconds $totalSeconds
    $script:window.FindName("AppUsageCurrentText").Text = "正在使用：" + $script:appUsageCurrentName
    $script:window.FindName("AppUsageDateText").Text = (Get-Date).ToString("M月d日")
    $usageCard = $script:window.FindName("AppUsageCard")
    $barMaxWidth = 206.0
    if ($null -ne $usageCard -and $usageCard.ActualWidth -gt 80) {
        $barMaxWidth = [Math]::Max(80.0, [double]$usageCard.ActualWidth - 42.0)
    }

    for ($index = 1; $index -le 4; $index++) {
        $nameText = $script:window.FindName("AppUsageName" + $index)
        $timeText = $script:window.FindName("AppUsageTime" + $index)
        $bar = $script:window.FindName("AppUsageBar" + $index)
        if ($index -le $entries.Count) {
            $entry = $entries[$index - 1]
            $nameText.Text = $entry.Name
            $timeText.Text = Format-AppUsageDuration -Seconds $entry.Seconds
            $bar.Width = [Math]::Round($barMaxWidth * $entry.Seconds / $maximum, 0)
        } else {
            $nameText.Text = if ($index -eq 1) { "暂无应用记录" } else { "--" }
            $timeText.Text = ""
            $bar.Width = 0
        }
    }
}

function Initialize-AppUsageTracker {
    $state = Read-Utf8Json -Path $script:appUsagePath
    if ($null -ne $state -and [string]$state.date -eq $script:appUsageDate) {
        foreach ($item in @($state.apps)) {
            $name = [string]$item.name
            if (![string]::IsNullOrWhiteSpace($name)) {
                $script:appUsageSeconds[$name] = [double]$item.seconds
            }
        }
    }
    $script:appUsageLastTick = [DateTime]::UtcNow
    $script:appUsageLastSave = [DateTime]::UtcNow
    Update-AppUsageWidget
    Write-WidgetLog "Low-frequency foreground app usage tracker loaded."
}

function Update-AppUsageTracker {
    Reset-AppUsageDayIfNeeded
    $now = [DateTime]::UtcNow
    $elapsed = ($now - $script:appUsageLastTick).TotalSeconds
    $script:appUsageLastTick = $now
    if ($elapsed -lt 0 -or $elapsed -gt 15) { $elapsed = 0 }

    $appName = Get-ForegroundUsageApp
    if ([string]::IsNullOrWhiteSpace([string]$appName)) {
        $script:appUsageCurrentName = "桌面空闲"
    } else {
        $script:appUsageCurrentName = [string]$appName
        if (!$script:appUsageSeconds.ContainsKey($appName)) { $script:appUsageSeconds[$appName] = 0.0 }
        $script:appUsageSeconds[$appName] = [double]$script:appUsageSeconds[$appName] + $elapsed
    }

    Update-AppUsageWidget
    if (($now - $script:appUsageLastSave).TotalSeconds -ge 60) { Save-AppUsageState }
}

function Get-MediaSourceDisplayName {
    param([string]$SourceId)
    if ([string]::IsNullOrWhiteSpace($SourceId)) { return "系统媒体" }
    switch -Regex ($SourceId) {
        "Spotify" { return "Spotify" }
        "QQMusic" { return "QQ 音乐" }
        "cloudmusic|NetEase" { return "网易云音乐" }
        "AppleMusic|AppleInc" { return "Apple Music" }
        "msedge|MicrosoftEdge" { return "Microsoft Edge" }
        "chrome" { return "Google Chrome" }
        "firefox" { return "Mozilla Firefox" }
        "MediaPlayer|ZuneMusic" { return "Windows 媒体播放器" }
        "bilibili" { return "哔哩哔哩" }
        default {
            $name = [IO.Path]::GetFileNameWithoutExtension($SourceId)
            if ($name -match "!") { $name = ($name -split "!")[-1] }
            if ([string]::IsNullOrWhiteSpace($name)) { return "系统媒体" }
            return $name
        }
    }
}

function Test-PinnedMediaSnapshot {
    param($Snapshot)

    if ($null -eq $Snapshot) { return $false }
    $source = [string]$Snapshot.SourceId
    $title = [string]$Snapshot.Title
    $artist = [string]$Snapshot.Artist
    if ($source -match "ObsidianSoundCloudPlayer|SoundCloudPlayer") { return $true }
    if ($title -match "依然与你同在|Still With You") { return $true }
    if ($artist -match "Jung Kook|정국" -and $source -match "msedge|MicrosoftEdge|WebView") { return $true }
    return $false
}

function Test-MusicMediaSnapshot {
    param($Snapshot)

    if ($null -eq $Snapshot) { return $false }
    if (Test-PinnedMediaSnapshot -Snapshot $Snapshot) { return $true }
    $identity = ([string]$Snapshot.SourceId) + "|" + ([string]$Snapshot.Title) + "|" + ([string]$Snapshot.Artist) + "|" + ([string]$Snapshot.Album)
    return $identity -match "Spotify|QQMusic|cloudmusic|NetEase|AppleMusic|AppleInc|ZuneMusic|MediaPlayer|Music.UI|酷狗|KuGou|酷我|Kuwo|SoundCloud|music\.youtube|YouTubeMusic|bandcamp|tidal|deezer|官方音频|official audio|official lyric"
}

function Get-ForegroundMediaContext {
    $foreground = [MacWidgetNative]::GetForegroundWindow()
    if ($foreground -eq [IntPtr]::Zero) { return $null }

    [uint32]$processId = 0
    [void][MacWidgetNative]::GetWindowThreadProcessId($foreground, [ref]$processId)
    if ($processId -eq 0 -or $processId -eq [Diagnostics.Process]::GetCurrentProcess().Id) { return $null }
    try { $process = Get-Process -Id $processId -ErrorAction Stop } catch { return $null }

    $processName = [string]$process.ProcessName
    $title = [MacWidgetNative]::GetTitle($foreground)
    $windowClass = [MacWidgetNative]::GetWindowClass($foreground)
    $ignored = @("SearchHost", "StartMenuExperienceHost", "ShellExperienceHost", "LockApp", "dwm", "Dock_64", "MyDockFinder", "seelen-ui", "Lively")
    if ($processName -in $ignored) { return $null }
    $isDesktop = $processName -eq "explorer" -and (
        [string]::IsNullOrWhiteSpace($title) -or
        $title -eq "Program Manager" -or
        $windowClass -in @("Progman", "WorkerW")
    )
    if ($isDesktop) { return $null }

    $displayName = Get-ProcessDisplayName -ProcessName $processName
    if ([string]::IsNullOrWhiteSpace($title)) { $title = $displayName }
    # Audio peaks alone are not enough to create a movie/video record. Keep the
    # fallback constrained to established players or a browser title that clearly
    # identifies a media page, so chat and normal work windows are not misfiled.
    $knownPlayer = $processName -match "(?i)vlc|mpv|potplayer|mpc-hc|wmplayer|zunevideo|moviesandtv|mediaplayer|bilibili|qqlive|qiyiclient|youku|mango|douyin|kuaishou|plex|stremio|kmplayer"
    $browserMedia = $processName -match "(?i)msedge|chrome|firefox" -and $title -match "(?i)youtube|bilibili|哔哩|netflix|iqiyi|爱奇艺|腾讯视频|youku|优酷|mango|芒果|douyin|抖音|kuaishou|快手|播放器|电影|视频|影院|直播|anime|番剧"
    $likelyMedia = $knownPlayer -or $browserMedia

    return [pscustomobject]@{
        ProcessName = $processName
        DisplayName = $displayName
        Title = $title
        LikelyMedia = $likelyMedia
    }
}

function Test-FallbackMediaContext {
    param($Context)

    return $null -ne $Context -and [bool]$Context.LikelyMedia
}

function Test-MovieMediaContext {
    param(
        [string]$Title,
        [string]$SourceId,
        [string]$App,
        [double]$DurationSeconds = 0.0
    )

    if ($Title -in @("系统视频与电影声音", "正在播放的视频", "视频 / 电影实时字幕") -or
        $SourceId -eq "SystemAudio" -or $App -eq "系统音频") {
        return $false
    }

    $identity = ([string]$Title + "|" + [string]$SourceId + "|" + [string]$App)
    if ($identity -match "(?i)电影|movie|film|cinema|影院|影视|剧场版|电视剧|剧集|episode|season|dnying|dy2018|netflix|primevideo|disneyplus|hbomax|mubi") {
        return $true
    }

    $knownPlayer = $identity -match "(?i)vlc|mpv|potplayer|mpc-hc|wmplayer|zunevideo|moviesandtv|mediaplayer|plex|stremio|kmplayer"
    return $knownPlayer -and $DurationSeconds -ge 2700
}

function Get-MediaHistoryRecordType {
    param(
        [string]$ContentMode,
        [string]$Title,
        [string]$SourceId,
        [string]$App,
        [double]$DurationSeconds = 0.0
    )

    if ($ContentMode -eq "music") { return "音乐" }
    if ($ContentMode -eq "video" -and (Test-MovieMediaContext -Title $Title -SourceId $SourceId -App $App -DurationSeconds $DurationSeconds)) {
        return "电影"
    }
    return ""
}

function Get-MediaHistoryLinkInfo {
    param(
        [string]$Type,
        [string]$SourceId,
        [string]$Title,
        [string]$Artist
    )

    $source = [string]$SourceId
    $query = (([string]$Title + " " + [string]$Artist).Trim())
    if ([string]::IsNullOrWhiteSpace($query)) { $query = $source }
    if ([string]::IsNullOrWhiteSpace($query)) { $query = "media" }

    $direct = [regex]::Match($source, '(?i)https?://[^\s"''<>]+')
    if (!$direct.Success) { $direct = [regex]::Match([string]$Title, '(?i)https?://[^\s"''<>]+') }
    if ($direct.Success) {
        return [pscustomobject]@{ Url = [string]$direct.Value; Kind = "来源链接" }
    }

    $browserCandidate = ""
    if ($source -match "(?i)^(?:msedge|microsoftedge|chrome|firefox)\.(.+)$") {
        $browserCandidate = [string]$Matches[1]
    } elseif ($source -match "(?i)^(?:www\.)?[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)+(?:_?/.*)?$") {
        $browserCandidate = $source
    }
    if (![string]::IsNullOrWhiteSpace($browserCandidate)) {
        $browserCandidate = $browserCandidate -replace "_/", "/"
        if ($browserCandidate -match "(?i)^(?:www\.)?[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)+(?:/[^\s]*)?$") {
            return [pscustomobject]@{ Url = "https://" + $browserCandidate; Kind = "来源链接" }
        }
    }

    $escapedQuery = [Uri]::EscapeDataString($query)
    if ($Type -eq "音乐") {
        if ($source -match "(?i)Official SoundCloud|SoundCloudPlayer" -and ![string]::IsNullOrWhiteSpace($script:pinnedMediaUri)) {
            return [pscustomobject]@{ Url = $script:pinnedMediaUri; Kind = "来源链接" }
        }
        if ($source -match "(?i)Spotify") { return [pscustomobject]@{ Url = "https://open.spotify.com/search/" + $escapedQuery; Kind = "搜索链接" } }
        if ($source -match "(?i)QQMusic") { return [pscustomobject]@{ Url = "https://y.qq.com/n/ryqq/search?w=" + $escapedQuery; Kind = "搜索链接" } }
        if ($source -match "(?i)cloudmusic|NetEase") { return [pscustomobject]@{ Url = "https://music.163.com/#/search/m/?s=" + $escapedQuery + "&type=1"; Kind = "搜索链接" } }
        if ($source -match "(?i)AppleMusic|AppleInc") { return [pscustomobject]@{ Url = "https://music.apple.com/us/search?term=" + $escapedQuery; Kind = "搜索链接" } }
        if ($source -match "(?i)SoundCloud") { return [pscustomobject]@{ Url = "https://soundcloud.com/search?q=" + $escapedQuery; Kind = "搜索链接" } }
        return [pscustomobject]@{ Url = "https://www.bing.com/search?q=" + $escapedQuery; Kind = "搜索链接" }
    }

    $movieQuery = [Uri]::EscapeDataString((([string]$Title + " 电影").Trim()))
    return [pscustomobject]@{ Url = "https://www.bing.com/search?q=" + $movieQuery; Kind = "搜索链接" }
}

function Set-MediaHistoryEntryLink {
    param($Entry)

    if ($null -eq $Entry) { return $null }
    $info = Get-MediaHistoryLinkInfo -Type ([string]$Entry.type) -SourceId ([string]$Entry.sourceId) -Title ([string]$Entry.title) -Artist ([string]$Entry.artist)
    if ($null -eq $Entry.PSObject.Properties["link"]) {
        $Entry | Add-Member -MemberType NoteProperty -Name link -Value ([string]$info.Url)
    } else {
        $Entry.link = [string]$info.Url
    }
    if ($null -eq $Entry.PSObject.Properties["linkKind"]) {
        $Entry | Add-Member -MemberType NoteProperty -Name linkKind -Value ([string]$info.Kind)
    } else {
        $Entry.linkKind = [string]$info.Kind
    }
    return $info
}

function Test-MediaHistoryEntryRecordable {
    param($Entry)

    if ($null -eq $Entry) { return $false }
    $type = [string]$Entry.type
    if ($type -eq "音乐") { return $true }
    if ($type -eq "电影") {
        return Test-MovieMediaContext -Title ([string]$Entry.title) -SourceId ([string]$Entry.sourceId) -App ([string]$Entry.app) -DurationSeconds ([double]$Entry.durationSeconds)
    }
    if ($type -eq "电影/视频") {
        return Test-MovieMediaContext -Title ([string]$Entry.title) -SourceId ([string]$Entry.sourceId) -App ([string]$Entry.app) -DurationSeconds ([double]$Entry.durationSeconds)
    }
    return $false
}

function Copy-MediaHistoryLink {
    param($Entry)

    if (!(Test-MediaHistoryEntryRecordable -Entry $Entry)) { return $false }
    $link = [string]$Entry.link
    $kind = [string]$Entry.linkKind
    if ([string]::IsNullOrWhiteSpace($link)) {
        $info = Set-MediaHistoryEntryLink -Entry $Entry
        $link = [string]$info.Url
        $kind = [string]$info.Kind
        Save-MediaHistory
    }
    if ([string]::IsNullOrWhiteSpace($link)) { return $false }

    try {
        [Windows.Clipboard]::SetText($link)
        if ([string]::IsNullOrWhiteSpace($kind)) { $kind = "链接" }
        $script:mediaHistoryCopyStatusText = "已复制" + $kind
        $script:mediaHistoryCopyStatusUntilUtc = [DateTime]::UtcNow.AddSeconds(2)
        $script:mediaHistoryLastDisplaySignature = ""
        Write-WidgetLog ("Media history " + $kind + " copied to clipboard.")
        Update-MediaHistoryWidget
        return $true
    } catch {
        $script:mediaHistoryCopyStatusText = "复制失败"
        $script:mediaHistoryCopyStatusUntilUtc = [DateTime]::UtcNow.AddSeconds(2)
        $script:mediaHistoryLastDisplaySignature = ""
        Update-MediaHistoryWidget
        Write-WidgetLog ("Media history link copy failed: " + $_.Exception.Message)
        return $false
    }
}

function Disable-SyncedLyricsForLiveMedia {
    if ($null -ne $script:syncedLyricsFetchProcess) {
        try { if (!$script:syncedLyricsFetchProcess.HasExited) { $script:syncedLyricsFetchProcess.Kill() } } catch {}
        try { $script:syncedLyricsFetchProcess.Dispose() } catch {}
        $script:syncedLyricsFetchProcess = $null
    }
    $script:syncedLyricsEntries = @()
    $script:syncedLyricsKey = ""
    $script:syncedLyricsRequestedKey = ""
    $script:syncedLyricsCachePath = ""
    $script:syncedLyricsActive = $false
    $script:syncedLyricsLastIndex = -1
    $script:syncedLyricsLastElapsed = -1.0
    $script:syncedLyricsDuration = 0.0
    $script:syncedLyricsPlayerDuration = 0.0
}

function Invoke-WinRtAsync {
    param(
        $Operation,
        [Type]$ResultType,
        [int]$TimeoutMilliseconds = 2500
    )

    if ($null -eq $Operation) { return $null }
    if ($null -eq $script:winRtAsTaskMethod) {
        $script:winRtAsTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object {
                $_.Name -eq "AsTask" -and
                $_.IsGenericMethod -and
                $_.GetParameters().Count -eq 1
            } |
            Select-Object -First 1
    }
    if ($null -eq $script:winRtAsTaskMethod) { throw "WinRT AsTask bridge is unavailable." }

    $task = $script:winRtAsTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    if (!$task.Wait($TimeoutMilliseconds)) { throw "WinRT media request timed out." }
    if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
    return $task.Result
}

function Initialize-MediaSessionManager {
    if ($null -ne $script:mediaManager) { return $true }
    try {
        [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
        [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
        $operation = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
        $script:mediaManager = Invoke-WinRtAsync `
            -Operation $operation `
            -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
        Write-WidgetLog "Windows media session manager connected."
        return $null -ne $script:mediaManager
    } catch {
        $script:mediaManager = $null
        Write-WidgetLog ("Windows media session manager unavailable: " + $_.Exception.Message)
        return $false
    }
}

function Get-MediaSessionSnapshot {
    if (!(Initialize-MediaSessionManager)) { return $null }

    $currentSession = $script:mediaManager.GetCurrentSession()
    $candidates = New-Object System.Collections.Generic.List[object]
    if ($null -ne $currentSession) { [void]$candidates.Add($currentSession) }
    foreach ($candidate in @($script:mediaManager.GetSessions())) {
        $exists = $false
        foreach ($known in $candidates) {
            if ([object]::ReferenceEquals($known, $candidate)) { $exists = $true; break }
        }
        if (!$exists) { [void]$candidates.Add($candidate) }
    }
    if ($candidates.Count -eq 0) { return $null }

    $snapshots = @()
    foreach ($session in $candidates) {
        try {
            $properties = Invoke-WinRtAsync -Operation $session.TryGetMediaPropertiesAsync() -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
            $playback = $session.GetPlaybackInfo()
            $timeline = $session.GetTimelineProperties()
            $snapshots += [pscustomobject]@{
                Session = $session
                SourceId = [string]$session.SourceAppUserModelId
                Title = [string]$properties.Title
                Artist = [string]$properties.Artist
                Album = [string]$properties.AlbumTitle
                Status = [string]$playback.PlaybackStatus.ToString()
                Timeline = $timeline
                IsCurrent = [object]::ReferenceEquals($session, $currentSession)
            }
        } catch {
            Write-WidgetLog ("Media session snapshot skipped: " + $_.Exception.Message)
        }
    }
    if ($snapshots.Count -eq 0) { return $null }

    $selected = $snapshots | Where-Object { $_.Status -eq "Playing" -and !(Test-PinnedMediaSnapshot -Snapshot $_) } | Select-Object -First 1
    if ($null -eq $selected) { $selected = $snapshots | Where-Object { $_.Status -eq "Playing" } | Select-Object -First 1 }
    if ($null -eq $selected) { $selected = $snapshots | Where-Object { $_.IsCurrent } | Select-Object -First 1 }
    if ($null -eq $selected) { $selected = $snapshots | Select-Object -First 1 }
    return $selected
}

function Format-MediaTime {
    param([double]$Seconds)
    $safeSeconds = [Math]::Max(0, [Math]::Floor($Seconds))
    $duration = [TimeSpan]::FromSeconds($safeSeconds)
    if ($duration.TotalHours -ge 1) { return $duration.ToString("h\:mm\:ss") }
    return $duration.ToString("m\:ss")
}

function Initialize-MediaAvatar {
    $avatar = $script:window.FindName("MediaAvatarPortrait")
    if ($null -eq $avatar) { return }
    if (!(Test-Path -LiteralPath $script:mediaAvatarPath)) {
        Write-WidgetLog ("Media avatar missing: " + $script:mediaAvatarPath)
        return
    }

    try {
        $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.DecodePixelWidth = 160
        $bitmap.UriSource = [Uri]::new($script:mediaAvatarPath, [UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()

        $brush = [Windows.Media.ImageBrush]::new($bitmap)
        $brush.Stretch = [Windows.Media.Stretch]::UniformToFill
        $brush.AlignmentX = [Windows.Media.AlignmentX]::Center
        $brush.AlignmentY = [Windows.Media.AlignmentY]::Center
        $avatar.Fill = $brush
        Write-WidgetLog "Strawberry player avatar loaded from the supplied reference image."
    } catch {
        Write-WidgetLog ("Media avatar load failed: " + $_.Exception.Message)
    }
}

function Set-MediaPlayingVisualState {
    param([bool]$IsPlaying)

    if ($null -ne $script:mediaPlayingVisualState -and [bool]$script:mediaPlayingVisualState -eq $IsPlaying) { return }
    $script:mediaPlayingVisualState = $IsPlaying

    $rotation = $script:window.FindName("MediaAvatarRotate")
    $avatarPulse = $script:window.FindName("MediaAvatarPulse")
    $playAura = $script:window.FindName("MediaPlayAura")
    if ($null -eq $rotation -or $null -eq $avatarPulse -or $null -eq $playAura) { return }

    $rotation.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $null)
    $avatarPulse.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
    $playAura.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)

    if (!$IsPlaying -or ![Windows.SystemParameters]::ClientAreaAnimation) {
        $rotation.Angle = 0
        $avatarPulse.Opacity = if ($IsPlaying) { 0.38 } else { 0.22 }
        $playAura.Opacity = if ($IsPlaying) { 0.40 } else { 0.24 }
        return
    }

    $avatarBreath = [Windows.Media.Animation.DoubleAnimation]::new()
    $avatarBreath.From = 0.20
    $avatarBreath.To = 0.54
    $avatarBreath.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(1700))
    $avatarBreath.AutoReverse = $true
    $avatarBreath.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($avatarBreath, 30)
    $avatarPulse.BeginAnimation([Windows.UIElement]::OpacityProperty, $avatarBreath)

    $buttonBreath = [Windows.Media.Animation.DoubleAnimation]::new()
    $buttonBreath.From = 0.25
    $buttonBreath.To = 0.52
    $buttonBreath.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(1350))
    $buttonBreath.AutoReverse = $true
    $buttonBreath.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($buttonBreath, 30)
    $playAura.BeginAnimation([Windows.UIElement]::OpacityProperty, $buttonBreath)
}

function Get-SyncedLyricsCachePath {
    param(
        [string]$Title,
        [string]$Artist
    )

    $identity = ($Title.Trim().ToLowerInvariant() + "|" + $Artist.Trim().ToLowerInvariant())
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($identity)
        $hash = $algorithm.ComputeHash($bytes)
        $name = -join ($hash | Select-Object -First 12 | ForEach-Object { $_.ToString("x2") })
    } finally {
        $algorithm.Dispose()
    }
    return $script:syncedLyricsRoot + "\" + $name + ".json"
}

function Load-SyncedLyricsCache {
    param(
        [string]$Path,
        [string]$Key
    )

    $cache = Read-Utf8Json -Path $Path
    if ($null -eq $cache -or @($cache.entries).Count -eq 0) { return $false }
    $script:syncedLyricsEntries = @($cache.entries | Sort-Object { [double]$_.time })
    $script:syncedLyricsKey = $Key
    $script:syncedLyricsRequestedKey = $Key
    $script:syncedLyricsFailedKey = ""
    $script:syncedLyricsCachePath = $Path
    $script:syncedLyricsActive = $true
    $script:syncedLyricsLastIndex = -1
    $script:syncedLyricsLastElapsed = -1.0
    $script:syncedLyricsDuration = 0.0
    try { $script:syncedLyricsDuration = [double]$cache.duration } catch {}
    if ($script:subtitleRequested) { Stop-MediaSubtitles }
    Set-MediaSubtitleStatus -Text "同步歌词已就绪 · 原文 → 简中" -Color "#FFA7F3D0"
    Write-WidgetLog ("Synchronized lyrics loaded: " + $script:syncedLyricsEntries.Count + " timed line(s).")
    return $true
}

function Complete-SyncedLyricsFetch {
    if ($null -eq $script:syncedLyricsFetchProcess) { return }
    try {
        if (!$script:syncedLyricsFetchProcess.HasExited) { return }
        $exitCode = $script:syncedLyricsFetchProcess.ExitCode
        $script:syncedLyricsFetchProcess.Dispose()
        $script:syncedLyricsFetchProcess = $null
        if ($exitCode -eq 0 -and (Test-Path -LiteralPath $script:syncedLyricsCachePath)) {
            [void](Load-SyncedLyricsCache -Path $script:syncedLyricsCachePath -Key $script:syncedLyricsRequestedKey)
        } else {
            $script:syncedLyricsFailedKey = $script:syncedLyricsRequestedKey
            Set-MediaSubtitleStatus -Text "没有匹配的时间轴歌词，改用实时识别" -Color "#FFFFD38A"
            Write-WidgetLog ("Synchronized lyrics fetch did not produce a cache; exit=" + $exitCode + ".")
        }
    } catch {
        $script:syncedLyricsFailedKey = $script:syncedLyricsRequestedKey
        if ($null -ne $script:syncedLyricsFetchProcess) {
            try { $script:syncedLyricsFetchProcess.Dispose() } catch {}
        }
        $script:syncedLyricsFetchProcess = $null
        Write-WidgetLog ("Synchronized lyrics fetch check failed: " + $_.Exception.Message)
    }
}

function Request-SyncedLyrics {
    param(
        [string]$Title,
        [string]$Artist,
        [double]$DurationSeconds
    )

    if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Artist)) { return }
    if ($DurationSeconds -gt 0) { $script:syncedLyricsPlayerDuration = $DurationSeconds }
    Complete-SyncedLyricsFetch
    $key = ($Title.Trim().ToLowerInvariant() + "|" + $Artist.Trim().ToLowerInvariant())
    if ($script:syncedLyricsActive -and $script:syncedLyricsKey -eq $key) { return }
    if ($script:syncedLyricsFailedKey -eq $key) { return }
    if ($null -ne $script:syncedLyricsFetchProcess -and !$script:syncedLyricsFetchProcess.HasExited) {
        if ($script:syncedLyricsRequestedKey -eq $key) { return }
        try { $script:syncedLyricsFetchProcess.Kill() } catch {}
        try { $script:syncedLyricsFetchProcess.Dispose() } catch {}
        $script:syncedLyricsFetchProcess = $null
    }

    if ($script:syncedLyricsKey -ne $key) {
        $script:syncedLyricsEntries = @()
        $script:syncedLyricsActive = $false
        $script:syncedLyricsLastIndex = -1
        $script:syncedLyricsLastElapsed = -1.0
        $script:syncedLyricsDuration = 0.0
        $script:syncedLyricsKey = ""
    }

    if (!(Test-Path -LiteralPath $script:syncedLyricsRoot)) {
        [void](New-Item -ItemType Directory -Force -Path $script:syncedLyricsRoot)
    }
    $cachePath = Get-SyncedLyricsCachePath -Title $Title -Artist $Artist
    $script:syncedLyricsRequestedKey = $key
    $script:syncedLyricsCachePath = $cachePath
    if (Test-Path -LiteralPath $cachePath) {
        [void](Load-SyncedLyricsCache -Path $cachePath -Key $key)
        return
    }
    if (!(Test-Path -LiteralPath $script:speechPythonPath) -or !(Test-Path -LiteralPath $script:syncedLyricsFetcherPath)) {
        $script:syncedLyricsFailedKey = $key
        return
    }

    try {
        $escape = {
            param([string]$Value)
            return '"' + $Value.Replace('"', '\"') + '"'
        }
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $script:speechPythonPath
        $startInfo.Arguments = (& $escape $script:syncedLyricsFetcherPath) +
            " --title " + (& $escape $Title) +
            " --artist " + (& $escape $Artist) +
            " --duration " + $DurationSeconds.ToString([Globalization.CultureInfo]::InvariantCulture) +
            " --output " + (& $escape $cachePath)
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $script:syncedLyricsFetchProcess = [Diagnostics.Process]::Start($startInfo)
        Set-MediaSubtitleStatus -Text "正在匹配时间轴歌词" -Color "#FFFFD98A"
        Write-WidgetLog ("Synchronized lyrics lookup started for current track.")
    } catch {
        $script:syncedLyricsFailedKey = $key
        Write-WidgetLog ("Synchronized lyrics lookup failed to start: " + $_.Exception.Message)
    }
}

function Update-SyncedLyricsDisplay {
    param([double]$ElapsedSeconds)

    Complete-SyncedLyricsFetch
    if (!$script:syncedLyricsActive -or $script:syncedLyricsEntries.Count -eq 0) { return $false }
    $elapsed = [Math]::Max(0, $ElapsedSeconds)
    if ($script:syncedLyricsLastElapsed -ge 0 -and $elapsed -lt ($script:syncedLyricsLastElapsed - 0.75)) {
        $script:syncedLyricsLastIndex = -1
    }
    $script:syncedLyricsLastElapsed = $elapsed

    $targetTime = $elapsed
    if ($script:syncedLyricsDuration -gt 0 -and $script:syncedLyricsPlayerDuration -gt 0) {
        $durationRatio = $script:syncedLyricsDuration / $script:syncedLyricsPlayerDuration
        if ($durationRatio -ge 0.94 -and $durationRatio -le 1.06) {
            $targetTime = $elapsed * $durationRatio
        }
    }
    $targetTime = [Math]::Max(0, $targetTime + $script:syncedLyricsOffsetSeconds)
    $lineIndex = -1
    for ($index = 0; $index -lt $script:syncedLyricsEntries.Count; $index++) {
        if ([double]$script:syncedLyricsEntries[$index].time -le $targetTime) {
            $lineIndex = $index
        } else {
            break
        }
    }
    if ($lineIndex -lt 0) {
        if ($script:syncedLyricsLastIndex -ne -1) {
            $introTitle = if (![string]::IsNullOrWhiteSpace($script:mediaCurrentTitle)) { $script:mediaCurrentTitle } else { $script:pinnedMediaTitle }
            $introArtist = if (![string]::IsNullOrWhiteSpace($script:mediaCurrentArtist)) { $script:mediaCurrentArtist } else { $script:pinnedMediaArtist }
            Set-MediaSubtitleLines -Chinese $introTitle -English $introArtist
            $script:syncedLyricsLastIndex = -1
        }
        return $true
    }
    if ($lineIndex -ne $script:syncedLyricsLastIndex) {
        $entry = $script:syncedLyricsEntries[$lineIndex]
        $isClearMarker = $false
        if ($null -ne $entry.PSObject.Properties["clear"]) { $isClearMarker = [bool]$entry.clear }
        if ($isClearMarker -or [string]::IsNullOrWhiteSpace([string]$entry.original)) {
            $script:subtitleLastChinese = ""
            $script:subtitleLastOriginal = ""
            $script:subtitleHasCaption = $false
            Set-MediaSubtitleLines -Chinese "纯音乐间奏" -English "Instrumental"
            Set-MediaSubtitleStatus -Text "时间轴同步 · 间奏" -Color "#FFB9C7FF"
        } else {
            $script:subtitleLastChinese = ConvertTo-SimplifiedChinese -Text ([string]$entry.chinese)
            $script:subtitleLastOriginal = [string]$entry.original
            $script:subtitleHasCaption = $true
            Set-MediaSubtitleLines -Chinese $script:subtitleLastChinese -English $script:subtitleLastOriginal
            Set-MediaSubtitleStatus -Text "时间轴歌词 · 原文 → 简中" -Color "#FFA7F3D0"
        }
        $script:syncedLyricsLastIndex = $lineIndex
    }
    $script:window.FindName("MediaStateText").Text = "同步歌词"
    return $true
}

function Get-PinnedPlayerState {
    if (!(Test-Path -LiteralPath $script:pinnedMediaStatePath)) { return $null }
    try {
        $values = @{}
        foreach ($line in Get-Content -LiteralPath $script:pinnedMediaStatePath -Encoding UTF8) {
            $separator = $line.IndexOf('=')
            if ($separator -le 0) { continue }
            $values[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
        }
        if (!$values.ContainsKey("updatedUtc")) { return $null }
        $updated = [DateTime]::Parse($values["updatedUtc"], [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
        if (([DateTime]::UtcNow - $updated.ToUniversalTime()).TotalSeconds -gt 8) { return $null }
        return [pscustomobject]@{
            Status = [string]$values["status"]
            PositionSeconds = [double]$values["positionMs"] / 1000.0
            DurationSeconds = [double]$values["durationMs"] / 1000.0
            Source = [string]$values["source"]
            Title = [string]$values["title"]
            Artist = [string]$values["artist"]
            UpdatedUtc = $updated.ToUniversalTime()
        }
    } catch {
        return $null
    }
}

function Update-MediaProgress {
    $elapsed = 0.0
    $duration = 0.0
    $timeline = $script:mediaTimeline
    if ($null -ne $timeline) {
        try {
            $start = [double]$timeline.StartTime.TotalSeconds
            $end = [double]$timeline.EndTime.TotalSeconds
            $elapsed = [double]$timeline.Position.TotalSeconds - $start
            $duration = $end - $start
            if ($script:mediaPlaybackStatus -eq "Playing") {
                $age = ([DateTimeOffset]::Now - [DateTimeOffset]$timeline.LastUpdatedTime).TotalSeconds
                if ($age -gt 0 -and $age -lt 10) { $elapsed += $age }
            }
        } catch {
            $elapsed = 0
            $duration = 0
        }
    } elseif ($script:pinnedMediaDuration -gt 0) {
        $elapsed = $script:pinnedMediaElapsed
        $duration = $script:pinnedMediaDuration
        if ($script:mediaPlaybackStatus -eq "Playing" -and $script:pinnedMediaUpdatedUtc -ne [DateTime]::MinValue) {
            $age = ([DateTime]::UtcNow - $script:pinnedMediaUpdatedUtc).TotalSeconds
            if ($age -gt 0 -and $age -lt 8) { $elapsed += $age }
        }
    }

    if ($duration -gt 0) {
        $elapsed = [Math]::Max(0, [Math]::Min($duration, $elapsed))
        $ratio = $elapsed / $duration
    } else {
        $ratio = 0
    }

    $script:mediaElapsedSeconds = [double]$elapsed
    $script:mediaDurationSeconds = [double]$duration
    $script:window.FindName("MediaElapsedText").Text = Format-MediaTime -Seconds $elapsed
    $script:window.FindName("MediaDurationText").Text = Format-MediaTime -Seconds $duration
    $track = $script:window.FindName("MediaProgressTrack")
    $fill = $script:window.FindName("MediaProgressFill")
    $thumb = $script:window.FindName("MediaProgressThumb")
    $thumbTranslate = $script:window.FindName("MediaProgressThumbTranslate")
    if ($null -ne $track -and $null -ne $fill) {
        $trackWidth = [Math]::Max(0, [double]$track.ActualWidth)
        $fill.Width = $trackWidth * $ratio
        if ($null -ne $thumb -and $null -ne $thumbTranslate) {
            $thumbWidth = if ($thumb.ActualWidth -gt 0) { [double]$thumb.ActualWidth } else { 7.0 }
            $thumbTranslate.X = [Math]::Max(0, [Math]::Min(($trackWidth - $thumbWidth), (($trackWidth * $ratio) - ($thumbWidth / 2))))
        }
    }
    [void](Update-SyncedLyricsDisplay -ElapsedSeconds $elapsed)
}

function Get-MediaHistoryHardwareSnapshot {
    $nowUtc = [DateTime]::UtcNow
    if ($null -ne $script:mediaHistoryHardwareSnapshot -and
        ($nowUtc - $script:mediaHistoryHardwareLastSampleUtc).TotalSeconds -lt 30) {
        return $script:mediaHistoryHardwareSnapshot
    }

    $processorName = "未知处理器"
    $processorUsage = -1
    $graphicsName = "未知显卡"
    $audioName = "默认音频设备"
    $memoryTotalGb = 0.0
    $memoryUsedPercent = -1

    try {
        $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($null -ne $processor -and ![string]::IsNullOrWhiteSpace([string]$processor.Name)) {
            $processorName = [string]$processor.Name
        }
        if ($null -ne $processor -and $null -ne $processor.LoadPercentage) {
            $processorUsage = [int][Math]::Min(100, [Math]::Max(0, [int]$processor.LoadPercentage))
        }
    } catch {}

    if ($processorUsage -lt 0) {
        try {
            $totalProcessor = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop | Select-Object -First 1
            if ($null -ne $totalProcessor) {
                $processorUsage = [int][Math]::Min(100, [Math]::Max(0, [int]$totalProcessor.PercentProcessorTime))
            }
        } catch {}
    }

    try {
        $graphics = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.Name } | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        if ($graphics.Count -gt 0) { $graphicsName = ($graphics -join " / ") }
    } catch {}

    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($null -ne $computer.TotalPhysicalMemory) {
            $memoryTotalGb = [Math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 1)
        }
    } catch {}

    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($memoryTotalGb -gt 0 -and $null -ne $operatingSystem.FreePhysicalMemory) {
            $freeGb = [double]$operatingSystem.FreePhysicalMemory / 1MB
            $memoryUsedPercent = [int][Math]::Min(100, [Math]::Max(0, [Math]::Round((1 - ($freeGb / $memoryTotalGb)) * 100)))
        }
    } catch {}

    try {
        $audioDevices = @(Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.Name } | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        if ($audioDevices.Count -gt 0) { $audioName = ($audioDevices -join " / ") }
    } catch {}

    $script:mediaHistoryHardwareSnapshot = [pscustomobject]@{
        computer = [Environment]::MachineName
        processor = $processorName
        processorUsagePercent = $processorUsage
        graphics = $graphicsName
        memoryTotalGb = $memoryTotalGb
        memoryUsedPercent = $memoryUsedPercent
        audio = $audioName
        sampledAt = [DateTimeOffset]::UtcNow.ToString("o")
    }
    $script:mediaHistoryHardwareLastSampleUtc = $nowUtc
    return $script:mediaHistoryHardwareSnapshot
}

function Get-MediaHistoryHardwareSummary {
    param($Hardware)
    if ($null -eq $Hardware) { return "硬件：等待采样" }
    $gpu = [string]$Hardware.graphics
    if ([string]::IsNullOrWhiteSpace($gpu)) { $gpu = "显卡待识别" }
    if ($gpu.Length -gt 24) { $gpu = $gpu.Substring(0, 23) + "…" }
    $cpu = "--"
    $memory = "--"
    try {
        if ($null -ne $Hardware.processorUsagePercent -and [int]$Hardware.processorUsagePercent -ge 0) {
            $cpu = [string]$Hardware.processorUsagePercent + "%"
        }
    } catch {}
    try {
        if ($null -ne $Hardware.memoryUsedPercent -and [int]$Hardware.memoryUsedPercent -ge 0) {
            $memory = [string]$Hardware.memoryUsedPercent + "%"
        }
    } catch {}
    return "硬件：" + $gpu + " · CPU " + $cpu + " · 内存 " + $memory
}

function Format-MediaHistoryTimestamp {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    try {
        return ([DateTimeOffset]::Parse($Value).ToLocalTime()).ToString("M月d日 HH:mm")
    } catch {
        return ""
    }
}

function Save-MediaHistory {
    if (!$script:mediaHistoryLoaded) { return }
    try {
        $entries = @($script:mediaHistory | Select-Object -First $script:mediaHistoryMaxEntries)
        $state = [ordered]@{
            version = 2
            updatedAt = [DateTimeOffset]::UtcNow.ToString("o")
            entries = $entries
        }
        Write-Utf8Json -Path $script:mediaHistoryPath -Value $state
        $script:mediaHistoryLastSaveUtc = [DateTime]::UtcNow
    } catch {
        Write-WidgetLog ("Media history save failed: " + $_.Exception.Message)
    }
}

function Add-MediaHistoryRowVisual {
    param(
        [Windows.Controls.Panel]$Panel,
        [int]$Index,
        $Entry
    )
    if ($null -eq $Panel -or $null -eq $Entry) { return }

    $row = New-Object Windows.Controls.Border
    $row.Name = "MediaHistoryLinkRow" + $Index
    $row.Height = 28
    $row.Padding = [Windows.Thickness]::new(4, 2, 4, 2)
    $row.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
    $row.Background = ConvertTo-Brush -Color $(if ($Index -eq 1) { "#16000000" } elseif ($Index -eq 2) { "#10000000" } else { "#0C000000" })
    $row.BorderBrush = ConvertTo-Brush -Color "#267F9AC8"
    $row.BorderThickness = [Windows.Thickness]::new(0, 0, 0, 1)
    $row.Cursor = [Windows.Input.Cursors]::Hand
    $row.Tag = $Entry

    $grid = New-Object Windows.Controls.Grid
    $firstRow = New-Object Windows.Controls.RowDefinition
    $firstRow.Height = [Windows.GridLength]::new(14)
    $secondRow = New-Object Windows.Controls.RowDefinition
    $secondRow.Height = [Windows.GridLength]::new(10)
    [void]$grid.RowDefinitions.Add($firstRow)
    [void]$grid.RowDefinitions.Add($secondRow)
    $titleColumn = New-Object Windows.Controls.ColumnDefinition
    $titleColumn.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $progressColumn = New-Object Windows.Controls.ColumnDefinition
    $progressColumn.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Auto)
    [void]$grid.ColumnDefinitions.Add($titleColumn)
    [void]$grid.ColumnDefinitions.Add($progressColumn)

    $type = if (![string]::IsNullOrWhiteSpace([string]$Entry.type)) { [string]$Entry.type } else { "媒体" }
    $titleText = New-Object Windows.Controls.TextBlock
    $titleText.Text = "[" + $type + "] " + [string]$Entry.title
    $titleText.Foreground = ConvertTo-Brush -Color "#E8FFFFFF"
    $titleText.FontSize = 7.5
    $titleText.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

    $progressText = New-Object Windows.Controls.TextBlock
    $progressText.Text = [string]$Entry.position + " / " + [string]$Entry.duration
    $progressText.Foreground = ConvertTo-Brush -Color "#C8D9E8FF"
    $progressText.FontSize = 7
    [Windows.Controls.Grid]::SetColumn($progressText, 1)

    $app = if (![string]::IsNullOrWhiteSpace([string]$Entry.app)) { [string]$Entry.app } else { "系统媒体" }
    $stamp = Format-MediaHistoryTimestamp -Value ([string]$Entry.lastSeenAt)
    $metaText = New-Object Windows.Controls.TextBlock
    $metaText.Text = $app + $(if ($stamp) { " · " + $stamp } else { "" })
    $metaText.Foreground = ConvertTo-Brush -Color "#78FFFFFF"
    $metaText.FontSize = 6
    $metaText.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetRow($metaText, 1)
    [Windows.Controls.Grid]::SetColumnSpan($metaText, 2)

    [void]$grid.Children.Add($titleText)
    [void]$grid.Children.Add($progressText)
    [void]$grid.Children.Add($metaText)
    $row.Child = $grid
    $linkKind = if (![string]::IsNullOrWhiteSpace([string]$Entry.linkKind)) { [string]$Entry.linkKind } else { "链接" }
    $row.ToolTip = [string]$Entry.title + "`n" + $app + "`n" + [string]$Entry.position + " / " + [string]$Entry.duration + "`n单击复制" + $linkKind
    $row.Add_MouseLeftButtonUp({
        param($sender, $eventArgs)
        if ($eventArgs.ChangedButton -eq [Windows.Input.MouseButton]::Left) {
            [void](Copy-MediaHistoryLink -Entry $sender.Tag)
            $eventArgs.Handled = $true
        }
    })
    [void]$Panel.Children.Add($row)
}

function Set-MediaHistoryRow {
    param([int]$Index, $Entry)
    $row = $script:window.FindName(("MediaHistoryRow{0}" -f $Index))
    $titleText = $script:window.FindName(("MediaHistoryRow{0}Title" -f $Index))
    $progressText = $script:window.FindName(("MediaHistoryRow{0}Progress" -f $Index))
    $metaText = $script:window.FindName(("MediaHistoryRow{0}Meta" -f $Index))
    if ($null -eq $row -or $null -eq $titleText -or $null -eq $progressText -or $null -eq $metaText) { return }
    if ($null -eq $Entry) {
        $row.Visibility = [Windows.Visibility]::Collapsed
        return
    }

    $row.Visibility = [Windows.Visibility]::Visible
    $type = if (![string]::IsNullOrWhiteSpace([string]$Entry.type)) { [string]$Entry.type } else { "媒体" }
    $titleText.Text = "[" + $type + "] " + [string]$Entry.title
    $progressText.Text = [string]$Entry.position + " / " + [string]$Entry.duration
    $app = if (![string]::IsNullOrWhiteSpace([string]$Entry.app)) { [string]$Entry.app } else { "系统媒体" }
    $stamp = Format-MediaHistoryTimestamp -Value ([string]$Entry.lastSeenAt)
    $metaText.Text = $app + $(if ($stamp) { " · " + $stamp } else { "" })
}

function Update-MediaHistoryWidget {
    if ($null -eq $script:window) { return }
    $entries = @($script:mediaHistory | Where-Object { Test-MediaHistoryEntryRecordable -Entry $_ })
    $current = $null
    if (![string]::IsNullOrWhiteSpace($script:mediaHistoryActiveKey)) {
        $current = @($entries | Where-Object { [string]$_.key -eq $script:mediaHistoryActiveKey } | Select-Object -First 1)
        if ($current.Count -gt 0) { $current = $current[0] } else { $current = $null }
    }
    $isLiveVideo = $script:mediaContentMode -eq "video" -and
        $script:mediaPlaybackStatus -in @("Playing", "Paused", "Changing") -and
        ![string]::IsNullOrWhiteSpace([string]$script:mediaCurrentTitle) -and
        [string]$script:mediaCurrentTitle -notin @("暂无播放内容", "音乐已关闭")
    $copyStatusActive = [DateTime]::UtcNow -lt $script:mediaHistoryCopyStatusUntilUtc
    $signature = $script:mediaHistoryActiveKey + "|" + $entries.Count + "|" + $isLiveVideo + "|" + $script:mediaPlaybackStatus + "|" + $script:mediaCurrentTitle + "|" + $copyStatusActive
    if ($null -ne $current) {
        $signature += "|" + [string]$current.position + "|" + [string]$current.status + "|" + [string]$current.lastSeenAt
    }

    $statusText = $script:window.FindName("MediaHistoryStatusText")
    $currentTitle = $script:window.FindName("MediaHistoryCurrentTitle")
    $currentMeta = $script:window.FindName("MediaHistoryCurrentMeta")
    $currentProgress = $script:window.FindName("MediaHistoryCurrentProgress")
    $hardwareText = $script:window.FindName("MediaHistoryHardwareText")
    if ($null -eq $statusText -or $null -eq $currentTitle -or $null -eq $currentMeta -or $null -eq $currentProgress) { return }

    if ($signature -ne $script:mediaHistoryLastDisplaySignature) {
        $script:mediaHistoryLastDisplaySignature = $signature
        if ($copyStatusActive) {
            $statusText.Text = $script:mediaHistoryCopyStatusText
            $statusText.Foreground = ConvertTo-Brush -Color "#D9F7CB"
        } elseif ($null -ne $current) {
            $statusText.Text = if ([string]$current.status -eq "Playing") { "正在记录" } elseif ([string]$current.status -eq "Paused") { "已暂停" } else { "已保存" }
            $statusText.Foreground = ConvertTo-Brush -Color "#A8D9F7CB"
        } elseif ($isLiveVideo) {
            $statusText.Text = "视频字幕"
            $statusText.Foreground = ConvertTo-Brush -Color "#A8D9F7CB"
            $currentTitle.Text = [string]$script:mediaCurrentTitle
            $currentMeta.Text = "视频不写入历史 · " + [string]$script:mediaSourceName
            $currentProgress.Text = (Format-MediaTime -Seconds ([double]$script:mediaElapsedSeconds)) + " / " + $(if ([double]$script:mediaDurationSeconds -gt 0) { Format-MediaTime -Seconds ([double]$script:mediaDurationSeconds) } else { "--" })
        } else {
            $statusText.Text = "实时监听"
            $statusText.Foreground = ConvertTo-Brush -Color "#A8D9F7CB"
            $currentTitle.Text = "等待电影或音乐"
            $currentMeta.Text = "视频只显示实时字幕，不写入历史"
            $currentProgress.Text = "-- / --"
        }

        if ($null -ne $current) {
            $currentTitle.Text = [string]$current.title
            $currentMeta.Text = ([string]$current.type) + " · " + ([string]$current.app)
            $currentProgress.Text = [string]$current.position + " / " + [string]$current.duration
        }
    }

    $rowsPanel = $script:window.FindName("MediaHistoryRowsPanel")
    if ($null -ne $rowsPanel) {
        $rowEntries = @($entries | Select-Object -First $script:mediaHistoryMaxEntries)
        $rowsSignature = (@($rowEntries | ForEach-Object { [string]$_.key + "|" + [string]$_.status + "|" + [string]$_.link }) -join ";")
        $rowsRefreshDue = ([DateTime]::UtcNow - $script:mediaHistoryLastRowsRefreshUtc).TotalSeconds -ge 10
        if ($rowsSignature -ne $script:mediaHistoryLastRowsSignature -or $rowsRefreshDue) {
            $rowsPanel.Children.Clear()
            if ($rowEntries.Count -eq 0) {
                $emptyText = New-Object Windows.Controls.TextBlock
                $emptyText.Text = "暂无历史记录"
                $emptyText.Foreground = ConvertTo-Brush -Color "#A8FFFFFF"
                $emptyText.FontSize = 7.5
                $emptyText.Margin = [Windows.Thickness]::new(4, 4, 4, 4)
                [void]$rowsPanel.Children.Add($emptyText)
            } else {
                $rowIndex = 0
                foreach ($rowEntry in $rowEntries) {
                    $rowIndex++
                    Add-MediaHistoryRowVisual -Panel $rowsPanel -Index $rowIndex -Entry $rowEntry
                }
            }
            $script:mediaHistoryLastRowsSignature = $rowsSignature
            $script:mediaHistoryLastRowsRefreshUtc = [DateTime]::UtcNow
        }
    } else {
        # Compatibility fallback for an older XAML file kept in a user backup.
        $rows = @($entries | Select-Object -First 3)
        for ($index = 1; $index -le 3; $index++) {
            $entry = if ($rows.Count -ge $index) { $rows[$index - 1] } else { $null }
            Set-MediaHistoryRow -Index $index -Entry $entry
        }
    }

    if ($null -ne $hardwareText) {
        $hardware = if ($null -ne $current) { $current.hardware } elseif ($entries.Count -gt 0) { $entries[0].hardware } else { $script:mediaHistoryHardwareSnapshot }
        $hardwareText.Text = Get-MediaHistoryHardwareSummary -Hardware $hardware
        if ($null -ne $hardware) {
            $hardwareText.ToolTip = "处理器：" + [string]$hardware.processor + "`n显卡：" + [string]$hardware.graphics + "`n内存：" + [string]$hardware.memoryTotalGb + " GB，已用 " + [string]$hardware.memoryUsedPercent + "%`n音频：" + [string]$hardware.audio
        }
    }
}

function Initialize-MediaHistory {
    $script:mediaHistory = @()
    $state = Read-Utf8Json -Path $script:mediaHistoryPath
    $historyChanged = $false
    if ($null -ne $state -and $null -ne $state.entries) {
        $validEntries = New-Object System.Collections.Generic.List[object]
        foreach ($entry in @($state.entries)) {
            if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.title)) { continue }
            if ([string]::IsNullOrWhiteSpace([string]$entry.key)) {
                $entry.key = ([string]$entry.sourceId + "|" + [string]$entry.type + "|" + [string]$entry.title + "|" + [string]$entry.artist).ToLowerInvariant()
                $historyChanged = $true
            }
            if ([string]$entry.type -eq "电影/视频") {
                $durationSeconds = 0.0
                try { $durationSeconds = [double]$entry.durationSeconds } catch {}
                $entry.type = if (Test-MovieMediaContext -Title ([string]$entry.title) -SourceId ([string]$entry.sourceId) -App ([string]$entry.app) -DurationSeconds $durationSeconds) { "电影" } else { "视频" }
                $historyChanged = $true
            }
            if ([string]$entry.type -eq "电影" -and !(Test-MovieMediaContext -Title ([string]$entry.title) -SourceId ([string]$entry.sourceId) -App ([string]$entry.app) -DurationSeconds ([double]$entry.durationSeconds))) {
                $entry.type = "视频"
                $historyChanged = $true
            }
            if (Test-MediaHistoryEntryRecordable -Entry $entry) {
                $oldLink = if ($null -ne $entry.PSObject.Properties["link"]) { [string]$entry.link } else { "" }
                $oldLinkKind = if ($null -ne $entry.PSObject.Properties["linkKind"]) { [string]$entry.linkKind } else { "" }
                $info = Set-MediaHistoryEntryLink -Entry $entry
                if ($oldLink -ne [string]$info.Url -or $oldLinkKind -ne [string]$info.Kind) { $historyChanged = $true }
            }
            [void]$validEntries.Add($entry)
            if ($validEntries.Count -ge $script:mediaHistoryMaxEntries) { break }
        }
        $script:mediaHistory = @($validEntries.ToArray())
    }
    $script:mediaHistoryLoaded = $true
    if (!(Test-Path -LiteralPath $script:mediaHistoryPath) -or $historyChanged) { Save-MediaHistory }
    Update-MediaHistoryWidget
}

function Close-MediaHistoryActiveEntry {
    $activeKey = [string]$script:mediaHistoryActiveKey
    if ([string]::IsNullOrWhiteSpace($activeKey)) { return $false }

    $active = @($script:mediaHistory | Where-Object { [string]$_.key -eq $activeKey } | Select-Object -First 1)
    if ($active.Count -gt 0) {
        $active = $active[0]
        if ($null -eq $active.PSObject.Properties["endedAt"]) {
            $active | Add-Member -MemberType NoteProperty -Name endedAt -Value $null
        }
        if ([string]$active.status -ne "Stopped") {
            $active.status = "Stopped"
            $active.endedAt = [DateTimeOffset]::UtcNow.ToString("o")
        }
    }
    $script:mediaHistoryActiveKey = ""
    return $true
}

function Update-MediaHistory {
    if (!$script:mediaHistoryLoaded) { return }

    $title = [string]$script:mediaCurrentTitle
    $sourceId = [string]$script:mediaSourceId
    $status = [string]$script:mediaPlaybackStatus
    if ([string]::IsNullOrWhiteSpace($title) -or $title -in @("暂无播放内容", "音乐已关闭") -or ($status -eq "Idle" -and [string]::IsNullOrWhiteSpace($sourceId))) {
        if (![string]::IsNullOrWhiteSpace($script:mediaHistoryActiveKey)) {
            [void](Close-MediaHistoryActiveEntry)
            Save-MediaHistory
            Update-MediaHistoryWidget
        }
        return
    }

    $artist = [string]$script:mediaCurrentArtist
    $app = [string]$script:mediaSourceName
    if ([string]::IsNullOrWhiteSpace($app)) { $app = Get-MediaSourceDisplayName -SourceId $sourceId }
    if ([string]::IsNullOrWhiteSpace($app)) { $app = "系统媒体" }
    $type = Get-MediaHistoryRecordType -ContentMode ([string]$script:mediaContentMode) -Title $title -SourceId $sourceId -App $app -DurationSeconds ([double]$script:mediaDurationSeconds)
    if ([string]::IsNullOrWhiteSpace($type)) {
        if (![string]::IsNullOrWhiteSpace($script:mediaHistoryActiveKey)) {
            [void](Close-MediaHistoryActiveEntry)
            Save-MediaHistory
        }
        Update-MediaHistoryWidget
        return
    }
    $key = ($sourceId + "|" + $type + "|" + $title + "|" + $artist).ToLowerInvariant()
    $historyClosed = $false
    if (![string]::IsNullOrWhiteSpace($script:mediaHistoryActiveKey) -and $script:mediaHistoryActiveKey -ne $key) {
        $historyClosed = Close-MediaHistoryActiveEntry
    }
    $entry = @($script:mediaHistory | Where-Object { [string]$_.key -eq $key } | Select-Object -First 1)
    if ($entry.Count -gt 0) { $entry = $entry[0] } else { $entry = $null }
    $wasNew = $false
    $previousStatus = ""
    $nowText = [DateTimeOffset]::UtcNow.ToString("o")
    if ($null -eq $entry) {
        $entry = [pscustomobject]@{
            key = $key
            title = $title
            artist = $artist
            type = $type
            app = $app
            sourceId = $sourceId
            startedAt = $nowText
            lastSeenAt = $nowText
            status = $status
            playCount = if ($status -eq "Playing") { 1 } else { 0 }
            lastStartedAt = if ($status -eq "Playing") { $nowText } else { $null }
            positionSeconds = 0.0
            durationSeconds = 0.0
            position = "0:00"
            duration = "--"
            hardware = $null
            link = ""
            linkKind = ""
        }
        $script:mediaHistory = @($entry) + @($script:mediaHistory)
        $wasNew = $true
    } else {
        $previousStatus = [string]$entry.status
        if ($null -eq $entry.PSObject.Properties["playCount"]) {
            $entry | Add-Member -MemberType NoteProperty -Name playCount -Value 0
        }
        if ($null -eq $entry.PSObject.Properties["lastStartedAt"]) {
            $entry | Add-Member -MemberType NoteProperty -Name lastStartedAt -Value $null
        }
        if ($status -eq "Playing" -and $previousStatus -ne "Playing") {
            $entry.playCount = [int]$(if ($null -ne $entry.playCount) { $entry.playCount } else { 0 }) + 1
            $entry.lastStartedAt = $nowText
        }
    }

    $hardware = Get-MediaHistoryHardwareSnapshot
    $entry.title = $title
    $entry.artist = $artist
    $entry.type = $type
    $entry.app = $app
    $entry.sourceId = $sourceId
    $entry.status = $status
    $entry.lastSeenAt = [DateTimeOffset]::UtcNow.ToString("o")
    $entry.positionSeconds = [Math]::Round([double]$script:mediaElapsedSeconds, 1)
    $entry.durationSeconds = [Math]::Round([double]$script:mediaDurationSeconds, 1)
    $entry.position = Format-MediaTime -Seconds $entry.positionSeconds
    $entry.duration = if ($entry.durationSeconds -gt 0) { Format-MediaTime -Seconds $entry.durationSeconds } else { "--" }
    [void](Set-MediaHistoryEntryLink -Entry $entry)
    $entry.hardware = $hardware
    $script:mediaHistoryActiveKey = $key

    if ($script:mediaHistory.Count -gt $script:mediaHistoryMaxEntries) {
        $script:mediaHistory = @($script:mediaHistory | Select-Object -First $script:mediaHistoryMaxEntries)
    }
    $saveDue = ([DateTime]::UtcNow - $script:mediaHistoryLastSaveUtc).TotalSeconds -ge 15
    if ($wasNew -or $historyClosed -or $previousStatus -ne $status -or $saveDue) { Save-MediaHistory }
    Update-MediaHistoryWidget
}

function Set-MediaSubtitleLines {
    param(
        [string]$Chinese,
        [string]$English
    )

    $chineseLine = ConvertTo-SimplifiedChinese -Text ([string]$Chinese)
    $englishLine = [string]$English
    if ([string]::IsNullOrWhiteSpace($chineseLine)) { $chineseLine = "正在等待电影对白" }
    if ([string]::IsNullOrWhiteSpace($englishLine)) { $englishLine = "Waiting for dialogue" }
    $script:window.FindName("MediaTrackText").Text = $chineseLine.Trim()
    $script:window.FindName("MediaArtistText").Text = $englishLine.Trim()
}

function Show-LastMediaSubtitle {
    if ([string]::IsNullOrWhiteSpace($script:subtitleLastChinese) -and
        [string]::IsNullOrWhiteSpace($script:subtitleLastOriginal)) {
        return $false
    }
    Set-MediaSubtitleLines -Chinese $script:subtitleLastChinese -English $script:subtitleLastOriginal
    return $true
}

function Get-MediaSubtitleLanguageLabel {
    param([string]$LanguageCode)
    if ($script:subtitleLanguageLabels.Contains($LanguageCode)) {
        return [string]$script:subtitleLanguageLabels[$LanguageCode]
    }
    return "自动"
}

function Set-MediaSubtitleLanguage {
    param([string]$LanguageCode)

    if ([string]::IsNullOrWhiteSpace($LanguageCode) -or !$script:subtitleLanguageLabels.Contains($LanguageCode)) {
        $LanguageCode = "auto"
    }
    $script:subtitleLanguage = $LanguageCode
    try {
        [IO.File]::WriteAllText($script:subtitleLanguagePath, $LanguageCode, $script:utf8)
    } catch {
        Write-WidgetLog ("Subtitle language preference could not be saved: " + $_.Exception.Message)
    }

    $label = Get-MediaSubtitleLanguageLabel -LanguageCode $LanguageCode
    $button = $script:window.FindName("MediaLanguageButton")
    if ($null -ne $button) {
        $button.Content = $label
        $button.ToolTip = "视频 / 电影 / 音乐原声：" + $label + "；输出：原文 + 简体中文"
        if ($null -ne $button.ContextMenu) {
            foreach ($item in $button.ContextMenu.Items) {
                if ($item -is [Windows.Controls.MenuItem]) {
                    $item.IsChecked = ([string]$item.Tag -eq $LanguageCode)
                }
            }
        }
    }

    if ($null -ne $script:subtitleProcess) {
        try {
            if (!$script:subtitleProcess.HasExited) {
                [void](Send-MediaSubtitleCommand -Command "set_language" -Language $LanguageCode)
            }
        } catch {}
    }
    Set-MediaSubtitleStatus -Text ("原声语言：" + $label + " → 简体中文") -Color "#FFB9C7FF"
    Write-WidgetLog ("Subtitle language changed to " + $LanguageCode + ".")
}

function Initialize-MediaSubtitleLanguage {
    if (Test-Path -LiteralPath $script:subtitleLanguagePath) {
        try {
            $savedLanguage = [IO.File]::ReadAllText($script:subtitleLanguagePath, $script:utf8).Trim().ToLowerInvariant()
            if ($script:subtitleLanguageLabels.Contains($savedLanguage)) {
                $script:subtitleLanguage = $savedLanguage
            }
        } catch {
            Write-WidgetLog ("Subtitle language preference could not be loaded: " + $_.Exception.Message)
        }
    }

    $button = $script:window.FindName("MediaLanguageButton")
    if ($null -eq $button) { return }
    $menu = [Windows.Controls.ContextMenu]::new()
    foreach ($languageCode in $script:subtitleLanguageLabels.Keys) {
        $item = [Windows.Controls.MenuItem]::new()
        $languageLabel = [string]$script:subtitleLanguageLabels[$languageCode]
        $item.Header = if ([string]$languageCode -eq "auto") { "自动识别（推荐）" } else { "原声：" + $languageLabel }
        $item.Tag = [string]$languageCode
        $item.IsCheckable = $true
        $item.Add_Click({
            param($sender, $eventArgs)
            Set-MediaSubtitleLanguage -LanguageCode ([string]$sender.Tag)
            $eventArgs.Handled = $true
        })
        [void]$menu.Items.Add($item)
    }
    $button.ContextMenu = $menu
    $button.Add_Click({
        param($sender, $eventArgs)
        $sender.ContextMenu.PlacementTarget = $sender
        $sender.ContextMenu.IsOpen = $true
        $eventArgs.Handled = $true
    })
    Set-MediaSubtitleLanguage -LanguageCode $script:subtitleLanguage
}

function Set-MediaSubtitleStatus {
    param(
        [string]$Text,
        [string]$Color = "#FFB9C7FF"
    )

    $script:subtitleStatusText = $Text
    $script:subtitleStatusColor = $Color
    $script:window.FindName("MediaOutputText").Text = $Text
    $script:window.FindName("MediaOutputDot").Fill = ConvertTo-Brush -Color $Color
}

function Set-MediaIdentity {
    param(
        [string]$Title,
        [string]$Artist
    )

    $safeTitle = if ([string]::IsNullOrWhiteSpace($Title)) { $script:pinnedMediaTitle } else { $Title.Trim() }
    $safeArtist = if ([string]::IsNullOrWhiteSpace($Artist)) { $script:pinnedMediaArtist } else { $Artist.Trim() }
    $identity = $safeTitle + " · " + $safeArtist
    $identityText = $script:window.FindName("MediaIdentityText")
    if ($null -ne $identityText) {
        $identityText.Text = $identity
        $identityText.ToolTip = $identity
    }
}

function Show-PinnedMedia {
    if ($script:pinnedMediaAutoplayDisabled) {
        Set-MediaIdentity -Title "音乐已关闭" -Artist "Music playback disabled"
        Set-MediaSubtitleLines -Chinese "音乐已关闭" -English "Music playback disabled"
        $script:window.FindName("MediaAppText").Text = "桌面音乐"
        $script:window.FindName("MediaStateText").Text = "已关闭"
        $script:window.FindName("MediaPlayPauseButton").Content = [char]0xE768
        $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color "#78FFFFFF"
        return
    }
    Set-MediaIdentity -Title $script:pinnedMediaTitle -Artist $script:pinnedMediaArtist
    Set-MediaSubtitleLines -Chinese $script:pinnedMediaTitle -English $script:pinnedMediaArtist
    $script:window.FindName("MediaAppText").Text = "桌面收藏"
    $script:window.FindName("MediaStateText").Text = "开机显示"
}

function Reset-MediaDisplay {
    $playerState = Get-PinnedPlayerState
    $script:mediaSession = $null
    $script:mediaTimeline = $null
    $script:mediaCurrentTitle = ""
    $script:mediaCurrentArtist = ""
    $script:mediaSourceName = ""
    $script:mediaSourceId = ""

    if ($null -ne $playerState) {
        $script:mediaPlaybackStatus = $playerState.Status
        $script:pinnedMediaElapsed = $playerState.PositionSeconds
        $script:pinnedMediaDuration = $playerState.DurationSeconds
        $script:pinnedMediaUpdatedUtc = $playerState.UpdatedUtc
        if ($playerState.Status -eq "Disabled" -and $script:pinnedMediaAutoplayDisabled) {
            Show-PinnedMedia
            Update-MediaProgress
            return
        }
        Set-MediaIdentity -Title $playerState.Title -Artist $playerState.Artist
        $lyricsTitle = if ($playerState.Source -eq "Official SoundCloud") { "Still With You" } else { $playerState.Title }
        $lyricsArtist = if ($playerState.Source -eq "Official SoundCloud") { "Jung Kook" } else { $playerState.Artist }
        Request-SyncedLyrics -Title $lyricsTitle -Artist $lyricsArtist -DurationSeconds $playerState.DurationSeconds
        if (!$script:subtitleHasCaption) { Show-PinnedMedia }
        $script:window.FindName("MediaAppText").Text = if ($playerState.Source -eq "Local Music") { "本地音乐" } else { "SoundCloud 官方" }
        $script:window.FindName("MediaStateText").Text = if ($playerState.Status -eq "Playing") { "正在播放" } else { "正在连接" }
        $script:window.FindName("MediaPlayPauseButton").Content = if ($playerState.Status -eq "Playing") { [char]0xE769 } else { [char]0xE768 }
        $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color $(if ($playerState.Status -eq "Playing") { "#FFA7F3D0" } else { "#FFFFD38A" })
        Update-MediaProgress
        return
    }

    $script:mediaPlaybackStatus = "Idle"
    $script:pinnedMediaElapsed = 0.0
    $script:pinnedMediaDuration = 0.0
    $script:pinnedMediaUpdatedUtc = [DateTime]::MinValue
    Set-MediaIdentity -Title $script:pinnedMediaTitle -Artist $script:pinnedMediaArtist
    if (!$script:subtitleHasCaption) {
        if ($script:subtitleRequested) {
            Set-MediaSubtitleLines -Chinese "正在准备中文字幕" -English "Preparing English subtitles"
        } else {
            Show-PinnedMedia
        }
    }
    if ($script:subtitleRequested) {
        $script:window.FindName("MediaAppText").Text = "系统音频"
        $script:window.FindName("MediaStateText").Text = "中英字幕"
    }
    $script:window.FindName("MediaPlayPauseButton").Content = [char]0xE768
    $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color "#78FFFFFF"
    Update-MediaProgress
}

function Update-MediaCore {
    try {
        $pinnedState = Get-PinnedPlayerState
        $snapshot = Get-MediaSessionSnapshot
        $foregroundContext = Get-ForegroundMediaContext
        $peak = [double][MacWidgetNative]::GetAudioPeak()
        $nowUtc = [DateTime]::UtcNow
        $externalSnapshot = $null -ne $snapshot -and !(Test-PinnedMediaSnapshot -Snapshot $snapshot)
        $externalPlaying = $externalSnapshot -and $snapshot.Status -eq "Playing"

        if ($externalPlaying -and $null -ne $pinnedState -and $pinnedState.Status -eq "Playing" -and !$script:pinnedPausedForExternalMedia) {
            if (Send-PinnedPlayerCommand -Command "pause") {
                $script:pinnedPausedForExternalMedia = $true
                Write-WidgetLog "Pinned music paused while external video or media is playing."
            }
        }

        if (!$externalPlaying -and $null -ne $pinnedState -and $pinnedState.Status -eq "Playing" -and
            $null -ne $foregroundContext -and [bool]$foregroundContext.LikelyMedia -and !$script:pinnedPausedForExternalMedia) {
            if (Send-PinnedPlayerCommand -Command "pause") {
                $script:pinnedPausedForExternalMedia = $true
                $script:mediaFallbackActiveUntilUtc = $nowUtc.AddSeconds(6)
                Write-WidgetLog "Pinned music paused for foreground movie playback without a Windows media session."
            }
        }

        $fallbackContextIsMedia = Test-FallbackMediaContext -Context $foregroundContext
        if (!$fallbackContextIsMedia -and !$externalSnapshot) {
            $script:mediaFallbackActiveUntilUtc = [DateTime]::MinValue
        }
        $fallbackAudio = $fallbackContextIsMedia -and $peak -gt 0.006 -and ($null -eq $pinnedState -or $pinnedState.Status -ne "Playing")
        if ($fallbackAudio) { $script:mediaFallbackActiveUntilUtc = $nowUtc.AddSeconds(6) }
        $fallbackActive = !$externalSnapshot -and $fallbackContextIsMedia -and $nowUtc -lt $script:mediaFallbackActiveUntilUtc

        if ($externalSnapshot -or $fallbackActive) {
            $script:mediaSession = if ($externalSnapshot) { $snapshot.Session } else { $null }
            $script:mediaTimeline = if ($externalSnapshot) { $snapshot.Timeline } else { $null }
            $script:mediaPlaybackStatus = if ($externalSnapshot) { $snapshot.Status } else { "Playing" }
            $script:pinnedMediaElapsed = 0.0
            $script:pinnedMediaDuration = 0.0
            $script:pinnedMediaUpdatedUtc = [DateTime]::MinValue

            if ($externalSnapshot) {
                $title = if (![string]::IsNullOrWhiteSpace($snapshot.Title)) { $snapshot.Title } elseif ($null -ne $foregroundContext) { [string]$foregroundContext.Title } else { "正在播放的视频" }
                $artist = if (![string]::IsNullOrWhiteSpace($snapshot.Artist)) {
                    $snapshot.Artist
                } elseif (![string]::IsNullOrWhiteSpace($snapshot.Album)) {
                    $snapshot.Album
                } else {
                    "实时双语字幕"
                }
                $sourceId = [string]$snapshot.SourceId
                $sourceName = Get-MediaSourceDisplayName -SourceId $sourceId
                $isMusic = Test-MusicMediaSnapshot -Snapshot $snapshot
                $script:mediaSourceName = $sourceName
            } else {
                $title = if ($null -ne $foregroundContext -and ![string]::IsNullOrWhiteSpace([string]$foregroundContext.Title)) { [string]$foregroundContext.Title } else { "系统视频与电影声音" }
                $artist = "实时双语字幕"
                $sourceId = if ($null -ne $foregroundContext) { [string]$foregroundContext.ProcessName } else { "SystemAudio" }
                $sourceName = if ($null -ne $foregroundContext) { [string]$foregroundContext.DisplayName } else { "系统音频" }
                $isMusic = $false
                $script:mediaSourceName = $sourceName
            }

            $script:mediaCurrentTitle = $title
            $script:mediaCurrentArtist = $artist
            $script:mediaSourceId = $sourceId
            $script:mediaContentMode = if ($isMusic) { "music" } else { "video" }
            $mediaIdentity = $sourceId + "|" + $title + "|" + $artist
            if (![string]::IsNullOrWhiteSpace($script:subtitleMediaIdentity) -and $mediaIdentity -ne $script:subtitleMediaIdentity) {
                $script:subtitleHasCaption = $false
                $script:subtitleLastChinese = ""
                $script:subtitleLastOriginal = ""
            }
            $script:subtitleMediaIdentity = $mediaIdentity

            if ($script:mediaContentMode -eq "music") {
                $timelineDuration = 0.0
                if ($null -ne $script:mediaTimeline) {
                    try { $timelineDuration = [double]($script:mediaTimeline.EndTime - $script:mediaTimeline.StartTime).TotalSeconds } catch {}
                }
                Request-SyncedLyrics -Title $title -Artist $artist -DurationSeconds $timelineDuration
                Set-MediaIdentity -Title $title -Artist $artist
                if (!$script:subtitleHasCaption) { Set-MediaSubtitleLines -Chinese $title -English $artist }
            } else {
                Disable-SyncedLyricsForLiveMedia
                Set-MediaIdentity -Title $title -Artist "视频 / 电影实时字幕"
                if (!$script:subtitleHasCaption) {
                    Set-MediaSubtitleLines -Chinese "正在等待电影对白" -English "Waiting for original-language dialogue"
                }
            }

            $stateText = switch ($script:mediaPlaybackStatus) {
                "Playing" { if ($script:mediaContentMode -eq "video") { "视频字幕" } else { "正在播放" } }
                "Paused" { "已暂停" }
                "Changing" { "正在切换" }
                default { "已停止" }
            }
            $stateColor = switch ($script:mediaPlaybackStatus) {
                "Playing" { "#FFA7F3D0" }
                "Paused" { "#FFFFD38A" }
                default { "#78FFFFFF" }
            }
            $script:window.FindName("MediaAppText").Text = $sourceName
            $script:window.FindName("MediaStateText").Text = if ($script:subtitleRequested) { "实时字幕" } else { $stateText }
            $script:window.FindName("MediaPlayPauseButton").Content = if ($script:mediaPlaybackStatus -eq "Playing") { [char]0xE769 } else { [char]0xE768 }
            $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color $stateColor
            Update-MediaProgress
            return
        }

        $usePinnedState = $null -ne $pinnedState -and
            $pinnedState.Source -eq "Official SoundCloud" -and
            ($pinnedState.Status -eq "Playing" -or $null -eq $snapshot -or $snapshot.Status -ne "Playing")
        if ($usePinnedState) {
            $script:mediaSession = $null
            $script:mediaTimeline = $null
            $script:mediaPlaybackStatus = $pinnedState.Status
            $script:mediaCurrentTitle = $script:pinnedMediaTitle
            $script:mediaCurrentArtist = $script:pinnedMediaArtist
            $script:mediaSourceName = "SoundCloud 官方"
            $script:mediaSourceId = "Official SoundCloud"
            $script:mediaContentMode = "music"
            $script:pinnedMediaElapsed = $pinnedState.PositionSeconds
            $script:pinnedMediaDuration = $pinnedState.DurationSeconds
            $script:pinnedMediaUpdatedUtc = $pinnedState.UpdatedUtc
            Request-SyncedLyrics -Title "Still With You" -Artist "Jung Kook" -DurationSeconds $pinnedState.DurationSeconds
            if (!$script:subtitleHasCaption) { Show-PinnedMedia }
            $script:window.FindName("MediaAppText").Text = "SoundCloud 官方"
            $script:window.FindName("MediaStateText").Text = if ($pinnedState.Status -eq "Playing") { "正在播放" } else { "已暂停" }
            $script:window.FindName("MediaPlayPauseButton").Content = if ($pinnedState.Status -eq "Playing") { [char]0xE769 } else { [char]0xE768 }
            $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color $(if ($pinnedState.Status -eq "Playing") { "#FFA7F3D0" } else { "#FFFFD38A" })
            Update-MediaProgress
            return
        }
        if ($null -eq $snapshot) {
            $script:mediaContentMode = "music"
            $script:mediaSourceName = ""
            $script:mediaSourceId = ""
            Reset-MediaDisplay
            return
        }

        $script:mediaSession = $snapshot.Session
        $script:mediaPlaybackStatus = $snapshot.Status
        $script:mediaTimeline = $snapshot.Timeline
        $script:pinnedMediaElapsed = 0.0
        $script:pinnedMediaDuration = 0.0
        $script:mediaContentMode = "music"
        $script:mediaSourceName = Get-MediaSourceDisplayName -SourceId $snapshot.SourceId
        $script:mediaSourceId = [string]$snapshot.SourceId

        $title = if (![string]::IsNullOrWhiteSpace($snapshot.Title)) { $snapshot.Title } else { "未命名媒体" }
        $artist = if (![string]::IsNullOrWhiteSpace($snapshot.Artist)) {
            $snapshot.Artist
        } elseif (![string]::IsNullOrWhiteSpace($snapshot.Album)) {
            $snapshot.Album
        } else {
            "未提供歌手信息"
        }
        $script:mediaCurrentTitle = $title
        $script:mediaCurrentArtist = $artist
        Set-MediaIdentity -Title $title -Artist $artist
        $timelineDuration = 0.0
        if ($null -ne $snapshot.Timeline) {
            try { $timelineDuration = [double]($snapshot.Timeline.EndTime - $snapshot.Timeline.StartTime).TotalSeconds } catch {}
        }
        Request-SyncedLyrics -Title $title -Artist $artist -DurationSeconds $timelineDuration
        $mediaIdentity = ([string]$snapshot.SourceId) + "|" + $title + "|" + $artist
        if (![string]::IsNullOrWhiteSpace($script:subtitleMediaIdentity) -and $mediaIdentity -ne $script:subtitleMediaIdentity) {
            $script:subtitleHasCaption = $false
            $script:subtitleLastChinese = ""
            $script:subtitleLastOriginal = ""
        }
        $script:subtitleMediaIdentity = $mediaIdentity

        $stateText = switch ($snapshot.Status) {
            "Playing" { "正在播放" }
            "Paused" { "已暂停" }
            "Changing" { "正在切换" }
            default { "已停止" }
        }
        $stateColor = switch ($snapshot.Status) {
            "Playing" { "#FFA7F3D0" }
            "Paused" { "#FFFFD38A" }
            default { "#78FFFFFF" }
        }

        if (!$script:subtitleHasCaption) { Set-MediaSubtitleLines -Chinese $title -English $artist }
        $script:window.FindName("MediaAppText").Text = $script:mediaSourceName
        $script:window.FindName("MediaStateText").Text = if ($script:subtitleRequested) { "双语字幕" } else { $stateText }
        $script:window.FindName("MediaPlayPauseButton").Content = if ($snapshot.Status -eq "Playing") { [char]0xE769 } else { [char]0xE768 }
        $script:window.FindName("MediaStatusDot").Fill = ConvertTo-Brush -Color $stateColor
        Update-MediaProgress
    } catch {
        $script:mediaManager = $null
        Reset-MediaDisplay
        Write-WidgetLog ("Media update failed: " + $_.Exception.Message)
    }
}

function Update-Media {
    try { Update-MediaCore } finally {
        try { Update-MediaHistory } catch { Write-WidgetLog ("Media history update failed: " + $_.Exception.Message) }
    }
}

function Set-MediaSubtitleOverlayVisibility {
    param([bool]$HasAudio)

    $mediaWindow = $script:widgetWindows["MediaCard"]
    if ($null -eq $mediaWindow) { return }
    # MediaCard is a desktop-only surface; subtitle processing can continue in the background.
    if ($script:mediaOverlayActive) {
        $mediaWindow.Topmost = $false
        $script:mediaOverlayActive = $false
    }
    if ($script:widgetsAutoHidden) {
        if ($mediaWindow.IsVisible) { $mediaWindow.Hide() }
        return
    }
    if ($null -ne $mediaWindow.Tag -and $mediaWindow.Topmost) {
        $mediaWindow.Topmost = $false
        try { [MacWidgetNative]::ConfigureDesktopWidgetWindow([IntPtr]$mediaWindow.Tag.Handle) } catch {}
    }
}

function Set-MediaVisualizerCadence {
    param([bool]$Active)

    if ($null -eq $script:mediaVisualizerTimer -or !$script:mediaVisualizerStarted) { return }
    $targetMilliseconds = if ($Active) { $script:mediaVisualizerFastIntervalMs } else { $script:mediaVisualizerIdleIntervalMs }
    if ([Math]::Abs($script:mediaVisualizerTimer.Interval.TotalMilliseconds - $targetMilliseconds) -gt 1) {
        $script:mediaVisualizerTimer.Interval = [TimeSpan]::FromMilliseconds($targetMilliseconds)
        Write-WidgetLog ("Media visualizer cadence changed to " + $targetMilliseconds + "ms.")
    }
}

function Start-DeferredMediaVisualizer {
    if ($null -eq $script:mediaVisualizerTimer -or $script:mediaVisualizerStarted) { return }
    if ($null -eq $script:mediaVisualizerStartTimer) {
        $script:mediaVisualizerStartTimer = [Windows.Threading.DispatcherTimer]::new()
        $script:mediaVisualizerStartTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
        $script:mediaVisualizerStartTimer.Add_Tick({
            $script:mediaVisualizerStartTimer.Stop()
            if ($script:mediaVisualizerStarted -or $null -eq $script:mediaVisualizerTimer) { return }
            $script:mediaVisualizerTimer.Interval = [TimeSpan]::FromMilliseconds($script:mediaVisualizerIdleIntervalMs)
            $script:mediaVisualizerStarted = $true
            $script:mediaVisualizerTimer.Start()
            Write-WidgetLog "Media visualizer started in idle cadence after desktop UI settled."
        })
    }
    $script:mediaVisualizerStartTimer.Stop()
    $script:mediaVisualizerStartTimer.Start()
}

function Update-MediaVisualizer {
    $script:mediaVisualizerPhase += 0.34
    $peak = [double][MacWidgetNative]::GetAudioPeak()
    $hasAudio = $peak -gt 0.006
    $isPlaying = $script:mediaPlaybackStatus -eq "Playing" -or ($script:mediaContentMode -eq "video" -and $hasAudio)
    Set-MediaVisualizerCadence -Active ($isPlaying -or $hasAudio -or $script:subtitleRequested -or $script:speechListening)
    Set-MediaPlayingVisualState -IsPlaying $isPlaying
    if ($hasAudio) {
        $script:subtitleAudioTicks++
        $script:subtitleSilenceTicks = 0
    } else {
        $script:subtitleAudioTicks = 0
        $script:subtitleSilenceTicks++
    }

    $usingTimedLyrics = $script:mediaContentMode -eq "music" -and $script:syncedLyricsActive
    if ($usingTimedLyrics) {
        $script:subtitleAudioTicks = 0
        if ($script:subtitleRequested) { Stop-MediaSubtitles }
    } else {
        if (!$script:subtitleRequested -and !$script:speechListening -and [DateTime]::UtcNow -ge $script:subtitleRetryAfterUtc -and $script:subtitleAudioTicks -ge 8) {
            Start-MediaSubtitles -ContentMode $script:mediaContentMode
            $script:subtitleAudioTicks = 0
        } elseif ($script:subtitleRequested) {
            if ($script:mediaContentMode -eq "video") {
                $silentLimit = if ($isPlaying) { 240 } else { 80 }
            } else {
                $silentLimit = if ($isPlaying) { 1200 } else { 450 }
            }
            if ($script:subtitleSilenceTicks -ge $silentLimit) {
                Stop-MediaSubtitles
                $script:subtitleSilenceTicks = 0
            }
        }
    }

    # Keep audio/subtitle detection alive while desktop widgets are hidden, but skip
    # the 18-bar visual redraw and other presentation work until the card is visible.
    $mediaWindow = $script:widgetWindows["MediaCard"]
    $visualsSuppressed = $script:widgetsAutoHidden
    if (!$visualsSuppressed -and $null -ne $mediaWindow) { $visualsSuppressed = !$mediaWindow.IsVisible }
    if ($visualsSuppressed) {
        Update-MediaProgress
        Set-MediaSubtitleOverlayVisibility -HasAudio $hasAudio
        return
    }
    $visualizerScale = Get-ModeDeckVisualizerScale
    $energy = if ($hasAudio) {
        [Math]::Min(1.0, (0.12 + ($peak * 2.7)) * $visualizerScale)
    } elseif ($isPlaying) {
        [Math]::Min(1.0, (0.12 + (0.03 * ([Math]::Sin($script:mediaVisualizerPhase) + 1.0))) * $visualizerScale)
    } else {
        0.0
    }

    for ($index = 0; $index -lt $script:mediaVisualizerBars.Count; $index++) {
        $bar = $script:mediaVisualizerBars[$index]
        $waveA = [Math]::Abs([Math]::Sin($script:mediaVisualizerPhase + ($index * 0.54)))
        $waveB = [Math]::Abs([Math]::Sin(($script:mediaVisualizerPhase * 0.63) - ($index * 0.31)))
        $shape = 0.28 + (0.46 * $waveA) + (0.26 * $waveB)
        if ($null -ne $script:modeDeckState -and [string]$script:modeDeckState.activeMode -eq "music") {
            $bassShape = [double]$script:modeDeckState.music.bass / 100.0
            $voiceShape = [double]$script:modeDeckState.music.voice / 100.0
            $shape = ($shape * 0.64) + ($bassShape * 0.22) + ($voiceShape * 0.14)
        }
        $target = if ($energy -gt 0) { 2.0 + (7.0 * $energy * $shape) } else { 2.0 }
        $current = if ([double]::IsNaN($bar.Height)) { 2.0 } else { [double]$bar.Height }
        $bar.Height = [Math]::Max(2.0, [Math]::Min(9.0, ($current * 0.54) + ($target * 0.46)))
        $bar.Opacity = if ($energy -gt 0) { 0.66 + (0.34 * $shape) } else { 0.38 }
    }

    $outputText = $script:window.FindName("MediaOutputText")
    $outputDot = $script:window.FindName("MediaOutputDot")
    if ($script:subtitleRequested) {
        $outputText.Text = $script:subtitleStatusText
        $outputDot.Fill = ConvertTo-Brush -Color $script:subtitleStatusColor
    } elseif ($usingTimedLyrics) {
        $outputText.Text = "同步歌词 · 原文 / 简中"
        $outputDot.Fill = ConvertTo-Brush -Color "#FFA7F3D0"
    } elseif ($hasAudio -and $script:mediaContentMode -eq "video") {
        $outputText.Text = "正在监听视频对白"
        $outputDot.Fill = ConvertTo-Brush -Color "#FFA7F3D0"
    } elseif ($hasAudio) {
        $outputText.Text = "实时声场 " + [Math]::Round($peak * 100).ToString() + "%"
        $outputDot.Fill = ConvertTo-Brush -Color "#FFA7F3D0"
    } elseif ($script:mediaPlaybackStatus -eq "Paused") {
        $outputText.Text = "播放已暂停"
        $outputDot.Fill = ConvertTo-Brush -Color "#FFFFD38A"
    } elseif ($isPlaying) {
        $outputText.Text = if ($script:mediaContentMode -eq "video") { "等待下一句对白" } else { "正在播放 · 静音" }
        $outputDot.Fill = ConvertTo-Brush -Color "#FFB9C7FF"
    } else {
        $outputText.Text = "等待音频"
        $outputDot.Fill = ConvertTo-Brush -Color "#72FFFFFF"
    }

    Update-MediaProgress
    Set-MediaSubtitleOverlayVisibility -HasAudio $hasAudio
}

function Send-MediaKey {
    param([byte]$Key)
    [MacWidgetNative]::SendMediaKey($Key)
    Write-WidgetLog ("Media key sent: " + $Key)
}

function Send-PinnedPlayerCommand {
    param([ValidateSet("toggle", "play", "pause", "stop")][string]$Command)

    try {
        [IO.File]::WriteAllText(
            $script:pinnedMediaCommandPath,
            $Command,
            (New-Object Text.UTF8Encoding($false))
        )
        Write-WidgetLog ("Pinned player command sent: " + $Command)
        return $true
    } catch {
        Write-WidgetLog ("Pinned player command failed: " + $_.Exception.Message)
        return $false
    }
}

function Invoke-MediaPlayPause {
    $playerProcess = Get-Process -Name "ObsidianSoundCloudPlayer" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $playerProcess) {
        $playerState = Get-PinnedPlayerState
        $wasPlaying = $null -ne $playerState -and $playerState.Status -eq "Playing"
        $command = if ($wasPlaying) { "pause" } else { "play" }
        if (Send-PinnedPlayerCommand -Command $command) {
            $script:mediaPlaybackStatus = if ($wasPlaying) { "Paused" } else { "Playing" }
            $script:window.FindName("MediaStateText").Text = if ($wasPlaying) { "已暂停" } else { "正在播放" }
            $script:window.FindName("MediaPlayPauseButton").Content = if ($wasPlaying) { [char]0xE768 } else { [char]0xE769 }
            Set-MediaSubtitleStatus -Text $(if ($wasPlaying) { "音乐已暂停" } else { "音乐继续播放" }) -Color $(if ($wasPlaying) { "#FFFFD38A" } else { "#FFA7F3D0" })
        }
        return
    }

    if ($null -ne $script:mediaSession) {
        Send-MediaKey -Key 0xB3
        return
    }

    try {
        if (!(Test-Path -LiteralPath $script:pinnedMediaStartPath)) { throw "本地播放器启动脚本不存在" }
        & $script:pinnedMediaStartPath
        Start-Sleep -Milliseconds 250
        [void](Send-PinnedPlayerCommand -Command "play")
        Set-MediaSubtitleStatus -Text "音乐开始播放" -Color "#FFA7F3D0"
        Write-WidgetLog "Pinned desktop player started from the media widget."
    } catch {
        Set-MediaSubtitleStatus -Text "本地播放器暂时无法启动" -Color "#FFFFB4A8"
        Write-WidgetLog ("Pinned media player start failed: " + $_.Exception.Message)
    }
}

function Clear-MediaSubtitleRegistration {
    foreach ($source in @($script:subtitleSources)) {
        Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
        Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
    }
    if ($null -ne $script:subtitleProcess) { try { $script:subtitleProcess.Dispose() } catch {} }
    $script:subtitleProcess = $null
    $script:subtitleSources = @()
}

function Invoke-SubtitleWarmupStage {
    if ($script:subtitleRequested -or $script:speechListening) {
        if ($null -ne $script:subtitleWarmupTimer) { $script:subtitleWarmupTimer.Stop() }
        return
    }

    if ($script:subtitleWarmupStage -eq 0) {
        [void](Initialize-MediaSubtitles)
        $script:subtitleWarmupStage = 1
        if ($null -ne $script:subtitleWarmupTimer) {
            $script:subtitleWarmupTimer.Interval = [TimeSpan]::FromMilliseconds(2200)
        }
        Write-WidgetLog "Subtitle worker startup staged after desktop UI initialization."
        return
    }

    if ($null -ne $script:subtitleWarmupTimer) { $script:subtitleWarmupTimer.Stop() }
    if (!$script:subtitleWarmupRequested -and !$script:subtitleRequested -and (Initialize-MediaSubtitles)) {
        if (Send-MediaSubtitleCommand -Command "warmup" -Language $script:subtitleLanguage) {
            $script:subtitleWarmupRequested = $true
            Write-WidgetLog ("Bilingual subtitle model warmup requested after staged delay; language=" + $script:subtitleLanguage + ".")
        }
    }
    $script:subtitleWarmupStage = 2
}

function Start-DeferredSubtitleWarmup {
    if ($script:subtitleWarmupStage -ge 2) { return }
    if ($null -eq $script:subtitleWarmupTimer) {
        $script:subtitleWarmupTimer = [Windows.Threading.DispatcherTimer]::new()
        $script:subtitleWarmupTimer.Interval = [TimeSpan]::FromMilliseconds(1800)
        $script:subtitleWarmupTimer.Add_Tick({ Invoke-SubtitleWarmupStage })
    }
    if (!$script:subtitleWarmupTimer.IsEnabled) {
        $script:subtitleWarmupTimer.Start()
        Write-WidgetLog "Subtitle model warmup scheduled in two background stages."
    }
}

function Initialize-MediaSubtitles {
    if ($null -ne $script:subtitleProcess) {
        try {
            if (!$script:subtitleProcess.HasExited) { return $true }
        } catch {}
        Clear-MediaSubtitleRegistration
    } elseif ($script:subtitleSources.Count -gt 0) {
        Clear-MediaSubtitleRegistration
    }

    if (!(Test-Path -LiteralPath $script:speechPythonPath) -or !(Test-Path -LiteralPath $script:subtitleWorkerPath)) {
        Set-MediaSubtitleStatus -Text "字幕运行环境未安装" -Color "#FFFFB4A8"
        Write-WidgetLog "Bilingual subtitle runtime is missing."
        return $false
    }

    try {
        if (!(Test-Path -LiteralPath $script:speechCachePath)) {
            [void](New-Item -ItemType Directory -Force -Path $script:speechCachePath)
        }
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $script:speechPythonPath
        $startInfo.Arguments = '"' + $script:subtitleWorkerPath + '" --cache-dir "' + $script:speechCachePath + '"'
        $startInfo.WorkingDirectory = $script:root
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [Text.Encoding]::UTF8
        $startInfo.EnvironmentVariables["PYTHONUTF8"] = "1"
        $startInfo.EnvironmentVariables["HF_HOME"] = $script:speechCachePath
        $startInfo.EnvironmentVariables["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
        if (Test-Path -LiteralPath ($script:speechCudaPath + "\cublas64_12.dll")) {
            $startInfo.EnvironmentVariables["PATH"] = $script:speechCudaPath + ";" + $env:PATH
        }

        $script:subtitleProcess = [Diagnostics.Process]::new()
        $script:subtitleProcess.StartInfo = $startInfo
        $script:subtitleProcess.EnableRaisingEvents = $true
        if (!$script:subtitleProcess.Start()) { throw "Subtitle worker did not start." }
        try { $script:subtitleProcess.PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}

        $base = "MacWidgetSubtitle-" + $PID
        $stdoutSource = $base + "-stdout"
        $stderrSource = $base + "-stderr"
        $exitSource = $base + "-exit"
        Register-ObjectEvent -InputObject $script:subtitleProcess -EventName OutputDataReceived -SourceIdentifier $stdoutSource | Out-Null
        Register-ObjectEvent -InputObject $script:subtitleProcess -EventName ErrorDataReceived -SourceIdentifier $stderrSource | Out-Null
        Register-ObjectEvent -InputObject $script:subtitleProcess -EventName Exited -SourceIdentifier $exitSource | Out-Null
        $script:subtitleSources = @($stdoutSource, $stderrSource, $exitSource)
        $script:subtitleProcess.BeginOutputReadLine()
        $script:subtitleProcess.BeginErrorReadLine()
        Write-WidgetLog ("Bilingual subtitle worker started hidden: " + $script:subtitleProcess.Id)
        return $true
    } catch {
        Set-MediaSubtitleStatus -Text "字幕服务启动失败" -Color "#FFFFB4A8"
        Write-WidgetLog ("Bilingual subtitle initialization failed: " + $_.Exception.ToString())
        Clear-MediaSubtitleRegistration
        return $false
    }
}

function Send-MediaSubtitleCommand {
    param(
        [string]$Command,
        [string]$Language = "",
        [string]$ContentMode = ""
    )
    if ($null -eq $script:subtitleProcess -or $script:subtitleProcess.HasExited) { return $false }
    try {
        $message = @{ command = $Command }
        if (![string]::IsNullOrWhiteSpace($Language)) {
            $message.language = $Language
        }
        if (![string]::IsNullOrWhiteSpace($ContentMode)) {
            $message.content_mode = $ContentMode
        }
        $payload = $message | ConvertTo-Json -Compress
        $script:subtitleProcess.StandardInput.WriteLine($payload)
        $script:subtitleProcess.StandardInput.Flush()
        return $true
    } catch {
        Write-WidgetLog ("Subtitle command failed: " + $Command + " | " + $_.Exception.Message)
        return $false
    }
}

function Start-MediaSubtitles {
    param([ValidateSet("music", "video")][string]$ContentMode = "video")

    if ($script:subtitleRequested -or $script:speechListening) { return }
    if ($null -ne $script:subtitleWarmupTimer) { $script:subtitleWarmupTimer.Stop() }
    $script:subtitleWarmupStage = 2
    $script:subtitleRequested = $true
    $script:subtitleListening = $false
    if (!(Show-LastMediaSubtitle)) {
        $script:subtitleHasCaption = $false
        if ($ContentMode -eq "video") {
            Set-MediaSubtitleLines -Chinese "正在准备简体中文字幕" -English "Preparing original-language video subtitles"
        } else {
            Set-MediaSubtitleLines -Chinese "正在准备简体中文字幕" -English "Preparing original-language lyrics"
        }
    } else {
        $script:subtitleHasCaption = $true
    }
    Set-MediaSubtitleStatus -Text "加载本地字幕模型" -Color "#FFFFD98A"
    $script:window.FindName("MediaStateText").Text = if ($ContentMode -eq "video") { "视频字幕" } else { "双语字幕" }

    if (!(Initialize-MediaSubtitles) -or !(Send-MediaSubtitleCommand -Command "start" -Language $script:subtitleLanguage -ContentMode $ContentMode)) {
        $script:subtitleRequested = $false
        $script:subtitleRetryAfterUtc = [DateTime]::UtcNow.AddSeconds(45)
        Set-MediaSubtitleStatus -Text "字幕服务稍后重试" -Color "#FFFFB4A8"
        return
    }
    Write-WidgetLog ("Automatic bilingual subtitles requested from system loopback audio; mode=" + $ContentMode + "; language=" + $script:subtitleLanguage + ".")
}

function Stop-MediaSubtitles {
    param([switch]$ReleaseWorker)

    if ($script:subtitleRequested -and $null -ne $script:subtitleProcess) {
        [void](Send-MediaSubtitleCommand -Command "stop")
    }
    $script:subtitleRequested = $false
    $script:subtitleListening = $false
    $script:subtitleHasCaption = Show-LastMediaSubtitle
    if ($ReleaseWorker -and $null -ne $script:subtitleProcess) {
        try {
            if (!$script:subtitleProcess.HasExited) {
                [void](Send-MediaSubtitleCommand -Command "quit")
                if (!$script:subtitleProcess.WaitForExit(1600)) { $script:subtitleProcess.Kill() }
            }
        } catch {
            Write-WidgetLog ("Subtitle worker shutdown failed: " + $_.Exception.Message)
        }
        Clear-MediaSubtitleRegistration
    }
    if (!$script:subtitleHasCaption -and ![string]::IsNullOrWhiteSpace($script:mediaCurrentTitle)) {
        Set-MediaSubtitleLines -Chinese $script:mediaCurrentTitle -English $script:mediaCurrentArtist
    } elseif (!$script:subtitleHasCaption) {
        Show-PinnedMedia
    }
    Set-MediaSubtitleStatus -Text "双语字幕待机" -Color "#72FFFFFF"
}

function Get-ModeDeckVisualizerScale {
    $scale = 1.0
    if ($null -eq $script:modeDeckState) { return $scale }

    switch ([string]$script:modeDeckState.activeMode) {
        "cinema" {
            $scale = 0.72 + ([double]$script:modeDeckState.cinema.soundfield / 100.0 * 0.38)
            break
        }
        "code" {
            $scale = 0.52
            break
        }
        "music" {
            $bass = [double]$script:modeDeckState.music.bass / 100.0
            $voice = [double]$script:modeDeckState.music.voice / 100.0
            $ambience = [double]$script:modeDeckState.music.ambience / 100.0
            $scale = 0.62 + ($bass * 0.46) + ($voice * 0.16) + ($ambience * 0.24)
            break
        }
    }
    return [Math]::Max(0.35, [Math]::Min(1.55, $scale))
}

function Process-MediaSubtitleEvents {
    if ($script:subtitleSources.Count -eq 0) { return }
    foreach ($source in $script:subtitleSources) {
        $events = @(Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue)
        foreach ($eventItem in $events) {
            try {
                if ($source.EndsWith("-stdout")) {
                    $line = [string]$eventItem.SourceEventArgs.Data
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    try { $message = $line | ConvertFrom-Json } catch {
                        Write-WidgetLog ("Subtitle output parse failed: " + $line)
                        continue
                    }

                    if ($message.event -eq "subtitle") {
                        $chinese = ConvertTo-SimplifiedChinese -Text ([string]$message.chinese)
                        $original = [string]$message.original
                        if ([string]::IsNullOrWhiteSpace($original)) { $original = [string]$message.english }
                        Set-MediaSubtitleLines -Chinese $chinese -English $original
                        $script:subtitleLastChinese = $chinese
                        $script:subtitleLastOriginal = $original
                        $script:subtitleHasCaption = $true
                        $script:subtitleListening = $true
                        $script:subtitleLastCaptionUtc = [DateTime]::UtcNow
                        $percent = [Math]::Round(([double]$message.confidence) * 100)
                        $detectedLanguage = [string]$message.language
                        Set-MediaSubtitleStatus -Text ("字幕 " + $percent + "% · " + $detectedLanguage + " → 简中") -Color "#FFA7F3D0"
                        Write-WidgetLog ("Bilingual subtitle completed: zh=" + $chinese.Length + ", original=" + $original.Length + ", language=" + [string]$message.language + ", confidence=" + [string]$message.confidence)
                    } elseif ($message.event -eq "status") {
                        $state = [string]$message.state
                        $text = [string]$message.text
                        $color = if ($state -in @("ready", "listening")) {
                            "#FFA7F3D0"
                        } elseif ($state -in @("loading", "fallback", "recognizing", "busy")) {
                            "#FFFFD98A"
                        } elseif ($state -eq "translation_fallback") {
                            "#FFFFD38A"
                        } else {
                            "#FFB9C7FF"
                        }
                        Set-MediaSubtitleStatus -Text $text -Color $color
                        if ($state -in @("loading", "ready", "fallback", "language", "listening", "recognizing", "stopped", "no_speech")) {
                            Write-WidgetLog ("Subtitle status: " + $state + " | " + $text)
                        }
                        if ($state -eq "listening") { $script:subtitleListening = $true }
                        if ($state -eq "stopped") {
                            $script:subtitleListening = $false
                            $script:subtitleRequested = $false
                        }
                    } elseif ($message.event -eq "error") {
                        $script:subtitleRequested = $false
                        $script:subtitleListening = $false
                        $script:subtitleRetryAfterUtc = [DateTime]::UtcNow.AddSeconds(45)
                        Set-MediaSubtitleStatus -Text ([string]$message.text) -Color "#FFFFB4A8"
                        Write-WidgetLog ("Subtitle error: " + [string]$message.text + " | " + [string]$message.detail)
                    }
                } elseif ($source.EndsWith("-stderr")) {
                    $line = [string]$eventItem.SourceEventArgs.Data
                    if (![string]::IsNullOrWhiteSpace($line)) { Write-WidgetLog ("Subtitle runtime: " + $line) }
                } elseif ($source.EndsWith("-exit")) {
                    $script:subtitleRequested = $false
                    $script:subtitleListening = $false
                    $script:subtitleRetryAfterUtc = [DateTime]::UtcNow.AddSeconds(20)
                    Set-MediaSubtitleStatus -Text "字幕服务已休眠" -Color "#72FFFFFF"
                }
            } finally {
                Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue
            }
        }
    }
}

function Dispose-MediaSubtitles {
    if ($null -ne $script:subtitleWarmupTimer) { $script:subtitleWarmupTimer.Stop() }
    if ($null -ne $script:subtitleProcess) {
        try {
            if (!$script:subtitleProcess.HasExited) {
                [void](Send-MediaSubtitleCommand -Command "quit")
                if (!$script:subtitleProcess.WaitForExit(1600)) { $script:subtitleProcess.Kill() }
            }
        } catch {}
    }
    Clear-MediaSubtitleRegistration
    $script:subtitleRequested = $false
    $script:subtitleListening = $false
}

function ConvertTo-SimplifiedChinese {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    try {
        return [Microsoft.VisualBasic.Strings]::StrConv($Text, [Microsoft.VisualBasic.VbStrConv]::SimplifiedChinese, 2052)
    } catch {
        return $Text
    }
}

function Set-SpeechState {
    param([string]$Text)
    $script:window.FindName("SpeechStatusText").Text = $Text
    $stateColor = if ($Text -match "失败|错误|无法|未安装|服务已停止") {
        "#FFFFB4A8"
    } elseif ($Text -match "完成|已就绪|已停止并释放|已复制|已清空") {
        "#FFA7F3D0"
    } else {
        "#FFFFD98A"
    }
    $parsedColor = [Windows.Media.ColorConverter]::ConvertFromString($stateColor)
    $statusBrush = [Windows.Media.SolidColorBrush]::new($parsedColor)
    $script:window.FindName("SpeechStatusDot").Fill = $statusBrush
}

function Set-SpeechButtonState {
    param([bool]$Listening)

    $script:window.FindName("SpeechToggleText").Text = if ($Listening) { "停止听写" } else { "开始听写" }
    $buttonColor = if ($Listening) {
        [Windows.Media.Color]::FromArgb(0x45, 0xFF, 0xD9, 0x8A)
    } else {
        [Windows.Media.Color]::FromArgb(0x22, 0xFF, 0xFF, 0xFF)
    }
    $script:window.FindName("SpeechToggleButton").Background = [Windows.Media.SolidColorBrush]::new($buttonColor)
}

function Clear-SpeechWorkerRegistration {
    foreach ($source in @($script:speechSources)) {
        Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
        Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
    }
    if ($null -ne $script:speechProcess) { try { $script:speechProcess.Dispose() } catch {} }
    $script:speechProcess = $null
    $script:speechSources = @()
}

function Initialize-SpeechRecognition {
    if ($null -ne $script:speechProcess) {
        try {
            if (!$script:speechProcess.HasExited) { return $true }
        } catch {}
        Clear-SpeechWorkerRegistration
    } elseif ($script:speechSources.Count -gt 0) {
        Clear-SpeechWorkerRegistration
    }
    if (!(Test-Path -LiteralPath $script:speechPythonPath) -or !(Test-Path -LiteralPath $script:speechWorkerPath)) {
        Set-SpeechState -Text "Whisper 运行环境未安装"
        Write-WidgetLog "Whisper runtime is missing."
        return $false
    }

    try {
        if (!(Test-Path -LiteralPath $script:speechCachePath)) {
            [void](New-Item -ItemType Directory -Force -Path $script:speechCachePath)
        }
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $script:speechPythonPath
        $startInfo.Arguments = '"' + $script:speechWorkerPath + '" --cache-dir "' + $script:speechCachePath + '"'
        $startInfo.WorkingDirectory = $script:root
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [Text.Encoding]::UTF8
        $startInfo.EnvironmentVariables["PYTHONUTF8"] = "1"
        $startInfo.EnvironmentVariables["HF_HOME"] = $script:speechCachePath
        $startInfo.EnvironmentVariables["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
        if (Test-Path -LiteralPath ($script:speechCudaPath + "\cublas64_12.dll")) {
            $startInfo.EnvironmentVariables["PATH"] = $script:speechCudaPath + ";" + $env:PATH
        }

        $script:speechProcess = [Diagnostics.Process]::new()
        $script:speechProcess.StartInfo = $startInfo
        $script:speechProcess.EnableRaisingEvents = $true
        if (!$script:speechProcess.Start()) { throw "Whisper worker did not start." }

        $base = "MacWidgetWhisper-" + $PID
        $stdoutSource = $base + "-stdout"
        $stderrSource = $base + "-stderr"
        $exitSource = $base + "-exit"
        Register-ObjectEvent -InputObject $script:speechProcess -EventName OutputDataReceived -SourceIdentifier $stdoutSource | Out-Null
        Register-ObjectEvent -InputObject $script:speechProcess -EventName ErrorDataReceived -SourceIdentifier $stderrSource | Out-Null
        Register-ObjectEvent -InputObject $script:speechProcess -EventName Exited -SourceIdentifier $exitSource | Out-Null
        $script:speechSources = @($stdoutSource, $stderrSource, $exitSource)
        $script:speechProcess.BeginOutputReadLine()
        $script:speechProcess.BeginErrorReadLine()
        Set-SpeechState -Text "Whisper 服务正在启动"
        Write-WidgetLog ("Whisper worker started: " + $script:speechProcess.Id)
        return $true
    } catch {
        Set-SpeechState -Text "Whisper 服务启动失败"
        Write-WidgetLog ("Whisper initialization failed: " + $_.Exception.ToString())
        return $false
    }
}

function Send-SpeechCommand {
    param([string]$Command)
    if ($null -eq $script:speechProcess -or $script:speechProcess.HasExited) { return $false }
    try {
        $payload = @{ command = $Command } | ConvertTo-Json -Compress
        $script:speechProcess.StandardInput.WriteLine($payload)
        $script:speechProcess.StandardInput.Flush()
        return $true
    } catch {
        Write-WidgetLog ("Whisper command failed: " + $Command + " | " + $_.Exception.Message)
        return $false
    }
}

function Start-SpeechRecognition {
    if ($null -ne $script:speechIdleTimer) { $script:speechIdleTimer.Stop() }
    if ($script:subtitleRequested -or $null -ne $script:subtitleProcess) {
        Stop-MediaSubtitles -ReleaseWorker
    }
    if (!(Initialize-SpeechRecognition)) { return }
    if (Send-SpeechCommand -Command "start") {
        $script:speechListening = $true
        Set-SpeechState -Text "正在准备高精度识别"
        Set-SpeechButtonState -Listening $true
        Write-WidgetLog "Whisper recognition requested."
    }
}

function Stop-SpeechRecognition {
    if (!$script:speechListening) { return }
    [void](Send-SpeechCommand -Command "stop")
    $script:speechListening = $false
    Set-SpeechState -Text "正在完成最后一句"
    Set-SpeechButtonState -Listening $false
    if ($null -ne $script:speechIdleTimer) {
        $script:speechIdleTimer.Stop()
        $script:speechIdleTimer.Start()
    }
    Write-WidgetLog "Whisper recognition stop requested."
}

function Process-SpeechEvents {
    if ($script:speechSources.Count -eq 0) { return }
    foreach ($source in $script:speechSources) {
        $events = @(Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue)
        foreach ($eventItem in $events) {
            try {
                if ($source.EndsWith("-stdout")) {
                    $line = [string]$eventItem.SourceEventArgs.Data
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    try { $message = $line | ConvertFrom-Json } catch {
                        Write-WidgetLog ("Whisper output parse failed: " + $line)
                        continue
                    }

                    if ($message.event -eq "transcript") {
                        $recognized = ConvertTo-SimplifiedChinese -Text ([string]$message.text)
                        if (![string]::IsNullOrWhiteSpace($recognized)) {
                            $resultText = $script:window.FindName("SpeechResultText")
                            $placeholder = Get-WidgetText -Name "speechPlaceholder" -Fallback "Recognition appears here"
                            if ($resultText.Text -eq $placeholder) { $resultText.Text = $recognized }
                            else { $resultText.Text = ($resultText.Text.TrimEnd() + [Environment]::NewLine + $recognized).Trim() }
                            if ($resultText.Text.Length -gt 12000) { $resultText.Text = $resultText.Text.Substring($resultText.Text.Length - 12000) }
                            $resultText.CaretIndex = $resultText.Text.Length
                            $resultText.ScrollToEnd()
                            $percent = [Math]::Round(([double]$message.confidence) * 100)
                            Set-SpeechState -Text ("识别完成 " + $percent + "% · " + [string]$message.device)
                            Write-WidgetLog ("Whisper transcript completed: characters=" + $recognized.Length + ", confidence=" + [string]$message.confidence)
                        }
                    } elseif ($message.event -eq "status") {
                        Set-SpeechState -Text ([string]$message.text)
                        if ($message.state -eq "stopped") {
                            $script:speechListening = $false
                            Set-SpeechButtonState -Listening $false
                        }
                    } elseif ($message.event -eq "error") {
                        Set-SpeechState -Text ([string]$message.text)
                        Write-WidgetLog ("Whisper error: " + [string]$message.text + " | " + [string]$message.detail)
                    }
                } elseif ($source.EndsWith("-stderr")) {
                    $line = [string]$eventItem.SourceEventArgs.Data
                    if (![string]::IsNullOrWhiteSpace($line)) { Write-WidgetLog ("Whisper runtime: " + $line) }
                } elseif ($source.EndsWith("-exit")) {
                    $script:speechListening = $false
                    Set-SpeechButtonState -Listening $false
                    Set-SpeechState -Text "Whisper 服务已停止"
                }
            } finally {
                Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue
            }
        }
    }
}

function Dispose-SpeechRecognition {
    Stop-SpeechRecognition
    if ($null -ne $script:speechIdleTimer) { $script:speechIdleTimer.Stop() }
    if ($null -ne $script:speechProcess -and !$script:speechProcess.HasExited) {
        [void](Send-SpeechCommand -Command "quit")
        if (!$script:speechProcess.WaitForExit(1200)) { try { $script:speechProcess.Kill() } catch {} }
    }
    Clear-SpeechWorkerRegistration
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianAIDesktopDashboard", [ref]$createdNew)
if (!$createdNew) { exit 0 }

try {
    $script:settings = Read-Utf8Json -Path $script:settingsPath
    Initialize-WidgetVirtualDesktopSupport
    $script:window = Import-WidgetXaml
    $script:window.Add_SourceInitialized({
        param($sender, $eventArgs)
        $helper = [Windows.Interop.WindowInteropHelper]::new($sender)
        $script:hostWindowHandle = $helper.Handle
        [void](Register-DesktopWidgetHandle -Handle $helper.Handle -Name "Host")
    })
    Initialize-ModularWidgetWindows
    Initialize-ModeDeckWidget
    Initialize-MediaAvatar
    $script:mediaVisualizerBars = @(
        for ($barIndex = 1; $barIndex -le 18; $barIndex++) {
            $script:window.FindName(("MediaBar{0:D2}" -f $barIndex))
        }
    )
    Initialize-MediaSubtitleLanguage
    Set-MediaSubtitleStatus -Text "字幕服务将在后台分阶段预热" -Color "#FFB9C7FF"
    Start-DeferredSubtitleWarmup
    Initialize-MediaHistory
    Apply-ModeDeckPersistedRuntimeProfile

    $script:window.FindName("MediaPreviousButton").Add_Click({ Send-MediaKey -Key 0xB1 })
    $script:window.FindName("MediaPlayPauseButton").Add_Click({ Invoke-MediaPlayPause })
    $script:window.FindName("MediaNextButton").Add_Click({ Send-MediaKey -Key 0xB0 })
    $script:window.FindName("SpeechToggleButton").Add_Click({
        if ($script:speechListening) { Stop-SpeechRecognition } else { Start-SpeechRecognition }
    })
    $script:window.FindName("AddSpeechToTodoButton").Add_Click({ Add-SpeechResultToTodo })
    $script:window.FindName("PhotoImportButton").Add_Click({ Import-WeChatPhotos })
    $script:window.FindName("PhotoPreviousButton").Add_Click({ Move-PhotoSelection -Delta -1 })
    $script:window.FindName("PhotoNextButton").Add_Click({ Move-PhotoSelection -Delta 1 })
    $script:window.FindName("PhotoLockScreenButton").Add_Click({ Set-CurrentPhotoAsLockScreen })
    $script:window.FindName("PhotoOpenButton").Add_Click({ Open-PhotoDropFolder })
    $script:window.FindName("PhotoOpenButton").Add_PreviewMouseRightButtonUp({
        param($sender, $eventArgs)
        Open-CurrentPhotoLocation
        $eventArgs.Handled = $true
    })

    $photoVideo = $script:window.FindName("PhotoVideo")
    $photoVideo.Add_MediaOpened({
        param($sender, $eventArgs)
        if ($sender.Visibility -eq [Windows.Visibility]::Visible) {
            $sender.Position = [TimeSpan]::Zero
            $sender.Play()
            if ($null -ne $script:photoPreviewPauseTimer) {
                $script:photoPreviewPauseTimer.Stop()
                $script:photoPreviewPauseTimer.Start()
            }
        }
    })
    $photoVideo.Add_MediaEnded({
        param($sender, $eventArgs)
        if ($sender.Visibility -eq [Windows.Visibility]::Visible) {
            $surface = $script:window.FindName("PhotoSwipeSurface")
            if ($null -ne $surface -and $surface.IsMouseOver) {
                $sender.Position = [TimeSpan]::Zero
                $sender.Play()
            } else {
                $sender.Pause()
            }
        }
    })
    $photoVideo.Add_MediaFailed({
        param($sender, $eventArgs)
        $script:window.FindName("PhotoEmptyText").Text = "此动态照片需要 Windows 解码器"
        $script:window.FindName("PhotoEmptyOverlay").Visibility = [Windows.Visibility]::Visible
        Write-WidgetLog ("Dynamic photo playback failed: " + $eventArgs.ErrorException.Message)
    })

    $photoSwipeSurface = $script:window.FindName("PhotoSwipeSurface")
    $photoViewport = $script:window.FindName("PhotoViewport")
    $photoDropTarget = $script:widgetWindows["PhotoCard"]
    $photoDropTarget.AllowDrop = $true
    $photoDropTarget.Add_PreviewDragOver({
        param($sender, $eventArgs)
        if (Test-WeChatPhotoDropData -Data $eventArgs.Data) {
            $eventArgs.Effects = [Windows.DragDropEffects]::Copy
        } else {
            $eventArgs.Effects = [Windows.DragDropEffects]::None
        }
        $eventArgs.Handled = $true
    })
    $photoDropTarget.Add_DragEnter({
        param($sender, $eventArgs)
        if (Test-WeChatPhotoDropData -Data $eventArgs.Data) {
            $script:window.FindName("PhotoCaptionText").Text = "松开即可加入微信生活"
        }
    })
    $photoDropTarget.Add_DragLeave({
        Update-PhotoWidget
    })
    $photoDropTarget.Add_PreviewDrop({
        param($sender, $eventArgs)
        [void](Import-WeChatPhotoDropData -Data $eventArgs.Data)
        $eventArgs.Handled = $true
    })
    $script:photoPreviewPauseTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:photoPreviewPauseTimer.Interval = [TimeSpan]::FromMilliseconds(1400)
    $script:photoPreviewPauseTimer.Add_Tick({
        $script:photoPreviewPauseTimer.Stop()
        $surface = $script:window.FindName("PhotoSwipeSurface")
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible -and !$surface.IsMouseOver) {
            try { $video.Pause() } catch {}
        }
    })
    $photoSwipeSurface.Add_MouseEnter({
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
            $script:photoPreviewPauseTimer.Stop()
            try { $video.Play() } catch {}
        }
    })
    $photoSwipeSurface.Add_MouseLeave({
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
            try { $video.Pause() } catch {}
        }
    })
    $photoSwipeSurface.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $script:photoSwipeStartX = $eventArgs.GetPosition($sender).X
        [void]$sender.CaptureMouse()
        $eventArgs.Handled = $true
    })
    $photoSwipeSurface.Add_PreviewMouseLeftButtonUp({
        param($sender, $eventArgs)
        $endX = $eventArgs.GetPosition($sender).X
        $startX = $script:photoSwipeStartX
        $script:photoSwipeStartX = $null
        $sender.ReleaseMouseCapture()
        if ($null -ne $startX) {
            $distance = $endX - [double]$startX
            if ([Math]::Abs($distance) -ge 42) {
                Move-PhotoSelection -Delta $(if ($distance -lt 0) { 1 } else { -1 })
            }
        }
        $eventArgs.Handled = $true
    })
    $photoSwipeSurface.Add_PreviewMouseWheel({
        param($sender, $eventArgs)
        Move-PhotoSelection -Delta $(if ($eventArgs.Delta -lt 0) { 1 } else { -1 })
        $eventArgs.Handled = $true
    })
    $photoSwipeSurface.Add_TouchDown({
        param($sender, $eventArgs)
        $script:photoTouchStartX = $eventArgs.GetTouchPoint($sender).Position.X
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
            try { $video.Play() } catch {}
        }
        $eventArgs.Handled = $true
    })
    $photoSwipeSurface.Add_TouchUp({
        param($sender, $eventArgs)
        $endX = $eventArgs.GetTouchPoint($sender).Position.X
        $startX = $script:photoTouchStartX
        $script:photoTouchStartX = $null
        if ($null -ne $startX) {
            $distance = $endX - [double]$startX
            if ([Math]::Abs($distance) -ge 36) {
                Move-PhotoSelection -Delta $(if ($distance -lt 0) { 1 } else { -1 })
            }
        }
        $video = $script:window.FindName("PhotoVideo")
        if ($null -ne $video -and $video.Visibility -eq [Windows.Visibility]::Visible) {
            try { $video.Pause() } catch {}
        }
        $eventArgs.Handled = $true
    })
    $script:window.FindName("SpeechResultText").Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $featureWindow = $script:widgetWindows["FeatureCard"]
        if ($null -ne $featureWindow) { try { [void]$featureWindow.Activate() } catch {} }
        [void]$sender.Focus()
        $placeholder = Get-WidgetText -Name "speechPlaceholder" -Fallback "识别结果会显示在这里"
        if ($sender.Text -eq $placeholder) { $sender.Clear() }
    })
    $script:window.FindName("SpeechResultText").Add_LostKeyboardFocus({
        param($sender, $eventArgs)
        if ([string]::IsNullOrWhiteSpace($sender.Text)) {
            $sender.Text = Get-WidgetText -Name "speechPlaceholder" -Fallback "识别结果会显示在这里"
        }
    })
    $script:window.FindName("CopySpeechButton").Add_Click({
        $text = [string]$script:window.FindName("SpeechResultText").Text
        $placeholder = Get-WidgetText -Name "speechPlaceholder" -Fallback "Recognition appears here"
        if (![string]::IsNullOrWhiteSpace($text) -and $text -ne $placeholder) {
            [Windows.Clipboard]::SetText($text)
            Set-SpeechState -Text (Get-WidgetText -Name "speechCopied" -Fallback "Copied")
        }
    })
    $script:window.FindName("ClearSpeechButton").Add_Click({
        $script:window.FindName("SpeechResultText").Text = Get-WidgetText -Name "speechPlaceholder" -Fallback "识别结果会显示在这里"
        Set-SpeechState -Text "识别内容已清空"
    })

    $script:todoSaveTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:todoSaveTimer.Interval = [TimeSpan]::FromMilliseconds(350)
    $script:todoSaveTimer.Add_Tick({
        $script:todoSaveTimer.Stop()
        Save-TodoState
    })
    for ($index = 1; $index -le 4; $index++) {
        $todoTextBox = $script:window.FindName("TodoText" + $index)
        $todoCheckBox = $script:window.FindName("TodoCheck" + $index)
        $todoTextBox.Add_TextChanged({
            if ($script:todoLoaded) {
                $script:todoSaveTimer.Stop()
                $script:todoSaveTimer.Start()
            }
        })
        $todoTextBox.Add_LostKeyboardFocus({ Save-TodoState })
        $todoCheckBox.Add_Click({
            Update-TodoAppearance
            Save-TodoState
        })
    }
    Initialize-TodoComponent
    Initialize-PhotoLibrary
    Initialize-AppUsageTracker

    $script:photoFolderSyncTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:photoFolderSyncTimer.Interval = [TimeSpan]::FromSeconds(15)
    $script:photoFolderSyncTimer.Add_Tick({
        try { [void](Sync-PhotoDropFolder -SelectNewest $true -Refresh $true) }
        catch { Write-WidgetLog ("Photo folder sync tick failed: " + $_.Exception.Message) }
    })

    $script:appUsageTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:appUsageTimer.Interval = [TimeSpan]::FromSeconds(5)
    $script:appUsageTimer.Add_Tick({
        try { Update-AppUsageTracker } catch { Write-WidgetLog ("App usage tick failed: " + $_.Exception.Message) }
    })

    $clockTimer = [Windows.Threading.DispatcherTimer]::new()
    $clockTimer.Interval = [TimeSpan]::FromSeconds(1)
    $clockTimer.Add_Tick({
        try { Update-Clock } catch { Write-WidgetLog ("Clock tick failed: " + $_.Exception.Message) }
    })

    $systemTimer = [Windows.Threading.DispatcherTimer]::new()
    $systemTimer.Interval = [TimeSpan]::FromSeconds(15)
    $systemTimer.Add_Tick({
        try { Update-Battery; Update-Calendar } catch { Write-WidgetLog ("System tick failed: " + $_.Exception.Message) }
    })

    $script:lockWidgetTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:lockWidgetTimer.Interval = [TimeSpan]::FromSeconds(1)
    $script:lockWidgetTimer.Add_Tick({ Update-LockDurationWidget })

    $script:powerHistoryTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:powerHistoryTimer.Interval = [TimeSpan]::FromMinutes(10)
    $script:powerHistoryTimer.Add_Tick({ Update-PowerHistoryWidget })

    $script:deferredPowerHistoryTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:deferredPowerHistoryTimer.Interval = [TimeSpan]::FromMilliseconds(1600)
    $script:deferredPowerHistoryTimer.Add_Tick({
        $script:deferredPowerHistoryTimer.Stop()
        try { Update-PowerHistoryWidget } catch { Write-WidgetLog ("Deferred power history failed: " + $_.Exception.Message) }
    })

    $statusPulseTimer = [Windows.Threading.DispatcherTimer]::new()
    $statusPulseTimer.Interval = [TimeSpan]::FromSeconds(3.2)
    $statusPulseTimer.Add_Tick({
        $script:statusLightsDimmed = !$script:statusLightsDimmed
        $target = if ($script:statusLightsDimmed) { 0.54 } else { 0.86 }
        foreach ($light in $script:statusLights) {
            $light.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-WidgetDoubleAnimation -To $target -Milliseconds 260))
        }
    })

    $script:petAnimationTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:petAnimationTimer.Interval = [TimeSpan]::FromMilliseconds(230)
    $script:petAnimationTimer.Add_Tick({
        try { Update-WidgetPetAnimations } catch { Write-WidgetLog ("Pet animation tick failed: " + $_.Exception.Message) }
    })

    $mediaTimer = [Windows.Threading.DispatcherTimer]::new()
    $mediaTimer.Interval = [TimeSpan]::FromSeconds(1)
    $mediaTimer.Add_Tick({
        try { Update-Media } catch { Write-WidgetLog ("Media tick failed: " + $_.Exception.Message) }
    })

    $script:mediaVisualizerTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:mediaVisualizerTimer.Interval = [TimeSpan]::FromMilliseconds($script:mediaVisualizerIdleIntervalMs)
    $script:mediaVisualizerTimer.Add_Tick({
        try { Update-MediaVisualizer } catch { Write-WidgetLog ("Media visualizer tick failed: " + $_.Exception.Message) }
    })

    $script:virtualDesktopTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:virtualDesktopTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:virtualDesktopTimer.Add_Tick({
        try { Ensure-WidgetVirtualDesktopPins } catch { Write-WidgetLog ("Virtual desktop pin refresh failed: " + $_.Exception.Message) }
    })

    $script:cinemaModeTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:cinemaModeTimer.Interval = [TimeSpan]::FromMilliseconds(400)
    $script:cinemaModeTimer.Add_Tick({
        try { Update-WidgetCinemaMode } catch { Write-WidgetLog ("Cinema avoidance tick failed: " + $_.Exception.Message) }
    })

    $script:desktopSurfaceRestoreTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:desktopSurfaceRestoreTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
    $script:desktopSurfaceRestoreTimer.Add_Tick({
        $script:desktopSurfaceRestoreTimer.Stop()
        try { Restore-DesktopWidgetSurfaces } catch { Write-WidgetLog ("Desktop surface retry failed: " + $_.Exception.Message) }
    })

    $speechTimer = [Windows.Threading.DispatcherTimer]::new()
    $speechTimer.Interval = [TimeSpan]::FromMilliseconds(180)
    $speechTimer.Add_Tick({
        try {
            Process-SpeechEvents
            Process-MediaSubtitleEvents
        } catch { Write-WidgetLog ("Speech or subtitle tick failed: " + $_.Exception.Message) }
    })

    $script:speechIdleTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:speechIdleTimer.Interval = [TimeSpan]::FromSeconds(90)
    $script:speechIdleTimer.Add_Tick({
        $script:speechIdleTimer.Stop()
        if (!$script:speechListening -and $null -ne $script:speechProcess) {
            try {
                if (!$script:speechProcess.HasExited) {
                    [void](Send-SpeechCommand -Command "quit")
                    if (!$script:speechProcess.WaitForExit(1500)) { $script:speechProcess.Kill() }
                }
            } catch {
                Write-WidgetLog ("Whisper idle shutdown failed: " + $_.Exception.Message)
            }
            Clear-SpeechWorkerRegistration
            Set-SpeechState -Text "语音服务已休眠 · 点击可重新启动"
            Write-WidgetLog "Whisper worker released after 90 seconds idle."
        }
    })

    $weatherTimer = [Windows.Threading.DispatcherTimer]::new()
    $weatherTimer.Interval = [TimeSpan]::FromMinutes(30)
    $weatherTimer.Add_Tick({
        try { Update-Weather } catch { Write-WidgetLog ("Weather tick failed: " + $_.Exception.Message) }
    })

    $script:window.Add_Loaded({
        Update-Clock
        Update-Calendar
        Update-Battery
        if (!$script:lockWidgetAutoHidden) { Update-LockDurationWidget }
        Update-Media
        Update-MediaVisualizer
        Update-AppUsageTracker
        Ensure-WidgetVirtualDesktopPins
        $clockTimer.Start()
        $systemTimer.Start()
        if (!$script:lockWidgetAutoHidden) { $script:lockWidgetTimer.Start() }
        $script:powerHistoryTimer.Start()
        $script:deferredPowerHistoryTimer.Start()
        $statusPulseTimer.Start()
        Update-WidgetPetAnimations
        $script:petAnimationTimer.Start()
        $mediaTimer.Start()
        Start-DeferredMediaVisualizer
        $script:virtualDesktopTimer.Start()
        $script:cinemaModeTimer.Start()
        $script:photoFolderSyncTimer.Start()
        $script:appUsageTimer.Start()
        $speechTimer.Start()
        $weatherTimer.Start()
        $script:deferredWeatherTimer = [Windows.Threading.DispatcherTimer]::new()
        $script:deferredWeatherTimer.Interval = [TimeSpan]::FromMilliseconds(350)
        $script:deferredWeatherTimer.Add_Tick({
            $script:deferredWeatherTimer.Stop()
            try { Update-Weather } catch { Write-WidgetLog ("Deferred weather failed: " + $_.Exception.Message) }
        })
        $script:deferredWeatherTimer.Start()
        Write-WidgetLog "Independent movable desktop widget panels loaded."
    })

    $script:window.Add_Closed({
        foreach ($timer in @($clockTimer, $systemTimer, $script:lockWidgetTimer, $script:powerHistoryTimer, $script:deferredPowerHistoryTimer, $statusPulseTimer, $script:petAnimationTimer, $mediaTimer, $script:mediaVisualizerTimer, $script:mediaVisualizerStartTimer, $script:subtitleWarmupTimer, $script:virtualDesktopTimer, $script:cinemaModeTimer, $script:desktopSurfaceRestoreTimer, $script:photoPreviewPauseTimer, $script:photoFolderSyncTimer, $script:appUsageTimer, $script:modeDeckSaveTimer, $speechTimer, $weatherTimer, $script:speechIdleTimer, $script:todoSaveTimer, $script:deferredWeatherTimer)) {
            if ($null -ne $timer) { $timer.Stop() }
        }
        Save-WidgetLayout
        Save-TodoState
        Save-PhotoLibrary
        Save-AppUsageState
        Save-MediaHistory
        Stop-PhotoVideo
        Set-CinemaShellVisibility -Hidden $false
        Dispose-MediaSubtitles
        Dispose-SpeechRecognition
        Release-WidgetVirtualDesktopPins
        foreach ($widgetWindow in @($script:widgetWindows.Values)) {
            if ($null -ne $widgetWindow.Tag.LayoutSaveTimer) { $widgetWindow.Tag.LayoutSaveTimer.Stop() }
            if ($null -ne $widgetWindow -and $widgetWindow.IsVisible) { try { $widgetWindow.Close() } catch {} }
        }
        Write-WidgetLog "Independent movable desktop widget panels closed."
        $script:window.Dispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Background)
    })

    Write-WidgetLog "Starting independent movable desktop widget panels."
    $script:window.Show()
    [Windows.Threading.Dispatcher]::Run()
} catch {
    Write-WidgetLog ("Mac widget fatal error: " + $_.Exception.ToString())
    throw
} finally {
    Dispose-MediaSubtitles
    Dispose-SpeechRecognition
    if ($createdNew) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
}
