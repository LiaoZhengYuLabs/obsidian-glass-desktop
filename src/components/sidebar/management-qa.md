# Phase 5 Management QA

## Visual comparison

- Combined reference and implementation review: `management-design-comparison.png`
- Application menu capture: `management-context-menu.png`
- Rail menu capture: `management-rail-menu.png`
- Native application selector capture: `management-file-dialog-native.png`
- Native folder selector capture: `management-folder-dialog-native.png`

The menus preserve the selected Ink Arc direction: near-black glass, restrained silver borders, compact spacing, and no bright native menu gutter. Both menus remain inside the narrow interaction footprint and keep the primary desktop visible.

## Interaction verification

- Right-click fixed application opens the application management menu.
- Pin and unpin update persistent layout state.
- Rename persists after a process restart.
- Change icon accepts `.ico`, image, executable, and shortcut sources.
- Open file location opened Explorer and selected the Visual Studio Code shortcut.
- Remove hides a fixed application without deleting its shortcut or executable.
- Restore hidden apps returns removed fixed applications.
- Add application created a pinned Notepad entry from the native file selector.
- Add folder created a pinned DesktopClean entry from the native folder selector.
- Add website created and persisted a valid HTTPS entry.
- Restore default layout removed every temporary QA entry and returned exactly five built-in entries.
- Native dialog cancellation returns control to the sidebar and logs that monitoring is active.

## Safety verification

- Application and folder entries store references only.
- No target executable, shortcut, folder, or website data is moved or deleted.
- Custom state is isolated to `state\app-layout.json`.
- `restore.ps1` removes generated layout state but does not uninstall software or delete user files.
- The final state contains no temporary QA entry or temporary QA folder.

final result: passed
