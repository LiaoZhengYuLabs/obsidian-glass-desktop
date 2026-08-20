$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DesktopLanguageToggle {
    public const uint WM_INPUTLANGCHANGEREQUEST = 0x0050;
    public const uint KLF_ACTIVATE = 0x00000001;

    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll")] public static extern IntPtr GetKeyboardLayout(uint threadId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadKeyboardLayout(string id, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr ActivateKeyboardLayout(IntPtr layout, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
'@

$window = [DesktopLanguageToggle]::GetForegroundWindow()
$processId = 0
$threadId = [DesktopLanguageToggle]::GetWindowThreadProcessId($window, [ref]$processId)
$currentLayout = [DesktopLanguageToggle]::GetKeyboardLayout($threadId)
$currentLanguage = $currentLayout.ToInt64() -band 0xFFFF

if ($currentLanguage -eq 0x0804) {
    $targetId = '00000409'
    $targetName = 'English (US)'
} else {
    $targetId = '00000804'
    $targetName = '简体中文'
}

$targetLayout = [DesktopLanguageToggle]::LoadKeyboardLayout($targetId, [DesktopLanguageToggle]::KLF_ACTIVATE)
[void][DesktopLanguageToggle]::ActivateKeyboardLayout($targetLayout, 0)
if ($window -ne [IntPtr]::Zero) {
    [void][DesktopLanguageToggle]::PostMessage($window, [DesktopLanguageToggle]::WM_INPUTLANGCHANGEREQUEST, [IntPtr]::Zero, $targetLayout)
}

$stateRoot = "$env:LOCALAPPDATA\ObsidianDesktopMediaCenter"
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
[IO.File]::WriteAllText("$stateRoot\language-state.txt", $targetName, (New-Object Text.UTF8Encoding($false)))
