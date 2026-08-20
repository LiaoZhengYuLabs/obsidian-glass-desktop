#requires -version 5.1

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$MediaRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
$StateToolbar = "$env:APPDATA\com.seelen.seelen-ui\data\seelen-fancy-toolbar\state.yml"
$ReportPath = "$WorkspaceRoot\DesktopMediaCenter\logs\verify-camera-language-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) | Out-Null

$Results = New-Object System.Collections.Generic.List[string]
function Add-Result {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $State = if ($Passed) { 'PASS' } else { 'FAIL' }
    $Line = '[' + $State + '] ' + $Name + ' - ' + $Detail
    $Results.Add($Line)
    Write-Host $Line
}

$Camera = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -eq 'Integrated Camera' -and $_.Status -eq 'OK' } | Select-Object -First 1
Add-Result '摄像头驱动' ($null -ne $Camera) 'Integrated Camera 状态为 OK'

$Ffmpeg = (Get-Command 'ffmpeg.exe' -ErrorAction SilentlyContinue).Source
$ProbePassed = $false
if ($Ffmpeg) {
    & $Ffmpeg -hide_banner -loglevel error -f dshow -framerate 15 -video_size 640x480 -i 'video=Integrated Camera' -frames:v 1 -f null - 2>$null
    $ProbePassed = ($LASTEXITCODE -eq 0)
}
Add-Result '摄像头实时取帧' $ProbePassed 'FFmpeg 从 Integrated Camera 读取一帧'

$Languages = Get-WinUserLanguageList
$English = $Languages | Where-Object { $_.LanguageTag -eq 'en-US' -and $_.InputMethodTips -contains '0409:00000409' } | Select-Object -First 1
Add-Result 'English 输入法' ($null -ne $English) 'English (US) 键盘布局已注册'

$ToolbarText = if (Test-Path -LiteralPath $StateToolbar) { Get-Content -LiteralPath $StateToolbar -Raw } else { '' }
Add-Result '实时语言控件' ($ToolbarText -match "@seelen/tb-keyboard-selector") 'Seelen 键盘选择器已接管语言显示和选择'
Add-Result '摄像头入口' ($ToolbarText -match 'open-camera\.cmd') '顶部摄像头仍连接媒体中心'

$MediaText = Get-Content -LiteralPath "$MediaRoot\DesktopMediaCenter.ps1" -Raw
Add-Result '设备选择逻辑' ($MediaText -notmatch 'Get-PnpDevice -Class Camera') '不会再把 Integrated IR Camera 当作视频设备'
Add-Result '单击摄像头预览' ($MediaText -match 'AutoOpenCameraPreview') '顶部摄像头打开后会自动启动实时预览'

Add-Result 'Seelen UI 进程' ($null -ne (Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue)) '工具栏进程正在运行'

$Results | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host ('报告：' + $ReportPath)
if (@($Results | Where-Object { $_.StartsWith('[FAIL]') }).Count -gt 0) { exit 1 }
