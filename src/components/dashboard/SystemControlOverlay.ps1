param(
    [switch]$SelfTest,
    [switch]$RenderPreview
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:xamlPath = $script:root + "\SystemControlOverlay.xaml"
$script:logDirectory = $script:root + "\logs"
$script:logPath = $script:logDirectory + "\control-overlay.log"

if (!(Test-Path -LiteralPath $script:logDirectory)) {
    New-Item -ItemType Directory -Path $script:logDirectory -Force | Out-Null
}

function Write-ControlOverlayLog {
    param([string]$Message)
    try {
        $line = "{0} {1}" -f ([DateTime]::Now.ToString("s")), $Message
        Add-Content -LiteralPath $script:logPath -Value $line -Encoding UTF8
    } catch {
    }
}

if (!(Test-Path -LiteralPath $script:xamlPath)) {
    Write-ControlOverlayLog "XAML file is missing."
    throw "SystemControlOverlay.xaml is missing."
}

if (!("ObsidianSystemControlNative" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ObsidianSystemControlNative
{
    enum EDataFlow { eRender, eCapture, eAll }
    enum ERole { eConsole, eMultimedia, eCommunications }

    [Flags]
    enum CLSCTX : uint
    {
        INPROC_SERVER = 0x1,
        INPROC_HANDLER = 0x2,
        LOCAL_SERVER = 0x4,
        REMOTE_SERVER = 0x10,
        ALL = INPROC_SERVER | INPROC_HANDLER | LOCAL_SERVER | REMOTE_SERVER
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorComObject { }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(EDataFlow dataFlow, int stateMask, out IntPtr devices);
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
        [PreserveSig] int GetState(out int state);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
    interface IAudioEndpointVolume
    {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int GetChannelCount(out uint channelCount);
        [PreserveSig] int SetMasterVolumeLevel(float levelDb, ref Guid eventContext);
        [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        [PreserveSig] int GetMasterVolumeLevel(out float levelDb);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
        [PreserveSig] int SetChannelVolumeLevel(uint channel, float levelDb, ref Guid eventContext);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid eventContext);
        [PreserveSig] int GetChannelVolumeLevel(uint channel, out float levelDb);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint channel, out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
        [PreserveSig] int GetVolumeStepInfo(out uint step, out uint stepCount);
        [PreserveSig] int VolumeStepUp(ref Guid eventContext);
        [PreserveSig] int VolumeStepDown(ref Guid eventContext);
        [PreserveSig] int QueryHardwareSupport(out uint hardwareSupportMask);
        [PreserveSig] int GetVolumeRange(out float minDb, out float maxDb, out float incrementDb);
    }

    static IAudioEndpointVolume endpointVolume;

    static bool EnsureEndpoint()
    {
        if (endpointVolume != null) return true;
        try
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            IMMDevice endpoint;
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out endpoint) != 0 || endpoint == null)
            {
                endpointVolume = null;
                return false;
            }

            Guid iid = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
            object instance;
            if (endpoint.Activate(ref iid, CLSCTX.ALL, IntPtr.Zero, out instance) != 0 || instance == null)
            {
                endpointVolume = null;
                return false;
            }
            endpointVolume = (IAudioEndpointVolume)instance;
            return endpointVolume != null;
        }
        catch
        {
            endpointVolume = null;
            return false;
        }
    }

    public static bool TryGetVolume(out float scalar, out bool muted)
    {
        scalar = 0f;
        muted = false;
        lock (typeof(ObsidianSystemControlNative))
        {
            if (!EnsureEndpoint()) return false;
            try
            {
                float value;
                bool isMuted;
                if (endpointVolume.GetMasterVolumeLevelScalar(out value) != 0 || endpointVolume.GetMute(out isMuted) != 0)
                {
                    endpointVolume = null;
                    return false;
                }
                scalar = Math.Max(0f, Math.Min(1f, value));
                muted = isMuted;
                return true;
            }
            catch
            {
                endpointVolume = null;
                return false;
            }
        }
    }

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    static extern int GetWindowLong(IntPtr windowHandle, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    static extern int SetWindowLong(IntPtr windowHandle, int index, int value);

    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr windowHandle, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr windowHandle, out uint processId);

    public static void ConfigureOverlayWindow(IntPtr windowHandle)
    {
        if (windowHandle == IntPtr.Zero) return;
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x00000080;
        const int WS_EX_NOACTIVATE = 0x08000000;
        const int WS_EX_TRANSPARENT = 0x00000020;
        int style = GetWindowLong(windowHandle, GWL_EXSTYLE);
        style |= WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT;
        SetWindowLong(windowHandle, GWL_EXSTYLE, style);
        SetWindowPos(windowHandle, IntPtr.Zero, 0, 0, 0, 0, 0x27);
    }
}
'@
}

function Import-ControlOverlayXaml {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($script:xamlPath)
    $reader = New-Object System.Xml.XmlNodeReader($xml)
    try {
        return [Windows.Markup.XamlReader]::Load($reader)
    } finally {
        $reader.Close()
    }
}

function Convert-ControlBrush {
    param([string]$Color)
    return [Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function New-ControlGradientBrush {
    param(
        [string]$StartColor,
        [string]$EndColor
    )
    $brush = New-Object Windows.Media.LinearGradientBrush
    $brush.StartPoint = [Windows.Point]::new(0, 0)
    $brush.EndPoint = [Windows.Point]::new(1, 0)

    $start = New-Object Windows.Media.GradientStop
    $start.Color = [Windows.Media.ColorConverter]::ConvertFromString($StartColor)
    $start.Offset = 0
    $brush.GradientStops.Add($start)

    $end = New-Object Windows.Media.GradientStop
    $end.Color = [Windows.Media.ColorConverter]::ConvertFromString($EndColor)
    $end.Offset = 1
    $brush.GradientStops.Add($end)
    return $brush
}

function Get-CurrentVolumeState {
    $scalar = 0.0
    $muted = $false
    $available = [ObsidianSystemControlNative]::TryGetVolume([ref]$scalar, [ref]$muted)
    $value = [int][Math]::Round(([double]$scalar * 100.0), 0)
    if ($muted) { $value = 0 }
    return [pscustomobject]@{
        Available = $available
        Value = [Math]::Max(0, [Math]::Min(100, $value))
        Muted = $muted
    }
}

$script:brightnessUnavailableLogged = $false

function Get-CurrentBrightnessState {
    try {
        $items = @()
        try {
            $items = @(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop)
        } catch {
            $items = @(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness -ErrorAction Stop)
        }
        if ($items.Count -gt 0) {
            $item = $items | Select-Object -First 1
            $value = [int]$item.CurrentBrightness
            return [pscustomobject]@{
                Available = $true
                Value = [Math]::Max(0, [Math]::Min(100, $value))
            }
        }
    } catch {
        if (!$script:brightnessUnavailableLogged) {
            Write-ControlOverlayLog ("Brightness read failed: " + $_.Exception.Message)
            $script:brightnessUnavailableLogged = $true
        }
    }

    if (!$script:brightnessUnavailableLogged) {
        Write-ControlOverlayLog "Brightness is not exposed by the active display."
        $script:brightnessUnavailableLogged = $true
    }
    return [pscustomobject]@{
        Available = $false
        Value = 0
    }
}

function Set-ControlOverlayPosition {
    if ($null -eq $script:window) { return }
    $area = [Windows.SystemParameters]::WorkArea
    $left = $area.Left + (($area.Width - $script:window.Width) / 2)
    $top = $area.Top + 24
    if ($left -lt $area.Left + 12) { $left = $area.Left + 12 }
    if ($top -lt $area.Top + 12) { $top = $area.Top + 12 }
    if ($top + $script:window.Height -gt $area.Bottom - 12) {
        $top = [Math]::Max($area.Top + 12, $area.Bottom - $script:window.Height - 12)
    }
    $script:window.Left = $left
    $script:window.Top = $top
}

function Set-ControlOverlayFillWidth {
    param([int]$Value)
    if ($null -eq $script:levelTrack -or $null -eq $script:levelFill) { return }
    $trackWidth = [double]$script:levelTrack.ActualWidth
    if ($trackWidth -le 1) { $trackWidth = 340 }
    $usableWidth = [Math]::Max(0, $trackWidth - 2)
    $script:levelFill.Width = $usableWidth * ([double]$Value / 100.0)
}

function Update-ControlOverlayVisual {
    param(
        [ValidateSet("brightness", "volume")]
        [string]$Kind,
        [int]$Value,
        [ValidateSet("up", "down", "steady")]
        [string]$Direction,
        [bool]$Muted = $false
    )

    $Value = [Math]::Max(0, [Math]::Min(100, $Value))
    $actualLabel = if ($Kind -eq "brightness") { "BRIGHTNESS" } else { "VOLUME" }
    # Match the supplied direction references: rising uses the Brightness artwork,
    # falling uses the Volume artwork. The small source line remains truthful.
    $referenceProfile = if ($Direction -eq "down") { "volume" } else { "brightness" }
    $script:titleText.Text = if ($referenceProfile -eq "brightness") { "Brightness" } else { "Volume" }
    $script:sourceText.Text = "SYSTEM " + $actualLabel
    $script:percentText.Text = ($Value.ToString() + "%")

    if ($Muted) {
        $script:directionText.Text = "x"
        $script:sourceText.Text = "SYSTEM VOLUME - MUTED"
    } elseif ($Direction -eq "up") {
        $script:directionText.Text = "^"
    } elseif ($Direction -eq "down") {
        $script:directionText.Text = "v"
    } else {
        $script:directionText.Text = "."
    }

    # The supplied references use a warm rising state and a cool falling state.
    # The title and icon still identify the real control being changed.
    if ($Direction -eq "up") {
        $fill = New-ControlGradientBrush "#FFFFF4B0" "#FFFFB51C"
        $accent = "#FFFFE37D"
        $shellBorder = "#F5FFF0C1"
    } elseif ($Direction -eq "down") {
        $fill = New-ControlGradientBrush "#FFE4FAFF" "#FF3AA7F0"
        $accent = "#FFB8EFFF"
        $shellBorder = "#F0C8F3FF"
    } elseif ($Kind -eq "brightness") {
        $fill = New-ControlGradientBrush "#FFFFF4B0" "#FFFFC52F"
        $accent = "#FFFFE37D"
        $shellBorder = "#E8FFF0C1"
    } else {
        $fill = New-ControlGradientBrush "#FFD9F6FF" "#FF4EADEB"
        $accent = "#FFB8EFFF"
        $shellBorder = "#E0C8F3FF"
    }

    $script:levelFill.Background = $fill
    $script:shell.BorderBrush = Convert-ControlBrush $shellBorder
    $script:directionText.Foreground = Convert-ControlBrush $accent
    $script:percentText.Foreground = Convert-ControlBrush "#FFFFFFFF"
    $script:titleText.Foreground = Convert-ControlBrush $(if ($referenceProfile -eq "brightness") { "#FFFFFFFF" } else { "#D8FFF5F0" })
    $buttonGlass = Convert-ControlBrush "#6A606469"
    $script:brightnessButton.Background = $buttonGlass
    $script:volumeButton.Background = $buttonGlass
    $script:brightnessButton.BorderBrush = Convert-ControlBrush $(if ($referenceProfile -eq "brightness") { $accent } else { "#B0FFFFFF" })
    $script:volumeButton.BorderBrush = Convert-ControlBrush $(if ($referenceProfile -eq "volume") { $accent } else { "#B0FFFFFF" })
    $script:brightnessButton.Foreground = Convert-ControlBrush $(if ($referenceProfile -eq "brightness") { "#FFFFFF00" } else { "#F5FFFFFF" })
    $script:volumeButton.Foreground = Convert-ControlBrush $(if ($referenceProfile -eq "volume") { "#FFDFFFEF" } else { "#F5FFFFFF" })

    $angle = -55 + (110 * ([double]$Value / 100.0))
    $script:dialNeedle.RenderTransform = [Windows.Media.RotateTransform]::new($angle, 48, 65)
    Set-ControlOverlayFillWidth -Value $Value
}

$script:window = $null
$script:levelTrack = $null
$script:levelFill = $null
$script:titleText = $null
$script:percentText = $null
$script:directionText = $null
$script:sourceText = $null
$script:shell = $null
$script:brightnessButton = $null
$script:volumeButton = $null
$script:dialNeedle = $null
$script:hideTimer = $null
$script:pollTimer = $null
$script:selfTestTimer = $null
$script:lastShownAt = [DateTime]::MinValue
$script:lastVolume = 0
$script:lastVolumeMuted = $false
$script:lastVolumeAvailable = $false
$script:lastBrightness = -1
$script:brightnessPollTicks = 0
$script:baselineReady = $false
$script:baselineLogged = $false
$script:volumeTransitionActive = $false
$script:volumeTransitionOrigin = 0
$script:volumeTransitionCurrent = 0
$script:volumeTransitionMinimum = 0
$script:volumeTransitionOriginMuted = $false
$script:volumeTransitionCurrentMuted = $false
$script:volumeTransitionWeChatForeground = $false
$script:volumeTransitionStartedAt = [DateTime]::MinValue
$script:volumeTransitionLastChangeAt = [DateTime]::MinValue
$script:lastOverlayKind = ""
$script:weChatVoiceGuardActive = $false
$script:weChatVoiceGuardUntil = [DateTime]::MinValue
$script:weChatVoiceGuardLastCheckAt = [DateTime]::MinValue
$script:weChatVoiceGuardLogged = $false

function Reset-VolumeTransition {
    $script:volumeTransitionActive = $false
    $script:volumeTransitionWeChatForeground = $false
    $script:volumeTransitionStartedAt = [DateTime]::MinValue
    $script:volumeTransitionLastChangeAt = [DateTime]::MinValue
}

function Test-WeChatForeground {
    try {
        $handle = [ObsidianSystemControlNative]::GetForegroundWindow()
        if ($handle -eq [IntPtr]::Zero) { return $false }

        [uint32]$processId = 0
        [void][ObsidianSystemControlNative]::GetWindowThreadProcessId($handle, [ref]$processId)
        if ($processId -eq 0) { return $false }

        $processName = (Get-Process -Id $processId -ErrorAction Stop).ProcessName
        return $processName -match '^(Weixin|WeChat|WeChatAppEx)$'
    } catch {
        return $false
    }
}

function Update-WeChatVoiceGuard {
    param([switch]$Force)

    $now = [DateTime]::UtcNow
    $elapsedMs = ($now - $script:weChatVoiceGuardLastCheckAt).TotalMilliseconds
    if ($Force -or $elapsedMs -ge 750) {
        $script:weChatVoiceGuardLastCheckAt = $now
        if (Test-WeChatForeground) {
            # Keep the guard briefly after the input host takes focus while WeChat
            # begins or finishes speech-to-text.
            $script:weChatVoiceGuardUntil = $now.AddSeconds(6)
        }
    }

    return $now -lt $script:weChatVoiceGuardUntil
}

function Update-VolumeTransition {
    param(
        [int]$Value,
        [bool]$Muted
    )

    $now = [DateTime]::UtcNow

    # Voice-to-text can make Windows apply communications attenuation. Treat
    # every volume transition while WeChat is active as non-user input, so the
    # desktop capsule never appears during dictation.
    $script:weChatVoiceGuardActive = Update-WeChatVoiceGuard -Force
    if ($script:weChatVoiceGuardActive) {
        if ($script:lastOverlayKind -eq "volume") {
            Hide-ControlOverlay
        }
        if (!$script:weChatVoiceGuardLogged) {
            Write-ControlOverlayLog "Suppressed volume capsule during WeChat voice-to-text guard."
            $script:weChatVoiceGuardLogged = $true
        }
        Reset-VolumeTransition
        return
    }

    if (!$script:volumeTransitionActive) {
        $script:volumeTransitionActive = $true
        $script:volumeTransitionOrigin = $script:lastVolume
        $script:volumeTransitionCurrent = $Value
        $script:volumeTransitionMinimum = [Math]::Min($script:lastVolume, $Value)
        $script:volumeTransitionOriginMuted = $script:lastVolumeMuted
        $script:volumeTransitionCurrentMuted = $Muted
        $script:volumeTransitionWeChatForeground = Test-WeChatForeground
        $script:volumeTransitionStartedAt = $now
        $script:volumeTransitionLastChangeAt = $now
    } elseif ($Value -ne $script:volumeTransitionCurrent -or $Muted -ne $script:volumeTransitionCurrentMuted) {
        if ($script:volumeTransitionWeChatForeground -and !(Test-WeChatForeground)) {
            $script:volumeTransitionWeChatForeground = $false
        }
        $script:volumeTransitionCurrent = $Value
        $script:volumeTransitionCurrentMuted = $Muted
        $script:volumeTransitionMinimum = [Math]::Min($script:volumeTransitionMinimum, $Value)
        $script:volumeTransitionLastChangeAt = $now
    }

    $ageMs = ($now - $script:volumeTransitionStartedAt).TotalMilliseconds
    $drop = $script:volumeTransitionOrigin - $script:volumeTransitionMinimum
    $returnedToOrigin = [Math]::Abs($Value - $script:volumeTransitionOrigin) -le 1

    # While WeChat is foreground, a large downward transition is its
    # communications attenuation. Hold it until the output returns instead of
    # showing a desktop volume capsule during voice-to-text input.
    if ($script:volumeTransitionWeChatForeground -and !$Muted -and
        !$script:volumeTransitionOriginMuted -and $drop -ge 20) {
        if ($returnedToOrigin) {
            Write-ControlOverlayLog ("Suppressed WeChat communications ducking; baseline=" + $script:volumeTransitionOrigin + "; minimum=" + $script:volumeTransitionMinimum + "; restored=" + $Value)
            Reset-VolumeTransition
        }
        return
    }

    # WeChat voice input can trigger Windows communications ducking: the output
    # briefly drops by a large amount and then returns to the prior value. This
    # is not a user volume action, so suppress only that short reversible pattern.
    if (!$Muted -and !$script:volumeTransitionOriginMuted -and
        $drop -ge 20 -and $returnedToOrigin -and $ageMs -le 6500) {
        Write-ControlOverlayLog ("Suppressed transient communications ducking; baseline=" + $script:volumeTransitionOrigin + "; minimum=" + $script:volumeTransitionMinimum + "; restored=" + $Value)
        Reset-VolumeTransition
        return
    }

    $quietMs = if ($drop -ge 20) { 4500 } else { 220 }
    $stableMs = ($now - $script:volumeTransitionLastChangeAt).TotalMilliseconds
    if ($stableMs -lt $quietMs -and $ageMs -lt 6500) { return }

    $changedFromOrigin = [Math]::Abs($Value - $script:volumeTransitionOrigin) -ge 1
    $muteChanged = $Muted -ne $script:volumeTransitionOriginMuted
    if ($changedFromOrigin -or $muteChanged) {
        $direction = if ($Value -gt $script:volumeTransitionOrigin -and !$Muted) { "up" } else { "down" }
        Show-ControlOverlay -Kind "volume" -Value $Value -Direction $direction -Muted $Muted
    }
    Reset-VolumeTransition
}

function Hide-ControlOverlay {
    if ($null -eq $script:window -or $script:window.Visibility -eq [Windows.Visibility]::Collapsed) { return }
    $fade = New-Object Windows.Media.Animation.DoubleAnimation
    $fade.From = [double]$script:window.Opacity
    $fade.To = 0
    $fade.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
    $fade.Add_Completed({
        if ($null -ne $script:window) {
            $script:window.Visibility = [Windows.Visibility]::Collapsed
            $script:window.BeginAnimation([Windows.Window]::OpacityProperty, $null)
            $script:window.Opacity = 0
        }
    })
    $script:window.BeginAnimation([Windows.Window]::OpacityProperty, $fade)
}

function Show-ControlOverlay {
    param(
        [string]$Kind,
        [int]$Value,
        [string]$Direction,
        [bool]$Muted = $false
    )
    if ($null -eq $script:window) { return }
    if ($Kind -eq "volume" -and $script:weChatVoiceGuardActive) { return }
    $script:lastOverlayKind = $Kind
    Update-ControlOverlayVisual -Kind $Kind -Value $Value -Direction $Direction -Muted $Muted
    Set-ControlOverlayPosition
    $script:lastShownAt = [DateTime]::UtcNow
    $script:window.Topmost = $true
    $script:window.Visibility = [Windows.Visibility]::Visible
    $script:window.Opacity = 0
    $script:window.BeginAnimation([Windows.Window]::OpacityProperty, $null)
    $fade = New-Object Windows.Media.Animation.DoubleAnimation
    $fade.From = 0
    $fade.To = 1
    $fade.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(160))
    $script:window.BeginAnimation([Windows.Window]::OpacityProperty, $fade)
    $script:window.Dispatcher.BeginInvoke([Action]{ Set-ControlOverlayFillWidth -Value $Value }) | Out-Null
    Write-ControlOverlayLog ("Shown kind=" + $Kind + "; value=" + $Value + "; direction=" + $Direction + "; muted=" + $Muted + "; left=" + [int]$script:window.Left + "; top=" + [int]$script:window.Top)
}

function Save-ControlOverlayPreview {
    param([string]$Path)
    $script:window.UpdateLayout()
    $width = [Math]::Max(1, [int]$script:window.ActualWidth)
    $height = [Math]::Max(1, [int]$script:window.ActualHeight)
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($width, $height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($script:window)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Create)
    try {
        $encoder.Save($stream)
    } finally {
        $stream.Dispose()
    }
}

function Update-ControlOverlayState {
    $script:weChatVoiceGuardActive = Update-WeChatVoiceGuard
    if (!$script:weChatVoiceGuardActive) {
        $script:weChatVoiceGuardLogged = $false
    }

    $volume = Get-CurrentVolumeState
    $brightness = $null
    $script:brightnessPollTicks++
    if ($script:brightnessPollTicks -ge 4 -or $script:lastBrightness -lt 0) {
        $script:brightnessPollTicks = 0
        $brightness = Get-CurrentBrightnessState
    }

    if (!$script:baselineReady) {
        if ($volume.Available) {
            $script:lastVolume = $volume.Value
            $script:lastVolumeMuted = $volume.Muted
            $script:lastVolumeAvailable = $true
        }
        if ($null -ne $brightness -and $brightness.Available) { $script:lastBrightness = $brightness.Value }
        if ($script:lastVolumeAvailable -or $script:lastBrightness -ge 0) {
            $script:baselineReady = $true
            if (!$script:baselineLogged) {
                Write-ControlOverlayLog ("Baseline volume=" + $script:lastVolume + "; brightness=" + $script:lastBrightness)
                $script:baselineLogged = $true
            }
        }
        return
    }

    if ($null -ne $brightness -and $brightness.Available -and $script:lastBrightness -ge 0) {
        if ([Math]::Abs($brightness.Value - $script:lastBrightness) -ge 1) {
            $direction = if ($brightness.Value -gt $script:lastBrightness) { "up" } else { "down" }
            Show-ControlOverlay -Kind "brightness" -Value $brightness.Value -Direction $direction
        }
        $script:lastBrightness = $brightness.Value
    } elseif ($null -ne $brightness -and $brightness.Available) {
        $script:lastBrightness = $brightness.Value
    }

    if ($volume.Available) {
        $volumeChanged = $false
        if ($script:lastVolumeAvailable) {
            $volumeChanged = [Math]::Abs($volume.Value - $script:lastVolume) -ge 1 -or
                ($volume.Muted -ne $script:lastVolumeMuted)
        }

        if ($volumeChanged -or $script:volumeTransitionActive) {
            Update-VolumeTransition -Value $volume.Value -Muted $volume.Muted
        }
        $script:lastVolume = $volume.Value
        $script:lastVolumeMuted = $volume.Muted
        $script:lastVolumeAvailable = $true
    }
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianAISystemControlOverlay", [ref]$createdNew)
if (!$createdNew) {
    exit 0
}

try {
    $script:window = Import-ControlOverlayXaml
    $script:levelTrack = $script:window.FindName("LevelTrack")
    $script:levelFill = $script:window.FindName("LevelFill")
    $script:titleText = $script:window.FindName("TitleText")
    $script:percentText = $script:window.FindName("PercentText")
    $script:directionText = $script:window.FindName("DirectionText")
    $script:sourceText = $script:window.FindName("SourceText")
    $script:shell = $script:window.FindName("Shell")
    $script:brightnessButton = $script:window.FindName("BrightnessButton")
    $script:volumeButton = $script:window.FindName("VolumeButton")
    $script:dialNeedle = $script:window.FindName("DialNeedle")

    $script:window.Add_SourceInitialized({
        param($sender, $eventArgs)
        try {
            $helper = [Windows.Interop.WindowInteropHelper]::new($sender)
            [ObsidianSystemControlNative]::ConfigureOverlayWindow($helper.Handle)
            Set-ControlOverlayPosition
        } catch {
            Write-ControlOverlayLog ("Window configuration failed: " + $_.Exception.Message)
        }
    })

    $script:hideTimer = New-Object Windows.Threading.DispatcherTimer
    $script:hideTimer.Interval = [TimeSpan]::FromMilliseconds(100)
    $script:hideTimer.Add_Tick({
        if ($script:window.Visibility -eq [Windows.Visibility]::Visible -and
            ([DateTime]::UtcNow - $script:lastShownAt).TotalMilliseconds -gt 1450) {
            Hide-ControlOverlay
        }
    })

    $script:pollTimer = New-Object Windows.Threading.DispatcherTimer
    $script:pollTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $script:pollTimer.Add_Tick({
        try { Update-ControlOverlayState } catch { Write-ControlOverlayLog ("State poll failed: " + $_.Exception.Message) }
    })

    $script:window.Add_Closed({
        if ($null -ne $script:hideTimer) { $script:hideTimer.Stop() }
        if ($null -ne $script:pollTimer) { $script:pollTimer.Stop() }
        if ($null -ne $script:selfTestTimer) { $script:selfTestTimer.Stop() }
        try { $script:window.Dispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Background) | Out-Null } catch {}
    })

    Set-ControlOverlayPosition
    Update-ControlOverlayVisual -Kind "brightness" -Value 52 -Direction "steady"
    $script:window.Show()
    $script:window.Visibility = [Windows.Visibility]::Collapsed
    $script:hideTimer.Start()

    if ($RenderPreview) {
        Write-ControlOverlayLog "Render preview started."
        $script:window.Visibility = [Windows.Visibility]::Visible
        $script:window.Opacity = 1
        Update-ControlOverlayVisual -Kind "brightness" -Value 52 -Direction "up"
        Save-ControlOverlayPreview -Path ($script:logDirectory + "\control-overlay-up.png")
        Update-ControlOverlayVisual -Kind "volume" -Value 53 -Direction "down"
        Save-ControlOverlayPreview -Path ($script:logDirectory + "\control-overlay-down.png")
        Write-ControlOverlayLog "Render preview completed."
        $script:window.Close()
    } elseif ($SelfTest) {
        Write-ControlOverlayLog "Self-test started."
        $script:selfTestStep = 0
        $script:selfTestTimer = New-Object Windows.Threading.DispatcherTimer
        $script:selfTestTimer.Interval = [TimeSpan]::FromMilliseconds(650)
        $script:selfTestTimer.Add_Tick({
            $script:selfTestStep++
            if ($script:selfTestStep -eq 1) {
                Show-ControlOverlay -Kind "brightness" -Value 52 -Direction "up"
            } elseif ($script:selfTestStep -eq 2) {
                Show-ControlOverlay -Kind "volume" -Value 53 -Direction "down"
            } else {
                $script:selfTestTimer.Stop()
                Write-ControlOverlayLog "Self-test completed."
                $script:window.Close()
            }
        })
        $script:selfTestTimer.Start()
    } else {
        $script:pollTimer.Start()
        Write-ControlOverlayLog "Control overlay started; native Windows OSD left enabled."
    }

    [Windows.Threading.Dispatcher]::Run()
} catch {
    Write-ControlOverlayLog ("Fatal error: " + $_.Exception.ToString())
    throw
} finally {
    if ($null -ne $script:window -and $script:window.IsVisible) { try { $script:window.Close() } catch {} }
    if ($createdNew) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
}
