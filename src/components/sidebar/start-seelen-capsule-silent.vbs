Option Explicit

Dim shell, fso, projectRoot, workspaceRoot, previewScript, closeSettingsScript
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

Function IsProcessRunning(processName)
    Dim service, processes
    Set service = GetObject("winmgmts:\\.\root\cimv2")
    Set processes = service.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name='" & processName & "'")
    IsProcessRunning = (processes.Count > 0)
End Function

projectRoot = fso.GetParentFolderName(WScript.ScriptFullName)
workspaceRoot = fso.GetParentFolderName(projectRoot)
previewScript = projectRoot & "\start_seelen_live_preview.ps1"
closeSettingsScript = workspaceRoot & "\close_seelen_settings.ps1"

If Not IsProcessRunning("seelen-ui.exe") Then
    shell.Run "explorer.exe shell:AppsFolder\Seelen.SeelenUI_p6yyn03m1894e!App", 0, False
End If

If fso.FileExists(closeSettingsScript) Then
    shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & closeSettingsScript & """ -WatchSeconds 30", 0, False
End If

WScript.Sleep 3500

If fso.FileExists(previewScript) Then
    shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & previewScript & """", 0, False
End If
