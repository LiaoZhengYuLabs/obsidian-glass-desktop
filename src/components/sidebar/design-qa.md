# Phase 1 Design QA

## Evidence

- Source truth: `assets/selected-ink-arc.png`
- Implementation capture: `phase1-desktop-expanded.png`
- Combined comparison: `design-comparison.png`
- Viewport: 3200 x 2000 physical pixels, captured at 200% Windows scaling and reviewed at 1600 x 1000
- State: desktop visible, sidebar expanded, Visual Studio Code item hovered

The combined comparison contains both full desktop views and focused sidebar crops at the same review scale.

## Findings

- No P0, P1, or P2 visual defects remain.
- The implementation preserves the selected black obsidian surface, asymmetric arc, silver edge, restrained purple-blue reflection, vertical official icons, hover lens, and dark tooltip.
- The native rail is intentionally narrower than the concept image to meet the 70-90 DIP product constraint. It is 90 DIP wide and approximately 47% of the work area height.
- The rail clears the Seelen UI top bars and the existing bottom Dock.
- ChatGPT and Codex use their installed official local icon assets; those assets share the same OpenAI knot mark on this machine.

## Interaction And Performance

- Left-edge reveal: passed
- Automatic hide: passed
- Hover magnification and mouse-following reflection: passed
- Visual Studio Code launch: passed
- Single-instance protection: passed
- PowerShell 5.1 syntax parse: passed
- Idle CPU sample over 5 seconds: 0 seconds of added CPU time
- Idle working set: approximately 220 MB for the PowerShell 5.1 WPF host

## Fix History

1. Moved the expanded window origin to the physical left edge so the pointer cannot leave the rail while it animates open.
2. Attached the reflection to a translate transform so pointer movement actually changes its position.
3. Replaced the square system tooltip surface with a compact rounded dark label.

final result: passed
