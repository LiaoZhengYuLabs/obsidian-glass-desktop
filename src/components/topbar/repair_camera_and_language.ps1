#requires -version 5.1

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$MediaRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
$SeelenRoot = "$env:APPDATA\com.seelen.seelen-ui"
$StateToolbar = "$SeelenRoot\data\seelen-fancy-toolbar\state.yml"
$BaseToolbar = "$SeelenRoot\profiles\base\toolbar.yml"
$BackupRoot = "$WorkspaceRoot\DesktopMediaCenter\backups\camera-language-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
$LogRoot = "$WorkspaceRoot\DesktopMediaCenter\logs"
$LogPath = "$LogRoot\repair-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'

New-Item -ItemType Directory -Force -Path $BackupRoot, $LogRoot | Out-Null

function Write-RepairLog {
    param([string]$Message)
    $Line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Write-Host $Line
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
}

function Copy-BackupFile {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination ($BackupRoot + '\' + (Split-Path -Leaf $Path)) -Force
    }
}

function Write-Utf8Bom {
    param([string]$Path, [string]$Content)
    # Windows PowerShell 5.1 needs a BOM to read the Chinese UI strings reliably.
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($true)))
}

function Ensure-EnglishKeyboard {
    $Languages = Get-WinUserLanguageList
    $English = $Languages | Where-Object { $_.LanguageTag -eq 'en-US' } | Select-Object -First 1
    if (-not $English) {
        Write-RepairLog '添加 English (United States) 键盘布局。'
        $English = New-WinUserLanguageList 'en-US'
        $Languages.Add($English[0])
        Set-WinUserLanguageList $Languages -Force
    }

    $Tips = @(Get-WinUserLanguageList | Where-Object { $_.LanguageTag -eq 'en-US' } | ForEach-Object { $_.InputMethodTips })
    if ($Tips -notcontains '0409:00000409') {
        throw 'English (US) 键盘布局没有成功添加。'
    }
}

function Get-DshowVideoCamera {
    $Ffmpeg = (Get-Command 'ffmpeg.exe' -ErrorAction SilentlyContinue).Source
    if (-not $Ffmpeg) { return $null }
    # DirectShow intentionally returns a nonzero exit code after listing devices.
    # Treat its text output as the authoritative device list.
    $PreviousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $Output = & $Ffmpeg -hide_banner -list_devices true -f dshow -i dummy 2>&1
    } finally {
        $ErrorActionPreference = $PreviousErrorAction
    }
    foreach ($LineObject in $Output) {
        $Line = [string]$LineObject
        if ($Line -match '"([^"]+)"\s*\(video\)') {
            return $matches[1]
        }
    }
    return $null
}

function Set-CameraDeviceInMediaCenter {
    param([string]$DeviceName)
    $Path = "$MediaRoot\DesktopMediaCenter.ps1"
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "未找到媒体中心脚本：$Path"
    }
    $Text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    if ($Text -match 'PreviousErrorAction') {
        # The PowerShell 5.1-compatible DirectShow parsing is already installed.
        return
    }
    $Pattern = '(?s)function Get-CameraDeviceName \{.*?\n\}\n\n\$script:CameraDevice = Get-CameraDeviceName'
    $Replacement = @"
function Get-CameraDeviceName {
    if (-not `$script:FfmpegPath) { return `$null }
    `$previousErrorAction = `$ErrorActionPreference
    try {
        `$ErrorActionPreference = 'Continue'
        `$output = & `$script:FfmpegPath -hide_banner -list_devices true -f dshow -i dummy 2>&1
    } finally {
        `$ErrorActionPreference = `$previousErrorAction
    }
    foreach (`$entry in `$output) {
        `$line = [string]`$entry
        if (`$line -match '"([^\"]+)"\s*\(video\)') {
            return `$matches[1]
        }
    }
    return `$null
}

`$script:CameraDevice = Get-CameraDeviceName
"@
    $Updated = [regex]::Replace($Text, $Pattern, $Replacement, 1)
    if ($Updated -eq $Text) {
        throw '未能定位媒体中心的摄像头设备选择逻辑。'
    }
    Write-Utf8Bom -Path $Path -Content $Updated
}

function Enable-AutoCameraPreview {
    $Path = "$MediaRoot\DesktopMediaCenter.ps1"
    $Text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    if ($Text -match 'AutoOpenCameraPreview') {
        return
    }

    $Pattern = '\$script:WindowReady = \$true\r?\n\[void\]\$script:Window\.ShowDialog\(\)'
    $Replacement = @'
$script:WindowReady = $true
if ($Mode -eq 'Camera') {
    $script:AutoOpenCameraPreview = $true
    $script:Window.Add_ContentRendered({
        if ($script:AutoOpenCameraPreview) {
            $script:AutoOpenCameraPreview = $false
            Toggle-CameraPreview
        }
    })
}
[void]$script:Window.ShowDialog()
'@ -replace "`r?`n", [Environment]::NewLine

    $Updated = [regex]::Replace($Text, $Pattern, $Replacement, 1)
    if ($Updated -eq $Text) {
        throw '未能定位媒体中心的启动位置。'
    }
    Write-Utf8Bom -Path $Path -Content $Updated
}

function Set-ToolbarItems {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "未找到工具栏配置：$Path"
    }

    $Text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    if ($Text -match "@seelen/tb-keyboard-selector") {
        return
    }
    $ItemStart = $Text.IndexOf('- id: language-toggle')
    if ($ItemStart -lt 0) {
        throw "未能定位语言切换控件：$Path"
    }
    $NextItem = $Text.IndexOf('- id: practical-tasks', $ItemStart)
    if ($NextItem -lt 0) {
        throw "未能定位语言切换控件：$Path"
    }

    $LineStart = $Text.LastIndexOf("`n", $ItemStart) + 1
    $NextLineStart = $Text.LastIndexOf("`n", $NextItem) + 1
    $Indent = $Text.Substring($LineStart, $ItemStart - $LineStart)
    $Replacement = $Indent + "- '@seelen/tb-keyboard-selector'" + [Environment]::NewLine
    $Updated = $Text.Substring(0, $LineStart) + $Replacement + $Text.Substring($NextLineStart)
    Write-Utf8Bom -Path $Path -Content $Updated
}

function Write-LanguageToggle {
    $Path = "$MediaRoot\toggle-language.ps1"
    $Lines = @(
        '$ErrorActionPreference = ''Stop''',
        '',
        'Add-Type @''',
        'using System;',
        'using System.Runtime.InteropServices;',
        'public static class DesktopLanguageToggle {',
        '    public const uint WM_INPUTLANGCHANGEREQUEST = 0x0050;',
        '    public const uint KLF_ACTIVATE = 0x00000001;',
        '    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
        '    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);',
        '    [DllImport("user32.dll")] public static extern IntPtr GetKeyboardLayout(uint threadId);',
        '    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadKeyboardLayout(string id, uint flags);',
        '    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);',
        '}',
        '''@',
        '',
        '$languages = Get-WinUserLanguageList',
        'if (-not ($languages | Where-Object { $_.LanguageTag -eq ''en-US'' })) {',
        '    $english = New-WinUserLanguageList ''en-US''',
        '    $languages.Add($english[0])',
        '    Set-WinUserLanguageList $languages -Force',
        '}',
        '',
        '$window = [DesktopLanguageToggle]::GetForegroundWindow()',
        '$processId = 0',
        '$threadId = [DesktopLanguageToggle]::GetWindowThreadProcessId($window, [ref]$processId)',
        '$layout = [DesktopLanguageToggle]::GetKeyboardLayout($threadId)',
        '$languageId = $layout.ToInt64() -band 0xFFFF',
        '',
        'if ($languageId -eq 0x0409) {',
        '    $targetId = ''00000804''',
        '    $targetName = ''简体中文''',
        '} else {',
        '    $targetId = ''00000409''',
        '    $targetName = ''English (US)''',
        '}',
        '',
        '$targetLayout = [DesktopLanguageToggle]::LoadKeyboardLayout($targetId, [DesktopLanguageToggle]::KLF_ACTIVATE)',
        'if ($targetLayout -eq [IntPtr]::Zero) {',
        '    throw "无法加载输入法：$targetName"',
        '}',
        'if ($window -ne [IntPtr]::Zero) {',
        '    [void][DesktopLanguageToggle]::PostMessage(',
        '        $window,',
        '        [DesktopLanguageToggle]::WM_INPUTLANGCHANGEREQUEST,',
        '        [IntPtr]::Zero,',
        '        $targetLayout',
        '    )',
        '}',
        '',
        '$stateRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"',
        'New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null',
        '[IO.File]::WriteAllText("$stateRoot\language-state.txt", $targetName, (New-Object Text.UTF8Encoding($false)))'
    )
    $Content = $Lines -join [Environment]::NewLine
    Write-Utf8Bom -Path $Path -Content $Content
}

function Write-CameraLauncher {
    $Path = "$MediaRoot\open-camera.cmd"
    $Content = '@echo off' + [Environment]::NewLine + 'start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0DesktopMediaCenter.ps1" -Mode Camera'
    Write-Utf8Bom -Path $Path -Content $Content
}

Write-RepairLog '开始备份现有工具栏和媒体中心配置。'
foreach ($Path in @($StateToolbar, $BaseToolbar, "$MediaRoot\DesktopMediaCenter.ps1", "$MediaRoot\toggle-language.ps1", "$MediaRoot\open-camera.cmd")) {
    Copy-BackupFile -Path $Path
}

Write-RepairLog '检查并补齐 English (US) 键盘布局。'
Ensure-EnglishKeyboard

$CameraDevice = Get-DshowVideoCamera
if ([string]::IsNullOrWhiteSpace($CameraDevice)) {
    throw '未找到 DirectShow 视频摄像头。'
}
Write-RepairLog ('检测到可用视频摄像头：' + $CameraDevice)

Write-RepairLog '修复媒体中心的摄像头设备选择。'
Set-CameraDeviceInMediaCenter -DeviceName $CameraDevice
Enable-AutoCameraPreview
Write-LanguageToggle
Write-CameraLauncher

Write-RepairLog '将语言入口替换为 Seelen 实时键盘布局选择器。'
Set-ToolbarItems -Path $StateToolbar
Set-ToolbarItems -Path $BaseToolbar

Write-RepairLog '刷新 Seelen UI 工具栏。'
Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$SeelenExe = Get-ChildItem 'C:\Program Files\WindowsApps\Seelen.SeelenUI_*\seelen-ui.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if ($SeelenExe) {
    Start-Process -FilePath $SeelenExe
}

Write-RepairLog '完成。工具栏显示的是当前真实输入法，摄像头会使用实际视频设备。'
