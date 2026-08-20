# Security and Privacy

Obsidian Glass Desktop is a user-level Windows 11 shell layer. It is intentionally conservative because it coordinates third-party desktop software.

## What it changes

- `install.ps1 -Apply` creates one current-user scheduled task unless `-SkipScheduledTask` is supplied.
- `-UseStartupFolder` may create one current-user Startup shortcut.
- Component scripts may create their own state under `%LOCALAPPDATA%\ObsidianGlassDesktop` when explicitly enabled.
- The optional topbar installer can back up and edit Seelen UI/MyDockFinder configuration. It is disabled in both example profiles.
- `install-current-startup.ps1 -Apply` is a separate opt-in task for the current-workspace launcher. It owns only the task named `Obsidian Glass Desktop - Current` and its own Startup shortcut.

## What it does not change

- Windows core files, BIOS, Defender, Windows Update, proxy settings, drivers, or personal documents.
- Other applications' startup settings unless an explicitly selected third-party integration says so.
- Chat content, cookies, browser profiles, or credentials.

## Restore

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -Preview
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

The standard restore path only acts on the task, shortcut, and process IDs recorded by this package. The current-workspace startup entry has its own restore command:

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-current-startup.ps1 -Preview
powershell -ExecutionPolicy Bypass -File .\restore-current-startup.ps1
```

The current restore path does not delete installed software, personal files, wallpaper assets, or third-party settings.

## Publishing rules

Never commit browser data, WebView2 data, speech models, tokens, screenshots with private content, generated logs, backups, compiled binaries, personal music, subtitles, or community media without verified rights. Run `test.ps1` and inspect every warning before pushing. The file list in `docs/current-source-manifest.json` is the publish audit record for this snapshot.
