# Phase 3 QA

## Scope

Phase 3 adds live hover previews without activating source windows. It supports one or multiple top-level windows, direct per-window selection, restrained transitions, pointer reflection, and immediate thumbnail cleanup. Right-click management and global window treatment remain outside this phase.

## Evidence

- Selected source: `assets/selected-ink-arc.png`
- Single-window capture: `phase3-vscode-preview.png`
- Multi-window capture: `phase3-multi-preview.png`
- Combined design comparison: `phase3-design-comparison.png`
- Runtime log: `logs/sidebar.log`
- Viewport: 3200 x 2000 physical pixels at 200% Windows scaling

## Functional Verification

- Visual Studio Code live DWM preview: passed
- Source window remains inactive while hovering: passed
- Foreground before hover: ChatGPT
- Foreground during preview hover: ChatGPT
- Preview card click activates Visual Studio Code: passed
- Two Microsoft Paint windows render as separate live cards: passed
- Second-card click changed foreground PID from 39472 to 28692: passed
- Moving from the icon into the preview keeps it open: passed
- Leaving the preview fades it and makes the host window invisible: passed
- DWM thumbnails unregister when the preview closes: passed
- Restore while a preview is visible closes both preview and sidebar: passed
- Restore clears generated recent state without touching user files: passed
- Restart after restore returns to exactly one sidebar process: passed
- Existing icon click, edge reveal, auto-hide, recent apps, and running apps remain functional: passed
- PowerShell 5.1 syntax parse: passed

## Architecture And Performance

- Preview source: Windows DWM thumbnail compositor
- Screenshot polling loops: none
- Hover delay: 300 ms
- Hide delay: 280 ms
- Fade duration: 160 ms
- Maximum simultaneous preview cards: 6
- Visible-preview 10-second CPU sample: 0.359 CPU seconds
- Normalized total CPU during preview: approximately 0.224%
- Working set during preview: approximately 256 MB

## Visual Review

- The preview uses a quiet black obsidian surface, silver edge, rounded Windows 11 corners, and restrained blue-purple reflection.
- Single-window previews remain compact and legible.
- Multiple windows use a two-column grid with one title per card.
- No persistent labels or large text were added to the sidebar.
- Preview placement clears the Seelen top bars and the bottom Dock.

final result: passed
