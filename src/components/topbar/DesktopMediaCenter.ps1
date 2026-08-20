param(
    [ValidateSet('Screenshot', 'Recording', 'Camera')]
    [string]$Mode = 'Screenshot'
)

$ErrorActionPreference = 'Stop'
$script:AppRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:StateRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
$script:LogRoot = "$script:StateRoot\logs"
$script:ThumbnailRoot = "$script:StateRoot\thumbnails"
$script:ModeSignalPath = "$script:StateRoot\open-mode.txt"
$script:PidPath = "$script:StateRoot\media-center.pid"

New-Item -ItemType Directory -Force -Path $script:StateRoot, $script:LogRoot, $script:ThumbnailRoot | Out-Null

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DesktopMediaNative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string className, string windowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
}
'@

[void][DesktopMediaNative]::SetProcessDPIAware()

$createdNew = $false
$script:SingleInstanceMutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianDesktopMediaCenter', [ref]$createdNew)
if (-not $createdNew) {
    [IO.File]::WriteAllText($script:ModeSignalPath, $Mode, (New-Object Text.UTF8Encoding($false)))
    $existingWindow = [DesktopMediaNative]::FindWindow($null, '桌面媒体中心')
    if ($existingWindow -ne [IntPtr]::Zero) {
        [void][DesktopMediaNative]::ShowWindow($existingWindow, 9)
        [void][DesktopMediaNative]::SetForegroundWindow($existingWindow)
    }
    exit 0
}

[IO.File]::WriteAllText($script:PidPath, [string]$PID, (New-Object Text.UTF8Encoding($false)))

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

function Write-MediaLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath "$script:LogRoot\media-center.log" -Value $line -Encoding UTF8
}

function Get-ExecutablePath {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

$script:FfmpegPath = Get-ExecutablePath 'ffmpeg.exe'
$script:FfplayPath = Get-ExecutablePath 'ffplay.exe'
if (-not $script:FfplayPath -and $script:FfmpegPath) {
    $candidate = (Split-Path -Parent $script:FfmpegPath) + '\ffplay.exe'
    if (Test-Path -LiteralPath $candidate) { $script:FfplayPath = $candidate }
}

function Get-CameraDeviceName {
    if (-not $script:FfmpegPath) { return $null }
    try {
        $output = & $script:FfmpegPath -hide_banner -list_devices true -f dshow -i dummy 2>&1
        foreach ($entry in $output) {
            $line = [string]$entry
            if ($line -match '"([^"]+)"\s*\(video\)') {
                return $matches[1]
            }
        }
    } catch {
        foreach ($entry in $_.ErrorDetails.Message) {
            if ([string]$entry -match '"([^"]+)"\s*\(video\)') { return $matches[1] }
        }
    }
    try {
        return (Get-PnpDevice -Class Camera -Status OK -ErrorAction Stop | Select-Object -First 1 -ExpandProperty FriendlyName)
    } catch {
        return 'Integrated Camera'
    }
}

$script:CameraDevice = Get-CameraDeviceName

$picturesRoot = [Environment]::GetFolderPath('MyPictures')
if ([string]::IsNullOrWhiteSpace($picturesRoot)) { $picturesRoot = "$env:USERPROFILE\Pictures" }
$script:LibraryRoot = "$picturesRoot\桌面媒体中心"
$script:ModeRoots = @{
    Screenshot = "$script:LibraryRoot\截图"
    Recording  = "$script:LibraryRoot\屏幕录像"
    Camera     = "$script:LibraryRoot\摄像头录像"
}
New-Item -ItemType Directory -Force -Path $script:LibraryRoot, $script:ModeRoots.Screenshot, $script:ModeRoots.Recording, $script:ModeRoots.Camera | Out-Null

$xamlPath = "$script:AppRoot\MediaCenter.xaml"
if (-not (Test-Path -LiteralPath $xamlPath)) { throw "MediaCenter.xaml not found: $xamlPath" }
$xamlText = [IO.File]::ReadAllText($xamlPath, [Text.Encoding]::UTF8)
$script:Window = [Windows.Markup.XamlReader]::Parse($xamlText)

function Find-Control {
    param([string]$Name)
    return $script:Window.FindName($Name)
}

$script:HeaderSubtitle = Find-Control 'HeaderSubtitle'
$script:ScreenshotTabButton = Find-Control 'ScreenshotTabButton'
$script:RecordingTabButton = Find-Control 'RecordingTabButton'
$script:CameraTabButton = Find-Control 'CameraTabButton'
$script:PrimaryActionButton = Find-Control 'PrimaryActionButton'
$script:SecondaryActionButton = Find-Control 'SecondaryActionButton'
$script:RecordingControlPanel = Find-Control 'RecordingControlPanel'
$script:RecordingStatusDot = Find-Control 'RecordingStatusDot'
$script:RecordingStateText = Find-Control 'RecordingStateText'
$script:RecordingToggleButton = Find-Control 'RecordingToggleButton'
$script:RecordingDurationText = Find-Control 'RecordingDurationText'
$script:OpenFolderButton = Find-Control 'OpenFolderButton'
$script:AddFolderButton = Find-Control 'AddFolderButton'
$script:UpButton = Find-Control 'UpButton'
$script:RefreshButton = Find-Control 'RefreshButton'
$script:BreadcrumbText = Find-Control 'BreadcrumbText'
$script:MediaItemsControl = Find-Control 'MediaItemsControl'
$script:StatusText = Find-Control 'StatusText'
$script:ItemCountText = Find-Control 'ItemCountText'
$script:CloseButton = Find-Control 'CloseButton'
$script:MinimizeButton = Find-Control 'MinimizeButton'
$script:DragHeader = Find-Control 'DragHeader'

$script:CurrentMode = $Mode
$script:CurrentPath = $script:ModeRoots[$Mode]
$script:ScreenRecordingProcess = $null
$script:ScreenRecordingStartedAt = $null
$script:LastScreenRecordingDuration = [TimeSpan]::Zero
$script:LastDisplayedRecordingSecond = -1
$script:LastRecordingUiState = $null
$script:RecordingActiveTextBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#FFF18B96'))
$script:RecordingActiveDotBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#FFFF5B6E'))
$script:RecordingIdleTextBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#AEB7C2'))
$script:RecordingIdleDotBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#6677838C'))
$script:CameraRecordingProcess = $null
$script:CameraPreviewProcess = $null
$script:ScreenOutputPath = $null
$script:CameraOutputPath = $null
$script:LastSignalValue = $null
$script:WindowReady = $false

function Quote-ProcessArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Test-ProcessRunning {
    param($Process)
    if (-not $Process) { return $false }
    try { return -not $Process.HasExited } catch { return $false }
}

function Set-Status {
    param([string]$Message)
    $script:StatusText.Text = $Message
    Write-MediaLog $Message
}

function Minimize-MediaWindow {
    $script:Window.WindowState = [Windows.WindowState]::Minimized
}

function Restore-MediaWindow {
    $script:Window.WindowState = [Windows.WindowState]::Normal
    $script:Window.Topmost = $true
    $script:Window.Activate()
}

function Get-VideoThumbnail {
    param([IO.FileInfo]$File)
    if (-not $script:FfmpegPath) { return $null }
    try {
        $identity = "$($File.FullName)|$($File.Length)|$($File.LastWriteTimeUtc.Ticks)"
        $sha = [Security.Cryptography.SHA1]::Create()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($identity)
            $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        } finally { $sha.Dispose() }
        $thumbnail = "$script:ThumbnailRoot\$hash.jpg"
        if (Test-Path -LiteralPath $thumbnail) { return $thumbnail }

        $arguments = '-hide_banner -loglevel error -ss 00:00:00.600 -i ' + (Quote-ProcessArgument $File.FullName) +
            ' -frames:v 1 -vf "scale=320:-2" -y ' + (Quote-ProcessArgument $thumbnail)
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $script:FfmpegPath
        $psi.Arguments = $arguments
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $process = [Diagnostics.Process]::Start($psi)
        if ($process.WaitForExit(10000) -and (Test-Path -LiteralPath $thumbnail)) { return $thumbnail }
        if (-not $process.HasExited) { $process.Kill() }
    } catch {
        Write-MediaLog "Thumbnail failed: $($File.FullName) :: $($_.Exception.Message)"
    }
    return $null
}

function New-MediaItem {
    param([IO.FileSystemInfo]$Entry)
    $isFolder = $Entry.PSIsContainer
    $thumbnail = $null
    $glyph = ''
    $badge = ''
    $meta = ''

    if ($isFolder) {
        $glyph = [string][char]0xE8B7
        $badge = '文件夹'
        $meta = '点击打开'
    } else {
        $extension = $Entry.Extension.ToLowerInvariant()
        if ($extension -in @('.png', '.jpg', '.jpeg', '.bmp', '.webp', '.gif')) {
            $thumbnail = $Entry.FullName
            $badge = '图片'
        } elseif ($extension -in @('.mp4', '.mkv', '.mov', '.webm', '.avi')) {
            $thumbnail = Get-VideoThumbnail ([IO.FileInfo]$Entry)
            if (-not $thumbnail) { $glyph = [string][char]0xE714 }
            $badge = '视频'
        } else {
            $glyph = [string][char]0xE7C3
            $badge = '文件'
        }
        $meta = $Entry.LastWriteTime.ToString('MM-dd HH:mm')
    }

    return [pscustomobject]@{
        Name = $Entry.Name
        FullPath = $Entry.FullName
        IsFolder = $isFolder
        Thumbnail = $thumbnail
        Glyph = $glyph
        Badge = $badge
        BadgeVisibility = 'Visible'
        Meta = $meta
    }
}

function Update-Breadcrumb {
    $root = $script:ModeRoots[$script:CurrentMode]
    $relative = $script:CurrentPath.Substring($root.Length).TrimStart('\')
    $modeName = switch ($script:CurrentMode) {
        Screenshot { '截图' }
        Recording { '屏幕录像' }
        Camera { '摄像头录像' }
    }
    if ($relative) { $script:BreadcrumbText.Text = "$modeName / $relative" }
    else { $script:BreadcrumbText.Text = $modeName }
    $script:UpButton.IsEnabled = ($script:CurrentPath -ne $root)
}

function Refresh-MediaItems {
    New-Item -ItemType Directory -Force -Path $script:CurrentPath | Out-Null
    $entries = @(Get-ChildItem -LiteralPath $script:CurrentPath -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.PSIsContainer -or $_.Extension.ToLowerInvariant() -in @('.png','.jpg','.jpeg','.bmp','.webp','.gif','.mp4','.mkv','.mov','.webm','.avi') } |
        Sort-Object @{Expression={-not $_.PSIsContainer};Ascending=$true}, @{Expression='LastWriteTime';Descending=$true})
    $items = New-Object Collections.ObjectModel.ObservableCollection[object]
    foreach ($entry in ($entries | Select-Object -First 120)) { [void]$items.Add((New-MediaItem $entry)) }
    $script:MediaItemsControl.ItemsSource = $items
    $script:ItemCountText.Text = "$($entries.Count) 项"
    Update-Breadcrumb
}

function Set-ActiveTabStyle {
    foreach ($button in @($script:ScreenshotTabButton, $script:RecordingTabButton, $script:CameraTabButton)) {
        $button.Background = [Windows.Media.Brushes]::Transparent
        $button.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#AEB7C2'))
    }
    $active = switch ($script:CurrentMode) {
        Screenshot { $script:ScreenshotTabButton }
        Recording { $script:RecordingTabButton }
        Camera { $script:CameraTabButton }
    }
    $active.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#354A5966'))
    $active.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#FFFFFF'))
}

function Format-RecordingDuration {
    param([TimeSpan]$Duration)
    $hours = [Math]::Floor($Duration.TotalHours)
    return '{0:00}:{1:00}:{2:00}' -f $hours, $Duration.Minutes, $Duration.Seconds
}

function Get-ScreenRecordingDuration {
    if ($script:ScreenRecordingStartedAt) {
        return (Get-Date) - $script:ScreenRecordingStartedAt
    }
    return $script:LastScreenRecordingDuration
}

function Update-RecordingUi {
    $isRecordingMode = $script:CurrentMode -eq 'Recording'
    $script:RecordingControlPanel.Visibility = if ($isRecordingMode) { 'Visible' } else { 'Collapsed' }

    $isRecording = Test-ProcessRunning $script:ScreenRecordingProcess
    $uiState = if ($isRecording) { 'Recording' } else { 'Idle' }
    if ($uiState -ne $script:LastRecordingUiState) {
        $script:RecordingToggleButton.IsChecked = $isRecording
        if ($isRecording) {
            $script:RecordingStateText.Text = '录制中'
            $script:RecordingStateText.Foreground = $script:RecordingActiveTextBrush
            $script:RecordingStatusDot.Fill = $script:RecordingActiveDotBrush
        } else {
            $script:RecordingStateText.Text = '未录制'
            $script:RecordingStateText.Foreground = $script:RecordingIdleTextBrush
            $script:RecordingStatusDot.Fill = $script:RecordingIdleDotBrush
        }
        $script:LastRecordingUiState = $uiState
    }

    $duration = Get-ScreenRecordingDuration
    $wholeSecond = [Math]::Floor($duration.TotalSeconds)
    if ($wholeSecond -ne $script:LastDisplayedRecordingSecond) {
        $script:RecordingDurationText.Text = Format-RecordingDuration $duration
        $script:LastDisplayedRecordingSecond = $wholeSecond
    }
}

function Update-ActionLabels {
    switch ($script:CurrentMode) {
        Screenshot {
            $script:HeaderSubtitle.Text = '直接截图与历史图片'
            $script:PrimaryActionButton.Content = '立即截图'
            $script:SecondaryActionButton.Content = '系统区域截图'
        }
        Recording {
            $script:HeaderSubtitle.Text = '屏幕录像与历史视频'
            $script:PrimaryActionButton.Content = if (Test-ProcessRunning $script:ScreenRecordingProcess) { '停止屏幕录像' } else { '开始屏幕录像' }
            $script:SecondaryActionButton.Content = '打开录像文件夹'
        }
        Camera {
            $script:HeaderSubtitle.Text = if ($script:CameraDevice) { "摄像头：$script:CameraDevice" } else { '未检测到摄像头' }
            $script:PrimaryActionButton.Content = if (Test-ProcessRunning $script:CameraPreviewProcess) { '关闭摄像头窗口' } else { '桌面摄像头窗口' }
            $script:SecondaryActionButton.Content = if (Test-ProcessRunning $script:CameraRecordingProcess) { '停止摄像' } else { '开始摄像' }
        }
    }
    Update-RecordingUi
}

function Switch-MediaMode {
    param([string]$NewMode)
    if ($NewMode -notin @('Screenshot','Recording','Camera')) { return }
    $script:CurrentMode = $NewMode
    $script:CurrentPath = $script:ModeRoots[$NewMode]
    Set-ActiveTabStyle
    Update-ActionLabels
    Refresh-MediaItems
    if ($script:WindowReady) {
        Restore-MediaWindow
    }
}

function Start-FfmpegRecording {
    param([string]$Kind)
    if (-not $script:FfmpegPath) {
        Set-Status '未找到 FFmpeg，无法开始录像'
        return $null
    }

    New-Item -ItemType Directory -Force -Path $script:CurrentPath | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    if ($Kind -eq 'Screen') {
        $output = "$script:CurrentPath\屏幕录像_$timestamp.mp4"
        $arguments = '-hide_banner -loglevel warning -y -f gdigrab -framerate 24 -draw_mouse 1 -i desktop ' +
            '-c:v libx264 -preset ultrafast -crf 24 -pix_fmt yuv420p -movflags +faststart ' + (Quote-ProcessArgument $output)
    } else {
        if (-not $script:CameraDevice) {
            Set-Status '未检测到可用摄像头'
            return $null
        }
        $output = "$script:CurrentPath\摄像头录像_$timestamp.mp4"
        $input = 'video=' + $script:CameraDevice
        $arguments = '-hide_banner -loglevel warning -y -f dshow -rtbufsize 256M -framerate 30 -video_size 1280x720 -i ' +
            (Quote-ProcessArgument $input) + ' -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p -movflags +faststart ' +
            (Quote-ProcessArgument $output)
    }

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $script:FfmpegPath
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    try {
        $process = [Diagnostics.Process]::Start($psi)
        Start-Sleep -Milliseconds 700
        if ($process.HasExited) {
            Set-Status '录像启动失败，请检查设备是否被其他应用占用'
            return $null
        }
        if ($Kind -eq 'Screen') { $script:ScreenOutputPath = $output }
        else { $script:CameraOutputPath = $output }
        return $process
    } catch {
        Set-Status "录像启动失败：$($_.Exception.Message)"
        return $null
    }
}

function Stop-FfmpegRecording {
    param($Process, [string]$Label)
    if (-not (Test-ProcessRunning $Process)) { return }
    try {
        $Process.StandardInput.WriteLine('q')
        $Process.StandardInput.Flush()
        if (-not $Process.WaitForExit(9000)) { $Process.Kill() }
        Set-Status "$Label 已保存"
    } catch {
        try { $Process.Kill() } catch {}
        Set-Status "$Label 已停止"
    }
}

function Capture-FullDesktop {
    $output = "$script:CurrentPath\截图_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
    try {
        Minimize-MediaWindow
        Start-Sleep -Milliseconds 450
        $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
        $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bounds.Size)
            $bitmap.Save($output, [Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
        Set-Status "截图已保存：$([IO.Path]::GetFileName($output))"
    } catch {
        Set-Status "截图失败：$($_.Exception.Message)"
    } finally {
        Restore-MediaWindow
        Refresh-MediaItems
    }
}

function Toggle-ScreenRecording {
    if (Test-ProcessRunning $script:ScreenRecordingProcess) {
        $script:LastScreenRecordingDuration = Get-ScreenRecordingDuration
        Stop-FfmpegRecording $script:ScreenRecordingProcess '屏幕录像'
        $script:ScreenRecordingProcess = $null
        $script:ScreenRecordingStartedAt = $null
        $durationText = Format-RecordingDuration $script:LastScreenRecordingDuration
        Set-Status "屏幕录像已保存，录制时长 $durationText"
        Refresh-MediaItems
    } else {
        $script:ScreenRecordingProcess = Start-FfmpegRecording 'Screen'
        if ($script:ScreenRecordingProcess) {
            $script:ScreenRecordingStartedAt = Get-Date
            $script:LastScreenRecordingDuration = [TimeSpan]::Zero
            $script:LastDisplayedRecordingSecond = -1
            Set-Status '屏幕录像进行中，录像页会实时显示录制时长'
            Minimize-MediaWindow
        }
    }
    Update-ActionLabels
}

function Stop-CameraPreview {
    if (Test-ProcessRunning $script:CameraPreviewProcess) {
        try { $script:CameraPreviewProcess.Kill() } catch {}
    }
    $script:CameraPreviewProcess = $null
}

function Toggle-CameraPreview {
    if (Test-ProcessRunning $script:CameraPreviewProcess) {
        Stop-CameraPreview
        Set-Status '摄像头桌面窗口已关闭'
        Update-ActionLabels
        return
    }
    if (Test-ProcessRunning $script:CameraRecordingProcess) {
        Set-Status '正在摄像，请先停止摄像再打开预览窗口'
        return
    }
    if (-not $script:FfplayPath -or -not $script:CameraDevice) {
        Set-Status '未找到 FFplay 或可用摄像头'
        return
    }
    $input = 'video=' + $script:CameraDevice
    $arguments = '-hide_banner -loglevel error -f dshow -framerate 30 -video_size 1280x720 -i ' +
        (Quote-ProcessArgument $input) + ' -window_title "桌面摄像头预览" -x 960 -y 540'
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $script:FfplayPath
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    try {
        $script:CameraPreviewProcess = [Diagnostics.Process]::Start($psi)
        Start-Sleep -Milliseconds 1800
        if ($script:CameraPreviewProcess.HasExited) {
            $previewError = $script:CameraPreviewProcess.StandardError.ReadToEnd().Trim()
            if ($previewError) { Write-MediaLog "Camera preview error: $previewError" }
            $script:CameraPreviewProcess = $null
            Set-Status '摄像头窗口启动失败，设备可能被占用'
        } else {
            Set-Status '摄像头窗口已生成，可自由移动和缩放'
            Minimize-MediaWindow
        }
    } catch {
        Set-Status "摄像头窗口启动失败：$($_.Exception.Message)"
    }
    Update-ActionLabels
}

function Toggle-CameraRecording {
    if (Test-ProcessRunning $script:CameraRecordingProcess) {
        Stop-FfmpegRecording $script:CameraRecordingProcess '摄像头录像'
        $script:CameraRecordingProcess = $null
        Refresh-MediaItems
    } else {
        Stop-CameraPreview
        $script:CameraRecordingProcess = Start-FfmpegRecording 'Camera'
        if ($script:CameraRecordingProcess) {
            Set-Status '摄像进行中，点击顶部“摄像头”可返回停止'
            Minimize-MediaWindow
        }
    }
    Update-ActionLabels
}

function Invoke-PrimaryAction {
    switch ($script:CurrentMode) {
        Screenshot { Capture-FullDesktop }
        Recording { Toggle-ScreenRecording }
        Camera { Toggle-CameraPreview }
    }
}

function Invoke-SecondaryAction {
    switch ($script:CurrentMode) {
        Screenshot {
            Minimize-MediaWindow
            Start-Process 'ms-screenclip:'
            Set-Status '系统区域截图已打开；自动保存由 Windows 截图工具设置决定'
        }
        Recording { Start-Process explorer.exe -ArgumentList (Quote-ProcessArgument $script:ModeRoots.Recording) }
        Camera { Toggle-CameraRecording }
    }
}

function Add-CustomFolder {
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('输入新文件夹名称：', '新建媒体文件夹', '')
    $name = $name.Trim()
    if (-not $name) { return }
    if ($name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $name -in @('.', '..')) {
        Set-Status '文件夹名称包含无效字符'
        return
    }
    $newFolder = "$script:CurrentPath\$name"
    if (Test-Path -LiteralPath $newFolder) {
        Set-Status '同名文件夹已经存在'
        return
    }
    New-Item -ItemType Directory -Path $newFolder | Out-Null
    Set-Status "已创建文件夹：$name"
    Refresh-MediaItems
}

function Open-MediaItem {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ((Get-Item -LiteralPath $Path).PSIsContainer) {
        $script:CurrentPath = $Path
        Refresh-MediaItems
    } else {
        Start-Process -FilePath $Path
    }
}

$script:ScreenshotTabButton.Add_Click({ Switch-MediaMode 'Screenshot' })
$script:RecordingTabButton.Add_Click({ Switch-MediaMode 'Recording' })
$script:CameraTabButton.Add_Click({ Switch-MediaMode 'Camera' })
$script:PrimaryActionButton.Add_Click({ Invoke-PrimaryAction })
$script:SecondaryActionButton.Add_Click({ Invoke-SecondaryAction })
$script:RecordingToggleButton.Add_Click({ Toggle-ScreenRecording })
$script:OpenFolderButton.Add_Click({ Start-Process explorer.exe -ArgumentList (Quote-ProcessArgument $script:CurrentPath) })
$script:AddFolderButton.Add_Click({ Add-CustomFolder })
$script:RefreshButton.Add_Click({ Refresh-MediaItems; Set-Status '历史内容已刷新' })
$script:UpButton.Add_Click({
    $root = $script:ModeRoots[$script:CurrentMode]
    if ($script:CurrentPath -ne $root) {
        $parent = [IO.Directory]::GetParent($script:CurrentPath)
        if ($parent -and $parent.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $script:CurrentPath = $parent.FullName
            Refresh-MediaItems
        }
    }
})
$script:CloseButton.Add_Click({ $script:Window.Close() })
$script:MinimizeButton.Add_Click({ Minimize-MediaWindow })
$script:DragHeader.Add_MouseLeftButtonDown({ try { $script:Window.DragMove() } catch {} })

$tileClickHandler = [Windows.RoutedEventHandler]{
    param($sender, $eventArgs)
    $element = $eventArgs.OriginalSource
    while ($element -and -not ($element -is [Windows.Controls.Button])) {
        $element = [Windows.Media.VisualTreeHelper]::GetParent($element)
    }
    if ($element -and $element.Tag) {
        Open-MediaItem ([string]$element.Tag)
        $eventArgs.Handled = $true
    }
}
$script:MediaItemsControl.AddHandler([Windows.Controls.Button]::ClickEvent, $tileClickHandler)

$script:SignalTimer = New-Object Windows.Threading.DispatcherTimer
$script:SignalTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$script:SignalTimer.Add_Tick({
    try {
        if (Test-Path -LiteralPath $script:ModeSignalPath) {
            $requested = [IO.File]::ReadAllText($script:ModeSignalPath).Trim()
            if ($requested -and $requested -ne $script:LastSignalValue) {
                $script:LastSignalValue = $requested
                Switch-MediaMode $requested
            }
            Remove-Item -LiteralPath $script:ModeSignalPath -Force -ErrorAction SilentlyContinue
            $script:LastSignalValue = $null
        }
        if ($script:ScreenRecordingProcess -and -not (Test-ProcessRunning $script:ScreenRecordingProcess)) {
            $script:LastScreenRecordingDuration = Get-ScreenRecordingDuration
            $script:ScreenRecordingStartedAt = $null
            $script:ScreenRecordingProcess = $null
            $durationText = Format-RecordingDuration $script:LastScreenRecordingDuration
            Set-Status "屏幕录像已结束，录制时长 $durationText"
            Update-ActionLabels
            Refresh-MediaItems
        }
        if ($script:CameraRecordingProcess -and -not (Test-ProcessRunning $script:CameraRecordingProcess)) {
            $script:CameraRecordingProcess = $null
            Update-ActionLabels
            Refresh-MediaItems
        }
        if ($script:CameraPreviewProcess -and -not (Test-ProcessRunning $script:CameraPreviewProcess)) {
            $script:CameraPreviewProcess = $null
            Update-ActionLabels
        }
        Update-RecordingUi
    } catch {
        Write-MediaLog "Timer error: $($_.Exception.Message)"
    }
})
$script:SignalTimer.Start()

$script:Window.Add_SourceInitialized({
    $workArea = [Windows.SystemParameters]::WorkArea
    $script:Window.Left = [Math]::Max($workArea.Left + 20, $workArea.Left + (($workArea.Width - $script:Window.Width) / 2))
    $script:Window.Top = $workArea.Top + 42
})
$script:Window.Add_Closing({
    $script:SignalTimer.Stop()
    if (Test-ProcessRunning $script:ScreenRecordingProcess) { Stop-FfmpegRecording $script:ScreenRecordingProcess '屏幕录像' }
    if (Test-ProcessRunning $script:CameraRecordingProcess) { Stop-FfmpegRecording $script:CameraRecordingProcess '摄像头录像' }
    Stop-CameraPreview
    Remove-Item -LiteralPath $script:PidPath, $script:ModeSignalPath -Force -ErrorAction SilentlyContinue
    try { $script:SingleInstanceMutex.ReleaseMutex() } catch {}
    $script:SingleInstanceMutex.Dispose()
})

Switch-MediaMode $Mode
Set-Status '媒体中心已就绪'
$script:WindowReady = $true
[void]$script:Window.ShowDialog()
