# Functional Three-Zone Dock QA

日期：2026-07-14

## 需求核对

| 需求 | 权威证据 | 结果 |
| --- | --- | --- |
| 左区固定全部应用 | UI Automation 实测 `fixed app:*` 共 14 项，与 MyDockFinder 的 14 个 `filepath` 一致 | 通过 |
| 中区负责当前运行 | 临时 QA 窗口启动后，`running app: Windows PowerShell` 出现；运行区来自实时窗口枚举 | 通过 |
| 右区页面驻留 | 临时窗口最小化后出现 `Retained page: Dock Retention QA 20260714` | 通过 |
| 点击恢复精确页面 | 页面按钮支持 Invoke；点击后原窗口句柄从最小化恢复 | 通过 |
| 恢复后不再驻留 | 恢复后对应页面按钮自动消失，日志记录 `Page released` | 通过 |
| 多页面独立 | 当前微信、天禧、Chrome、QuickQ、Notepad 等最小化窗口分别形成独立卡片 | 通过 |
| 原应用边栏不变 | `ObsidianSidebar.ps1` 未修改，Sidebar 进程保持单实例 | 通过 |

## 闭环结果

`functional-retention-test.json` 记录：

- `MiddleDetectedWindowsPowerShell = true`
- `MinimizedBeforeInvoke = true`
- `RetainedPageButtonAppeared = true`
- `RetainedPageButtonEnabled = true`
- `WindowRestoredAfterClick = true`
- `RetainedPageRemovedAfterRestore = true`

## 视觉

- 最终截图：`functional-three-zone-final.png`。
- APPS 显示全部固定应用；ACTIVE 显示当前运行应用和圆点；PAGES 使用窗口标题卡片。
- Dock 物理尺寸为 `2840 x 232`（200% DPI），三个区域和分隔线均可辨认。
- 右侧页面卡不是应用图标副本，能直接区分同一应用的不同窗口标题。
- 当前 6 个驻留页面已同时完整显示；更多页面可在 PAGES 区横向滚动访问。
- 废纸篓位于最右端并使用正确的系统资源图标。

## 安全与性能

- Windows PowerShell 5.1 解析通过。
- 不修改 MyDockFinder 配置、系统注册表、Windows 核心文件或个人文件。
- Window Tracker 更新周期 1.4 秒；DWM 预览只在悬停后注册。
- 全屏安全模式实测可进入和退出，Dock 进程不会因此结束。
- `restore.ps1` 会停止自定义 Dock、恢复原生 MyDockFinder 并移除本模块开机入口。

最终结果：通过。
