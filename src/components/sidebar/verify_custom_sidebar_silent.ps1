$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $root + "\ObsidianSidebar.ps1"
$resultPath = $root + "\sidebar-runtime-verification.json"
$passFlag = $root + "\sidebar-runtime-verification-passed.flag"
$errorDir = $root + "\sidebar-runtime-verification-errors"
$errors = New-Object System.Collections.Generic.List[string]

if (Test-Path -LiteralPath $passFlag) { Remove-Item -LiteralPath $passFlag -Force }
if (Test-Path -LiteralPath $errorDir) { Remove-Item -LiteralPath $errorDir -Recurse -Force }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class ObsidianSidebarAuditNative
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

$monitorRunning = @(Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -like "*apply_sidebar_when_safe.ps1*" -and
    $_.ProcessId -ne $PID
})
if ($monitorRunning.Count -gt 0) {
    $errors.Add("The temporary safe-apply monitor is still running.")
}

$audit = [ordered]@{
    VerifiedAt = (Get-Date).ToString("o")
    ProcessCount = $running.Count
    ProcessId = $null
    Window = $null
    ForegroundUnchanged = $false
    CpuDeltaSeconds = $null
    FullscreenMediaActive = $false
    SafeApplyMonitorCount = $monitorRunning.Count
}

if ($running.Count -ne 1) {
    $errors.Add("Expected one Sidebar process; found $($running.Count).")
} else {
    $processId = [uint32]$running[0].ProcessId
    $audit.ProcessId = $processId
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $cpuBefore = if ($process) { [double]$process.CPU } else { 0.0 }
    $foregroundBefore = [ObsidianSidebarAuditNative]::GetForegroundWindow()
    Start-Sleep -Seconds 6
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $foregroundAfter = [ObsidianSidebarAuditNative]::GetForegroundWindow()

    if (!$process) {
        $errors.Add("Sidebar process exited during the runtime sample.")
    } else {
        $cpuDelta = [double]$process.CPU - $cpuBefore
        $audit.CpuDeltaSeconds = [Math]::Round($cpuDelta, 4)
        if ($cpuDelta -gt 1.5) {
            $errors.Add(("Sidebar CPU delta was too high: {0:N3}s / 6s." -f $cpuDelta))
        }
    }

    $audit.ForegroundUnchanged = ($foregroundBefore -eq $foregroundAfter)
    if (!$audit.ForegroundUnchanged) {
        $errors.Add("Foreground focus changed during the silent runtime sample.")
    }

    $windows = [ObsidianSidebarAuditNative]::FindVisibleWindows($processId)
    $candidate = $null
    foreach ($handle in $windows) {
        $rect = New-Object ObsidianSidebarAuditNative+RECT
        [void][ObsidianSidebarAuditNative]::GetWindowRect($handle, [ref]$rect)
        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top
        if ($height -ge 620 -and $width -le 540) {
            $candidate = [ordered]@{
                Handle = $handle.ToInt64()
                Left = $rect.Left
                Top = $rect.Top
                Right = $rect.Right
                Bottom = $rect.Bottom
                Width = $width
                Height = $height
                Topmost = (([int64][ObsidianSidebarAuditNative]::GetWindowLongPtr($handle, -20) -band 0x8) -ne 0)
            }
            break
        }
    }

    if ($null -eq $candidate) {
        $errors.Add("Sidebar did not create the expected Stage Manager window.")
    } else {
        $audit.Window = $candidate
        if ($candidate.Width -lt 200 -or $candidate.Width -gt 520) {
            $errors.Add("Unexpected Sidebar width: $($candidate.Width).")
        }
        if ($candidate.Height -lt 780 -or $candidate.Height -gt 1750) {
            $errors.Add("Unexpected Sidebar height: $($candidate.Height).")
        }
        if ($candidate.Left -lt -560 -or $candidate.Left -gt 80) {
            $errors.Add("Sidebar is outside the intended left-edge range: left=$($candidate.Left).")
        }

        $foregroundRect = New-Object ObsidianSidebarAuditNative+RECT
        [void][ObsidianSidebarAuditNative]::GetWindowRect($foregroundAfter, [ref]$foregroundRect)
        [uint32]$foregroundProcessId = 0
        [void][ObsidianSidebarAuditNative]::GetWindowThreadProcessId($foregroundAfter, [ref]$foregroundProcessId)
        $foregroundProcess = Get-Process -Id $foregroundProcessId -ErrorAction SilentlyContinue
        $screen = [Windows.Forms.Screen]::FromHandle($foregroundAfter)
        $bounds = $screen.Bounds
        $isFullscreen = [Math]::Abs($foregroundRect.Left - $bounds.Left) -le 4 -and
            [Math]::Abs($foregroundRect.Top - $bounds.Top) -le 4 -and
            [Math]::Abs($foregroundRect.Right - $bounds.Right) -le 4 -and
            [Math]::Abs($foregroundRect.Bottom - $bounds.Bottom) -le 4
        $protectedProcesses = @("msedge", "chrome", "firefox", "vlc", "mpv", "potplayer", "applicationframehost")
        $isFullscreenMedia = $isFullscreen -and $foregroundProcess -and
            ($protectedProcesses -contains $foregroundProcess.ProcessName.ToLowerInvariant())
        $audit.FullscreenMediaActive = [bool]$isFullscreenMedia

        if ($isFullscreenMedia) {
            if ($candidate.Left -gt (-1 * $candidate.Width + 8)) {
                $errors.Add("Sidebar did not move fully off-screen during fullscreen media: left=$($candidate.Left).")
            }
            if ($candidate.Topmost) {
                $errors.Add("Sidebar remained topmost during fullscreen media.")
            }
        } elseif ($candidate.Left -gt -10 -and !$candidate.Topmost) {
            $errors.Add("An expanded Sidebar is expected to be topmost outside fullscreen media.")
        }
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
