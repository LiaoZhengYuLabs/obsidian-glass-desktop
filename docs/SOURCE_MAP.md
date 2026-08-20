# Source Map

This table maps the **current** isolated public package to the active desktop work without copying live runtime state. The old package remains available as a separate historical branch.

| Capability | Public entry | Important files | External dependency |
|---|---|---|---|
| Dock | `src/components/dock/` | `ObsidianAIDock.ps1`, `start.ps1`, `stop.ps1`, `status.ps1`, `WeChat*.cs`, `WindowTracker.cs` | MyDockFinder, Windows PowerShell 5.1, DWM thumbnail APIs |
| Left rail | `src/components/sidebar/` | `ObsidianSidebar.ps1`, `SeelenLivePreview.cs`, `start.ps1`, preview helpers | Optional Seelen UI, native Win32 |
| Dashboard | `src/components/dashboard/` | `MacWidgetDashboard.ps1`, `Dashboard.xaml`, `SystemControlOverlay.ps1`, speech/media workers | WPF/.NET Framework, optional FFmpeg and isolated speech runtime |
| Topbar | `src/components/topbar/` | `DesktopTopbar.cs`, `DesktopMediaCenter.ps1`, language/camera/X/GitHub helpers | Optional Seelen UI, MyDockFinder, FFmpeg |
| Ambient | `src/components/ambient/` | `DockVisibilityController.ps1`, `DockMediaProgress.cs`, install/restore helpers | Windows media session APIs |
| Wallpaper | `src/components/wallpaper/` | `index.html`, `space-environment/`, `animal-trail/`, `deploy/` | Lively Wallpaper/WebGL |
| Current startup | `src/current/`, root wrappers | `startup_optimized.ps1`, `start-current.ps1`, `install-current-startup.ps1` | Windows Task Scheduler, optional installed apps |
| Generic startup kit | `src/` and `config/obsidian-glass.example.json` | `Install-StartupKit.ps1`, `Start-DesktopSession.ps1`, `Restore-StartupKit.ps1` | Windows Task Scheduler |

The public package uses `%LOCALAPPDATA%\ObsidianGlassDesktop` for state where the current source has been adapted for portability. No path in this table points back to a private user profile. The current snapshot is a source publication, not a prebuilt binary distribution.
