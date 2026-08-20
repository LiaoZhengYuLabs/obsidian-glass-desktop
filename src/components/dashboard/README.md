# macOS 桌面小组件

这是 Windows 11 的轻量 WPF 小组件层，外观按参考图重做。它与原来的 `Obsidian AI Workspace` 左侧应用边栏并行运行，不替换边栏，也不修改 Windows 核心文件、个人文件或桌面壁纸。

## 实时音量与亮度胶囊

- `SystemControlOverlay.ps1` 是独立的轻量 WPF 浮层，音量或亮度发生变化时显示，约 1.45 秒后自动淡出。
- 音量百分比来自 Windows Core Audio 默认输出设备；亮度百分比来自 Windows WMI 显示器接口，因此数值是本机实时值，不需要安装外部 X/GitHub 工具或上传数据。
- 提高音量或亮度时使用参考图一的暖黄色 `Brightness` 视觉；降低音量或亮度时使用参考图二的冷蓝色 `Volume` 视觉。
- 胶囊固定在主屏工作区正上方居中显示，不再位于底部。
- 原生 Windows 音量/亮度提示没有被关闭或替换。微信语音通信衰减已设为“什么都不做”，自定义胶囊继续保留，不修改系统核心文件、驱动、壁纸或现有组件。
- 当前显示器若不通过 WMI 暴露亮度控制，亮度胶囊会保持不可用并写入日志；音量读取仍可独立工作。

手动控制：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\start-control-overlay.ps1
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\stop-control-overlay.ps1
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\restore-control-overlay.ps1
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\start-control-overlay.ps1 -Enable
```

恢复脚本只停止并禁用自定义胶囊，Windows 原生提示继续保留；重新启用时使用 `-Enable`。自测不会改变实际音量或亮度：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\SystemControlOverlay.ps1 -SelfTest
```

需要查看当前实际渲染的两种状态时：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\SystemControlOverlay.ps1 -RenderPreview
```

该命令会覆盖项目 `logs\control-overlay-up.png` 和 `logs\control-overlay-down.png`，不会覆盖备份中的两张原始参考图。

## 当前组件

- 模式中枢：提供电影、AI 编程、音乐三种可切换的一键调优面板；电影会准备现有实时双语字幕并沿用全屏避让，AI 编程会打开现有 AI 捕捉与行动中心并应用本地工具链选项，音乐会刷新现有媒体可视化与同步歌词。参数保存在 `data/mode-deck.json`，不修改系统音频驱动、注册表或开发环境。
- 天气：读取 Open-Meteo 的揭阳市实时天气与五日预报，失败时使用本地缓存。
- 时钟：每秒更新的模拟时钟。
- 日历：显示当前月份并高亮当天。
- 电池：显示真实电量和充电状态。
- 音乐与视频字幕：原固定 SoundCloud 曲目已关闭开机自动播放，播放器改为手动模式；音乐可视化组件仍保留，播放浏览器视频、电影播放器或其他系统音频时，会优先切换到实时双语字幕，第一行显示简体中文、第二行保留原声文字，同时保留进度、18 段频谱和媒体按键。
- 电影与音乐记录：已与原音乐可视化合并为同一张靠右的主卡，自动识别电影或音乐的标题、来源、播放位置和总时长，并保存播放期间的处理器、显卡、内存和音频设备快照到 `data/media-history.json`。单击任意电影或音乐历史条目会复制真实来源链接；无法从播放器还原真实地址时，会复制对应平台或关键词的搜索链接，并在悬停提示中明确标注。普通视频不写入历史，仍会在同一播放器卡片显示实时双语字幕。右侧记录列表支持鼠标滚轮、触控板和触摸上下滑动，最多保留 80 条。
- AI 捕捉与行动中心：把本地 `Whisper large-v3-turbo` 听写、正文编辑和四条纵向多行待办整合成一条完整工作流，可直接把听写内容整理为待办。
- 微信生活：可把微信图片直接拖进组件，或点击“导入”选择图片，不需要先创建文件夹；也支持自动同步“图片\微信生活”文件夹。兼容 HEIC/HEIF、Apple Live Photo 配套 MOV 和常见视频，并支持按钮、滚轮、鼠标拖动与触控左右切换。

## 当前布局

- 照片投放卡保持原尺寸与坐标；音乐可视化与影音记录现在共用一张 440×142 的右侧主卡，沿用原音乐可视化的绿色玻璃主题，桌面表面刷新不会把它写到新位置。
- AI 捕捉与行动中心缩小为右侧工作卡，整张卡支持纵向滚动，听写结果、编辑框和下方待办不会因高度不足而丢失上下文。
- 应用使用时间改为浅色卡片，并与右侧三个独立模式卡留出明确间距；电影、AI 编程、音乐卡在同一行排列，整体高度与照片卡对齐。

## 启动与关闭

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\start.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\stop.ps1
```

启动脚本保持单实例，并维护唯一的开机启动快捷方式。开机后延迟 12 秒加载组件，避免与 Dock、桌面和常用启动软件争抢资源；字幕进程会在界面稳定后分两阶段启动，模型预热不会阻塞首屏，字幕工作进程使用低于普通的进程优先级。可视化初始使用低频刷新，检测到播放或声音后才切换到高频刷新；桌面组件被自动隐藏时仍保持字幕检测，但暂停频谱条的重绘。电源历史扫描也在首屏完成后延迟执行。各组件都是独立工具窗口，默认不置顶、不抢焦点、不出现在任务栏或任务视图；按住任意组件的空白区域即可单独拖动，位置会在停下约 300ms 后保存。组件默认只在 Windows 桌面层显示：切换到 Codex、微信、浏览器、资源管理器或其他应用时自动隐藏，回到桌面时自动恢复。唯一例外是播放视频或电影时的媒体字幕卡片，它会单独以不抢焦点的小窗显示对白，其他组件仍保持隐藏；声音停止后字幕卡片自动恢复桌面专属行为。组件仍会固定到所有虚拟桌面，并保留“显示桌面”后的层级恢复；真正全屏时仍会同步隐藏 Seelen 顶栏和 MyDockFinder Dock。

## 语音转文字

1. 点击麦克风按钮开始听写。
2. Windows 第一次使用麦克风时，需要允许桌面应用访问麦克风。
3. 首次点击会加载本地模型，之后保持工作进程以缩短连续识别等待时间。
4. 状态显示“正在听写 · 自动分句”后可说普通话、英文或中英混合内容。
5. 识别结果显示在下方，可直接编辑，也可点击复制或清空按钮。
6. 再次点击麦克风会停止识别并释放录音输入。

识别在本机完成，不上传音频，日志只记录结果字数和置信度，不写入识别正文。Whisper 使用项目自己的 Python 虚拟环境，不修改全局 Python 或 AI 开发环境；GPU 运行库也只放在项目目录，缺失时会自动回退到 CPU。

## 电影双语字幕

1. 播放 Chrome、Edge、哔哩哔哩、常见电影播放器或其他含对白的系统音频，组件检测到连续声音后会自动启动字幕，不需要点击，也不会弹出页面。
2. 外部视频和电影的播放会话优先于开机收藏音乐；播放器没有接入 Windows 媒体会话时，仍会通过 WASAPI 系统扬声器回录识别对白。
3. 观看应用位于前台时，只让原来的媒体卡片单独悬浮显示；天气、日历、照片等其他组件继续隐藏。停止播放或长时间无声后，媒体卡片自动退出悬浮状态。
4. 卡片中央第一行显示简体中文翻译，第二行保留原语言识别文本；视频标题、来源、播放状态、进度、频谱和媒体按键继续保留。
5. 原声语言可自动识别，也可手动选择英语、日语、韩语、西班牙语、法语、德语、俄语、泰语、中文、意大利语、葡萄牙语、阿拉伯语、印地语、越南语、印尼语、马来语、土耳其语、波兰语和荷兰语。
6. 音频与 Whisper 识别始终在本机完成。其他语言需要生成简体中文时，仅把已识别的短句发送给翻译回退服务，绝不上传音频；网络不可用时仍保留原语言文本并在卡片内提示。
7. 有匹配时间轴的歌曲继续按播放器毫秒进度显示同步歌词；视频模式会关闭旧歌曲时间轴，避免歌词覆盖电影对白。
8. 字幕模型在后台预热；系统静音时只停止扬声器回录并保留已加载模型，因此再次播放不需要重新等待。使用“灵感听写”麦克风时，字幕仍会先释放扬声器回录，避免同时占用输入与输出设备。

## 开机曲目

- 后台播放器使用 SoundCloud 官方嵌入接口，不保存或复制歌曲音频文件，不修改 Windows 系统总音量。
- 收藏曲目使用本地缓存的时间轴歌词，第一行显示简体中文，第二行显示原文；播放、暂停和拖动进度后均按当前时间重新定位。
- 开机后不会弹出浏览器窗口；隐藏播放器和桌面组件均有单实例保护。
- 独立的 Rainmeter `THANK YOU 2020` 音乐皮肤已停用，避免左侧出现重复卡片。
- 播放器位于 `SoundCloudPlayer`，WebView2 依赖只保存在该目录，不修改全局开发环境。

## 微信生活与锁屏

最直接的用法不需要创建文件夹：

1. 在微信里把图片拖到“微信生活”卡片后松开；微信提供临时文件或位图时都会被接收。
2. 如果微信当前页面不允许向外拖动，就点击卡片底部“导入”，直接选择微信图片、实况照片的静态图片与配套 MOV，或普通视频。
3. 导入只会在组件数据目录保存一份缓存副本，不移动、不改名、不删除微信原图。
4. 在照片主体上左右拖动、触控滑动或滚动鼠标滚轮即可切换；图片和动态照片会完整居中显示，不裁切原画面。
5. 动态内容切换后会短暂预览；鼠标停留或触控时播放，移开后暂停，以降低桌面空闲占用。
6. 点击锁形按钮把当前静态照片设为锁屏壁纸；该操作不会修改桌面壁纸。

通常通过图片文件夹添加的方法：

1. 点击卡片右下角的文件夹按钮，系统会打开 `%USERPROFILE%\Pictures\微信生活`。该文件夹由组件自动创建，不需要你手动建立。
2. 把 JPG、PNG、WebP、BMP、GIF、HEIC、HEIF、MOV、MP4、M4V 或 WebM 放进去；子文件夹也可以。
3. 最多等待 15 秒，新内容会自动复制到组件缓存并显示。重复扫描不会重复添加，同一源文件仍保留在原位置。
4. Apple Live Photo 建议把静态的 HEIC/JPG 和配套 MOV 一起放入；组件里可以分别滑动查看和播放。
5. 如果要自己创建，打开资源管理器的“图片”，右键空白处选择“新建 > 文件夹”，命名为“微信生活”，再把图片放进去即可。

首次设置锁屏时会在项目数据目录备份原锁屏图片。需要恢复时运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\restore_photo_lock_screen.ps1
```

## 底部 Dock

底部已恢复为原生 MyDockFinder。原来的应用图标、运行状态点、废纸篓、放大动画和应用启动功能均由 MyDockFinder 自身提供；自定义 Obsidian Dock 不再随系统启动，也没有残留进程。

## 模式中枢的一键调优

- **电影模式**：接入已有媒体卡片、实时双语字幕准备和全屏自动避让；不会自动播放或改变系统音量。
- **AI 编程模式**：显示已有 AI 捕捉与行动中心，并把本地补全、工具链和终端配置切换到推荐值；不会修改 VS Code、注册表或开发环境文件。
- **音乐模式**：刷新当前媒体会话、18 段可视化和同步歌词；不会强制启动或播放音乐。
- 点击已启用的按钮或“重置”即可恢复待机。模式参数和动作状态只写入项目 `data` 目录，所有视觉调优都在组件进程内完成。

## 顶部实用按钮

Seelen Fancy Toolbar 左侧依次提供：文件、当前项目、Visual Studio Code、Windows Terminal、截图工具、任务管理器和 Windows 设置。配置使用已解析的绝对路径或系统协议，不依赖工具栏脚本环境中的 Node API。

## 恢复

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\restore.ps1
```

以上命令关闭桌面组件并移除它的开机启动项，保留项目、位置记录和语音模型。恢复原生 Dock 使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDock\restore.ps1
```

Dock 恢复脚本会关闭旧的自定义 Dock 并恢复原来的 MyDockFinder 显示。两个恢复脚本都不删除软件、项目数据或个人文件，也不会修改左侧应用边栏。

## 应用使用时间

- 新增“应用使用时间”独立组件，可像其他面板一样拖动并自动保存位置。
- 每 5 秒读取一次当前前台窗口，只累计应用名称和使用秒数，不读取窗口正文、网页内容或文档内容。
- 显示今日总专注时长、当前应用和前四名应用；跨天自动开始新的统计。
- 记录保存在 `data/app-usage.json`，每分钟最多写入一次，关闭组件时再保存一次。
- 打开普通应用时仍沿用桌面专属隐藏策略；播放视频或电影时只有媒体字幕卡片可短暂悬浮，其余组件不会遮住画面。

只恢复本次组件升级可运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDashboard\restore_app_usage_widget.ps1
```

## 文件

- `Dashboard.xaml`：当前小组件视觉结构；音乐可视化和影音记录位于同一个 `MediaCard`。
- `MacWidgetDashboard.ps1`：天气、时钟、日历、电池、媒体与听写逻辑。
- `data/mac-widget-settings.json`：简体中文界面文字与天气位置。
- `data/mac-widget-weather-cache.json`：天气缓存。
- `data/mac-widget-layout.json`：各独立组件的位置和可见状态。
- `data/media-history.json`：电影、视频和音乐的最近播放记录、位置、时长与播放期间硬件快照。
- `data/mode-deck.json`：电影、AI 编程和音乐模式的本地参数。
- `data/app-usage.json`：当天的前台应用累计时长，不包含窗口内容。
- `data/wechat-photo-library.json`：微信生活媒体索引和当前显示项。
- `lib/VirtualDesktopAccessor.dll`：负责把独立组件固定到所有 Windows 虚拟桌面。
- `lib/VirtualDesktopAccessor-LICENSE.txt`：VirtualDesktopAccessor 的 MIT 许可证。
- `restore_photo_lock_screen.ps1`：恢复首次修改前的锁屏壁纸，不触碰桌面壁纸。
- `speech/whisper_worker.py`：本地录音、语音活动检测与 Whisper 转写工作进程。
- `speech/subtitle_worker.py`：隐藏运行的系统扬声器回录、电影对白识别和双语字幕备用工作进程。
- `speech/synced_lyrics_fetcher.py`：按歌曲、歌手和时长匹配时间轴歌词并生成本地双语缓存。
- `speech/requirements-subtitles.txt`：双语字幕新增的隔离运行时依赖。
- `speech-runtime/`：隔离的便携 Python、模型与可选 GPU 运行库；不依赖已被卸载的全局 Python。
- `SoundCloudPlayer/`：隐藏的官方 SoundCloud 开机播放器、WebView2 局部依赖与运行日志。
- `start-delayed.ps1`：开机后延迟 12 秒启动组件。

## 性能

- 时钟每秒更新；电池低频刷新；应用时长每 5 秒采样；媒体信息每秒更新；音量频谱以 10 FPS 更新；天气每 30 分钟更新。
- 组件不使用浏览器内核或独立渲染循环，频谱由一个低频 DispatcherTimer 驱动；组件隐藏时不重绘频谱条，恢复显示后自动继续。
- 拖动位置使用 300ms 防抖保存，避免持续写盘。
- Whisper 字幕模型在组件启动后静默预热；停止听写会释放麦克风，系统长时间无声时只释放扬声器回录，保留模型以缩短下一句字幕的等待。
- 左侧应用边栏保留原来的固定、运行中、最近使用与窗口预览功能。
