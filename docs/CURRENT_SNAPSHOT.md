# Current Snapshot

## Identity

- Snapshot date: `2026-08-21`
- Source authority: the active Windows 11 desktop worktree at capture time
- Public package: `open-source/obsidian-glass-desktop-current`
- Successor branch: `codex/current-desktop-20260821`
- Predecessor branch: `codex/publish-obsidian-glass-desktop`
- Main branch: updated to the successor snapshot after API verification

This package is a new, addressable branch of the earlier open-source package. The earlier package is retained so the two versions can be compared or restored independently.

## Included current areas

- Dashboard widgets, control capsule, media progress, bilingual subtitle and speech adapters.
- Obsidian Glass Dock with fixed apps, running state, recent windows, preview helpers, and current portability adapters.
- Left Stage rail with edge reveal and native/DWM preview sources.
- Topbar/media center helpers, camera/language controls, and X/GitHub/Claude shortcut helpers.
- Dock visibility and media progress ambient controllers.
- Deep-space Lively wallpaper, twelve-constellation layer, meteors, fluid background, and Animal Trail System source.
- Current startup orchestration and separate, reversible current-user startup installer.

## Deliberate exclusions

- No user profile paths, account identifiers, chat transcripts, browser data, WebView2 data, tokens, or credentials.
- No personal music, lyrics cache, subtitles, screenshots containing private windows, or desktop capture logs.
- No `.exe`, `.dll`, `.pdb`, CUDA/Whisper model, portable Python, or other downloaded runtime binary.
- No full Petdex sprite cache. The live cache is approximately 3 GB; only metadata and eight lightweight starter sets are staged.
- No live logs, backups, state folders, or temporary browser profiles.

## Reproduction and audit

Run from this package directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1
powershell -ExecutionPolicy Bypass -File .\tools\New-CurrentSourceManifest.ps1
powershell -ExecutionPolicy Bypass -File .\start-current.ps1 -VerifyOnly
```

`current-source-manifest.json` records relative paths, byte sizes, and SHA-256 hashes for the publishable snapshot. It intentionally excludes generated runtime directories and the manifest itself.

## Runtime boundary

The source package is not a prebuilt installer. Optional hosts such as MyDockFinder, Seelen UI, Lively Wallpaper, Rainmeter, FFmpeg, and an isolated speech runtime must be installed or configured separately by the user. Missing dependencies are reported and do not trigger downloads.
