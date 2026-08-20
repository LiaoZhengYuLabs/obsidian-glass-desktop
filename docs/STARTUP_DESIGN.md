# Startup Design

## Lifecycle

1. `install.ps1` defaults to a read-only `WhatIf` preview.
2. `install.ps1 -Apply` registers one limited, interactive-logon task owned by the package.
3. The task launches `Start-DesktopSession.ps1` with a two-second base delay.
4. Each enabled component starts in its configured order and delay. A missing optional dependency is logged instead of being downloaded or silently substituted.
5. Session state records only component path, process ID, and timestamp.
6. `Stop-DesktopSession.ps1` stops only those recorded process IDs.
7. `restore.ps1` removes the owned startup entry and leaves software and personal files in place.

## Recommended order

| Delay | Component | Reason |
|---:|---|---|
| 0 s | Dashboard | Establishes the low-frequency status layer after the shell settles |
| 1 s | Sidebar | Adds the left rail after the desktop window station is ready |
| 2 s | Dock | Lets MyDockFinder finish loading before preview logic attaches |
| 3 s | Ambient controller | Starts visibility/media observers last |

The topbar integration is not part of the default order because it can edit third-party configuration. Enable it only with a separate reviewed profile.

## Performance rules

- Keep animation and media observers event-driven or low-frequency.
- Keep wallpaper animal activity capped at 40 active creatures and 80 catalogue slots.
- Do not start speech models or browser capture on the login critical path.
- Treat a missing optional component as a recoverable warning.
