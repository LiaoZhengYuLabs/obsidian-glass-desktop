# Dock Visibility Controller

This helper controls only the visible MyDockFinder panel. It does not modify MyDockFinder settings, Dock icons, Windows system files, or desktop content.

- Single click on an empty desktop area or a native app background: collapse the Dock.
- Double click on an empty desktop area or a native app background: keep the Dock fixed and visible.
- Buttons, text inputs, browser pages, video areas, and code editor content are excluded. A browser or editor title-bar background can still control the Dock.
- The selected mode is saved at `%LOCALAPPDATA%\ObsidianDockVisibility\mode.txt` and is restored at sign-in.
- Logs are written to `logs\dock-visibility-controller.log`.

Manual controls:

```powershell
powershell -ExecutionPolicy Bypass -File .\Set-DockVisibility.ps1 -Mode fixed
powershell -ExecutionPolicy Bypass -File .\Set-DockVisibility.ps1 -Mode collapsed
powershell -ExecutionPolicy Bypass -File .\stop.ps1
```
