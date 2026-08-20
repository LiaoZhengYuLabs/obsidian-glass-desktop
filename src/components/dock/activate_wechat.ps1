$ErrorActionPreference = "SilentlyContinue"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectFolder)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$wechatExe = $null
$wechatCandidates = @(
    (Join-Path ${env:ProgramFiles} 'Tencent\Weixin\Weixin.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Tencent\Weixin\Weixin.exe'),
    (Join-Path $env:LOCALAPPDATA 'Tencent\Weixin\Weixin.exe')
)
foreach ($candidate in $wechatCandidates) {
    if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $wechatExe = $candidate
        break
    }
}
$logFolder = "$projectFolder\logs"
$logFile = "$logFolder\wechat-activate.log"

New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WeChatWindowApi
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);

    public struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

$allProcesses = Get-CimInstance Win32_Process
$wechatProcesses = $allProcesses | Where-Object {
    $_.Name -eq "Weixin.exe" -and $_.CommandLine -notmatch "--type="
}
$wechatIds = @($wechatProcesses | ForEach-Object { [int]$_.ProcessId })
$windows = New-Object System.Collections.Generic.List[object]

[WeChatWindowApi]::EnumWindows({
    param($windowHandle, $parameter)

    if (-not [WeChatWindowApi]::IsWindowVisible($windowHandle)) {
        return $true
    }

    $windowProcessId = 0
    [void][WeChatWindowApi]::GetWindowThreadProcessId($windowHandle, [ref]$windowProcessId)
    if ($wechatIds -notcontains [int]$windowProcessId) {
        return $true
    }

    $rect = New-Object WeChatWindowApi+Rect
    [void][WeChatWindowApi]::GetWindowRect($windowHandle, [ref]$rect)
    $area = [Math]::Max(0, $rect.Right - $rect.Left) * [Math]::Max(0, $rect.Bottom - $rect.Top)
    $childCount = @($allProcesses | Where-Object { $_.ParentProcessId -eq $windowProcessId }).Count
    $score = ($childCount * 1000000000) + $area

    $windows.Add([pscustomobject]@{
        Handle = $windowHandle
        ProcessId = [int]$windowProcessId
        Score = $score
    })
    return $true
}, [IntPtr]::Zero) | Out-Null

$target = $windows | Sort-Object Score -Descending | Select-Object -First 1
if ($target) {
    [void][WeChatWindowApi]::ShowWindowAsync($target.Handle, 9)
    Start-Sleep -Milliseconds 120
    [void][WeChatWindowApi]::SetForegroundWindow($target.Handle)
    Add-Content -LiteralPath $logFile -Value "$(Get-Date -Format s) Activated existing WeChat PID $($target.ProcessId)."
    exit 0
}

if (Test-Path -LiteralPath $wechatExe) {
    Start-Process -FilePath $wechatExe
    Add-Content -LiteralPath $logFile -Value "$(Get-Date -Format s) Started WeChat because no existing window was found."
    exit 0
}

Add-Content -LiteralPath $logFile -Value "$(Get-Date -Format s) WeChat executable was not found."
exit 1
