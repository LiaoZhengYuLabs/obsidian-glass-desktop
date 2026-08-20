$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetRoot = $projectRoot + "\assets"
$logRoot = $projectRoot + "\logs"
$stateRoot = $projectRoot + "\state"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$logPath = $logRoot + "\sidebar.log"
$recentPath = $stateRoot + "\recent-apps.csv"
$windowStyleStatePath = $stateRoot + "\window-style-state.csv"
$appLayoutPath = $stateRoot + "\app-layout.json"

function Write-SidebarLog {
    param([string]$Message)
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + "  " + $Message
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($line + [Environment]::NewLine)
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $stream = $null
        try {
            $stream = New-Object IO.FileStream(
                $logPath,
                [IO.FileMode]::Append,
                [IO.FileAccess]::Write,
                [IO.FileShare]::ReadWrite
            )
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            return
        } catch {
            if ($attempt -lt 2) {
                Start-Sleep -Milliseconds 15
            }
        } finally {
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianAIWorkspace.Sidebar", [ref]$createdNew)
if (!$createdNew) {
    Write-SidebarLog "Another sidebar instance is already running."
    exit 0
}

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ObsidianNativeWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct NativeRect {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MonitorInfo {
        public int Size;
        public NativeRect Monitor;
        public NativeRect Work;
        public uint Flags;
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

    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
    public static extern IntPtr GetWindowLongPtr64(IntPtr hwnd, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
    public static extern IntPtr GetWindowLongPtr32(IntPtr hwnd, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
    public static extern IntPtr SetWindowLongPtr64(IntPtr hwnd, int index, IntPtr value);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong")]
    public static extern IntPtr SetWindowLongPtr32(IntPtr hwnd, int index, IntPtr value);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hwnd, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out NativeRect rect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [DllImport("gdi32.dll")]
    public static extern bool DeleteObject(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool QueryFullProcessImageName(IntPtr process, int flags, System.Text.StringBuilder path, ref int size);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    public static IntPtr GetWindowLongPtr(IntPtr hwnd, int index) {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hwnd, index) : GetWindowLongPtr32(hwnd, index);
    }

    public static IntPtr SetWindowLongPtr(IntPtr hwnd, int index, IntPtr value) {
        return IntPtr.Size == 8 ? SetWindowLongPtr64(hwnd, index, value) : SetWindowLongPtr32(hwnd, index, value);
    }

    public static string GetProcessImagePath(int processId) {
        IntPtr process = OpenProcess(0x1000, false, processId);
        if (process == IntPtr.Zero) return null;
        try {
            int size = 32768;
            var path = new System.Text.StringBuilder(size);
            return QueryFullProcessImageName(process, 0, path, ref size) ? path.ToString() : null;
        } finally {
            CloseHandle(process);
        }
    }

    public static bool IsBorderlessFullscreen(IntPtr hwnd) {
        long style = GetWindowLongPtr(hwnd, -16).ToInt64();
        if ((style & 0x00C00000L) != 0) return false;

        NativeRect windowRect;
        if (!GetWindowRect(hwnd, out windowRect)) return false;
        IntPtr monitor = MonitorFromWindow(hwnd, 2);
        if (monitor == IntPtr.Zero) return false;
        MonitorInfo info = new MonitorInfo();
        info.Size = Marshal.SizeOf(typeof(MonitorInfo));
        if (!GetMonitorInfo(monitor, ref info)) return false;

        return Math.Abs(windowRect.Left - info.Monitor.Left) <= 3 &&
               Math.Abs(windowRect.Top - info.Monitor.Top) <= 3 &&
               Math.Abs(windowRect.Right - info.Monitor.Right) <= 3 &&
               Math.Abs(windowRect.Bottom - info.Monitor.Bottom) <= 3;
    }
}

public sealed class ObsidianAppWindow {
    public IntPtr Handle { get; set; }
    public int ProcessId { get; set; }
    public string Title { get; set; }
    public string ClassName { get; set; }
}

public static class ObsidianAppScanner {
    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr state);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr state);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowTextLength(IntPtr hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hwnd, System.Text.StringBuilder text, int count);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr hwnd, uint command);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int size);

    public static ObsidianAppWindow[] GetVisibleWindows() {
        var windows = new System.Collections.Generic.List<ObsidianAppWindow>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr state) {
            if (!IsWindowVisible(hwnd) || GetWindow(hwnd, 4) != IntPtr.Zero) return true;

            int textLength = GetWindowTextLength(hwnd);
            if (textLength <= 0) return true;

            int cloaked = 0;
            try { DwmGetWindowAttribute(hwnd, 14, out cloaked, sizeof(int)); } catch { }
            if (cloaked != 0) return true;

            var title = new System.Text.StringBuilder(textLength + 1);
            GetWindowText(hwnd, title, title.Capacity);
            var className = new System.Text.StringBuilder(256);
            GetClassName(hwnd, className, className.Capacity);

            uint processId;
            GetWindowThreadProcessId(hwnd, out processId);
            windows.Add(new ObsidianAppWindow {
                Handle = hwnd,
                ProcessId = (int)processId,
                Title = title.ToString(),
                ClassName = className.ToString()
            });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}

public static class ObsidianDwmThumbnail {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Size {
        public int Width;
        public int Height;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Properties {
        public uint Flags;
        public Rect Destination;
        public Rect Source;
        public byte Opacity;
        [MarshalAs(UnmanagedType.Bool)] public bool Visible;
        [MarshalAs(UnmanagedType.Bool)] public bool SourceClientAreaOnly;
    }

    [DllImport("dwmapi.dll")]
    public static extern int DwmRegisterThumbnail(IntPtr destination, IntPtr source, out IntPtr thumbnail);

    [DllImport("dwmapi.dll")]
    public static extern int DwmUnregisterThumbnail(IntPtr thumbnail);

    [DllImport("dwmapi.dll")]
    public static extern int DwmUpdateThumbnailProperties(IntPtr thumbnail, ref Properties properties);

    [DllImport("dwmapi.dll")]
    public static extern int DwmQueryThumbnailSourceSize(IntPtr thumbnail, out Size size);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int size);

    [DllImport("dwmapi.dll")]
    public static extern int DwmFlush();
}
"@

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="ObsidianWindow"
        Title="Obsidian Stage Manager"
        Width="210"
        Height="820"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="False"
        Background="#090A0F"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="True"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True">
    <Grid x:Name="Root" Width="210" Height="820" Background="Transparent" ClipToBounds="True">
        <Border x:Name="GlassLayer"
                Margin="0,4,5,4"
                CornerRadius="0,24,24,0"
                BorderThickness="0,1,1,1"
                BorderBrush="#9A91A9CA">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#F007090E" Offset="0"/>
                    <GradientStop Color="#DD151A27" Offset="0.48"/>
                    <GradientStop Color="#F105070B" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Border.Effect>
                <DropShadowEffect BlurRadius="30" ShadowDepth="8" Direction="0" Opacity="0.72" Color="#365D91"/>
            </Border.Effect>
        </Border>

        <Ellipse x:Name="AmbientBloom"
                 Width="230"
                 Height="520"
                 Margin="-118,90,0,90"
                 HorizontalAlignment="Left"
                 VerticalAlignment="Stretch"
                 Opacity="0.34"
                 IsHitTestVisible="False">
            <Ellipse.Fill>
                <RadialGradientBrush RadiusX="0.5" RadiusY="0.5">
                    <GradientStop Color="#5A5B88C8" Offset="0"/>
                    <GradientStop Color="#263F5D90" Offset="0.48"/>
                    <GradientStop Color="#0010131A" Offset="1"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
            <Ellipse.Effect>
                <BlurEffect Radius="38"/>
            </Ellipse.Effect>
        </Ellipse>

        <Ellipse x:Name="Reflection"
                 Width="160"
                 Height="160"
                 Opacity="0"
                 HorizontalAlignment="Left"
                 VerticalAlignment="Top"
                 IsHitTestVisible="False">
            <Ellipse.RenderTransform>
                <TranslateTransform X="-80" Y="-80"/>
            </Ellipse.RenderTransform>
            <Ellipse.Fill>
                <RadialGradientBrush RadiusX="0.5" RadiusY="0.5">
                    <GradientStop Color="#4FDDE2F2" Offset="0"/>
                    <GradientStop Color="#153E4C68" Offset="0.42"/>
                    <GradientStop Color="#0010131A" Offset="1"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
            <Ellipse.Effect>
                <BlurEffect Radius="22"/>
            </Ellipse.Effect>
        </Ellipse>

        <Canvas x:Name="StageCanvas" Width="210" Height="820" Background="Transparent"/>
        <Canvas x:Name="IconCanvas" Width="1" Height="1" Visibility="Collapsed" IsHitTestVisible="False"/>

        <Border x:Name="EnergyRail"
                Width="2"
                Margin="0,28,7,28"
                HorizontalAlignment="Right"
                VerticalAlignment="Stretch"
                CornerRadius="1"
                Opacity="0.78"
                IsHitTestVisible="False">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                    <GradientStop Color="#007CDFFF" Offset="0"/>
                    <GradientStop Color="#D37CDFFF" Offset="0.28"/>
                    <GradientStop Color="#C8B79CFF" Offset="0.68"/>
                    <GradientStop Color="#00B79CFF" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Border.Effect>
                <DropShadowEffect BlurRadius="9" ShadowDepth="0" Opacity="0.85" Color="#6DAEFF"/>
            </Border.Effect>
        </Border>

        <Border x:Name="EdgeNotch"
                Width="7"
                Height="62"
                CornerRadius="4"
                HorizontalAlignment="Right"
                VerticalAlignment="Center"
                Margin="0,0,2,0"
                Opacity="0.88"
                IsHitTestVisible="False">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                    <GradientStop Color="#FFE4F4FF" Offset="0"/>
                    <GradientStop Color="#FF79CEFF" Offset="0.48"/>
                    <GradientStop Color="#FFB59DFF" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Border.Effect>
                <DropShadowEffect BlurRadius="12" ShadowDepth="0" Opacity="0.9" Color="#6BAEFF"/>
            </Border.Effect>
        </Border>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $root = $window.FindName("Root")
    $glassLayer = $window.FindName("GlassLayer")
    $ambientBloom = $window.FindName("AmbientBloom")
    $reflection = $window.FindName("Reflection")
    $reflectionTransform = [Windows.Media.TranslateTransform]$reflection.RenderTransform
    $iconCanvas = $window.FindName("IconCanvas")
    $stageCanvas = $window.FindName("StageCanvas")
    $energyRail = $window.FindName("EnergyRail")
    $edgeNotch = $window.FindName("EdgeNotch")

    [xml]$previewXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="PreviewWindow"
        Title="Obsidian AI Workspace Preview"
        Width="340"
        Height="240"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="False"
        Background="#08090D"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="True"
        Focusable="False"
        Opacity="0"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True">
    <Grid x:Name="PreviewRoot"
          Background="#08090D"
          ClipToBounds="True"
          RenderTransformOrigin="0.5,0.5">
        <Grid.RenderTransform>
            <ScaleTransform ScaleX="1" ScaleY="1"/>
        </Grid.RenderTransform>

        <Border x:Name="PreviewGlass"
                CornerRadius="22"
                BorderThickness="1"
                BorderBrush="#66777E8D">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#F007080C" Offset="0"/>
                    <GradientStop Color="#E90E1018" Offset="0.48"/>
                    <GradientStop Color="#F006070A" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Grid x:Name="PreviewMaterial" ClipToBounds="True">
                <Path Data="M 8,22 C 116,3 220,14 332,2"
                      Stroke="#224F638B"
                      StrokeThickness="28"
                      Opacity="0.42"
                      IsHitTestVisible="False">
                    <Path.Effect>
                        <BlurEffect Radius="20"/>
                    </Path.Effect>
                </Path>
                <Ellipse x:Name="PreviewReflection"
                         Width="180"
                         Height="180"
                         Opacity="0.24"
                         HorizontalAlignment="Left"
                         VerticalAlignment="Top"
                         IsHitTestVisible="False">
                    <Ellipse.RenderTransform>
                        <TranslateTransform X="-90" Y="-90"/>
                    </Ellipse.RenderTransform>
                    <Ellipse.Fill>
                        <RadialGradientBrush RadiusX="0.5" RadiusY="0.5">
                            <GradientStop Color="#58D8DAE7" Offset="0"/>
                            <GradientStop Color="#223F4564" Offset="0.42"/>
                            <GradientStop Color="#0010131A" Offset="1"/>
                        </RadialGradientBrush>
                    </Ellipse.Fill>
                    <Ellipse.Effect>
                        <BlurEffect Radius="24"/>
                    </Ellipse.Effect>
                </Ellipse>
            </Grid>
        </Border>

        <Canvas x:Name="PreviewCanvas" Background="Transparent"/>
    </Grid>
</Window>
"@

    $previewReader = New-Object System.Xml.XmlNodeReader($previewXaml)
    $previewWindow = [Windows.Markup.XamlReader]::Load($previewReader)
    $previewRoot = $previewWindow.FindName("PreviewRoot")
    $previewGlass = $previewWindow.FindName("PreviewGlass")
    $previewCanvas = $previewWindow.FindName("PreviewCanvas")
    $previewReflection = $previewWindow.FindName("PreviewReflection")
    $previewReflectionTransform = [Windows.Media.TranslateTransform]$previewReflection.RenderTransform
    $script:previewThumbnails = New-Object 'System.Collections.Generic.List[IntPtr]'
    $script:stageThumbnails = New-Object 'System.Collections.Generic.List[IntPtr]'
    $script:previewWindowShown = $false
    $script:previewVisible = $false
    $script:previewPendingButton = $null

    function Get-HardwareProfile {
        try {
            $profilePath = $stateRoot + "\hardware-profile.json"
            if (Test-Path -LiteralPath $profilePath) {
                $cachedProfile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
                $generatedAt = [DateTimeOffset]::Parse($cachedProfile.GeneratedAt)
                if ($generatedAt -gt [DateTimeOffset]::Now.AddDays(-7) -and
                    ![string]::IsNullOrWhiteSpace($cachedProfile.Quality)) {
                    $cachedProfile.BackdropType = if ($cachedProfile.Quality -eq "Efficiency") { 0 } else { 2 }
                    $cachedProfile | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $profilePath -Encoding UTF8
                    return $cachedProfile
                }
            }

            $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
            $computer = Get-CimInstance Win32_ComputerSystem
            $videoControllers = @(Get-CimInstance Win32_VideoController)
            $operatingSystem = Get-CimInstance Win32_OperatingSystem
            $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1

            $ramGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
            $displayController = $videoControllers |
                Where-Object { $_.CurrentHorizontalResolution -gt 0 } |
                Select-Object -First 1
            $refreshRate = if ($null -ne $displayController) { [int]$displayController.CurrentRefreshRate } else { 60 }
            $screenWidth = if ($null -ne $displayController) { [int]$displayController.CurrentHorizontalResolution } else { 0 }
            $screenHeight = if ($null -ne $displayController) { [int]$displayController.CurrentVerticalResolution } else { 0 }
            $gpuNames = @($videoControllers | ForEach-Object { $_.Name })
            $hasDiscreteGpu = @($gpuNames | Where-Object { $_ -match "NVIDIA|GeForce|Radeon RX|Arc A" }).Count -gt 0
            $vramMB = 0

            $nvidia = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
            if ($null -ne $nvidia) {
                $memoryText = & $nvidia.Source --query-gpu=memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1
                if ($memoryText -match "\d+") {
                    $vramMB = [int]$matches[0]
                }
            }

            $quality = "Balanced"
            if ($ramGB -ge 16 -and $hasDiscreteGpu -and $refreshRate -ge 60) {
                $quality = "High"
            } elseif ($ramGB -lt 8 -or (!$hasDiscreteGpu -and $refreshRate -lt 60)) {
                $quality = "Efficiency"
            }
            if ($null -ne $battery -and $battery.BatteryStatus -eq 1 -and $battery.EstimatedChargeRemaining -lt 25) {
                $quality = "Efficiency"
            }

            $profile = [pscustomobject]@{
                GeneratedAt = (Get-Date).ToString("o")
                Quality = $quality
                Cpu = $processor.Name.Trim()
                CpuCores = [int]$processor.NumberOfCores
                LogicalProcessors = [int]$processor.NumberOfLogicalProcessors
                MemoryGB = $ramGB
                Gpus = $gpuNames
                DedicatedVramMB = $vramMB
                ScreenWidth = $screenWidth
                ScreenHeight = $screenHeight
                RefreshRate = $refreshRate
                Windows = $operatingSystem.Caption
                WindowsBuild = $operatingSystem.BuildNumber
                NativeAnimations = [bool][Windows.SystemParameters]::ClientAreaAnimation
                BackdropType = if ($quality -eq "Efficiency") { 0 } else { 2 }
                StyleIntervalMs = if ($quality -eq "High") { 2500 } elseif ($quality -eq "Balanced") { 3500 } else { 5000 }
                PreviewCards = if ($quality -eq "High") { 6 } elseif ($quality -eq "Balanced") { 4 } else { 2 }
            }
            $profile | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $profilePath -Encoding UTF8
            return $profile
        } catch {
            Write-SidebarLog ("Hardware profile detection failed: " + $_.Exception.Message)
            return [pscustomobject]@{
                Quality = "Balanced"
                NativeAnimations = [bool][Windows.SystemParameters]::ClientAreaAnimation
                BackdropType = 2
                StyleIntervalMs = 3500
                PreviewCards = 4
            }
        }
    }

    $hardwareProfile = Get-HardwareProfile
    Write-SidebarLog ("Hardware profile: " + $hardwareProfile.Quality + ", backdrop " + $hardwareProfile.BackdropType + ", preview cards " + $hardwareProfile.PreviewCards + ".")

    function Get-LargestIconFrame {
        param([string]$Path)
        if (!(Test-Path -LiteralPath $Path)) {
            throw "Icon is missing: $Path"
        }

        $stream = [IO.File]::OpenRead($Path)
        try {
            $decoder = [Windows.Media.Imaging.IconBitmapDecoder]::new(
                $stream,
                [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
                [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            )
            $frame = $decoder.Frames | Sort-Object PixelWidth -Descending | Select-Object -First 1
            $frame.Freeze()
            return $frame
        } finally {
            $stream.Dispose()
        }
    }

    function New-Ease {
        $ease = [Windows.Media.Animation.CubicEase]::new()
        $ease.EasingMode = [Windows.Media.Animation.EasingMode]::EaseOut
        return $ease
    }

    $animationsEnabled = [Windows.SystemParameters]::ClientAreaAnimation -and $hardwareProfile.Quality -ne "Efficiency"
    $hoverSeconds = if ($animationsEnabled) { 0.24 } else { 0.01 }
    $slideSeconds = if ($animationsEnabled) { 0.28 } else { 0.01 }

    function Animate-Scale {
        param(
            [Windows.FrameworkElement]$Element,
            [double]$Target
        )
        $transform = [Windows.Media.ScaleTransform]$Element.RenderTransform
        $animationX = [Windows.Media.Animation.DoubleAnimation]::new()
        $animationX.To = $Target
        $animationX.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds($hoverSeconds))
        $animationX.EasingFunction = New-Ease
        $animationY = $animationX.Clone()
        $transform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $animationX)
        $transform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $animationY)
    }

    function Animate-BrushColor {
        param(
            [Windows.Media.SolidColorBrush]$Brush,
            [Windows.Media.Color]$Target
        )
        $animation = [Windows.Media.Animation.ColorAnimation]::new()
        $animation.To = $Target
        $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds($hoverSeconds))
        $animation.EasingFunction = New-Ease
        $Brush.BeginAnimation([Windows.Media.SolidColorBrush]::ColorProperty, $animation)
    }

    $script:iconSourceCache = @{}

    function Get-ExecutableIconFrame {
        param([string]$Path)

        $resolvedPath = $Path
        if ([string]::IsNullOrWhiteSpace($resolvedPath) -or !(Test-Path -LiteralPath $resolvedPath)) {
            $resolvedPath = $env:WINDIR + "\explorer.exe"
        }

        $cacheKey = $resolvedPath.ToLowerInvariant()
        if ($script:iconSourceCache.ContainsKey($cacheKey)) {
            return $script:iconSourceCache[$cacheKey]
        }

        $icon = $null
        try {
            $icon = [Drawing.Icon]::ExtractAssociatedIcon($resolvedPath)
            if ($null -eq $icon) {
                throw "Windows did not expose an icon."
            }
            $options = [Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(64, 64)
            $source = [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
                $icon.Handle,
                [Windows.Int32Rect]::Empty,
                $options
            )
            $source.Freeze()
            $script:iconSourceCache[$cacheKey] = $source
            return $source
        } catch {
            Write-SidebarLog ("Icon extraction failed for " + $resolvedPath + ": " + $_.Exception.Message)
            if ($resolvedPath -ne ($env:WINDIR + "\explorer.exe")) {
                return Get-ExecutableIconFrame -Path ($env:WINDIR + "\explorer.exe")
            }
            throw
        } finally {
            if ($null -ne $icon) {
                $icon.Dispose()
            }
        }
    }

    function Resolve-ShortcutTarget {
        param([string]$Path)
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($Path)
            return [pscustomobject]@{
                Target = $shortcut.TargetPath
                Icon = ($shortcut.IconLocation -split ",")[0]
            }
        } catch {
            return [pscustomobject]@{ Target = $Path; Icon = "" }
        }
    }

    function Get-EntryIconFrame {
        param(
            [string]$IconPath,
            [string]$TargetPath
        )

        $candidate = $IconPath
        if ([string]::IsNullOrWhiteSpace($candidate) -or !(Test-Path -LiteralPath $candidate)) {
            $candidate = $TargetPath
        }
        if (![string]::IsNullOrWhiteSpace($candidate) -and $candidate.EndsWith(".lnk", [StringComparison]::OrdinalIgnoreCase)) {
            $shortcut = Resolve-ShortcutTarget -Path $candidate
            if (![string]::IsNullOrWhiteSpace($shortcut.Icon) -and (Test-Path -LiteralPath $shortcut.Icon)) {
                $candidate = $shortcut.Icon
            } else {
                $candidate = $shortcut.Target
            }
        }

        $extension = [IO.Path]::GetExtension($candidate)
        if ($extension -ieq ".ico") {
            return Get-LargestIconFrame -Path $candidate
        }
        if ($extension -in @(".png", ".jpg", ".jpeg", ".bmp")) {
            try {
                $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
                $bitmap.BeginInit()
                $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bitmap.UriSource = [Uri]::new($candidate)
                $bitmap.EndInit()
                $bitmap.Freeze()
                return $bitmap
            } catch { }
        }
        return Get-ExecutableIconFrame -Path $candidate
    }

    function New-AppTooltip {
        param(
            [string]$Name,
            [string]$State
        )

        $tip = [Windows.Controls.ToolTip]::new()
        $tip.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Right
        $tip.HorizontalOffset = 12
        $tip.Padding = [Windows.Thickness]::new(0)
        $tip.Background = [Windows.Media.Brushes]::Transparent
        $tip.BorderThickness = [Windows.Thickness]::new(0)
        $tip.HasDropShadow = $false

        $tipText = [Windows.Controls.TextBlock]::new()
        $tipText.Text = if ([string]::IsNullOrWhiteSpace($State)) { $Name } else { $State + "  " + $Name }
        $tipText.Foreground = [Windows.Media.Brushes]::White
        $tipText.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $tipText.FontSize = 12

        $tipSurface = [Windows.Controls.Border]::new()
        $tipSurface.Padding = [Windows.Thickness]::new(10, 5, 10, 5)
        $tipSurface.CornerRadius = [Windows.CornerRadius]::new(8)
        $tipSurface.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#ED0A0B0F"))
        $tipSurface.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#526B7180"))
        $tipSurface.BorderThickness = [Windows.Thickness]::new(1)
        $tipSurface.Child = $tipText
        $tip.Content = $tipSurface
        return $tip
    }

    function Activate-AppWindow {
        param([IntPtr]$Handle)

        if ($Handle -eq [IntPtr]::Zero) {
            return $false
        }

        $currentHandle = [ObsidianNativeWindow]::GetForegroundWindow()
        if ($currentHandle -ne [IntPtr]::Zero -and $currentHandle -ne $Handle) {
            [uint32]$currentProcessId = 0
            [ObsidianNativeWindow]::GetWindowThreadProcessId($currentHandle, [ref]$currentProcessId) | Out-Null
            try {
                $currentProcess = Get-Process -Id $currentProcessId -ErrorAction Stop
                if ($currentProcess.ProcessName -in @("ChatGPT", "Codex")) {
                    $currentStyle = [ObsidianNativeWindow]::GetWindowLongPtr($currentHandle, -20).ToInt64()
                    if (($currentStyle -band 0x8) -ne 0) {
                        $noMoveNoActivate = [uint32]0x0613
                        [ObsidianNativeWindow]::SetWindowPos($currentHandle, [IntPtr]::new(-2), 0, 0, 0, 0, $noMoveNoActivate) | Out-Null
                        Write-SidebarLog "Released Codex always-on-top state before app switching."
                    }
                }
            } catch {
                Write-SidebarLog ("Could not inspect current window before switching: " + $_.Exception.Message)
            }
        }

        if ([ObsidianNativeWindow]::IsIconic($Handle)) {
            [ObsidianNativeWindow]::ShowWindowAsync($Handle, 9) | Out-Null
        } else {
            [ObsidianNativeWindow]::ShowWindowAsync($Handle, 5) | Out-Null
        }
        return [ObsidianNativeWindow]::SetForegroundWindow($Handle)
    }

    function Clear-PreviewThumbnails {
        foreach ($thumbnail in @($script:previewThumbnails.ToArray())) {
            if ($thumbnail -ne [IntPtr]::Zero) {
                [ObsidianDwmThumbnail]::DwmUnregisterThumbnail($thumbnail) | Out-Null
            }
        }
        $script:previewThumbnails.Clear()
    }

    function Get-WindowBitmapSource {
        param([IntPtr]$Handle)

        if ($Handle -eq [IntPtr]::Zero -or ![ObsidianNativeWindow]::IsWindow($Handle)) {
            return $null
        }

        $rect = New-Object ObsidianNativeWindow+NativeRect
        if (![ObsidianNativeWindow]::GetWindowRect($Handle, [ref]$rect)) {
            return $null
        }
        $width = [Math]::Max(1, $rect.Right - $rect.Left)
        $height = [Math]::Max(1, $rect.Bottom - $rect.Top)
        if ($width -gt 4096 -or $height -gt 4096) {
            return $null
        }

        $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppPArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $hdc = [IntPtr]::Zero
        $hBitmap = [IntPtr]::Zero
        try {
            $hdc = $graphics.GetHdc()
            $captured = [ObsidianNativeWindow]::PrintWindow($Handle, $hdc, 2)
            $graphics.ReleaseHdc($hdc)
            $hdc = [IntPtr]::Zero
            if (!$captured) {
                return $null
            }

            $hBitmap = $bitmap.GetHbitmap()
            $source = [Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap(
                $hBitmap,
                [IntPtr]::Zero,
                [Windows.Int32Rect]::Empty,
                [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
            )
            $source.Freeze()
            return $source
        } catch {
            Write-SidebarLog ("Window preview capture failed: " + $_.Exception.Message)
            return $null
        } finally {
            if ($hdc -ne [IntPtr]::Zero) {
                $graphics.ReleaseHdc($hdc)
            }
            if ($hBitmap -ne [IntPtr]::Zero) {
                [ObsidianNativeWindow]::DeleteObject($hBitmap) | Out-Null
            }
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }

    function Update-MinimizedPreviewFrame {
        if ($null -eq $script:previewCaptureImage -or $script:previewCaptureHandle -eq [IntPtr]::Zero) {
            return $false
        }
        $source = Get-WindowBitmapSource -Handle $script:previewCaptureHandle
        if ($null -eq $source) {
            return $false
        }
        $script:previewCaptureImage.Source = $source
        return $true
    }

    function Get-LivePreviewWindows {
        param([Windows.FrameworkElement]$Button)

        $staleWindows = @($Button.Tag.WindowInfos)
        $matchedApp = $null
        try {
            $snapshot = @(Get-RunningAppSnapshot)
            $key = [string]$Button.Tag.Key
            if (![string]::IsNullOrWhiteSpace($key)) {
                $matchedApp = @($snapshot | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
            }

            # Fixed entries can use a layout key instead of the executable path.
            # Resolve those entries through the process behind the old handle.
            if (($null -eq $matchedApp -or @($matchedApp).Count -eq 0) -and $staleWindows.Count -gt 0) {
                $oldHandle = [IntPtr]$staleWindows[0].Handle
                if ($oldHandle -ne [IntPtr]::Zero -and [ObsidianNativeWindow]::IsWindow($oldHandle)) {
                    $oldProcessId = Get-WindowProcessId -Handle $oldHandle
                    $oldProcess = Get-Process -Id $oldProcessId -ErrorAction SilentlyContinue
                    if ($null -ne $oldProcess) {
                        $matchedApp = @($snapshot | Where-Object { $_.ProcessName -eq $oldProcess.ProcessName } | Select-Object -First 1)
                    }
                }
            }

            if ($null -ne $matchedApp -and @($matchedApp).Count -gt 0) {
                $Button.Tag.WindowInfos = @($matchedApp[0].Windows)
                $Button.Tag.WindowHandles = @($matchedApp[0].Handles)
                return @($matchedApp[0].Windows)
            }
        } catch {
            Write-SidebarLog ("Live preview window refresh failed: " + $_.Exception.Message)
        }

        return $staleWindows
    }

    function Select-PreferredPreviewWindow {
        param([array]$Windows)

        $candidates = @($Windows | Where-Object {
                $_.Handle -ne [IntPtr]::Zero -and [ObsidianNativeWindow]::IsWindow([IntPtr]$_.Handle)
            })
        if ($candidates.Count -eq 0) { return $null }

        $ranked = @()
        foreach ($candidate in $candidates) {
            $rect = New-Object ObsidianNativeWindow+NativeRect
            $area = 0L
            if ([ObsidianNativeWindow]::GetWindowRect([IntPtr]$candidate.Handle, [ref]$rect)) {
                $width = [Math]::Max(0, $rect.Right - $rect.Left)
                $height = [Math]::Max(0, $rect.Bottom - $rect.Top)
                $area = [long]$width * [long]$height
            }

            $score = [double]$area
            if (![ObsidianNativeWindow]::IsIconic([IntPtr]$candidate.Handle)) {
                $score += 1000000
            }
            # WeChat exposes small helper/login windows with the title "Weixin".
            # The exact Chinese title is the real main window, even when minimized.
            if ([string]$candidate.Title -eq "微信") {
                $score += 100000000
            }
            $ranked += [pscustomobject]@{ Info = $candidate; Score = $score }
        }

        return @($ranked | Sort-Object Score -Descending | Select-Object -First 1 | ForEach-Object { $_.Info })
    }

    function Clear-StageThumbnails {
        foreach ($thumbnail in @($script:stageThumbnails.ToArray())) {
            if ($thumbnail -ne [IntPtr]::Zero) {
                [ObsidianDwmThumbnail]::DwmUnregisterThumbnail($thumbnail) | Out-Null
            }
        }
        $script:stageThumbnails.Clear()
    }

    function Set-PreviewThumbnail {
        param(
            [IntPtr]$DestinationHandle,
            [IntPtr]$SourceHandle,
            [double]$Left,
            [double]$Top,
            [double]$Width,
            [double]$Height,
            [double]$ScaleX,
            [double]$ScaleY,
            $ThumbnailCollection
        )

        if ($DestinationHandle -eq [IntPtr]::Zero -or
            $SourceHandle -eq [IntPtr]::Zero -or
            ![ObsidianNativeWindow]::IsWindow($SourceHandle)) {
            Write-SidebarLog ("DWM thumbnail skipped for invalid source or destination handle: " + $SourceHandle + ".")
            return $false
        }

        $thumbnail = [IntPtr]::Zero
        $result = [ObsidianDwmThumbnail]::DwmRegisterThumbnail(
            $DestinationHandle,
            $SourceHandle,
            [ref]$thumbnail
        )
        if ($result -ne 0 -or $thumbnail -eq [IntPtr]::Zero) {
            Write-SidebarLog ("DWM thumbnail registration failed with HRESULT " + $result + " for source " + $SourceHandle + ".")
            return $false
        }

        $sourceSize = New-Object ObsidianDwmThumbnail+Size
        $sizeResult = [ObsidianDwmThumbnail]::DwmQueryThumbnailSourceSize($thumbnail, [ref]$sourceSize)
        if ($sizeResult -ne 0 -or $sourceSize.Width -le 0 -or $sourceSize.Height -le 0) {
            [ObsidianDwmThumbnail]::DwmUnregisterThumbnail($thumbnail) | Out-Null
            Write-SidebarLog ("DWM thumbnail source size unavailable for " + $SourceHandle + ".")
            return $false
        }
        $fitWidth = $Width
        $fitHeight = $Height
        if ($sourceSize.Width -gt 0 -and $sourceSize.Height -gt 0) {
            $sourceRatio = $sourceSize.Width / [double]$sourceSize.Height
            $slotRatio = $Width / [double]$Height
            if ($sourceRatio -gt $slotRatio) {
                $fitHeight = $Width / $sourceRatio
            } else {
                $fitWidth = $Height * $sourceRatio
            }
        }

        $destinationLeft = [int][Math]::Round(($Left + (($Width - $fitWidth) / 2)) * $ScaleX)
        $destinationTop = [int][Math]::Round(($Top + (($Height - $fitHeight) / 2)) * $ScaleY)
        $destinationWidth = [int][Math]::Round($fitWidth * $ScaleX)
        $destinationHeight = [int][Math]::Round($fitHeight * $ScaleY)

        $destination = New-Object ObsidianDwmThumbnail+Rect
        $destination.Left = $destinationLeft
        $destination.Top = $destinationTop
        $destination.Right = $destinationLeft + $destinationWidth
        $destination.Bottom = $destinationTop + $destinationHeight

        $properties = New-Object ObsidianDwmThumbnail+Properties
        $properties.Flags = 1 -bor 4 -bor 8 -bor 16
        $properties.Destination = $destination
        $properties.Opacity = 255
        $properties.Visible = $true
        $properties.SourceClientAreaOnly = $false
        $updateResult = [ObsidianDwmThumbnail]::DwmUpdateThumbnailProperties($thumbnail, [ref]$properties)
        if ($updateResult -ne 0) {
            [ObsidianDwmThumbnail]::DwmUnregisterThumbnail($thumbnail) | Out-Null
            Write-SidebarLog ("DWM thumbnail update failed with HRESULT " + $updateResult + " for source " + $SourceHandle + ".")
            return $false
        }
        if ($null -eq $ThumbnailCollection) {
            $script:previewThumbnails.Add($thumbnail) | Out-Null
        } else {
            $ThumbnailCollection.Add($thumbnail) | Out-Null
        }
        return $true
    }

    function New-PreviewCard {
        param(
            $WindowInfo,
            [double]$Left,
            [double]$Top,
            [double]$Width,
            [double]$ThumbnailHeight
        )

        $card = [Windows.Controls.Border]::new()
        $card.Width = $Width
        $card.Height = $ThumbnailHeight + 40
        $card.CornerRadius = [Windows.CornerRadius]::new(14)
        $card.BorderThickness = [Windows.Thickness]::new(1)
        $card.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#586D7484"))
        $card.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#B808090D"))
        $card.Cursor = [Windows.Input.Cursors]::Hand
        $card.Tag = @{
            Handle = [IntPtr]$WindowInfo.Handle
            Title = $WindowInfo.Title
        }

        $content = [Windows.Controls.Grid]::new()
        $captureImage = [Windows.Controls.Image]::new()
        $captureImage.Margin = [Windows.Thickness]::new(6, 6, 6, 40)
        $captureImage.Stretch = [Windows.Media.Stretch]::Uniform
        $captureImage.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
        $captureImage.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
        [Windows.Media.RenderOptions]::SetBitmapScalingMode($captureImage, [Windows.Media.BitmapScalingMode]::HighQuality)
        $content.Children.Add($captureImage) | Out-Null

        $titleSurface = [Windows.Controls.Border]::new()
        $titleSurface.Height = 32
        $titleSurface.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
        $titleSurface.Margin = [Windows.Thickness]::new(6, 0, 6, 5)
        $titleSurface.CornerRadius = [Windows.CornerRadius]::new(8)
        $titleSurface.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#D30A0B0F"))

        $title = [Windows.Controls.TextBlock]::new()
        $title.Text = $WindowInfo.Title
        $title.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#E8E9EBF1"))
        $title.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $title.FontSize = 11.5
        $title.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
        $title.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $title.Margin = [Windows.Thickness]::new(10, 0, 10, 0)
        $titleSurface.Child = $title
        $content.Children.Add($titleSurface) | Out-Null
        $card.Child = $content
        $card.Tag.CaptureImage = $captureImage

        $card.Add_MouseEnter({
            param($sender, $eventArgs)
            $sender.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#A1A7B5D4"))
            $previewReflection.Opacity = 0.36
        })
        $card.Add_MouseLeave({
            param($sender, $eventArgs)
            $sender.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#586D7484"))
            $previewReflection.Opacity = 0.24
        })
        $card.Add_MouseLeftButtonUp({
            param($sender, $eventArgs)
            Activate-AppWindow -Handle ([IntPtr]$sender.Tag.Handle) | Out-Null
            Write-SidebarLog ("Activated preview window: " + $sender.Tag.Title)
            Hide-AppPreview
            $eventArgs.Handled = $true
        })

        [Windows.Controls.Canvas]::SetLeft($card, $Left)
        [Windows.Controls.Canvas]::SetTop($card, $Top)
        $previewCanvas.Children.Add($card) | Out-Null
        return $card
    }

    function Show-AppPreview {
        param([Windows.FrameworkElement]$Button)

        $availableWindows = @(Get-LivePreviewWindows -Button $Button)
        $windowInfos = @(Select-PreferredPreviewWindow -Windows $availableWindows)
        if ($windowInfos.Count -eq 0) {
            Hide-AppPreview
            return
        }

        $previewOpenTimer.Stop()
        $previewHideTimer.Stop()
        $previewCloseTimer.Stop()
        Clear-PreviewThumbnails
        $previewCanvas.Children.Clear()

        $columns = 1
        $rows = 1
        $cardWidth = 460.0
        $thumbnailHeight = 270.0
        $cardHeight = $thumbnailHeight + 40
        $padding = 12.0
        $gap = 10.0
        $previewWidth = ($padding * 2) + ($columns * $cardWidth) + (($columns - 1) * $gap)
        $previewHeight = ($padding * 2) + ($rows * $cardHeight) + (($rows - 1) * $gap)

        $previewWindow.Width = $previewWidth
        $previewWindow.Height = $previewHeight
        $previewRoot.Width = $previewWidth
        $previewRoot.Height = $previewHeight
        $previewCanvas.Width = $previewWidth
        $previewCanvas.Height = $previewHeight

        $anchor = $Button.TranslatePoint([Windows.Point]::new(0, 0), $window)
        $anchorCenter = $window.Top + $anchor.Y + ($Button.ActualHeight / 2)
        $workArea = [Windows.SystemParameters]::WorkArea
        $previewWindow.Left = [Math]::Min(
            $workArea.Right - $previewWidth - 12,
            [Math]::Max(98, $window.Left + $window.Width + 10)
        )
        $previewWindow.Top = [Math]::Max(
            $workArea.Top + 12,
            [Math]::Min($workArea.Bottom - $previewHeight - 12, $anchorCenter - ($previewHeight / 2))
        )

        $layouts = @()
        for ($index = 0; $index -lt $windowInfos.Count; $index++) {
            $row = [Math]::Floor($index / $columns)
            $column = $index % $columns
            $left = $padding + ($column * ($cardWidth + $gap))
            $top = $padding + ($row * ($cardHeight + $gap))
            $card = New-PreviewCard -WindowInfo $windowInfos[$index] -Left $left -Top $top -Width $cardWidth -ThumbnailHeight $thumbnailHeight
            $layouts += [pscustomobject]@{
                Window = $windowInfos[$index]
                CaptureImage = $card.Tag.CaptureImage
                Left = $left + 6
                Top = $top + 6
                Width = $cardWidth - 12
                Height = $thumbnailHeight - 8
            }
        }

        if (!$script:previewWindowShown) {
            $previewWindow.Show()
            $script:previewWindowShown = $true
        } elseif (!$previewWindow.IsVisible) {
            $previewWindow.Show()
        }
        $previewWindow.UpdateLayout()

        $helper = [Windows.Interop.WindowInteropHelper]::new($previewWindow)
        $destinationHandle = $helper.Handle
        $source = [Windows.PresentationSource]::FromVisual($previewWindow)
        $scaleX = 1.0
        $scaleY = 1.0
        if ($null -ne $source -and $null -ne $source.CompositionTarget) {
            $matrix = $source.CompositionTarget.TransformToDevice
            $scaleX = $matrix.M11
            $scaleY = $matrix.M22
        }

        $script:previewCaptureHandle = [IntPtr]::Zero
        $script:previewCaptureImage = $null
        foreach ($layout in $layouts) {
            $sourceHandle = [IntPtr]$layout.Window.Handle
            # Paint one current frame immediately so the card is never blank while
            # DWM attaches its live thumbnail. The same frame is also the fallback
            # for windows that reject DWM thumbnails (Chromium/Store windows can do so).
            $initialFrame = Get-WindowBitmapSource -Handle $sourceHandle
            if ($null -ne $initialFrame) {
                $layout.CaptureImage.Source = $initialFrame
            }

            $script:previewCaptureHandle = [IntPtr]::Zero
            $script:previewCaptureImage = $null
            $thumbnailAttached = Set-PreviewThumbnail `
                -DestinationHandle $destinationHandle `
                -SourceHandle $sourceHandle `
                -Left $layout.Left `
                -Top $layout.Top `
                -Width $layout.Width `
                -Height $layout.Height `
                -ScaleX $scaleX `
                -ScaleY $scaleY
            if (!$thumbnailAttached) {
                $script:previewCaptureHandle = $sourceHandle
                $script:previewCaptureImage = $layout.CaptureImage
                if ($null -eq $initialFrame) {
                    Update-MinimizedPreviewFrame | Out-Null
                }
            }
        }
        [ObsidianDwmThumbnail]::DwmFlush() | Out-Null
        if ($script:previewCaptureHandle -ne [IntPtr]::Zero -and $null -ne $script:previewCaptureImage) {
            $previewCaptureTimer.Stop()
            $previewCaptureTimer.Start()
        }

        $previewScale = [Windows.Media.ScaleTransform]$previewRoot.RenderTransform
        $previewScale.ScaleX = 1.0
        $previewScale.ScaleY = 1.0
        $opacityAnimation = [Windows.Media.Animation.DoubleAnimation]::new()
        $opacityAnimation.To = 1.0
        $opacityAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($(if ($animationsEnabled) { 135 } else { 1 })))
        $opacityAnimation.EasingFunction = New-Ease
        $previewWindow.BeginAnimation([Windows.Window]::OpacityProperty, $opacityAnimation)
        $script:previewVisible = $true
        Write-SidebarLog ("Preview shown for " + $Button.Tag.Name + ": " + $windowInfos.Count + " window(s).")
    }

    function Hide-AppPreview {
        $previewOpenTimer.Stop()
        $previewCaptureTimer.Stop()
        $script:previewPendingButton = $null
        if (!$script:previewVisible -or !$previewWindow.IsVisible) {
            return
        }
        $script:previewVisible = $false
        $opacityAnimation = [Windows.Media.Animation.DoubleAnimation]::new()
        $opacityAnimation.To = 0.0
        $opacityAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($(if ($animationsEnabled) { 110 } else { 1 })))
        $opacityAnimation.EasingFunction = New-Ease
        $previewWindow.BeginAnimation([Windows.Window]::OpacityProperty, $opacityAnimation)
        $previewCloseTimer.Stop()
        $previewCloseTimer.Start()
    }

    function Schedule-AppPreview {
        param([Windows.FrameworkElement]$Button)
        $script:previewPendingButton = $Button
        $previewHideTimer.Stop()
        $previewOpenTimer.Stop()
        $previewOpenTimer.Start()
    }

    function Schedule-HideAppPreview {
        $previewOpenTimer.Stop()
        $script:previewPendingButton = $null
        $previewHideTimer.Stop()
        $previewHideTimer.Start()
    }

    function New-AppButton {
        param(
            [string]$Name,
            [Windows.Media.ImageSource]$IconSource,
            [string]$LaunchPath,
            [string]$State,
            [double]$Size,
            [double]$IconSize,
            [string]$StatusColor,
            [string]$Key,
            [string]$EntryId,
            [string]$Kind,
            [string]$IconPath
        )

        $border = [Windows.Controls.Border]::new()
        $border.Width = $Size
        $border.Height = $Size
        $border.CornerRadius = [Windows.CornerRadius]::new($Size / 2)
        $border.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
        $border.RenderTransform = [Windows.Media.ScaleTransform]::new(1, 1)
        $border.Cursor = [Windows.Input.Cursors]::Hand
        $background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#16000000"))
        $border.Background = $background

        $content = [Windows.Controls.Grid]::new()
        $image = [Windows.Controls.Image]::new()
        $image.Width = $IconSize
        $image.Height = $IconSize
        $image.Stretch = [Windows.Media.Stretch]::Uniform
        $image.Source = $IconSource
        $image.SnapsToDevicePixels = $true
        $content.Children.Add($image) | Out-Null

        $indicator = [Windows.Shapes.Ellipse]::new()
        $indicator.Width = 5
        $indicator.Height = 5
        $indicator.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
        $indicator.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
        $indicator.Margin = [Windows.Thickness]::new(4, 0, 0, 4)
        $indicator.Fill = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($StatusColor))
        $indicator.Opacity = if ($State -eq "RUNNING") { 0.95 } else { 0.0 }
        $content.Children.Add($indicator) | Out-Null

        $border.Child = $content
        $border.ToolTip = New-AppTooltip -Name $Name -State $State
        [Windows.Controls.ToolTipService]::SetInitialShowDelay($border, 260)
        [Windows.Controls.ToolTipService]::SetBetweenShowDelay($border, 80)
        [Windows.Controls.ToolTipService]::SetShowDuration($border, 5000)

        $border.Tag = @{
            Name = $Name
            LaunchPath = $LaunchPath
            Background = $background
            Indicator = $indicator
            WindowHandles = @()
            WindowInfos = @()
            State = $State
            Key = $Key
            EntryId = $EntryId
            Kind = $Kind
            IconPath = $IconPath
        }

        $border.Add_MouseEnter({
            param($sender, $eventArgs)
            Animate-Scale -Element $sender -Target 1.12
            Animate-BrushColor -Brush $sender.Tag.Background -Target ([Windows.Media.ColorConverter]::ConvertFromString("#66383B46"))
            $reflection.Opacity = 0.42
            if (@($sender.Tag.WindowInfos).Count -gt 0) {
                [Windows.Controls.ToolTipService]::SetIsEnabled($sender, $false)
                Schedule-AppPreview -Button $sender
            }
        })

        $border.Add_MouseLeave({
            param($sender, $eventArgs)
            Animate-Scale -Element $sender -Target 1.0
            Animate-BrushColor -Brush $sender.Tag.Background -Target ([Windows.Media.ColorConverter]::ConvertFromString("#16000000"))
            $reflection.Opacity = 0.28
            [Windows.Controls.ToolTipService]::SetIsEnabled($sender, $true)
            Schedule-HideAppPreview
        })

        $border.Add_MouseLeftButtonUp({
            param($sender, $eventArgs)
            try {
                $handles = @($sender.Tag.WindowHandles)
                if ($handles.Count -gt 0) {
                    Activate-AppWindow -Handle ([IntPtr]$handles[0]) | Out-Null
                    Write-SidebarLog ("Activated " + $sender.Tag.Name)
                    Hide-AppPreview
                } elseif (![string]::IsNullOrWhiteSpace($sender.Tag.LaunchPath)) {
                    Start-Process -FilePath $sender.Tag.LaunchPath
                    Write-SidebarLog ("Launched " + $sender.Tag.Name)
                }
            } catch {
                Write-SidebarLog ("App action failed for " + $sender.Tag.Name + ": " + $_.Exception.Message)
            }
            $eventArgs.Handled = $true
        })
        $border.Add_MouseRightButtonUp({
            param($sender, $eventArgs)
            Write-SidebarLog ("App context menu opened: " + $sender.Tag.Name)
            Hide-AppPreview
            $menu = New-AppContextMenu -Button $sender
            $sender.ContextMenu = $menu
            $menu.IsOpen = $true
            $eventArgs.Handled = $true
        })
        return $border
    }

    function New-SectionSeparator {
        param(
            [double]$Top,
            [string]$Color
        )
        $line = [Windows.Controls.Border]::new()
        $line.Width = 44
        $line.Height = 1
        $line.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($Color))
        $line.Opacity = 0.54
        [Windows.Controls.Canvas]::SetLeft($line, 23)
        [Windows.Controls.Canvas]::SetTop($line, $Top)
        $iconCanvas.Children.Add($line) | Out-Null
    }

    function New-AppRegion {
        param(
            [double]$Top,
            [double]$Height
        )

        $panel = [Windows.Controls.StackPanel]::new()
        $panel.Width = 74
        $panel.HorizontalAlignment = [Windows.HorizontalAlignment]::Center

        $viewer = [Windows.Controls.ScrollViewer]::new()
        $viewer.Width = 74
        $viewer.Height = $Height
        $viewer.Background = [Windows.Media.Brushes]::Transparent
        $viewer.BorderThickness = [Windows.Thickness]::new(0)
        $viewer.HorizontalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Disabled
        $viewer.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Hidden
        $viewer.PanningMode = [Windows.Controls.PanningMode]::VerticalOnly
        $viewer.Content = $panel
        [Windows.Controls.Canvas]::SetLeft($viewer, 0)
        [Windows.Controls.Canvas]::SetTop($viewer, $Top)
        $iconCanvas.Children.Add($viewer) | Out-Null
        return $panel
    }

    # The localized folder can differ from its display name; resolve the GitHub PWA link by search.
    $githubLaunch = Find-ObsidianGlassShortcut -Name "GitHub"
    if ([string]::IsNullOrWhiteSpace($githubLaunch)) { $githubLaunch = "https://github.com" }
    $chatGptLaunch = Find-ObsidianGlassShortcut -Name "ChatGPT"
    if ([string]::IsNullOrWhiteSpace($chatGptLaunch)) { $chatGptLaunch = "https://chatgpt.com" }
    $codexLaunch = Find-ObsidianGlassShortcut -Name "Codex"
    if ([string]::IsNullOrWhiteSpace($codexLaunch)) { $codexLaunch = "https://chatgpt.com/codex" }
    $vscodeLaunch = Find-ObsidianGlassShortcut -Name "Visual Studio Code"
    if ([string]::IsNullOrWhiteSpace($vscodeLaunch)) {
        $codeCommand = Get-Command code.exe -ErrorAction SilentlyContinue
        if ($null -ne $codeCommand) { $vscodeLaunch = $codeCommand.Source }
    }
    $chromeLaunch = Find-ObsidianGlassShortcut -Name "Google Chrome"
    if ([string]::IsNullOrWhiteSpace($chromeLaunch)) {
        $chromeCommand = Get-Command chrome.exe -ErrorAction SilentlyContinue
        if ($null -ne $chromeCommand) { $chromeLaunch = $chromeCommand.Source }
    }

    function New-DefaultAppLayout {
        $entries = @(
            [pscustomobject]@{ Id = "builtin.chatgpt"; Name = "ChatGPT"; Target = $chatGptLaunch; IconPath = ($assetRoot + "\ChatGPT.ico"); Kind = "Application"; Pinned = $true; BuiltIn = $true; Removed = $false; Order = 0; ProcessNames = @("ChatGPT"); TitlePattern = ""; MatchKey = "" },
            [pscustomobject]@{ Id = "builtin.codex"; Name = "Codex"; Target = $codexLaunch; IconPath = ($assetRoot + "\Codex.ico"); Kind = "Application"; Pinned = $true; BuiltIn = $true; Removed = $false; Order = 1; ProcessNames = @("Codex"); TitlePattern = ""; MatchKey = "" },
            [pscustomobject]@{ Id = "builtin.vscode"; Name = "Visual Studio Code"; Target = $vscodeLaunch; IconPath = ($assetRoot + "\Visual Studio Code.ico"); Kind = "Application"; Pinned = $true; BuiltIn = $true; Removed = $false; Order = 2; ProcessNames = @("Code"); TitlePattern = ""; MatchKey = "" },
            [pscustomobject]@{ Id = "builtin.github"; Name = "GitHub"; Target = $githubLaunch; IconPath = ($assetRoot + "\GitHub.ico"); Kind = "Website"; Pinned = $true; BuiltIn = $true; Removed = $false; Order = 3; ProcessNames = @("chrome"); TitlePattern = "GitHub"; MatchKey = "" },
            [pscustomobject]@{ Id = "builtin.chrome"; Name = "Google Chrome"; Target = $chromeLaunch; IconPath = ($assetRoot + "\Google Chrome.ico"); Kind = "Application"; Pinned = $true; BuiltIn = $true; Removed = $false; Order = 4; ProcessNames = @("chrome"); TitlePattern = ""; MatchKey = "" }
        )
        return [pscustomobject]@{
            Version = 1
            Entries = $entries
            HiddenKeys = @()
            Overrides = @()
        }
    }

    function Save-AppLayout {
        $script:appLayout | ConvertTo-Json -Depth 8 |
            Set-Content -LiteralPath $appLayoutPath -Encoding UTF8
    }

    function Load-AppLayout {
        if (!(Test-Path -LiteralPath $appLayoutPath)) {
            $layout = New-DefaultAppLayout
            $layout | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $appLayoutPath -Encoding UTF8
            return $layout
        }
        try {
            $layout = Get-Content -LiteralPath $appLayoutPath -Raw | ConvertFrom-Json
            $layout.Entries = @($layout.Entries)
            $layout.HiddenKeys = @($layout.HiddenKeys)
            $layout.Overrides = @($layout.Overrides)
            return $layout
        } catch {
            Write-SidebarLog ("App layout could not be loaded; defaults restored: " + $_.Exception.Message)
            $layout = New-DefaultAppLayout
            $layout | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $appLayoutPath -Encoding UTF8
            return $layout
        }
    }

    function Get-AppOverride {
        param([string]$Key)
        return @($script:appLayout.Overrides | Where-Object { $_.Key -eq $Key }) | Select-Object -First 1
    }

    function Set-AppOverride {
        param(
            [string]$Key,
            [string]$Name,
            [string]$IconPath
        )
        $existing = Get-AppOverride -Key $Key
        if ($null -eq $existing) {
            $existing = [pscustomobject]@{ Key = $Key; Name = ""; IconPath = "" }
            $script:appLayout.Overrides = @($script:appLayout.Overrides) + @($existing)
        }
        if ($null -ne $Name) { $existing.Name = $Name }
        if ($null -ne $IconPath) { $existing.IconPath = $IconPath }
        Save-AppLayout
    }

    $fixedAppsPanel = New-AppRegion -Top 8 -Height 220
    New-SectionSeparator -Top 234 -Color "#566F7690"
    $currentAppsPanel = New-AppRegion -Top 241 -Height 140
    New-SectionSeparator -Top 389 -Color "#384B5161"
    $recentAppsPanel = New-AppRegion -Top 396 -Height 116

    $script:appLayout = Load-AppLayout
    $script:fixedDefinitions = @()
    $script:fixedButtons = @{}

    function Render-FixedApps {
        $fixedAppsPanel.Children.Clear()
        $script:fixedButtons = @{}
        $script:fixedDefinitions = @(
            $script:appLayout.Entries |
                Where-Object { $_.Pinned -and !$_.Removed } |
                Sort-Object Order
        )
        $offsets = @(-2, 3, -3, 3, -2)
        $index = 0
        foreach ($definition in $script:fixedDefinitions) {
            $key = if (![string]::IsNullOrWhiteSpace($definition.MatchKey)) { $definition.MatchKey } else { $definition.Target.ToLowerInvariant() }
            $button = New-AppButton -Name $definition.Name `
                -IconSource (Get-EntryIconFrame -IconPath $definition.IconPath -TargetPath $definition.Target) `
                -LaunchPath $definition.Target `
                -State "" `
                -Size 50 `
                -IconSize 36 `
                -StatusColor "#B8BFCBFF" `
                -Key $key `
                -EntryId $definition.Id `
                -Kind $definition.Kind `
                -IconPath $definition.IconPath
            $button.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
            $offset = $offsets[$index % $offsets.Count]
            $button.Margin = [Windows.Thickness]::new($offset, 0, -$offset, 0)
            $fixedAppsPanel.Children.Add($button) | Out-Null
            $script:fixedButtons[$definition.Id] = $button
            $index++
        }
    }

    Render-FixedApps

    function Get-LayoutEntry {
        param([string]$Id)
        return @($script:appLayout.Entries | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    }

    function Refresh-ApplicationUi {
        Render-FixedApps
        $script:recentApps = @($script:recentApps | Where-Object {
                $recent = $_
                $processName = [IO.Path]::GetFileNameWithoutExtension($recent.Path)
                $isFixed = $false
                foreach ($definition in $script:fixedDefinitions) {
                    if ((![string]::IsNullOrWhiteSpace($definition.MatchKey) -and $definition.MatchKey -eq $recent.Key) -or
                        (@($definition.ProcessNames) -contains $processName)) {
                        $isFixed = $true
                        break
                    }
                }
                !$isFixed
            })
        Save-RecentApps
        $script:runtimeSignature = ""
        Refresh-AppRuntime
    }

    function Show-ObsidianInputDialog {
        param(
            [string]$Title,
            [string]$Label,
            [string]$InitialValue
        )

        [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Obsidian AI Workspace"
        Width="390"
        Height="178"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        ShowInTaskbar="False"
        Topmost="True"
        WindowStartupLocation="CenterScreen">
    <Border CornerRadius="18"
            Background="#F20A0B0F"
            BorderBrush="#747A8291"
            BorderThickness="1"
            Padding="18">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="42"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock x:Name="DialogLabel"
                       Text=""
                       Foreground="#E7E8EBF2"
                       FontFamily="Segoe UI Variable Text"
                       FontSize="13"
                       Margin="2,0,0,8"/>
            <TextBox x:Name="DialogText"
                     Grid.Row="1"
                     Text=""
                     Foreground="White"
                     Background="#D515171D"
                     BorderBrush="#59657087"
                     BorderThickness="1"
                     Padding="10,7"
                     FontFamily="Segoe UI Variable Text"
                     FontSize="13"/>
            <StackPanel Grid.Row="2"
                        Orientation="Horizontal"
                        HorizontalAlignment="Right"
                        Margin="0,12,0,0">
                <Button x:Name="CancelButton"
                        Content="Cancel"
                        Width="76"
                        Height="30"
                        Margin="0,0,8,0"
                        Foreground="#D7D9DFE8"
                        Background="#1F252B35"
                        BorderBrush="#4B555F70"/>
                <Button x:Name="OkButton"
                        Content="OK"
                        Width="76"
                        Height="30"
                        Foreground="White"
                        Background="#46506A86"
                        BorderBrush="#7D899BB7"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
        $dialogReader = New-Object System.Xml.XmlNodeReader($dialogXaml)
        $dialog = [Windows.Markup.XamlReader]::Load($dialogReader)
        $dialog.Title = $Title
        $dialog.FindName("DialogLabel").Text = $Label
        $textBox = $dialog.FindName("DialogText")
        $textBox.Text = $InitialValue
        $okButton = $dialog.FindName("OkButton")
        $cancelButton = $dialog.FindName("CancelButton")
        $result = @{ Value = $null }
        $okButton.Add_Click({
            $result.Value = $textBox.Text.Trim()
            $dialog.DialogResult = $true
            $dialog.Close()
        })
        $cancelButton.Add_Click({ $dialog.Close() })
        $dialog.Add_KeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.Key -eq [Windows.Input.Key]::Enter) {
                $result.Value = $textBox.Text.Trim()
                $dialog.DialogResult = $true
                $dialog.Close()
            } elseif ($eventArgs.Key -eq [Windows.Input.Key]::Escape) {
                $dialog.Close()
            }
        })
        $dialog.Add_Loaded({ $textBox.Focus() | Out-Null; $textBox.SelectAll() })
        try {
            $dialog.ShowDialog() | Out-Null
        } finally {
            Resume-SidebarAfterDialog
        }
        return $result.Value
    }

    function Get-TargetProcessName {
        param([string]$Target)
        $resolved = $Target
        if ($Target.EndsWith(".lnk", [StringComparison]::OrdinalIgnoreCase)) {
            $resolved = (Resolve-ShortcutTarget -Path $Target).Target
        }
        if ([string]::IsNullOrWhiteSpace($resolved) -or !(Test-Path -LiteralPath $resolved)) {
            return ""
        }
        return [IO.Path]::GetFileNameWithoutExtension($resolved)
    }

    function Add-PinnedLayoutEntry {
        param(
            [string]$Name,
            [string]$Target,
            [string]$IconPath,
            [string]$Kind,
            [string]$MatchKey
        )

        $existing = @($script:appLayout.Entries | Where-Object { $_.Target -eq $Target }) | Select-Object -First 1
        if ($null -ne $existing) {
            $existing.Pinned = $true
            $existing.Removed = $false
            Save-AppLayout
            Refresh-ApplicationUi
            return
        }

        $orders = @($script:appLayout.Entries | ForEach-Object { [int]$_.Order })
        $nextOrder = if ($orders.Count) { ($orders | Measure-Object -Maximum).Maximum + 1 } else { 0 }
        $processName = if ($Kind -eq "Application") { Get-TargetProcessName -Target $Target } else { "" }
        $entry = [pscustomobject]@{
            Id = "custom." + [Guid]::NewGuid().ToString("N")
            Name = $Name
            Target = $Target
            IconPath = $IconPath
            Kind = $Kind
            Pinned = $true
            BuiltIn = $false
            Removed = $false
            Order = $nextOrder
            ProcessNames = if ([string]::IsNullOrWhiteSpace($processName)) { @() } else { @($processName) }
            TitlePattern = ""
            MatchKey = $MatchKey
        }
        $script:appLayout.Entries = @($script:appLayout.Entries) + @($entry)
        $script:appLayout.HiddenKeys = @($script:appLayout.HiddenKeys | Where-Object { $_ -ne $MatchKey })
        Save-AppLayout
        Refresh-ApplicationUi
        Write-SidebarLog ("Pinned custom entry: " + $Name)
    }

    function Select-CustomIcon {
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Title = "Choose an icon or image"
        $dialog.Filter = "Icon and image files|*.ico;*.png;*.jpg;*.jpeg;*.bmp;*.exe;*.lnk|All files|*.*"
        try {
            if ($dialog.ShowDialog() -eq $true) {
                return $dialog.FileName
            }
        } finally {
            Resume-SidebarAfterDialog
        }
        return $null
    }

    function Invoke-RenameEntry {
        param([Windows.FrameworkElement]$Button)
        $newName = Show-ObsidianInputDialog -Title "Rename" -Label "Display name" -InitialValue $Button.Tag.Name
        if ([string]::IsNullOrWhiteSpace($newName)) { return }
        if (![string]::IsNullOrWhiteSpace($Button.Tag.EntryId)) {
            $entry = Get-LayoutEntry -Id $Button.Tag.EntryId
            if ($null -ne $entry) { $entry.Name = $newName; Save-AppLayout }
        } else {
            Set-AppOverride -Key $Button.Tag.Key -Name $newName -IconPath $null
        }
        Refresh-ApplicationUi
        Write-SidebarLog ("Renamed sidebar entry to: " + $newName)
    }

    function Invoke-ChangeEntryIcon {
        param([Windows.FrameworkElement]$Button)
        $iconPath = Select-CustomIcon
        if ([string]::IsNullOrWhiteSpace($iconPath)) { return }
        if (![string]::IsNullOrWhiteSpace($Button.Tag.EntryId)) {
            $entry = Get-LayoutEntry -Id $Button.Tag.EntryId
            if ($null -ne $entry) { $entry.IconPath = $iconPath; Save-AppLayout }
        } else {
            Set-AppOverride -Key $Button.Tag.Key -Name $null -IconPath $iconPath
        }
        Refresh-ApplicationUi
        Write-SidebarLog ("Changed sidebar icon: " + $Button.Tag.Name)
    }

    function Invoke-TogglePinEntry {
        param([Windows.FrameworkElement]$Button)
        if (![string]::IsNullOrWhiteSpace($Button.Tag.EntryId)) {
            $entry = Get-LayoutEntry -Id $Button.Tag.EntryId
            if ($null -ne $entry) {
                $entry.Pinned = !$entry.Pinned
                $entry.Removed = $false
                Save-AppLayout
                Refresh-ApplicationUi
                $pinAction = "Unpinned sidebar entry: "
                if ($entry.Pinned) {
                    $pinAction = "Pinned sidebar entry: "
                }
                Write-SidebarLog ($pinAction + $entry.Name)
            }
            return
        }
        Add-PinnedLayoutEntry -Name $Button.Tag.Name `
            -Target $Button.Tag.LaunchPath `
            -IconPath $Button.Tag.IconPath `
            -Kind "Application" `
            -MatchKey $Button.Tag.Key
    }

    function Invoke-RemoveEntry {
        param([Windows.FrameworkElement]$Button)
        if (![string]::IsNullOrWhiteSpace($Button.Tag.EntryId)) {
            $entry = Get-LayoutEntry -Id $Button.Tag.EntryId
            if ($null -ne $entry) {
                if ($entry.BuiltIn) {
                    $entry.Removed = $true
                    $entry.Pinned = $false
                } else {
                    $script:appLayout.Entries = @($script:appLayout.Entries | Where-Object { $_.Id -ne $entry.Id })
                }
            }
        } elseif (![string]::IsNullOrWhiteSpace($Button.Tag.Key)) {
            if ($script:appLayout.HiddenKeys -notcontains $Button.Tag.Key) {
                $script:appLayout.HiddenKeys = @($script:appLayout.HiddenKeys) + @($Button.Tag.Key)
            }
            $script:recentApps = @($script:recentApps | Where-Object { $_.Key -ne $Button.Tag.Key })
            Save-RecentApps
        }
        Save-AppLayout
        Refresh-ApplicationUi
        Write-SidebarLog ("Removed sidebar entry: " + $Button.Tag.Name)
    }

    function Invoke-OpenEntryLocation {
        param([Windows.FrameworkElement]$Button)
        $target = $Button.Tag.LaunchPath
        if ([string]::IsNullOrWhiteSpace($target)) { return }
        if ($target -match "^https?://") {
            Start-Process $target
        } elseif (Test-Path -LiteralPath $target -PathType Container) {
            Start-Process explorer.exe -ArgumentList ('"' + $target + '"')
        } elseif (Test-Path -LiteralPath $target) {
            Start-Process explorer.exe -ArgumentList ('/select,"' + $target + '"')
        }
        Write-SidebarLog ("Opened entry location: " + $Button.Tag.Name)
    }

    function Resume-SidebarAfterDialog {
        if ($null -ne $runtimeTimer -and !$runtimeTimer.IsEnabled) {
            $runtimeTimer.Start()
        }
        if ($null -ne $hideTimer) {
            $hideTimer.Stop()
            if (!$window.IsMouseOver) {
                $hideTimer.Start()
            }
        }
        Write-SidebarLog "Native dialog closed; sidebar monitoring active."
    }

    function Get-DarkMenuItemTemplate {
        if ($null -ne $script:darkMenuItemTemplate) {
            return $script:darkMenuItemTemplate
        }
        [xml]$templateXaml = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type MenuItem}">
    <Border Background="{TemplateBinding Background}"
            CornerRadius="6"
            Padding="{TemplateBinding Padding}">
        <ContentPresenter ContentSource="Header"
                          RecognizesAccessKey="True"
                          VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
        $reader = New-Object System.Xml.XmlNodeReader($templateXaml)
        $script:darkMenuItemTemplate = [Windows.Markup.XamlReader]::Load($reader)
        return $script:darkMenuItemTemplate
    }

    function New-DarkMenuItem {
        param(
            [string]$Header,
            [scriptblock]$Action
        )
        $item = [Windows.Controls.MenuItem]::new()
        $item.Header = $Header
        $item.Foreground = [Windows.Media.Brushes]::White
        $item.Background = [Windows.Media.Brushes]::Transparent
        $item.Padding = [Windows.Thickness]::new(12, 7, 18, 7)
        $item.Template = Get-DarkMenuItemTemplate
        $item.Add_MouseEnter({
            param($sender, $eventArgs)
            $sender.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#3B384252"))
        })
        $item.Add_MouseLeave({
            param($sender, $eventArgs)
            $sender.Background = [Windows.Media.Brushes]::Transparent
        })
        $item.Add_Click($Action)
        return $item
    }

    function New-DarkMenuDivider {
        $divider = [Windows.Controls.Border]::new()
        $divider.Height = 1
        $divider.Margin = [Windows.Thickness]::new(8, 4, 8, 4)
        $divider.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#46515B6D"))
        $divider.IsHitTestVisible = $false
        return $divider
    }

    function Get-DarkContextMenuTemplate {
        if ($null -ne $script:darkContextMenuTemplate) {
            return $script:darkContextMenuTemplate
        }
        [xml]$templateXaml = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type ContextMenu}">
    <Border Background="{TemplateBinding Background}"
            BorderBrush="{TemplateBinding BorderBrush}"
            BorderThickness="{TemplateBinding BorderThickness}"
            CornerRadius="8"
            Padding="{TemplateBinding Padding}">
        <StackPanel IsItemsHost="True"
                    KeyboardNavigation.DirectionalNavigation="Cycle"/>
    </Border>
</ControlTemplate>
"@
        $reader = New-Object System.Xml.XmlNodeReader($templateXaml)
        $script:darkContextMenuTemplate = [Windows.Markup.XamlReader]::Load($reader)
        return $script:darkContextMenuTemplate
    }

    function New-ObsidianContextMenu {
        $menu = [Windows.Controls.ContextMenu]::new()
        $menu.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#F20A0B0F"))
        $menu.Foreground = [Windows.Media.Brushes]::White
        $menu.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#68737F91"))
        $menu.BorderThickness = [Windows.Thickness]::new(1)
        $menu.Padding = [Windows.Thickness]::new(4)
        $menu.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $menu.FontSize = 12
        $menu.Template = Get-DarkContextMenuTemplate
        $menu.Add_Opened({
            $hideTimer.Stop()
            Show-Sidebar
        })
        $menu.Add_Closed({
            if (!$window.IsMouseOver) {
                $hideTimer.Stop()
                $hideTimer.Start()
            }
        })
        return $menu
    }

    function New-AppContextMenu {
        param([Windows.FrameworkElement]$Button)
        $menu = New-ObsidianContextMenu
        $entry = if (![string]::IsNullOrWhiteSpace($Button.Tag.EntryId)) { Get-LayoutEntry -Id $Button.Tag.EntryId } else { $null }
        $pinHeader = if ($null -ne $entry -and $entry.Pinned) { "Unpin" } else { "Pin" }
        $menu.Items.Add((New-DarkMenuItem -Header $pinHeader -Action { Invoke-TogglePinEntry -Button $Button }.GetNewClosure())) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Rename..." -Action { Invoke-RenameEntry -Button $Button }.GetNewClosure())) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Change icon..." -Action { Invoke-ChangeEntryIcon -Button $Button }.GetNewClosure())) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Open file location" -Action { Invoke-OpenEntryLocation -Button $Button }.GetNewClosure())) | Out-Null
        $menu.Items.Add((New-DarkMenuDivider)) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Remove" -Action { Invoke-RemoveEntry -Button $Button }.GetNewClosure())) | Out-Null
        return $menu
    }

    function Invoke-AddApplication {
        Write-SidebarLog "Add application dialog requested."
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Title = "Add application"
        $dialog.Filter = "Applications and shortcuts|*.exe;*.lnk|All files|*.*"
        try {
            $dialogResult = $dialog.ShowDialog()
        } catch {
            Write-SidebarLog ("Add application dialog failed: " + $_.Exception.Message)
            return
        } finally {
            Resume-SidebarAfterDialog
        }
        if ($dialogResult -ne $true) { Write-SidebarLog "Add application dialog cancelled."; return }
        $name = [IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
        $resolved = if ($dialog.FileName.EndsWith(".lnk", [StringComparison]::OrdinalIgnoreCase)) { (Resolve-ShortcutTarget -Path $dialog.FileName).Target } else { $dialog.FileName }
        $key = if (![string]::IsNullOrWhiteSpace($resolved)) { $resolved.ToLowerInvariant() } else { $dialog.FileName.ToLowerInvariant() }
        Add-PinnedLayoutEntry -Name $name -Target $dialog.FileName -IconPath $dialog.FileName -Kind "Application" -MatchKey $key
    }

    function Invoke-AddFolder {
        Write-SidebarLog "Add folder dialog requested."
        $dialog = New-Object Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Add folder"
        try {
            $dialogResult = $dialog.ShowDialog()
        } catch {
            Write-SidebarLog ("Add folder dialog failed: " + $_.Exception.Message)
            return
        } finally {
            Resume-SidebarAfterDialog
        }
        if ($dialogResult -ne [Windows.Forms.DialogResult]::OK) { Write-SidebarLog "Add folder dialog cancelled."; return }
        $name = Split-Path -Leaf $dialog.SelectedPath
        Add-PinnedLayoutEntry -Name $name -Target $dialog.SelectedPath -IconPath ($env:WINDIR + "\explorer.exe") -Kind "Folder" -MatchKey ""
    }

    function Invoke-AddWebsite {
        Write-SidebarLog "Add website dialog requested."
        $url = Show-ObsidianInputDialog -Title "Add website" -Label "Website URL" -InitialValue "https://"
        if ([string]::IsNullOrWhiteSpace($url)) { return }
        if ($url -notmatch "^https?://") { $url = "https://" + $url }
        $name = Show-ObsidianInputDialog -Title "Add website" -Label "Display name" -InitialValue ([Uri]$url).Host
        if ([string]::IsNullOrWhiteSpace($name)) { return }
        Add-PinnedLayoutEntry -Name $name -Target $url -IconPath ($assetRoot + "\Google Chrome.ico") -Kind "Website" -MatchKey ""
        Write-SidebarLog ("Added website entry: " + $name)
    }

    function New-RailContextMenu {
        $menu = New-ObsidianContextMenu
        $menu.Items.Add((New-DarkMenuItem -Header "Add application..." -Action { Invoke-AddApplication })) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Add folder..." -Action { Invoke-AddFolder })) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Add website..." -Action { Invoke-AddWebsite })) | Out-Null
        $menu.Items.Add((New-DarkMenuDivider)) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Restore hidden apps" -Action {
                    $script:appLayout.HiddenKeys = @()
                    foreach ($entry in $script:appLayout.Entries) {
                        $entry.Removed = $false
                        $entry.Pinned = $true
                    }
                    Save-AppLayout
                    Refresh-ApplicationUi
                    Write-SidebarLog "Restored hidden sidebar entries."
                })) | Out-Null
        $menu.Items.Add((New-DarkMenuItem -Header "Restore default layout" -Action {
                    $script:appLayout = New-DefaultAppLayout
                    Save-AppLayout
                    Refresh-ApplicationUi
                    Write-SidebarLog "Restored default sidebar layout."
                })) | Out-Null
        return $menu
    }

    function Get-AppDisplayName {
        param(
            [string]$ProcessName,
            [string]$Path
        )

        $knownNames = @{
            "explorer" = "文件资源管理器"
            "msedge" = "Microsoft Edge"
            "Weixin" = "微信"
            "SystemSettings" = "设置"
            "XLSmartUI" = "天禧智能体"
            "XLAUI" = "天禧智能体"
            "steamwebhelper" = "Steam"
            "steam" = "Steam"
            "QuickQ" = "QuickQ"
            "devenv" = "Visual Studio"
            "WindowsTerminal" = "Windows Terminal"
            "Notepad" = "Notepad"
            "mspaint" = "Microsoft Paint"
        }
        if ($knownNames.ContainsKey($ProcessName)) {
            return $knownNames[$ProcessName]
        }

        try {
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            foreach ($candidate in @($version.FileDescription, $version.ProductName)) {
                if (![string]::IsNullOrWhiteSpace($candidate)) {
                    return $candidate.Trim()
                }
            }
        } catch { }
        return $ProcessName
    }

    function Get-RunningAppSnapshot {
        $excludedProcesses = @(
            "seelen-ui", "Dock_64", "NVIDIA Overlay", "TextInputHost",
            "SearchHost", "StartMenuExperienceHost", "ShellExperienceHost",
            "dwm", "LockApp", "ApplicationFrameHost"
        )
        $excludedClasses = @(
            "Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd",
            "CEF-OSC-WIDGET"
        )
        $groups = @{}
        $order = New-Object 'System.Collections.Generic.List[string]'

        foreach ($appWindow in [ObsidianAppScanner]::GetVisibleWindows()) {
            if ($appWindow.ProcessId -eq $PID -or
                $excludedClasses -contains $appWindow.ClassName) {
                continue
            }

            $process = Get-Process -Id $appWindow.ProcessId -ErrorAction SilentlyContinue
            if ($null -eq $process -or $excludedProcesses -contains $process.ProcessName) {
                continue
            }

            $path = $null
            try { $path = $process.MainModule.FileName } catch { }
            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = [ObsidianNativeWindow]::GetProcessImagePath($appWindow.ProcessId)
            }
            if ([string]::IsNullOrWhiteSpace($path) -or !(Test-Path -LiteralPath $path)) {
                continue
            }

            $key = $path.ToLowerInvariant()
            if (!$groups.ContainsKey($key)) {
                $groups[$key] = [pscustomobject]@{
                    Key = $key
                    Name = Get-AppDisplayName -ProcessName $process.ProcessName -Path $path
                    ProcessName = $process.ProcessName
                    Path = $path
                    Windows = New-Object 'System.Collections.Generic.List[object]'
                }
                $order.Add($key) | Out-Null
            }
            $groups[$key].Windows.Add($appWindow) | Out-Null
        }

        $result = @()
        foreach ($key in $order) {
            $app = $groups[$key]
            $windowArray = [object[]]$app.Windows.ToArray()
            $result += [pscustomobject]@{
                Key = $app.Key
                Name = $app.Name
                ProcessName = $app.ProcessName
                Path = $app.Path
                Windows = $windowArray
                Handles = [IntPtr[]]@($windowArray | ForEach-Object { $_.Handle })
            }
        }
        return $result
    }

    function Get-DwmAttributeState {
        param(
            [IntPtr]$Handle,
            [int]$Attribute
        )
        $value = 0
        $result = [ObsidianDwmThumbnail]::DwmGetWindowAttribute($Handle, $Attribute, [ref]$value, 4)
        return [pscustomobject]@{
            Has = ($result -eq 0)
            Value = $value
        }
    }

    function Set-DwmAttributeValue {
        param(
            [IntPtr]$Handle,
            [int]$Attribute,
            [int]$Value
        )
        return [ObsidianDwmThumbnail]::DwmSetWindowAttribute($Handle, $Attribute, [ref]$Value, 4)
    }

    function Get-WindowProcessId {
        param([IntPtr]$Handle)
        $processId = [uint32]0
        [ObsidianNativeWindow]::GetWindowThreadProcessId($Handle, [ref]$processId) | Out-Null
        return [int]$processId
    }

    function Save-WindowStyleState {
        $validRecords = @()
        foreach ($key in @($script:windowStyleRecords.Keys)) {
            $record = $script:windowStyleRecords[$key]
            $handle = [IntPtr]::new([int64]$record.Handle)
            if (![ObsidianNativeWindow]::IsWindow($handle) -or
                (Get-WindowProcessId -Handle $handle) -ne [int]$record.ProcessId) {
                $script:windowStyleRecords.Remove($key)
                continue
            }
            $validRecords += $record
        }

        if ($validRecords.Count -eq 0) {
            if (Test-Path -LiteralPath $windowStyleStatePath) {
                Remove-Item -LiteralPath $windowStyleStatePath -Force
            }
            return
        }
        $validRecords | Sort-Object ProcessName, Handle |
            Export-Csv -LiteralPath $windowStyleStatePath -NoTypeInformation -Encoding UTF8
    }

    function Load-WindowStyleState {
        $records = @{}
        if (!(Test-Path -LiteralPath $windowStyleStatePath)) {
            return $records
        }
        try {
            foreach ($record in @(Import-Csv -LiteralPath $windowStyleStatePath)) {
                $handle = [IntPtr]::new([int64]$record.Handle)
                if ([ObsidianNativeWindow]::IsWindow($handle) -and
                    (Get-WindowProcessId -Handle $handle) -eq [int]$record.ProcessId) {
                    $records[$record.Handle] = $record
                }
            }
        } catch {
            Write-SidebarLog ("Window style state could not be loaded: " + $_.Exception.Message)
        }
        return $records
    }

    function Test-WindowStyleEligibility {
        param(
            $App,
            $WindowInfo
        )

        $excludedProcesses = @(
            "seelen-ui", "Dock_64", "NVIDIA Overlay", "TextInputHost",
            "SearchHost", "StartMenuExperienceHost", "ShellExperienceHost",
            "dwm", "LockApp", "ApplicationFrameHost", "GameBar",
            "GameBarFTServer", "steamwebhelper", "powershell", "pwsh",
            "WindowsTerminal", "conhost", "phtrun"
        )
        if ($excludedProcesses -contains $App.ProcessName) {
            return $false
        }
        if ($WindowInfo.ClassName -in @("Progman", "WorkerW", "CEF-OSC-WIDGET")) {
            return $false
        }
        if ($App.Path -match "\\Steam\\steamapps\\common\\|\\Epic Games\\|\\XboxGames\\|EasyAntiCheat|BattlEye") {
            return $false
        }
        if ([ObsidianNativeWindow]::IsBorderlessFullscreen([IntPtr]$WindowInfo.Handle)) {
            return $false
        }
        return $true
    }

    function Add-WindowStyleRecord {
        param(
            $App,
            $WindowInfo
        )

        $handle = [IntPtr]$WindowInfo.Handle
        $key = $handle.ToInt64().ToString()
        if ($script:windowStyleRecords.ContainsKey($key)) {
            return $false
        }

        $transitions = Get-DwmAttributeState -Handle $handle -Attribute 3
        $dark = Get-DwmAttributeState -Handle $handle -Attribute 20
        $corner = Get-DwmAttributeState -Handle $handle -Attribute 33
        $border = Get-DwmAttributeState -Handle $handle -Attribute 34
        $caption = Get-DwmAttributeState -Handle $handle -Attribute 35
        $text = Get-DwmAttributeState -Handle $handle -Attribute 36
        $backdrop = Get-DwmAttributeState -Handle $handle -Attribute 38

        # Color attributes are set-only. Native Windows apps can safely return to
        # DWMWA_COLOR_DEFAULT; custom-drawn third-party windows are left untouched.
        $nativeColorProcesses = @("explorer", "Notepad", "mspaint")
        if ($nativeColorProcesses -contains $App.ProcessName) {
            if (!$border.Has) { $border = [pscustomobject]@{ Has = $true; Value = -1 } }
            if (!$caption.Has) { $caption = [pscustomobject]@{ Has = $true; Value = -1 } }
            if (!$text.Has) { $text = [pscustomobject]@{ Has = $true; Value = -1 } }
        }

        if (!($transitions.Has -or $dark.Has -or $corner.Has -or $border.Has -or
            $caption.Has -or $text.Has -or $backdrop.Has)) {
            return $false
        }

        $record = [pscustomobject]@{
            Handle = $handle.ToInt64()
            ProcessId = Get-WindowProcessId -Handle $handle
            ProcessName = $App.ProcessName
            Title = $WindowInfo.Title
            TransitionsHas = $transitions.Has
            TransitionsValue = $transitions.Value
            DarkHas = $dark.Has
            DarkValue = $dark.Value
            CornerHas = $corner.Has
            CornerValue = $corner.Value
            BorderHas = $border.Has
            BorderValue = $border.Value
            CaptionHas = $caption.Has
            CaptionValue = $caption.Value
            TextHas = $text.Has
            TextValue = $text.Value
            BackdropHas = $backdrop.Has
            BackdropValue = $backdrop.Value
        }
        $script:windowStyleRecords[$key] = $record
        Save-WindowStyleState

        if ($transitions.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 3 -Value 0 | Out-Null }
        if ($dark.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 20 -Value 1 | Out-Null }
        if ($corner.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 33 -Value 2 | Out-Null }
        if ($border.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 34 -Value 0x00857770 | Out-Null }
        if ($caption.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 35 -Value 0x000D0908 | Out-Null }
        if ($text.Has) { Set-DwmAttributeValue -Handle $handle -Attribute 36 -Value 0x00ECE6E4 | Out-Null }
        if ($backdrop.Has -and $backdrop.Value -in @(0, 1) -and $hardwareProfile.BackdropType -gt 0) {
            Set-DwmAttributeValue -Handle $handle -Attribute 38 -Value ([int]$hardwareProfile.BackdropType) | Out-Null
        }
        return $true
    }

    function Update-WindowStyles {
        param([array]$Snapshot)

        $styled = 0
        foreach ($app in $Snapshot) {
            foreach ($appWindow in $app.Windows) {
                if (Test-WindowStyleEligibility -App $app -WindowInfo $appWindow) {
                    if (Add-WindowStyleRecord -App $app -WindowInfo $appWindow) {
                        $styled++
                    }
                }
            }
        }
        Save-WindowStyleState
        if ($styled -gt 0) {
            Write-SidebarLog ("Applied reversible DWM style to " + $styled + " new window(s).")
        }
    }

    function Update-GameSafeMode {
        param([array]$Snapshot)

        $fullscreen = $false
        $foregroundHandle = [ObsidianNativeWindow]::GetForegroundWindow()
        if ($foregroundHandle -ne [IntPtr]::Zero) {
            [uint32]$foregroundProcessId = 0
            [ObsidianNativeWindow]::GetWindowThreadProcessId($foregroundHandle, [ref]$foregroundProcessId) | Out-Null
            try {
                $foregroundProcess = Get-Process -Id $foregroundProcessId -ErrorAction Stop
                $shellProcesses = @("explorer", "seelen-ui", "Dock_64")
                if ($foregroundProcessId -ne [Diagnostics.Process]::GetCurrentProcess().Id -and
                    $foregroundProcess.ProcessName -notin $shellProcesses) {
                    $fullscreen = [ObsidianNativeWindow]::IsBorderlessFullscreen($foregroundHandle)
                }
            } catch {
                $fullscreen = $false
            }
        }

        if ($fullscreen -eq $script:gameSafeMode) {
            return
        }
        $script:gameSafeMode = $fullscreen
        if ($fullscreen) {
            Hide-AppPreview
            Clear-StageThumbnails
            $script:isOpen = $false
            $window.BeginAnimation([Windows.Window]::LeftProperty, $null)
            $window.Left = -260
            $window.IsHitTestVisible = $false
            $window.Topmost = $false
            $runtimeTimer.Interval = [TimeSpan]::FromSeconds(5)
            $script:runtimeSignature = ""
            Write-SidebarLog "Game-safe mode enabled for a borderless fullscreen window."
        } else {
            $window.IsHitTestVisible = $true
            $window.Topmost = $true
            $runtimeTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
            $script:runtimeSignature = ""
            Show-Sidebar
            Write-SidebarLog "Game-safe mode disabled; pinned sidebar restored."
        }
    }

    $script:windowStyleRecords = Load-WindowStyleState
    $script:lastWindowStyleUpdate = [DateTime]::MinValue
    $script:gameSafeMode = $false
    $script:sidebarHandle = [IntPtr]::Zero

    function Test-IsFixedApp {
        param($App)
        foreach ($definition in $script:fixedDefinitions) {
            if (![string]::IsNullOrWhiteSpace($definition.MatchKey) -and $definition.MatchKey -eq $App.Key) {
                return $true
            }
            if (@($definition.ProcessNames) -contains $App.ProcessName) {
                if ([string]::IsNullOrWhiteSpace($definition.TitlePattern) -or
                    @($App.Windows | Where-Object { $_.Title -match $definition.TitlePattern }).Count -gt 0) {
                    return $true
                }
            }
        }
        return $false
    }

    function Add-NewAppsToFixedRegion {
        param([array]$Snapshot)

        $added = 0
        $orders = @($script:appLayout.Entries | ForEach-Object { [int]$_.Order })
        $nextOrder = if ($orders.Count -gt 0) { ($orders | Measure-Object -Maximum).Maximum + 1 } else { 0 }

        foreach ($app in $Snapshot) {
            if ((Test-IsFixedApp -App $app) -or $script:appLayout.HiddenKeys -contains $app.Key) {
                continue
            }
            $existing = @($script:appLayout.Entries | Where-Object {
                    (![string]::IsNullOrWhiteSpace($_.MatchKey) -and $_.MatchKey -eq $app.Key) -or
                    (![string]::IsNullOrWhiteSpace($_.Target) -and $_.Target -eq $app.Path)
                }) | Select-Object -First 1
            if ($null -ne $existing) {
                $existing.Pinned = $true
                $existing.Removed = $false
                continue
            }

            $entry = [pscustomobject]@{
                Id = "auto." + [Guid]::NewGuid().ToString("N")
                Name = $app.Name
                Target = $app.Path
                IconPath = $app.Path
                Kind = "Application"
                Pinned = $true
                BuiltIn = $false
                Removed = $false
                Order = $nextOrder
                ProcessNames = @($app.ProcessName)
                TitlePattern = ""
                MatchKey = $app.Key
            }
            $script:appLayout.Entries = @($script:appLayout.Entries) + @($entry)
            $nextOrder++
            $added++
            Write-SidebarLog ("Auto-pinned new application: " + $app.Name)
        }

        if ($added -gt 0) {
            Save-AppLayout
            Render-FixedApps
            $script:runtimeSignature = ""
        }
        return $added
    }

    function Test-IsRecentFixed {
        param($RecentApp)
        $processName = [IO.Path]::GetFileNameWithoutExtension($RecentApp.Path)
        foreach ($definition in $script:fixedDefinitions) {
            if ((![string]::IsNullOrWhiteSpace($definition.MatchKey) -and $definition.MatchKey -eq $RecentApp.Key) -or
                (@($definition.ProcessNames) -contains $processName)) {
                return $true
            }
        }
        return $false
    }

    function Update-FixedAppStatus {
        param([array]$Snapshot)

        foreach ($definition in $script:fixedDefinitions) {
            $handles = @()
            $windowInfos = @()
            foreach ($app in $Snapshot) {
                $keyMatches = ![string]::IsNullOrWhiteSpace($definition.MatchKey) -and $definition.MatchKey -eq $app.Key
                $processMatches = @($definition.ProcessNames) -contains $app.ProcessName
                if (!$keyMatches -and !$processMatches) {
                    continue
                }
                foreach ($appWindow in $app.Windows) {
                    if ([string]::IsNullOrWhiteSpace($definition.TitlePattern) -or
                        $appWindow.Title -match $definition.TitlePattern) {
                        $handles += $appWindow.Handle
                        $windowInfos += $appWindow
                    }
                }
            }

            $button = $script:fixedButtons[$definition.Id]
            if ($null -eq $button) { continue }
            $button.Tag.WindowHandles = @($handles)
            $button.Tag.WindowInfos = @($windowInfos)
            $button.Tag.Indicator.Opacity = if ($handles.Count -gt 0) { 0.95 } else { 0.0 }
        }
    }

    function Load-RecentApps {
        if (!(Test-Path -LiteralPath $recentPath)) {
            return @()
        }
        try {
            $items = @(
                Import-Csv -LiteralPath $recentPath |
                    Where-Object { Test-Path -LiteralPath $_.Path } |
                    Sort-Object LastSeen -Descending |
                    Select-Object -First 8
            )
            foreach ($item in $items) {
                $processName = [IO.Path]::GetFileNameWithoutExtension($item.Path)
                $item.Name = Get-AppDisplayName -ProcessName $processName -Path $item.Path
            }
            return $items
        } catch {
            Write-SidebarLog ("Recent app state could not be loaded: " + $_.Exception.Message)
            return @()
        }
    }

    function Save-RecentApps {
        try {
            $items = @(
                $script:recentApps |
                    Sort-Object LastSeen -Descending |
                    Select-Object -First 8
            )
            if ($items.Count -eq 0) {
                if (Test-Path -LiteralPath $recentPath) {
                    Remove-Item -LiteralPath $recentPath -Force
                }
                return
            }
            $items | Export-Csv -LiteralPath $recentPath -NoTypeInformation -Encoding UTF8
        } catch {
            Write-SidebarLog ("Recent app state could not be saved: " + $_.Exception.Message)
        }
    }

    function Render-AppRegion {
        param(
            [Windows.Controls.StackPanel]$Panel,
            [array]$Apps,
            [string]$State
        )

        $Panel.Children.Clear()
        foreach ($app in $Apps) {
            $override = Get-AppOverride -Key $app.Key
            $displayName = if ($null -ne $override -and ![string]::IsNullOrWhiteSpace($override.Name)) { $override.Name } else { $app.Name }
            $iconPath = if ($null -ne $override -and ![string]::IsNullOrWhiteSpace($override.IconPath)) { $override.IconPath } else { $app.Path }
            $button = New-AppButton -Name $displayName `
                -IconSource (Get-EntryIconFrame -IconPath $iconPath -TargetPath $app.Path) `
                -LaunchPath $app.Path `
                -State $State `
                -Size 40 `
                -IconSize 30 `
                -StatusColor "#9FB6C9FF" `
                -Key $app.Key `
                -EntryId "" `
                -Kind $State `
                -IconPath $iconPath
            $button.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
            $button.Margin = [Windows.Thickness]::new(0)
            if ($State -eq "RUNNING") {
                $button.Tag.WindowHandles = @($app.Handles)
                $button.Tag.WindowInfos = @($app.Windows)
            }
            $Panel.Children.Add($button) | Out-Null
        }
    }

    function Get-StageManagerApps {
        param([array]$Snapshot)

        $foregroundHandle = [ObsidianNativeWindow]::GetForegroundWindow()
        $script:stageForegroundHandle = $foregroundHandle
        $now = [DateTime]::UtcNow
        $index = 0

        foreach ($app in $Snapshot) {
            $isForeground = $false
            foreach ($appWindow in $app.Windows) {
                if ([IntPtr]$appWindow.Handle -eq $foregroundHandle) {
                    $isForeground = $true
                    break
                }
            }
            if ($isForeground) {
                $script:stageLastActive[$app.Key] = $now
            } elseif (!$script:stageLastActive.ContainsKey($app.Key)) {
                $script:stageLastActive[$app.Key] = $now.AddSeconds(-($index + 1))
            }
            $index++
        }

        $visible = @($Snapshot | Where-Object { $script:appLayout.HiddenKeys -notcontains $_.Key })
        return @(
            $visible |
                Sort-Object -Property @{ Expression = { $script:stageLastActive[$_.Key] }; Descending = $true } |
                Select-Object -First 7
        )
    }

    function New-StageManagerCard {
        param(
            $App,
            $WindowInfo,
            [double]$Left,
            [double]$Top,
            [double]$Width,
            [double]$Height
        )

        $override = Get-AppOverride -Key $App.Key
        $displayName = if ($null -ne $override -and ![string]::IsNullOrWhiteSpace($override.Name)) { $override.Name } else { $App.Name }
        $iconPath = if ($null -ne $override -and ![string]::IsNullOrWhiteSpace($override.IconPath)) { $override.IconPath } else { $App.Path }

        $card = [Windows.Controls.Border]::new()
        $card.Width = $Width
        $card.Height = $Height
        $card.CornerRadius = [Windows.CornerRadius]::new(12)
        $card.BorderThickness = [Windows.Thickness]::new(1)
        $card.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#8B91A7C6"))
        $card.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#EC0B0E16"))
        $card.Cursor = [Windows.Input.Cursors]::Hand
        $cardEffect = [Windows.Media.Effects.DropShadowEffect]::new()
        $cardEffect.Color = [Windows.Media.ColorConverter]::ConvertFromString("#FF5F8DCA")
        $cardEffect.BlurRadius = 18
        $cardEffect.ShadowDepth = 0
        $cardEffect.Opacity = 0.36
        $card.Effect = $cardEffect
        $card.SnapsToDevicePixels = $true
        $card.Tag = [pscustomobject]@{
            Handle = [IntPtr]$WindowInfo.Handle
            Name = $displayName
            Key = $App.Key
            EntryId = ""
            LaunchPath = $App.Path
            IconPath = $iconPath
            WindowHandles = @($App.Handles)
            WindowInfos = @($App.Windows)
            CaptureImage = $null
        }

        $content = [Windows.Controls.Grid]::new()

        $previewSurface = [Windows.Controls.Border]::new()
        $previewSurface.Height = 80
        $previewSurface.Margin = [Windows.Thickness]::new(6, 6, 6, 0)
        $previewSurface.VerticalAlignment = [Windows.VerticalAlignment]::Top
        $previewSurface.CornerRadius = [Windows.CornerRadius]::new(8)
        $previewSurface.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#FF111319"))
        $previewImage = [Windows.Controls.Image]::new()
        $previewImage.Margin = [Windows.Thickness]::new(1)
        $previewImage.Stretch = [Windows.Media.Stretch]::UniformToFill
        $previewImage.IsHitTestVisible = $false
        [Windows.Media.RenderOptions]::SetBitmapScalingMode($previewImage, [Windows.Media.BitmapScalingMode]::HighQuality)
        $previewSurface.Child = $previewImage
        $content.Children.Add($previewSurface) | Out-Null

        $footer = [Windows.Controls.Grid]::new()
        $footer.Height = 24
        $footer.Margin = [Windows.Thickness]::new(8, 0, 8, 1)
        $footer.VerticalAlignment = [Windows.VerticalAlignment]::Bottom

        $icon = [Windows.Controls.Image]::new()
        $icon.Width = 20
        $icon.Height = 20
        $icon.Margin = [Windows.Thickness]::new(0, 0, 0, 0)
        $icon.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
        $icon.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $icon.Stretch = [Windows.Media.Stretch]::Uniform
        $icon.Source = Get-EntryIconFrame -IconPath $iconPath -TargetPath $App.Path
        $footer.Children.Add($icon) | Out-Null

        $name = [Windows.Controls.TextBlock]::new()
        $name.Text = $displayName
        $name.Margin = [Windows.Thickness]::new(28, 0, 22, 0)
        $name.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $name.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#F2F2F4F8"))
        $name.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
        $name.FontSize = 11
        $name.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
        $footer.Children.Add($name) | Out-Null

        $statusDot = [Windows.Shapes.Ellipse]::new()
        $statusDot.Width = 5
        $statusDot.Height = 5
        $statusDot.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
        $statusDot.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $statusDot.Fill = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#B8B7D9FF"))
        $footer.Children.Add($statusDot) | Out-Null

        $content.Children.Add($footer) | Out-Null
        $card.Child = $content
        $card.Tag.CaptureImage = $previewImage
        $card.ToolTip = New-AppTooltip -Name $WindowInfo.Title -State $displayName

        $card.Add_MouseEnter({
            param($sender, $eventArgs)
            $sender.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#E0D9EBFF"))
            $sender.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#F5131927"))
            if ($null -ne $sender.Effect) { $sender.Effect.Opacity = 0.72 }
            if (@($sender.Tag.WindowInfos).Count -gt 0) {
                [Windows.Controls.ToolTipService]::SetIsEnabled($sender, $false)
                Schedule-AppPreview -Button $sender
            }
        })
        $card.Add_MouseLeave({
            param($sender, $eventArgs)
            $sender.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#8B91A7C6"))
            $sender.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#EC0B0E16"))
            if ($null -ne $sender.Effect) { $sender.Effect.Opacity = 0.36 }
            [Windows.Controls.ToolTipService]::SetIsEnabled($sender, $true)
            Schedule-HideAppPreview
        })
        $card.Add_MouseLeftButtonUp({
            param($sender, $eventArgs)
            $script:stageLastActive[$sender.Tag.Key] = [DateTime]::UtcNow
            $script:runtimeSignature = ""
            Activate-AppWindow -Handle ([IntPtr]$sender.Tag.Handle) | Out-Null
            Write-SidebarLog ("Stage Manager activated: " + $sender.Tag.Name)
            $eventArgs.Handled = $true
        })

        [Windows.Controls.Canvas]::SetLeft($card, $Left)
        [Windows.Controls.Canvas]::SetTop($card, $Top)
        $stageCanvas.Children.Add($card) | Out-Null
        return $card
    }

    function Render-StageManager {
        param([array]$Apps)

        Clear-StageThumbnails
        $stageCanvas.Children.Clear()
        if ($script:gameSafeMode) {
            return
        }

        if ($Apps.Count -eq 0) {
            $empty = [Windows.Controls.TextBlock]::new()
            $empty.Text = "没有打开的窗口"
            $empty.Width = 190
            $empty.TextAlignment = [Windows.TextAlignment]::Center
            $empty.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString("#83939BAA"))
            $empty.FontFamily = [Windows.Media.FontFamily]::new("Segoe UI Variable Text")
            $empty.FontSize = 12
            [Windows.Controls.Canvas]::SetLeft($empty, 10)
            [Windows.Controls.Canvas]::SetTop($empty, 400)
            $stageCanvas.Children.Add($empty) | Out-Null
            return
        }

        $cardWidth = 190.0
        $cardHeight = 108.0
        $gap = 8.0
        $totalHeight = ($Apps.Count * $cardHeight) + (($Apps.Count - 1) * $gap)
        $top = [Math]::Max(8.0, (820.0 - $totalHeight) / 2.0)
        $layouts = @()

        foreach ($app in $Apps) {
            $windowInfo = @(Select-PreferredPreviewWindow -Windows $app.Windows)
            if ($windowInfo.Count -eq 0) {
                continue
            }
            $selectedWindow = $windowInfo[0]
            New-StageManagerCard -App $app -WindowInfo $selectedWindow -Left 10 -Top $top -Width $cardWidth -Height $cardHeight | Out-Null
            $layouts += [pscustomobject]@{
                Handle = [IntPtr]$selectedWindow.Handle
                Left = 16.0
                Top = $top + 6.0
                Width = 178.0
                Height = 80.0
                CaptureImage = $null
            }
            $layouts[$layouts.Count - 1].CaptureImage = $stageCanvas.Children[$stageCanvas.Children.Count - 1].Tag.CaptureImage
            $top += $cardHeight + $gap
        }

        $window.UpdateLayout()
        $helper = [Windows.Interop.WindowInteropHelper]::new($window)
        $destinationHandle = $helper.Handle
        if ($destinationHandle -eq [IntPtr]::Zero) {
            return
        }
        $source = [Windows.PresentationSource]::FromVisual($window)
        $scaleX = 1.0
        $scaleY = 1.0
        if ($null -ne $source -and $null -ne $source.CompositionTarget) {
            $matrix = $source.CompositionTarget.TransformToDevice
            $scaleX = $matrix.M11
            $scaleY = $matrix.M22
        }

        foreach ($layout in $layouts) {
            $initialFrame = Get-WindowBitmapSource -Handle $layout.Handle
            if ($null -ne $initialFrame -and $null -ne $layout.CaptureImage) {
                $layout.CaptureImage.Source = $initialFrame
            }
            Set-PreviewThumbnail `
                -DestinationHandle $destinationHandle `
                -SourceHandle $layout.Handle `
                -Left $layout.Left `
                -Top $layout.Top `
                -Width $layout.Width `
                -Height $layout.Height `
                -ScaleX $scaleX `
                -ScaleY $scaleY `
                -ThumbnailCollection $script:stageThumbnails
        }
    }

    $script:recentApps = @(Load-RecentApps)
    Save-RecentApps
    $script:knownDynamicApps = @{}
    $script:previousDynamicKeys = @()
    $script:runtimeSignature = ""
    $script:stageLastActive = @{}
    $script:stageForegroundHandle = [IntPtr]::Zero
    $script:currentStageApps = @()

    function Refresh-AppRuntime {
        try {
            $snapshot = @(Get-RunningAppSnapshot)
            Update-GameSafeMode -Snapshot $snapshot
            $styleElapsed = ([DateTime]::UtcNow - $script:lastWindowStyleUpdate).TotalMilliseconds
            if (!$script:gameSafeMode -and $styleElapsed -ge $hardwareProfile.StyleIntervalMs) {
                Update-WindowStyles -Snapshot $snapshot
                $script:lastWindowStyleUpdate = [DateTime]::UtcNow
            }
            Add-NewAppsToFixedRegion -Snapshot $snapshot | Out-Null
            Update-FixedAppStatus -Snapshot $snapshot
            $dynamicApps = @($snapshot | Where-Object {
                    !(Test-IsFixedApp -App $_) -and $script:appLayout.HiddenKeys -notcontains $_.Key
                })
            $currentKeys = @($dynamicApps | ForEach-Object { $_.Key })
            $recentChanged = $false

            foreach ($closedKey in @($script:previousDynamicKeys | Where-Object { $currentKeys -notcontains $_ })) {
                if ($script:knownDynamicApps.ContainsKey($closedKey) -and $script:appLayout.HiddenKeys -notcontains $closedKey) {
                    $closedApp = $script:knownDynamicApps[$closedKey]
                    $script:recentApps = @($script:recentApps | Where-Object { $_.Key -ne $closedKey })
                    $script:recentApps = @([pscustomobject]@{
                        Key = $closedApp.Key
                        Name = $closedApp.Name
                        Path = $closedApp.Path
                        LastSeen = (Get-Date).ToString("o")
                    }) + @($script:recentApps)
                    $script:recentApps = @($script:recentApps | Select-Object -First 8)
                    $recentChanged = $true
                    Write-SidebarLog ("Moved to recent: " + $closedApp.Name)
                }
            }

            foreach ($app in $dynamicApps) {
                $script:knownDynamicApps[$app.Key] = $app
                $filteredRecent = @($script:recentApps | Where-Object { $_.Key -ne $app.Key })
                if ($filteredRecent.Count -ne $script:recentApps.Count) {
                    $script:recentApps = $filteredRecent
                    $recentChanged = $true
                }
            }

            $nonFixedRecent = @($script:recentApps | Where-Object { !(Test-IsRecentFixed -RecentApp $_) })
            if ($nonFixedRecent.Count -ne $script:recentApps.Count) {
                $script:recentApps = $nonFixedRecent
                $recentChanged = $true
            }

            $stageApps = @(Get-StageManagerApps -Snapshot $snapshot)
            $script:currentStageApps = @($stageApps)
            $signature = @($stageApps | ForEach-Object {
                    $app = $_
                    $firstWindow = @($app.Windows | Where-Object { [IntPtr]$_.Handle -eq $script:stageForegroundHandle } | Select-Object -First 1)
                    if ($firstWindow.Count -eq 0) {
                        $firstWindow = @($app.Windows | Select-Object -First 1)
                    }
                    $windowSignature = if ($firstWindow.Count -gt 0) {
                        $firstWindow[0].Handle.ToInt64().ToString() + ":" + $firstWindow[0].Title
                    } else {
                        "none"
                    }
                    $app.Key + ":" + $windowSignature
                }) -join "|"
            if ($signature -ne $script:runtimeSignature) {
                if ($script:isOpen) {
                    Render-StageManager -Apps $stageApps
                } else {
                    Clear-StageThumbnails
                }
                $script:runtimeSignature = $signature
                Write-SidebarLog ("Stage Manager refreshed: " + $stageApps.Count + " recent window card(s).")
            }

            if ($recentChanged) {
                Save-RecentApps
            }
            $script:previousDynamicKeys = @($currentKeys)
        } catch {
            Write-SidebarLog ("Runtime scan failed: " + $_.Exception.ToString() + " | " + $_.ScriptStackTrace)
        }
    }

    $runtimeTimer = [Windows.Threading.DispatcherTimer]::new()
    $runtimeTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $runtimeTimer.Add_Tick({ Refresh-AppRuntime })

    $previewOpenTimer = [Windows.Threading.DispatcherTimer]::new()
    $previewOpenTimer.Interval = [TimeSpan]::FromMilliseconds(110)
    $previewOpenTimer.Add_Tick({
        $previewOpenTimer.Stop()
        $button = $script:previewPendingButton
        if ($null -ne $button -and $button.IsMouseOver -and @($button.Tag.WindowInfos).Count -gt 0) {
            try {
                Show-AppPreview -Button $button
            } catch {
                Write-SidebarLog ("Preview open failed: " + $_.Exception.ToString() + " | " + $_.ScriptStackTrace)
                Hide-AppPreview
            }
        }
    })

    $previewHideTimer = [Windows.Threading.DispatcherTimer]::new()
    $previewHideTimer.Interval = [TimeSpan]::FromMilliseconds(140)
    $previewHideTimer.Add_Tick({
        $previewHideTimer.Stop()
        if (!$previewWindow.IsMouseOver) {
            Hide-AppPreview
        }
    })

    $previewCloseTimer = [Windows.Threading.DispatcherTimer]::new()
    $previewCloseTimer.Interval = [TimeSpan]::FromMilliseconds(125)
    $previewCloseTimer.Add_Tick({
        $previewCloseTimer.Stop()
        if (!$script:previewVisible) {
            Clear-PreviewThumbnails
            $previewWindow.Hide()
            Write-SidebarLog "Preview resources released."
        }
    })

    $previewCaptureTimer = [Windows.Threading.DispatcherTimer]::new()
    $previewCaptureTimer.Interval = [TimeSpan]::FromMilliseconds(400)
    $previewCaptureTimer.Add_Tick({
        if (!$script:previewVisible -or $script:previewCaptureHandle -eq [IntPtr]::Zero) {
            $previewCaptureTimer.Stop()
            return
        }
        Update-MinimizedPreviewFrame | Out-Null
    })

    $stageReleaseTimer = [Windows.Threading.DispatcherTimer]::new()
    $stageReleaseTimer.Interval = [TimeSpan]::FromMilliseconds(360)
    $stageReleaseTimer.Add_Tick({
        $stageReleaseTimer.Stop()
        if (!$script:isOpen) {
            Clear-StageThumbnails
            $stageCanvas.Children.Clear()
        }
    })

    $openLeft = 0.0
    $hiddenLeft = -200.0
    $isOpen = $false

    function Ensure-SidebarZOrder {
        if ($script:gameSafeMode -or $script:sidebarHandle -eq [IntPtr]::Zero) {
            return
        }

        $noMoveNoActivate = [uint32]0x0613
        [ObsidianNativeWindow]::SetWindowPos($script:sidebarHandle, [IntPtr]::new(-1), 0, 0, 0, 0, $noMoveNoActivate) | Out-Null
    }

    function Animate-WindowLeft {
        param([double]$Target)
        $animation = [Windows.Media.Animation.DoubleAnimation]::new()
        $animation.To = $Target
        $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds($slideSeconds))
        $animation.EasingFunction = New-Ease
        $window.BeginAnimation([Windows.Window]::LeftProperty, $animation)
    }

    function Animate-SidebarOpacity {
        param(
            [Windows.UIElement]$Element,
            [double]$Target,
            [int]$Milliseconds = 240
        )
        if ($null -eq $Element) { return }
        $animation = [Windows.Media.Animation.DoubleAnimation]::new()
        $animation.To = $Target
        $animation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($Milliseconds))
        $animation.EasingFunction = New-Ease
        [Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
        $Element.BeginAnimation([Windows.UIElement]::OpacityProperty, $animation)
    }

    function Show-Sidebar {
        if (!$script:isOpen) {
            $script:isOpen = $true
            $stageReleaseTimer.Stop()
            Render-StageManager -Apps @($script:currentStageApps)
            if (!$script:gameSafeMode) {
                $runtimeTimer.Interval = [TimeSpan]::FromMilliseconds(750)
            }
            Animate-SidebarOpacity -Element $glassLayer -Target 1.0
            Animate-SidebarOpacity -Element $ambientBloom -Target 0.46 -Milliseconds 320
            Animate-SidebarOpacity -Element $energyRail -Target 0.92 -Milliseconds 320
            Animate-SidebarOpacity -Element $edgeNotch -Target 0.0 -Milliseconds 150
            Animate-WindowLeft -Target $openLeft
            Write-SidebarLog "Sidebar revealed."
        }
    }

    function Hide-Sidebar {
        if ($script:isOpen) {
            $script:isOpen = $false
            Hide-AppPreview
            Animate-WindowLeft -Target $hiddenLeft
            $stageReleaseTimer.Stop()
            $stageReleaseTimer.Start()
            if (!$script:gameSafeMode) {
                $runtimeTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
            }
            Animate-SidebarOpacity -Element $glassLayer -Target 0.74 -Milliseconds 260
            Animate-SidebarOpacity -Element $ambientBloom -Target 0.18 -Milliseconds 260
            Animate-SidebarOpacity -Element $energyRail -Target 0.42 -Milliseconds 260
            Animate-SidebarOpacity -Element $edgeNotch -Target 0.88 -Milliseconds 260
            Write-SidebarLog "Sidebar hidden."
        }
    }

    $hideTimer = [Windows.Threading.DispatcherTimer]::new()
    $hideTimer.Interval = [TimeSpan]::FromMilliseconds(520)
    $hideTimer.Add_Tick({
        $hideTimer.Stop()
        if (!$window.IsMouseOver -and !$previewWindow.IsMouseOver) {
            Hide-Sidebar
        }
    })

    $zOrderTimer = [Windows.Threading.DispatcherTimer]::new()
    $zOrderTimer.Interval = [TimeSpan]::FromMilliseconds(400)
    $zOrderTimer.Add_Tick({
        Ensure-SidebarZOrder
    })

    $window.Add_MouseEnter({
        $hideTimer.Stop()
        Show-Sidebar
    })

    $window.Add_MouseLeave({
        $hideTimer.Stop()
        $hideTimer.Start()
    })

    $previewWindow.Add_MouseEnter({
        $previewHideTimer.Stop()
        $hideTimer.Stop()
    })

    $previewWindow.Add_MouseLeave({
        $previewHideTimer.Stop()
        $previewHideTimer.Start()
        $hideTimer.Stop()
        $hideTimer.Start()
    })

    $previewWindow.Add_MouseMove({
        param($sender, $eventArgs)
        $position = $eventArgs.GetPosition($previewRoot)
        $previewReflectionTransform.X = $position.X - 90
        $previewReflectionTransform.Y = $position.Y - 90
    })

    $root.Add_MouseMove({
        param($sender, $eventArgs)
        $position = $eventArgs.GetPosition($glassLayer)
        $reflectionTransform.X = $position.X - 80
        $reflectionTransform.Y = $position.Y - 80
        if ($reflection.Opacity -lt 0.16) {
            $reflection.Opacity = 0.16
        }
    })

    $window.Add_MouseRightButtonUp({
        param($sender, $eventArgs)
        if ([Windows.Input.Keyboard]::IsKeyDown([Windows.Input.Key]::LeftShift) -or
            [Windows.Input.Keyboard]::IsKeyDown([Windows.Input.Key]::RightShift)) {
            $window.Close()
            $eventArgs.Handled = $true
        } else {
            Write-SidebarLog "Rail context menu opened."
            Hide-AppPreview
            $menu = New-RailContextMenu
            $root.ContextMenu = $menu
            $menu.IsOpen = $true
            $eventArgs.Handled = $true
        }
    })

    $window.Add_SourceInitialized({
        $helper = [Windows.Interop.WindowInteropHelper]::new($window)
        $handle = $helper.Handle
        $script:sidebarHandle = $handle

        # Hide the sidebar from Alt+Tab while keeping normal mouse interaction.
        $GWL_EXSTYLE = -20
        $WS_EX_TOOLWINDOW = 0x00000080
        $style = [ObsidianNativeWindow]::GetWindowLongPtr($handle, $GWL_EXSTYLE).ToInt64()
        [ObsidianNativeWindow]::SetWindowLongPtr($handle, $GWL_EXSTYLE, [IntPtr]::new($style -bor $WS_EX_TOOLWINDOW)) | Out-Null

        # Request a user-space blur surface. The XAML material remains the fallback.
        $policy = New-Object ObsidianNativeWindow+AccentPolicy
        $policy.AccentState = 3
        $policy.AccentFlags = 2
        $policy.GradientColor = [int]0xD20B0C10
        $policy.AnimationId = 0
        $size = [Runtime.InteropServices.Marshal]::SizeOf($policy)
        $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
        try {
            [Runtime.InteropServices.Marshal]::StructureToPtr($policy, $pointer, $false)
            $data = New-Object ObsidianNativeWindow+WindowCompositionAttributeData
            $data.Attribute = 19
            $data.Data = $pointer
            $data.SizeOfData = $size
            [ObsidianNativeWindow]::SetWindowCompositionAttribute($handle, [ref]$data) | Out-Null
        } finally {
            [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
        }

        $cornerPreference = 2
        [ObsidianDwmThumbnail]::DwmSetWindowAttribute($handle, 33, [ref]$cornerPreference, 4) | Out-Null
    })

    $previewWindow.Add_SourceInitialized({
        $helper = [Windows.Interop.WindowInteropHelper]::new($previewWindow)
        $handle = $helper.Handle
        $GWL_EXSTYLE = -20
        $WS_EX_TOOLWINDOW = 0x00000080
        $WS_EX_NOACTIVATE = 0x08000000
        $style = [ObsidianNativeWindow]::GetWindowLongPtr($handle, $GWL_EXSTYLE).ToInt64()
        $style = $style -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE
        [ObsidianNativeWindow]::SetWindowLongPtr($handle, $GWL_EXSTYLE, [IntPtr]::new($style)) | Out-Null

        $policy = New-Object ObsidianNativeWindow+AccentPolicy
        $policy.AccentState = 3
        $policy.AccentFlags = 2
        $policy.GradientColor = [int]0xDE0B0C10
        $policy.AnimationId = 0
        $size = [Runtime.InteropServices.Marshal]::SizeOf($policy)
        $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
        try {
            [Runtime.InteropServices.Marshal]::StructureToPtr($policy, $pointer, $false)
            $data = New-Object ObsidianNativeWindow+WindowCompositionAttributeData
            $data.Attribute = 19
            $data.Data = $pointer
            $data.SizeOfData = $size
            [ObsidianNativeWindow]::SetWindowCompositionAttribute($handle, [ref]$data) | Out-Null
        } finally {
            [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
        }

        $cornerPreference = 2
        [ObsidianDwmThumbnail]::DwmSetWindowAttribute($handle, 33, [ref]$cornerPreference, 4) | Out-Null
    })

    $window.Add_Loaded({
        $workArea = [Windows.SystemParameters]::WorkArea
        $window.Top = [Math]::Round($workArea.Top + (($workArea.Height - $window.Height) / 2), 0)
        $window.Left = $hiddenLeft
        $window.IsHitTestVisible = $true
        $window.Topmost = $true
        $glassLayer.Opacity = 0.74
        $ambientBloom.Opacity = 0.18
        $energyRail.Opacity = 0.42
        $edgeNotch.Opacity = 0.88
        Refresh-AppRuntime
        if (!$script:gameSafeMode) {
            Ensure-SidebarZOrder
        }
        $runtimeTimer.Start()
        $zOrderTimer.Start()
        Write-SidebarLog ("Sidebar loaded at " + $window.Left + "," + $window.Top + ".")
    })

    $window.Add_Closed({
        $runtimeTimer.Stop()
        $zOrderTimer.Stop()
        $previewOpenTimer.Stop()
        $previewHideTimer.Stop()
        $previewCloseTimer.Stop()
        $previewCaptureTimer.Stop()
        $stageReleaseTimer.Stop()
        Clear-PreviewThumbnails
        Clear-StageThumbnails
        if ($script:previewWindowShown) {
            $previewWindow.Close()
        }
        $windowRestoreScript = $projectRoot + "\restore-window-style.ps1"
        if (Test-Path -LiteralPath $windowRestoreScript) {
            & $windowRestoreScript
        }
        Save-RecentApps
        Write-SidebarLog "Sidebar closed."
    })

    Write-SidebarLog "Starting Obsidian AI Workspace phase 5."
    $window.ShowDialog() | Out-Null
} catch {
    Write-SidebarLog ("Fatal error: " + $_.Exception.ToString())
    throw
} finally {
    if ($createdNew) {
        try { $mutex.ReleaseMutex() } catch {}
    }
    $mutex.Dispose()
}
