$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$todoPath = $root + "\data\todo.json"
$settingsPath = $root + "\data\component-settings.json"
$mainScript = $root + "\ObsidianAIDashboard.ps1"
$resultPath = $root + "\todo-runtime-verification.json"
$passFlag = $root + "\todo-runtime-verification-passed.flag"
$originalBytes = [IO.File]::ReadAllBytes($todoPath)
$errors = New-Object System.Collections.Generic.List[string]

function Read-DashboardJson {
    param([string]$Path)
    return ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-DashboardJson {
    param([string]$Path, $Value)
    $json = $Value | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

. ($root + "\services\todoService.ps1")

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ObsidianTodoAuditNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static IntPtr FindVisibleWindow(uint targetProcessId)
    {
        IntPtr result = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            uint id;
            GetWindowThreadProcessId(h, out id);
            if (id == targetProcessId && IsWindowVisible(h)) { result = h; return false; }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
"@

function Get-DashboardAutomationText {
    param([uint32]$ProcessId)
    $handle = [ObsidianTodoAuditNative]::FindVisibleWindow($ProcessId)
    if ($handle -eq [IntPtr]::Zero) { return @() }
    $rootElement = [Windows.Automation.AutomationElement]::FromHandle($handle)
    $items = $rootElement.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)
    $text = @()
    for ($index = 0; $index -lt $items.Count; $index++) {
        $name = [string]$items[$index].Current.Name
        if (![string]::IsNullOrWhiteSpace($name)) { $text += $name }
        $value = $items[$index].GetCurrentPropertyValue(
            [Windows.Automation.ValuePatternIdentifiers]::ValueProperty,
            $true
        )
        if ($value -is [string] -and ![string]::IsNullOrWhiteSpace([string]$value)) {
            $text += [string]$value
        }
    }
    return $text
}

$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -like ("*" + $mainScript + "*")
})
if ($running.Count -ne 1) { throw "Expected one running Dashboard process." }
$dashboardProcessId = [uint32]$running[0].ProcessId
$foregroundBefore = [ObsidianTodoAuditNative]::GetForegroundWindow()
$date = Get-Date -Format "yyyy-MM-dd"
$probeTitle = "todo-runtime-probe"
$updatedTitle = "todo-runtime-probe-updated"
$addedVisible = $false
$updatedVisible = $false
$restoredVisible = $false

try {
    $beforeSnapshot = Get-TodoSnapshot -DataPath $todoPath -Date $date
    $beforeCount = @($beforeSnapshot.Tasks).Count
    $beforeCompleted = @($beforeSnapshot.Tasks | Where-Object { [bool]$_.done }).Count
    if (!(Add-TodoTask -DataPath $todoPath -Date $date -Title $probeTitle -MaxTasks 30)) {
        throw "Could not add the runtime probe task."
    }

    $addedSnapshot = Get-TodoSnapshot -DataPath $todoPath -Date $date
    $probe = @($addedSnapshot.Tasks | Where-Object { [string]$_.title -eq $probeTitle }) | Select-Object -First 1
    if ($null -eq $probe) { throw "The runtime probe was not persisted." }
    Start-Sleep -Seconds 11
    $visibleText = Get-DashboardAutomationText -ProcessId $dashboardProcessId
    $addedVisible = ($visibleText -contains $probeTitle)
    if (!$addedVisible) { $errors.Add("The added plan was not visible in the live widget.") }

    [void](Set-TodoTitle -DataPath $todoPath -Date $date -TaskId ([string]$probe.id) -Title $updatedTitle)
    Set-TodoPriority -DataPath $todoPath -Date $date -TaskId ([string]$probe.id) -Priority 1
    Set-TodoState -DataPath $todoPath -Date $date -TaskId ([string]$probe.id) -Done $true
    Start-Sleep -Seconds 11
    $visibleText = Get-DashboardAutomationText -ProcessId $dashboardProcessId
    $settings = Read-DashboardJson -Path $settingsPath
    $summaryFormat = [string]$settings.text.todoCompleted
    $expectedSummary = $summaryFormat -f ($beforeCompleted + 1), ($beforeCount + 1)
    $updatedVisible = ($visibleText -contains $updatedTitle) -and ($visibleText -contains $expectedSummary)
    if (!$updatedVisible) { $errors.Add("The renamed and completed plan state was not visible in the live widget.") }
} finally {
    [IO.File]::WriteAllBytes($todoPath, $originalBytes)
    Start-Sleep -Seconds 11
    $visibleText = Get-DashboardAutomationText -ProcessId $dashboardProcessId
    $restoredVisible = ($visibleText -notcontains $probeTitle) -and ($visibleText -notcontains $updatedTitle)
    if (!$restoredVisible) { $errors.Add("The live widget did not return to the original plan data.") }
}

$foregroundAfter = [ObsidianTodoAuditNative]::GetForegroundWindow()
$foregroundUnchanged = ($foregroundBefore -eq $foregroundAfter)
if (!$foregroundUnchanged) { $errors.Add("Foreground focus changed during the silent plan test.") }

$result = [ordered]@{
    VerifiedAt = (Get-Date).ToString("o")
    DashboardProcessId = $dashboardProcessId
    AddedVisible = $addedVisible
    UpdatedVisible = $updatedVisible
    OriginalDataRestored = $restoredVisible
    ForegroundUnchanged = $foregroundUnchanged
    Errors = @($errors)
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8

if ($errors.Count -gt 0) { exit 1 }
[IO.File]::WriteAllText($passFlag, "OK", (New-Object Text.UTF8Encoding($false)))
exit 0
