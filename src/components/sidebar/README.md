# Obsidian AI Workspace

Windows 11 原生桌面增强项目。当前左侧栏采用类似 macOS Stage Manager 的最近窗口卡片，不修改系统核心文件。

## Implemented

- Independent WPF sidebar process
- 210px x 820px 黑曜石毛玻璃 Stage Manager 面板
- 最多显示 7 个最近活跃的运行窗口
- 每张卡片显示实时窗口画面、应用图标和应用名称
- 按最后活动时间自动排序，点击卡片恢复对应窗口
- 左侧边缘唤出并自动隐藏，默认仅保留 10px 触发区
- 240ms icon hover magnification
- Mouse-following glass reflection
- Reduced-motion support
- Single-instance protection
- Rounded native hover labels
- Visible top-level application detection every 1.8 seconds
- Fixed-app running indicators without duplicate icons
- DWM 原生实时缩略图，不进行高频截图轮询
- Elevated-application path detection without elevating the sidebar
- 全屏电影或游戏时自动完全移出屏幕，并把扫描间隔降为 5 秒
- Read-only CPU, GPU, VRAM, memory, display, refresh-rate, and Windows detection
- Cached High, Balanced, or Efficiency rendering profile
- Reversible per-window DWM corner, dark-title, border, and backdrop treatment
- Existing application backdrops are preserved; missing backdrops receive dark Mica
- Native Windows color treatment is limited to Explorer, Notepad, and Paint
- Borderless fullscreen mode moves the rail off-screen and reduces polling to five seconds
- Games, overlays, terminals, Steam WebHelper, and existing enhancement processes are excluded
- Windows native DWM open and close transitions remain enabled
- Right-click application menu for pin, unpin, rename, icon replacement, location, and removal
- Rail menu for adding applications, folders, and websites
- Scrollable fixed-app region for custom entries beyond the original five icons
- Persistent app layout with restore-hidden and restore-default actions
- Native file and folder selectors; referenced applications and folders are never moved or deleted
- No system-file, registry, MyDockFinder, or Seelen UI modification

## 左侧图标与特效

- 固定应用、运行中应用和最近应用统一使用 `42 x 42` 按钮与 `30 x 30` 图标，不再出现大小不一致。
- 悬停时提供轻微上浮、柔和青白光晕和 `1.16` 倍放大；点击时短暂收缩到 `0.94` 倍。
- 特效只在悬停和点击时运行，不增加常驻动画负担；全屏电影或游戏时侧栏仍会移到屏幕外。
- 可在 `state/sidebar-style.json` 调整图标尺寸、放大倍率、上浮距离、光晕颜色和透明度。
- 完整中文自定义说明位于上级项目目录 `CHINESE_COMPONENT_CUSTOMIZATION.md`。

## Start

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

把鼠标移动到屏幕最左边的细条即可展开最近窗口；移开后自动收起。点击卡片会切换到对应应用。

## Seelen 横向实时预览

`SeelenLivePreview.exe` 是独立的增量覆盖层，不写入 Seelen 配置，也不改变左侧蓝色组件。
鼠标在 Seelen 已打开应用图标上停留 500ms 后，会在蓝色组件右侧显示当前窗口：

- DWM 原生实时画面，不保存聊天或窗口截图。
- 固定横向胶囊；竖向窗口按比例完整展示，不拉伸。
- 同一应用最多横向排列三个当前窗口。
- 胶囊使用深血红玻璃底材，边缘采用随机彩焰配色；动画仅在预览可见时运行。
- 微信优先选择当前主窗口，避免显示旧登录页。

单独启动或停止：

```powershell
powershell -ExecutionPolicy Bypass -File .\start_seelen_live_preview.ps1
powershell -ExecutionPolicy Bypass -File .\stop_seelen_live_preview.ps1
```

## Stop

```powershell
powershell -ExecutionPolicy Bypass -File .\stop.ps1
```

Shift + right-click the expanded glass surface also closes the sidebar.

## Restore

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

The project is self-contained and does not install or uninstall any third-party software.
`restore.ps1` also clears the generated recent-app state. Logs and project files remain available for inspection.
`stop.ps1` and `restore.ps1` both restore every recorded DWM attribute before the process exits.

## Runtime Data

- Recent applications: `state\recent-apps.csv`
- App layout and custom entries: `state\app-layout.json`
- Hardware profile: `state\hardware-profile.json`
- Active DWM restore data: `state\window-style-state.csv`
- Runtime log: `logs\sidebar.log`
- Sidebar icon style: `state\sidebar-style.json`
- Phase 1 backup: `backups\phase1-20260713-032913`
- Phase 2 backup: `backups\phase2-20260713-034950`
- Phase 3 backup: `backups\phase3-20260713-040925`
- Phase 4 backup: `backups\phase4-20260713-044212`
- Phase 5 backup: `backups\phase5-20260713-053738`

The scanner reads only visible top-level window metadata, process names, executable paths, and application icons. It excludes the desktop, Seelen UI, NVIDIA overlays, taskbar surfaces, and common Windows shell overlays.

## QA

The selected visual reference, implementation captures, and verification notes are stored in `design-comparison.png`, `design-qa.md`, `phase2-qa.md`, `phase3-qa.md`, `phase4-qa.md`, `management-qa.md`, and `FINAL_AUDIT.md`.

运行检查脚本为 `verify_custom_sidebar_silent.ps1`。结果写入 `sidebar-runtime-verification.json`，检查单实例、窗口尺寸、后台 CPU、前台焦点和全屏避让。
