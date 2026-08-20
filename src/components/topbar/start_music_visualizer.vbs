Option Explicit

Dim shell
Set shell = CreateObject("WScript.Shell")
WScript.Sleep 8000
shell.Run """C:\Program Files\Rainmeter\Rainmeter.exe"" !ActivateConfig ""SonomaAI\Music"" ""Music.ini""", 0, False
