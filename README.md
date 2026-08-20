# Obsidian Glass Desktop · 当前版本

这是 **2026-08-21 当前工作区快照**，用于继承旧公开包并作为新分支继续开发。它不是旧版 `obsidian-glass-desktop` 的复制品：活动源码来自当前 Windows 11 桌面项目，历史备份、个人运行数据和本机缓存已被排除。

## 目标

在普通 Windows 11 上叠加一层可退出、可恢复的桌面体验：

- 黑曜石玻璃 Dock：固定应用、运行状态、驻留页面和 DWM 实时预览。
- 左侧 Stage Manager 胶囊：最近窗口、应用图标、边缘唤出和横向实时预览。
- WPF 桌面组件：天气、时钟、日历、电量、AI 捕捉、待办、媒体进度、双语字幕和播放记录。
- 顶部媒体中心：截图、录像、摄像头、输入法切换和 X/GitHub Dock 操作。
- Lively 深空壁纸：太极流体、星点、十二星座、流星和动态动物轨迹。
- 当前用户级启动编排与恢复入口。

项目不替换 Windows，不修改系统核心文件，也不要求安装黑苹果或修改 BIOS。

## 当前快照来源

以下目录是当前版本的活动源码入口：

| 能力 | 当前源码 | 当前保留内容 |
| --- | --- | --- |
| Dashboard | `src/components/dashboard/` | 当前 `MacWidgetDashboard.ps1`、组件 XAML、音乐/字幕/语音服务、控制胶囊 |
| Dock | `src/components/dock/` | 当前三区 Dock、窗口跟踪、微信实时预览与运行黑点修复源码 |
| 左侧栏 | `src/components/sidebar/` | 当前 Stage Manager 胶囊、DWM 缩略图、Seelen 横向预览 |
| 顶栏 | `src/components/topbar/` | 当前媒体中心、录像时长、语言切换、X/GitHub/Claude 操作脚本 |
| Ambient | `src/components/ambient/` | 当前 Dock 显隐和媒体进度组件 |
| 壁纸 | `src/components/wallpaper/` | 当前深空环境、星座、流星、动物轨迹和 Petdex 元数据 |
| 启动 | `src/current/` | 当前启动顺序的可移植版本及恢复脚本 |

精确的文件来源、哈希和排除清单见 `docs/CURRENT_SNAPSHOT.md` 与 `docs/current-source-manifest.json`。

## 快速检查

先做只读检查，不启动任何组件：

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1
powershell -ExecutionPolicy Bypass -File .\start-current.ps1 -VerifyOnly
```

## 启动方式

### 只启动当前组件会话

```powershell
powershell -ExecutionPolicy Bypass -File .\start-current.ps1
```

它会按当前桌面使用顺序尝试启动 Dashboard、左侧栏、Dock、Dock 显隐控制，并在检测到时启动 MyDockFinder、Lively Wallpaper 和 Rainmeter。未安装的外部软件只写日志，不会被下载或强行安装。

### 单独启动组件

```powershell
powershell -ExecutionPolicy Bypass -File .\src\components\dashboard\start.ps1 -NoStartup
powershell -ExecutionPolicy Bypass -File .\src\components\sidebar\start.ps1 -NoStartup
powershell -ExecutionPolicy Bypass -File .\src\components\dock\start.ps1 -NoStartup
powershell -ExecutionPolicy Bypass -File .\src\components\ambient\start.ps1
```

### 可恢复的开机入口

默认配置是安全预览，所有组件关闭：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

确认外部依赖和组件后，才使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Apply
```

安装器只创建当前用户计划任务或用户启动快捷方式，不修改系统核心文件。恢复：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
powershell -ExecutionPolicy Bypass -File .\restore-current-startup.ps1
```

如果只想为这个当前分支创建独立的开机入口，请先预览，再显式应用：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-current-startup.ps1
powershell -ExecutionPolicy Bypass -File .\install-current-startup.ps1 -Apply
```

它只使用当前用户权限，并只管理名为 `Obsidian Glass Desktop - Current` 的任务和同名启动快捷方式。旧版启动任务不会被迁移或删除。

## 语音、音乐与字幕

源码保留当前的本地语音识别、可编辑结果、电影双语字幕、同步歌词、媒体进度和播放历史逻辑。大模型、CUDA DLL、便携 Python、WebView2 数据和个人媒体没有放入 GitHub：

- 语音运行时默认位置：`%LOCALAPPDATA%\ObsidianGlassDesktop\runtime\speech`。
- 可通过环境变量 `OBSIDIAN_GLASS_SPEECH_ROOT` 指定自己的运行时目录。
- 缺少运行时会显示依赖不可用并保留界面，不会修改全局 Python 或 AI 开发环境。
- 当前收藏音乐的自动播放仍由现有桌面设置决定；公开包不会携带音频文件、歌词缓存或账号数据。

具体 Python 依赖见 `src/components/dashboard/speech/requirements-subtitles.txt`，安装到隔离运行时，不要覆盖系统环境。

## 深空壁纸与动物

把 `src/components/wallpaper/` 导入 Lively Wallpaper，即可使用当前网页壁纸源码。当前版本保留：

- 太极流体与分层深空环境。
- 十二星座轮换、星点漂移和流星通道。
- 动态动物轨迹系统：鼠标/触控板轨迹、闲置自主活动、群体行为、手势和低帧保护。
- Petdex 当前 1,593 条生物元数据和 8 个轻量 starter 精灵图。

完整 Petdex 精灵缓存约 3 GB，且社区素材许可需要逐项确认，因此不进入公开提交。需要时再按 `src/components/wallpaper/animal-trail/catalog/` 中的元数据自行同步，并保留原始来源声明。

## 外部依赖

| 依赖 | 作用 | 是否随包提供 |
| --- | --- | --- |
| Windows PowerShell 5.1 / WPF | 组件、Dock、左侧栏 | Windows 自带 |
| MyDockFinder | 底部 Dock 宿主 | 不提供，用户自行从 Steam/官网安装 |
| Seelen UI | 顶部栏和可选横向预览 | 不提供 |
| Lively Wallpaper | WebGL 深空壁纸宿主 | 不提供 |
| Rainmeter | 可选第三方皮肤 | 不提供 |
| FFmpeg / FFplay | 顶栏录像和摄像头功能 | 使用本机已有版本，不随包下载 |
| C# 编译器 | 微信预览/媒体进度辅助程序 | 只提供 `.cs` 源码，不提交 `.exe` |

## 安全边界

- 不删除个人文件，不清理微信、浏览器或媒体数据。
- 不关闭 Defender、Windows Update、安全中心或网络代理。
- 不修改 BIOS、驱动、系统核心文件或全局开发环境。
- 顶栏配置迁移、MyDockFinder 配置编辑和启动任务注册都需要显式运行对应脚本，并会先备份。
- 组件日志和状态写入本机运行目录或被 `.gitignore` 排除的目录，不应提交。

发布前运行 `test.ps1`，并人工检查 `git status`。安全规则见 `SECURITY.md`。

## 版本关系

- 旧版历史分支：`codex/publish-obsidian-glass-desktop`。
- 当前分支：`codex/current-desktop-20260821`。
- `main` 在发布完成后指向当前快照；旧分支仍保留，便于比较和回退。

这套分支策略保留旧版本，同时让当前桌面修改拥有独立、可追踪的发布点。
