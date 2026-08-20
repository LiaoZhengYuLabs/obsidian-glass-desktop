Set shell = CreateObject("WScript.Shell")
shell.Run """" & shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ObsidianDesktopTopbar\ObsidianDesktopTopbar.exe"""", 0, False
