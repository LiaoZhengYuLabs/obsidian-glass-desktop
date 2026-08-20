# Phase 4 QA

## Scope

Phase 4 adds hardware-adaptive quality, reversible DWM window treatment, native transition preservation, compatibility exclusions, and a game-safe fullscreen mode. It does not inject into applications, alter process priority, change client opacity, resize user windows, edit the registry, or replace system files.

## Evidence

- Selected direction: `assets/selected-ink-arc.png`
- Original Explorer capture: `phase4-before.png`
- Styled Explorer capture: `phase4-after.png`
- Restored Explorer capture: `phase4-restored.png`
- Combined comparison: `phase4-design-comparison.png`
- Hardware profile: `state/hardware-profile.json`
- Active restore records: `state/window-style-state.csv`
- Runtime log: `logs/sidebar.log`

## Hardware Profile

- CPU: Intel Core Ultra 7 356H, 16 cores
- Memory: 31.5 GB
- GPU: Intel Graphics and NVIDIA GeForce RTX 5060 Laptop GPU
- Detected dedicated VRAM: 8151 MB
- Display: 3200 x 2000 at 120 Hz
- Windows: Windows 11 build 26200
- Native client animation: enabled
- Selected quality: High
- Cached startup readiness: approximately 2.2 seconds

## Functional Verification

- Existing application backdrop values remain unchanged: passed
- Windows without a backdrop receive Mica instead of bright Acrylic: passed
- Explorer, Notepad, and Paint use black caption, silver edge, and light title text: passed
- Electron and custom-drawn apps are not forced to use native caption colors: passed
- New Paint window receives a saved style record automatically: passed
- Paint style record is pruned after the test window closes: passed
- PowerShell, Windows Terminal, console hosts, phtrun, Seelen UI, Dock, and NVIDIA overlays are excluded: passed
- Borderless fullscreen test enables game-safe mode: passed
- Sidebar moves from -78 to -200 while fullscreen is active: passed
- Sidebar returns to -78 after fullscreen closes: passed
- Fullscreen polling interval changes from 1.8 to 5 seconds: passed
- No client-area opacity or window-size mutation: passed

## Restore Verification

- Stop restores all live records and removes `window-style-state.csv`: passed
- Explorer dark-mode value returned to its original value: passed
- Explorer corner preference returned from 2 to its original value 0: passed
- Explorer backdrop remained/restored to its original type 4: passed
- Native color attributes restore through the documented Windows default value: passed
- Full `restore.ps1` test leaves zero sidebar processes and no style/recent state: passed
- Restart after restore returns to exactly one process and reapplies only eligible windows: passed
- Read-only hardware cache remains available so later starts avoid repeated hardware probing: passed
- Restored title-region mean absolute channel difference versus the original: 3.627
- Restored title-region identical-pixel share: 75.71%

## Performance

- Style work is throttled to 2500 ms on this High profile.
- Existing styled windows are not rewritten every scan.
- 10-second idle sample: 0.500 CPU seconds
- Normalized total CPU: approximately 0.312%
- Working set: approximately 209 MB
- Fullscreen mode lowers scanning frequency and removes the rail from the active screen area.

## Visual Review

- The Explorer title area stays black instead of becoming gray Acrylic.
- The outer edge is visible but restrained, with no neon treatment.
- Native application materials remain coherent with Windows 11 dark mode.
- Client content, layout, text, and controls are unchanged.
- No P0, P1, or P2 visual issue remains in the before, styled, and restored comparison.

final result: passed
