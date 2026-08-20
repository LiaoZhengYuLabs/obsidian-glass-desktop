# Current Desktop Startup

This directory contains the portable startup sequence copied from the current desktop worktree on 2026-08-21.

## Entry points

- `startup_optimized.ps1` starts the current Dashboard, left Stage rail, Dock, ambient visibility controller, and detected optional hosts.
- `start-current.ps1` is the package-root wrapper. Use `-VerifyOnly` for a read-only dependency and path check.
- `install-current-startup.ps1` registers an opt-in current-user task. It is preview-only unless `-Apply` is supplied.
- `restore-current-startup.ps1` removes only the task and shortcut recorded by that installer.

The sequence uses a mutex to avoid duplicate startup launches and writes its log to `%LOCALAPPDATA%\ObsidianGlassDesktop\startup\logs`. It does not bundle or start private speech runtimes, browser profiles, personal media, or compiled helper binaries.

The generic startup kit under `src/` remains available for the older safe-profile workflow. These two entry points are intentionally separate so the current snapshot can be treated as a branch of the predecessor without rewriting the predecessor's history.
