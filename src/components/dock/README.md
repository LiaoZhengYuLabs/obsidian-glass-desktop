# Obsidian Glass AI Dock

这是当前启用的 Windows 11 功能型三区 Dock。它读取 MyDockFinder 已有应用，但不修改 `config.ini`、`ico.ini`、Windows 核心文件、壁纸或个人文件。

## 三个区域

### APPS：固定应用

- 固定显示当前 MyDockFinder 中的全部 14 个应用。
- 点击时优先激活已有窗口；未运行时启动应用。
- 可拖动调整顺序，顺序只保存到本项目的 `state/fixed-order.json`。

### ACTIVE：当前运行

- Window Tracker 每 1.4 秒读取真实可见窗口并按应用归组。
- 应用启动后自动出现，完全退出后自动离开。
- 显示运行圆点；点击会激活该应用的现有窗口。
- 这里不是固定列表，也不读取 APPS 的分类位置。

### PAGES：驻留页面

- 只显示当前真正处于最小化状态的窗口，每个窗口独立成一张页面卡。
- 卡片显示应用图标与窗口标题，多个同应用窗口不会合并。
- 悬停 500ms 显示 Windows DWM 实时窗口预览。
- 点击卡片恢复对应的精确窗口；窗口恢复或关闭后，卡片自动离开 PAGES。
- 页面状态来自实时窗口句柄，不使用“最近应用”或静态占位数据，也不跨重启伪造页面。

最右侧保留废纸篓。左侧桌面应用边栏和右侧小组件不由本模块控制。

## 视觉与性能

- 黑色玻璃、柔和白边、原图标、两条分区线。
- 图标悬停使用中心 `1.35`、相邻 `1.15` 的放大效果。
- 窗口预览由 DWM 合成，不持续截图、不写入窗口图片。
- 全屏电影或游戏期间 Dock 自动移到屏幕外并暂停点击；退出全屏后恢复。

## 使用

启动并启用开机启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDock\start.ps1
```

查看三区状态：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDock\status.ps1
```

暂时停止并恢复原生 MyDockFinder：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDock\stop.ps1
```

恢复原样并移除本模块开机入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\ObsidianAIDock\restore.ps1
```

恢复不会删除软件、快捷方式、MyDockFinder 配置或个人文件。

## 微信预览修复

- `fix_wechat_preview.ps1`：使用微信官方开始菜单快捷方式映射 `Weixin.exe`，移除会阻止运行窗口匹配的错误虚拟路径，并启用轻量窗口保护。
- `WeChatPreviewGuard.exe`：使用 Windows 原生窗口事件，只在出现第二个微信登录窗口时处理；不轮询、不读取聊天内容。
- `WeChatDockPreview.exe`：为微信 4.x 提供 500 毫秒悬停实时 DWM 预览；不截取图片到磁盘，不读取聊天内容。
- `restore_wechat_preview.ps1`：恢复修复前的 Dock 配置和微信快捷方式，并关闭窗口保护。
- 修复备份保存在 `backups/wechat-preview-*`，不会删除微信数据或个人文件。

## 微信运行黑点修复（2026-07-27）

MyDockFinder 在 2026-07-26 的 Steam 更新后，新版 `Dock_64.exe` 内置了对微信 4.x 窗口类
`Qt51514QWindowIcon` + `weixin.exe` 的特殊处理，导致微信运行时 Dock 图标下的黑点不再亮起
（配置层面的 realpath / virtualpath 均无法恢复匹配）。

- `WeChatDockDot.exe`：检测到 `Weixin.exe` 进程运行时，在 Dock 微信图标下绘制与原生一致的
  运行黑点；点击穿透、不抢焦点，Dock 隐藏或微信退出时黑点同步消失；不读取聊天内容。
- 图标定位复用 `WeChatDockPreview` 的绿色像素扫描；Dock 位置通过 `MyDockAPP` 窗口获取。
- `start_wechat_dock_dot.ps1`：启动并注册开机自启（Startup 文件夹快捷方式）。
- `stop_wechat_dock_dot.ps1`：停止并移除开机自启。
- 若后续 MyDockFinder 更新修复了微信窗口识别，运行 stop 脚本即可移除本工具。

## 验证文件

- `functional-three-zone-final.png`：三个功能区的最终视觉。
- `functional-retention-test.json`：页面最小化、生成卡片、点击恢复、卡片移除的闭环结果。
- `QA.md`：完整验证记录。
