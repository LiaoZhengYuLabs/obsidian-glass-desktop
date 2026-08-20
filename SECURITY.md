# Security and Privacy

Obsidian Glass Desktop is a user-level Windows 11 shell layer. It is intentionally conservative because it coordinates third-party desktop software.

## What it changes

- `install.ps1 -Apply` creates one current-user scheduled task unless `-SkipScheduledTask` is supplied.
- `-UseStartupFolder` may create one current-user Startup shortcut.
- Component scripts may create their own state under `%LOCALAPPDATA%\ObsidianGlassDesktop` when explicitly enabled.
- The optional topbar installer can back up and edit Seelen UI/MyDockFinder configuration. It is disabled in both example profiles.

## What it does not change

- Windows core files, BIOS, Defender, Windows Update, proxy settings, drivers, or personal documents.
- Other applications' startup settings unless an explicitly selected third-party integration says so.
- Chat content, cookies, browser profiles, or credentials.

## Restore

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

The restore path only acts on the task, shortcut, and process IDs recorded by this package. Preview it first with `.estore.ps1 -Preview`.

## Publishing rules

Never commit browser data, WebView2 data, speech models, tokens, screenshots with private content, generated logs, backups, compiled binaries, personal music, subtitles, or community media without verified rights. Run `test.ps1` and inspect every warning before pushing.
