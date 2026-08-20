# Phase 2 QA

## Scope

Phase 2 adds visible application detection, fixed-app running indicators, a current-app region, recent-app persistence, existing-window activation, and recent-app relaunch. Live previews are intentionally reserved for Phase 3.

## Evidence

- Selected source: `assets/selected-ink-arc.png`
- Running-app capture: `phase2-running.png`
- Running and recent capture: `phase2-recent.png`
- Combined full-view and focused comparison: `phase2-design-comparison.png`
- Runtime log: `logs/sidebar.log`
- Recent state: `state/recent-apps.csv`
- Viewport: 3200 x 2000 physical pixels at 200% Windows scaling
- Sidebar size: 90 x 590 DIP, approximately 59% of screen height

## Functional Verification

- Visible top-level window scan: passed
- Seelen UI, NVIDIA overlay, desktop, and taskbar filtering: passed
- ChatGPT and Visual Studio Code fixed running indicators: passed
- File Explorer, WeChat, Notepad, and QuickQ dynamic icons: passed
- Elevated QuickQ detection without sidebar elevation: passed
- Microsoft Paint running-to-recent transition: passed
- Recent Microsoft Paint relaunch: passed
- Relaunched application removed from recent: passed
- Running Notepad activation without duplicate launch: passed
- Auto-hide, edge reveal, hover, and reflection regression checks: passed
- PowerShell 5.1 syntax parse: passed
- Single-instance protection: passed
- Restore stops the sidebar and clears generated recent state: passed
- Restart after restore returns to one clean instance: passed
- Latest clean runtime session contains no scan errors: passed

## Performance

- Scanner interval: 1800 ms
- UI rebuilds: only when running or recent app keys change
- 10-second idle sample: 0.375 CPU seconds
- Normalized total CPU during sample: approximately 0.234%
- Working set during sample: approximately 228 MB

## Visual Review

- Fixed, running, and recent areas are separated by two restrained silver lines.
- Four running icons and three recent icons fit without scrolling; additional items remain mouse-wheel scrollable.
- Running state uses a small blue-silver dot rather than text inside the rail.
- Tooltips identify `RUNNING` and `RECENT` state without adding persistent labels.
- The rail remains clear of the Seelen top bars and the bottom Dock.

final result: passed
