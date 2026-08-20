# Screenshot Catalog

The public package contains high-resolution, manually reviewed reference captures. They are visual documentation, not a promise that every optional dependency is installed on every machine. The first seven captures are sanitized public reference captures retained from the predecessor package; `08-current-wallpaper-live.png` is from the current workspace snapshot.

| File | Feature | Capture rule |
|---|---|---|
| `assets/screenshots/01-overview.png` | Full Obsidian Glass layout | Use a neutral project wallpaper and no private windows |
| `assets/screenshots/02-dock.png` | Dock, magnification, running dots, media progress | Show generic app labels only |
| `assets/screenshots/03-sidebar.png` | Left Stage rail and preview card | Do not show chat content or account names |
| `assets/screenshots/04-dashboard.png` | Glass widgets, system status, control capsule | Use synthetic/example values where possible |
| `assets/screenshots/05-topbar.png` | Top status bar and media center | Keep network and device identifiers out |
| `assets/screenshots/06-ambient.png` | Deep-space layers, glow and animal trail | Prefer the included wallpaper preview |
| `assets/screenshots/07-wallpaper.png` | Fluid, galaxies, meteors, starter animals | No user wallpaper or personal media |
| `assets/screenshots/08-current-wallpaper-live.png` | Current deep-space wallpaper and starter animal layer | Current snapshot capture; no desktop windows or account data |

`capture-screenshots.ps1` captures a new screen without changing state, but a live desktop capture may contain private information. Inspect and sanitize before staging. Existing raw workbench screenshots remain outside the public package.
