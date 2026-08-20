Option Explicit

Dim shell, fileSystem, projectRoot, powerShellPath, startScript, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

projectRoot = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powerShellPath = shell.ExpandEnvironmentStrings("%WINDIR%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
startScript = projectRoot & "\start.ps1"

command = Chr(34) & powerShellPath & Chr(34) & _
    " -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
    Chr(34) & startScript & Chr(34) & " -NoStartup"

shell.Run command, 0, False
