$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDashboard.ps1"
$controlOverlayScript = $projectRoot + "\SystemControlOverlay.ps1"
$cinemaStatePath = $projectRoot + "\data\cinema-mode-active.flag"
$controlOverlayRunning = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $controlOverlayScript + "*")
})

if ($controlOverlayRunning) {
    foreach ($process in $controlOverlayRunning) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "System control overlay stopped." -ForegroundColor Green
}

$running = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
}

if ($running) {
    foreach ($process in $running) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $cinemaStatePath) {
        try {
            Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class StopDashboardNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int command);

    public static void RestoreShellSurfaces()
    {
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId == 0) return true;

            string processName;
            try { processName = Process.GetProcessById((int)processId).ProcessName; }
            catch { return true; }

            StringBuilder title = new StringBuilder(128);
            StringBuilder windowClass = new StringBuilder(128);
            GetWindowText(hWnd, title, title.Capacity);
            GetClassName(hWnd, windowClass, windowClass.Capacity);
            bool isSeelenSurface = string.Equals(processName, "seelen-ui", StringComparison.OrdinalIgnoreCase) &&
                (string.Equals(title.ToString(), "Seelen Fancy Toolbar", StringComparison.OrdinalIgnoreCase) ||
                 string.Equals(title.ToString(), "SeelenWeg", StringComparison.OrdinalIgnoreCase));
            bool isMyDockFinderSurface = string.Equals(processName, "Dock_64", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(windowClass.ToString(), "MyDockAPP", StringComparison.OrdinalIgnoreCase);
            if (isSeelenSurface || isMyDockFinderSurface) ShowWindowAsync(hWnd, 4);
            return true;
        }, IntPtr.Zero);
    }
}
'@
            [StopDashboardNative]::RestoreShellSurfaces()
            [IO.File]::Delete($cinemaStatePath)
        } catch {
            Write-Warning ("Desktop shell restore failed: " + $_.Exception.Message)
        }
    }
    Write-Host "Obsidian AI Desktop Dashboard stopped." -ForegroundColor Green
} else {
    Write-Host "Dashboard is not running."
}
