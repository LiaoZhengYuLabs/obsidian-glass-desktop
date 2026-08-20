Option Explicit
Dim shell, fso, root, exePath, dockRoot
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
exePath = root & "\DockMediaProgress.exe"
dockRoot = "C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder"

WScript.Sleep 18000
If fso.FileExists(exePath) Then
    shell.Run Chr(34) & exePath & Chr(34) & " " & Chr(34) & dockRoot & Chr(34), 0, False
End If
