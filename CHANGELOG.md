# Changelog

## 0.2.0 - 2026-08-21

- Published a current-workspace snapshot as the successor branch `codex/current-desktop-20260821`.
- Refreshed Dashboard, Dock, left Stage rail, topbar, ambient controllers, wallpaper, and startup sources from the active desktop project.
- Moved Dashboard speech/media state and runtime paths to `%LOCALAPPDATA%\ObsidianGlassDesktop` so the public source tree does not become a runtime data directory.
- Added portable current-session launch and restore entry points without enabling components by default.
- Preserved the old public package and its branch as a historical predecessor instead of overwriting its source history.
- Added a current snapshot source map, file manifest, sanitized live wallpaper capture, and explicit exclusion list.
- Kept the full Petdex sprite cache, personal media, WebView data, logs, backups, compiled helpers, and user-specific files out of the publish set.

## 0.1.0 - 2026-08-20

- Renamed the public project to **Obsidian Glass Desktop** and created an isolated open-source package.
- Added portable PowerShell 5.1 install, start, status, restore, preview, and validation entry points.
- Organized Dock, left Stage rail, dashboard, topbar, ambient visibility/media progress, and wallpaper sources under `src/components`.
- Added path discovery for MyDockFinder and removed machine-specific user paths from the copied sources.
- Preserved the deep-space wallpaper layers and the Animal Trail System engine, starter sprites, and 1,593-entry Petdex catalogue snapshot.
- Added an opt-in animal asset synchronization tool; the approximately 3 GB full sprite cache stays out of the public commit.
- Removed the copied media-progress restore path that touched Docker startup settings; the public restore path now handles only package-owned state.
- Added publishing, security, asset, source-map, startup, and screenshot documentation.
- Kept the live desktop project and its runtime folders untouched.
- Replaced bundled community animal sprites with starter presets, original catalog URLs, and opt-in local synchronization so the public repository does not redistribute unverified community art.
- Hardened the optional topbar installer for machines without MyDockFinder and removed a machine-specific chat-media folder preference from the dashboard copy.

## Unreleased

- Verify third-party icon, wallpaper, and community animal asset rights before adding any binaries to a public release.
