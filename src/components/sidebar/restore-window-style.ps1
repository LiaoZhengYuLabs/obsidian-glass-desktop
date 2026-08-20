$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = $projectRoot + "\state\window-style-state.csv"
$logPath = $projectRoot + "\logs\sidebar.log"

if (!(Test-Path -LiteralPath $statePath)) {
    exit 0
}

if (!("ObsidianDwmRestoreNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ObsidianDwmRestoreNative {
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
"@
}

function Restore-Attribute {
    param(
        [IntPtr]$Handle,
        [int]$Attribute,
        [string]$HasValue,
        [string]$OriginalValue
    )

    if ($HasValue -ne "True") {
        return
    }
    $value = [int64]$OriginalValue
    $intValue = [BitConverter]::ToInt32([BitConverter]::GetBytes($value), 0)
    [ObsidianDwmRestoreNative]::DwmSetWindowAttribute($Handle, $Attribute, [ref]$intValue, 4) | Out-Null
}

$restored = 0
$records = @(Import-Csv -LiteralPath $statePath)
foreach ($record in $records) {
    $handle = [IntPtr]::new([int64]$record.Handle)
    if (![ObsidianDwmRestoreNative]::IsWindow($handle)) {
        continue
    }

    $processId = [uint32]0
    [ObsidianDwmRestoreNative]::GetWindowThreadProcessId($handle, [ref]$processId) | Out-Null
    if ($processId -ne [uint32]$record.ProcessId) {
        continue
    }

    Restore-Attribute -Handle $handle -Attribute 38 -HasValue $record.BackdropHas -OriginalValue $record.BackdropValue
    Restore-Attribute -Handle $handle -Attribute 36 -HasValue $record.TextHas -OriginalValue $record.TextValue
    Restore-Attribute -Handle $handle -Attribute 35 -HasValue $record.CaptionHas -OriginalValue $record.CaptionValue
    Restore-Attribute -Handle $handle -Attribute 34 -HasValue $record.BorderHas -OriginalValue $record.BorderValue
    Restore-Attribute -Handle $handle -Attribute 33 -HasValue $record.CornerHas -OriginalValue $record.CornerValue
    Restore-Attribute -Handle $handle -Attribute 20 -HasValue $record.DarkHas -OriginalValue $record.DarkValue
    Restore-Attribute -Handle $handle -Attribute 3 -HasValue $record.TransitionsHas -OriginalValue $record.TransitionsValue
    $restored++
}

Remove-Item -LiteralPath $statePath -Force
$line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + "  Restored DWM styles for " + $restored + " window(s)."
Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
