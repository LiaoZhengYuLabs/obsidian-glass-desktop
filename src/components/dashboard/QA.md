# macOS 桌面小组件 QA

日期：2026-07-14

## 视觉

- 最终小组件截图：`mac-widget-live-final.png`。
- 最终 Dock 截图：`..\ObsidianAIDock\native-dock-three-zones-window.png`。
- 保留边栏截图：`..\ObsidianAIWorkspace\sidebar-preserved-final.png`。
- 小组件物理尺寸为 `700 x 1376`（200% DPI），各卡片无重叠或裁切。
- 天气符号使用 Windows 自带 `Segoe UI Symbol`，已消除缺字方框。

## 功能

| 项目 | 结果 |
| --- | --- |
| 天气与五日预报 | 通过，真实数据和本地缓存均可用 |
| 模拟时钟、日历、电池 | 通过，显示实时本机状态 |
| 媒体标题与媒体按键 | 通过 |
| 普通话语音转文字 | 通过，启动/停止状态与本地 zh-CN 识别器正常 |
| 简体中文转换 | 通过，繁体测试文本可转换为简体 |
| Dock 三分区 | 通过，14 个应用、2 条分隔线、1 个废纸篓 |
| 左侧应用边栏 | 通过，原脚本未改，原三段应用布局与预览功能保留 |

## 运行与安全

- Windows PowerShell 5.1 语法、XAML 与 JSON 校验通过。
- Dashboard、Sidebar、Dock_64、Dockmod64 各保持一个实例。
- Dashboard 非置顶、不抢前台焦点。
- 没有注册表写入、系统文件替换或个人文件删除。
- `restore_mac_widget_reference.ps1` 可恢复本次小组件与 Dock 配置，且不处理应用边栏。

最终结果：通过。
