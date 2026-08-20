param(
    [int]$Seconds = 12
)

$ErrorActionPreference = "SilentlyContinue"
if ($Seconds -lt 1) { $Seconds = 1 }
if ($Seconds -gt 20) { $Seconds = 20 }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class LivelyStartupWindowGuard
{
    private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool ShowWindowAsync(IntPtr window, int command);

    public static void HideForProcessIds(int[] processIds)
    {
        EnumWindows(delegate(IntPtr window, IntPtr parameter)
        {
            uint processId;
            GetWindowThreadProcessId(window, out processId);
            if (IsWindowVisible(window) && Array.IndexOf(processIds, (int)processId) >= 0)
            {
                ShowWindowAsync(window, 0);
            }
            return true;
        }, IntPtr.Zero);
    }
}
"@

$deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
do {
    $processIds = @(Get-Process -Name "Lively" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    if ($processIds.Count -gt 0) {
        [LivelyStartupWindowGuard]::HideForProcessIds([int[]]$processIds)
    }
    Start-Sleep -Milliseconds 200
} while ([DateTime]::UtcNow -lt $deadline)
