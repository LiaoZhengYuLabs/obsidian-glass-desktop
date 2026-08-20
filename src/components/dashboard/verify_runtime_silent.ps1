$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $root + "\ObsidianAIDashboard.ps1"
$passFlag = $root + "\runtime-verification-passed.flag"
$resultPath = $root + "\dashboard-runtime-verification.json"
$errorDir = $root + "\runtime-verification-errors"
$errors = New-Object System.Collections.Generic.List[string]

if (Test-Path -LiteralPath $passFlag) { Remove-Item -LiteralPath $passFlag -Force }
if (Test-Path -LiteralPath $errorDir) { Remove-Item -LiteralPath $errorDir -Recurse -Force }

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class ObsidianRuntimeAuditNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")] public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int index);
    [DllImport("user32.dll", EntryPoint="GetWindowLong")] public static extern IntPtr GetWindowLongPtr32(IntPtr hWnd, int index);
    public static IntPtr GetWindowLongPtr(IntPtr hWnd, int index) { return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, index) : GetWindowLongPtr32(hWnd, index); }
    public static IntPtr[] FindVisibleWindows(uint targetProcessId)
    {
        var result = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            uint id;
            GetWindowThreadProcessId(h, out id);
            if (id == targetProcessId && IsWindowVisible(h)) result.Add(h);
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }
}
"@

$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
})
$audit = [ordered]@{
    VerifiedAt = (Get-Date).ToString("o")
    ProcessCount = $running.Count
    ProcessId = $null
    Window = $null
    ForegroundUnchanged = $false
    CpuDeltaSeconds = $null
}
if ($running.Count -ne 1) {
    $errors.Add("Expected one Dashboard process; found $($running.Count).")
} else {
    $processId = [uint32]$running[0].ProcessId
    $audit.ProcessId = $processId
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $cpuBefore = if ($process) { [double]$process.CPU } else { 0.0 }
    $foregroundBefore = [ObsidianRuntimeAuditNative]::GetForegroundWindow()
    Start-Sleep -Seconds 6
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $foregroundAfter = [ObsidianRuntimeAuditNative]::GetForegroundWindow()
    if (!$process) {
        $errors.Add("Dashboard process exited during the runtime sample.")
    } else {
        $cpuDelta = [double]$process.CPU - $cpuBefore
        $audit.CpuDeltaSeconds = [Math]::Round($cpuDelta, 4)
        if ($cpuDelta -gt 1.2) { $errors.Add(("Dashboard CPU delta was too high: {0:N3}s / 6s." -f $cpuDelta)) }
    }
    $audit.ForegroundUnchanged = ($foregroundBefore -eq $foregroundAfter)
    if (!$audit.ForegroundUnchanged) {
        $errors.Add("Foreground focus changed during the silent runtime sample.")
    }

    $windows = [ObsidianRuntimeAuditNative]::FindVisibleWindows($processId)
    if ($windows.Count -lt 1) {
        $errors.Add("Dashboard did not create a visible WPF window.")
    } else {
        $window = $windows[0]
        $rect = New-Object ObsidianRuntimeAuditNative+RECT
        [void][ObsidianRuntimeAuditNative]::GetWindowRect($window, [ref]$rect)
        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top
        if ($width -lt 360 -or $width -gt 430) { $errors.Add("Unexpected Dashboard window width: $width.") }
        if ($height -lt 470 -or $height -gt 540) { $errors.Add("Unexpected Dashboard window height: $height.") }
        if ($rect.Left -lt 1000) { $errors.Add("Dashboard is not positioned in the right-side safe area: left=$($rect.Left).") }
        $extendedStyle = [int64][ObsidianRuntimeAuditNative]::GetWindowLongPtr($window, -20)
        $audit.Window = [ordered]@{
            Handle = $window.ToInt64()
            Left = $rect.Left
            Top = $rect.Top
            Right = $rect.Right
            Bottom = $rect.Bottom
            Width = $width
            Height = $height
            Topmost = (($extendedStyle -band 0x8) -ne 0)
        }
        if (($extendedStyle -band 0x8) -ne 0) { $errors.Add("Dashboard is unexpectedly topmost.") }
    }
}

$audit.Errors = @($errors)
$audit | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultPath -Encoding UTF8

if ($errors.Count -gt 0) {
    [void](New-Item -ItemType Directory -Path $errorDir -Force)
    $index = 0
    foreach ($item in $errors) {
        $index++
        $safeName = ($item -replace '[\\/:*?"<>|\r\n]+', '_')
        [IO.File]::WriteAllText(($errorDir + "\" + $index.ToString("00") + "-" + $safeName + ".txt"), $item, (New-Object Text.UTF8Encoding($false)))
    }
    exit 1
}

[IO.File]::WriteAllText($passFlag, "OK", (New-Object Text.UTF8Encoding($false)))
exit 0
