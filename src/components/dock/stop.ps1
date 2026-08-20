$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = $projectRoot + "\ObsidianAIDock.ps1"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }

$processes = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 }

foreach ($process in @($processes)) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ObsidianDockRestoreNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint colorKey, byte alpha, uint flags);
    public static int ShowNativeDock(int processId) {
        int changed = 0;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint owner;
            GetWindowThreadProcessId(hWnd, out owner);
            if (owner != (uint)processId) return true;
            StringBuilder className = new StringBuilder(128);
            GetClassName(hWnd, className, className.Capacity);
            if (className.ToString() == "MyDockAPP") {
                int style = GetWindowLong(hWnd, -20);
                SetWindowLong(hWnd, -20, (style | 0x80000) & ~0x20);
                SetLayeredWindowAttributes(hWnd, 0, 255, 2);
                ShowWindow(hWnd, 5);
                changed++;
            }
            return true;
        }, IntPtr.Zero);
        return changed;
    }
}
"@

$dock = Get-Process Dock_64 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $dock) {
    $dockRoot = Get-ObsidianGlassDockRoot
    $dockExe = if (![string]::IsNullOrWhiteSpace($dockRoot)) { Join-Path $dockRoot "Dock_64.exe" } else { $null }
    if (![string]::IsNullOrWhiteSpace($dockExe) -and (Test-Path -LiteralPath $dockExe -PathType Leaf)) {
        Start-Process -FilePath $dockExe -WorkingDirectory (Split-Path -Parent $dockExe)
        Start-Sleep -Seconds 2
        $dock = Get-Process Dock_64 -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}
if ($null -ne $dock) { [void][ObsidianDockRestoreNative]::ShowNativeDock($dock.Id) }

Write-Host "Obsidian AI Dock stopped; MyDockFinder restored." -ForegroundColor Green
