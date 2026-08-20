# Source Map

This table maps the isolated public package to the existing desktop work without copying live runtime state.

| Capability | Public entry | Important files | External dependency |
|---|---|---|---|
| Dock | `src/components/dock/` | `ObsidianAIDock.ps1`, `start.ps1`, `stop.ps1`, `status.ps1`, `WeChat*.cs` | MyDockFinder, Windows PowerShell 5.1 |
| Left rail | `src/components/sidebar/` | `ObsidianSidebar.ps1`, `SeelenLivePreview.cs`, `start.ps1` | Optional Seelen UI, native Win32 |
| Dashboard | `src/components/dashboard/` | `MacWidgetDashboard.ps1`, `Dashboard.xaml`, `SystemControlOverlay.ps1` | WPF/.NET Framework, optional media/speech adapters |
| Topbar | `src/components/topbar/` | `DesktopTopbar.cs`, `DesktopMediaCenter.ps1`, `install_topbar.ps1` | Optional Seelen UI and MyDockFinder |
| Ambient | `src/components/ambient/` | `DockVisibilityController.ps1`, `DockMediaProgress.cs` | Windows media session APIs |
| Wallpaper | `src/components/wallpaper/` | `index.html`, `space-environment/`, `animal-trail/` | Lively Wallpaper/WebGL |
| Startup | root scripts and `src/` | `Install-StartupKit.ps1`, `Start-DesktopSession.ps1`, `Restore-StartupKit.ps1` | Windows Task Scheduler |

The public package uses `%LOCALAPPDATA%\ObsidianGlassDesktop` for state. No path in this table points back to a private user profile.
